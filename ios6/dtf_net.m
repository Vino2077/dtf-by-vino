#import "dtf_net.h"

#include <sys/time.h>
#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/error.h"
#include "mbedtls/platform_time.h"
#include "psa/crypto.h"

#include "ca_bundle.h"

/* iOS gained clock_gettime only in 10.0, so mbedTLS's own millisecond clock
   cannot compile against a 6.0 deployment target. */
mbedtls_ms_time_t mbedtls_ms_time(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (mbedtls_ms_time_t)tv.tv_sec * 1000 + (mbedtls_ms_time_t)tv.tv_usec / 1000;
}

static NSString *DTFErr(const char *stage, int ret)
{
    char buf[192];
    mbedtls_strerror(ret, buf, sizeof(buf));
    return [NSString stringWithFormat:@"%s: -0x%04x (%s)",
            stage, (unsigned int)-ret, buf];
}

NSData *DTFGet(NSString *host, NSString *path, NSString **error)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{ psa_crypto_init(); });

    NSMutableData *body = nil;
    int ret;

    mbedtls_net_context server;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    mbedtls_x509_crt cacert;

    mbedtls_net_init(&server);
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&conf);
    mbedtls_x509_crt_init(&cacert);
    mbedtls_ctr_drbg_init(&ctr_drbg);
    mbedtls_entropy_init(&entropy);

    const char *chost = [host UTF8String];

#define DTF_FAIL(stage, code) do { \
        if (error) *error = DTFErr(stage, code); \
        goto cleanup; \
    } while (0)

    ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                               (const unsigned char *)"dtf-ios6", 8);
    if (ret != 0) DTF_FAIL("rng", ret);

    ret = mbedtls_x509_crt_parse(&cacert, (const unsigned char *)CA_BUNDLE_PEM,
                                 sizeof(CA_BUNDLE_PEM));
    if (ret != 0) DTF_FAIL("roots", ret);

    ret = mbedtls_net_connect(&server, chost, "443", MBEDTLS_NET_PROTO_TCP);
    if (ret != 0) DTF_FAIL("connect", ret);

    ret = mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                                      MBEDTLS_SSL_TRANSPORT_STREAM,
                                      MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) DTF_FAIL("config", ret);

    mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_REQUIRED);
    mbedtls_ssl_conf_ca_chain(&conf, &cacert, NULL);
    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);

    ret = mbedtls_ssl_setup(&ssl, &conf);
    if (ret != 0) DTF_FAIL("setup", ret);
    ret = mbedtls_ssl_set_hostname(&ssl, chost);
    if (ret != 0) DTF_FAIL("sni", ret);
    mbedtls_ssl_set_bio(&ssl, &server, mbedtls_net_send, mbedtls_net_recv, NULL);

    while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
            DTF_FAIL("handshake", ret);
        }
    }

    /* HTTP/1.0 so the server answers with a plain body and closes — no need to
       decode chunked transfer encoding. */
    {
        NSString *req = [NSString stringWithFormat:
            @"GET %@ HTTP/1.0\r\nHost: %@\r\n"
             "User-Agent: DTF-by-Vino-iOS6\r\n"
             "Accept: application/json\r\n\r\n", path, host];
        const char *creq = [req UTF8String];
        size_t left = strlen(creq);
        const unsigned char *p = (const unsigned char *)creq;
        while (left > 0) {
            ret = mbedtls_ssl_write(&ssl, p, left);
            if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
            if (ret <= 0) DTF_FAIL("write", ret);
            p += ret;
            left -= (size_t)ret;
        }
    }

    {
        NSMutableData *raw = [NSMutableData data];
        unsigned char buf[4096];
        for (;;) {
            ret = mbedtls_ssl_read(&ssl, buf, sizeof(buf));
            if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
            if (ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY || ret == 0) break;
            if (ret < 0) break;   /* connection closed mid-stream: use what we have */
            [raw appendBytes:buf length:(NSUInteger)ret];
        }

        /* Split off the headers: body starts after the blank line. */
        const char *bytes = (const char *)[raw bytes];
        NSUInteger len = [raw length];
        NSUInteger start = 0;
        for (NSUInteger i = 0; i + 3 < len; i++) {
            if (bytes[i] == '\r' && bytes[i+1] == '\n' &&
                bytes[i+2] == '\r' && bytes[i+3] == '\n') {
                start = i + 4;
                break;
            }
        }
        if (start == 0 || start >= len) {
            if (error) *error = @"empty or malformed response";
        } else {
            body = [NSMutableData dataWithBytes:bytes + start length:len - start];
        }
    }

#undef DTF_FAIL

cleanup:
    mbedtls_ssl_close_notify(&ssl);
    mbedtls_net_free(&server);
    mbedtls_x509_crt_free(&cacert);
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&conf);
    mbedtls_ctr_drbg_free(&ctr_drbg);
    mbedtls_entropy_free(&entropy);
    return body;
}
