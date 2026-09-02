/*
 * DTF by Vino — iOS 6 connectivity probe.
 *
 * iOS 6's own networking stack cannot reach api.dtf.ru: the server only
 * accepts TLS 1.2 with AES-GCM, which SecureTransport of that era does not
 * implement, and its Let's Encrypt root is absent from the 2012 trust store.
 * (Confirmed on-device: Safari fails with "cannot establish a secure
 * connection" before certificate checking is even reached.)
 *
 * This probe bypasses the system stack entirely: raw BSD sockets plus a
 * bundled mbedTLS, with the ISRG roots compiled in. It reports each stage
 * separately so a failure tells us exactly which wall we hit.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/error.h"

#define HOST "api.dtf.ru"
#define PORT "443"
#define PATH "/v2.31/feed?pageName=popular&count=1"

/* ca_bundle.h is generated at build time from ca_bundle.pem */
#include "ca_bundle.h"

#include <sys/time.h>
#include "mbedtls/platform_time.h"
#include "psa/crypto.h"

/* iOS gained clock_gettime only in 10.0, so mbedTLS's default millisecond
   clock cannot compile against a 6.0 deployment target. Supply our own via
   gettimeofday (MBEDTLS_PLATFORM_MS_TIME_ALT is set on the command line). */
mbedtls_ms_time_t mbedtls_ms_time(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (mbedtls_ms_time_t)tv.tv_sec * 1000 + (mbedtls_ms_time_t)tv.tv_usec / 1000;
}

static void fail(const char *stage, int ret) {
    char buf[256];
    mbedtls_strerror(ret, buf, sizeof(buf));
    printf("[FAIL] %s: -0x%04x (%s)\n", stage, (unsigned int)-ret, buf);
}

int main(void) {
    int ret;
    mbedtls_net_context server;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    mbedtls_x509_crt cacert;

    setvbuf(stdout, NULL, _IONBF, 0);
    psa_crypto_init();
    printf("=== DTF probe for iOS 6 ===\n");
    printf("target: https://%s%s\n\n", HOST, PATH);

    mbedtls_net_init(&server);
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&conf);
    mbedtls_x509_crt_init(&cacert);
    mbedtls_ctr_drbg_init(&ctr_drbg);
    mbedtls_entropy_init(&entropy);

    /* --- 1. RNG ------------------------------------------------------- */
    ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                                (const unsigned char *)"dtf-ios6", 8);
    if (ret != 0) { fail("1 rng", ret); return 1; }
    printf("[ OK ] 1. random generator\n");

    /* --- 2. bundled roots --------------------------------------------- */
    ret = mbedtls_x509_crt_parse(&cacert, (const unsigned char *)CA_BUNDLE_PEM,
                                 sizeof(CA_BUNDLE_PEM));
    if (ret != 0) { fail("2 ca parse", ret); return 1; }
    printf("[ OK ] 2. bundled CA roots loaded\n");

    /* --- 3. TCP ------------------------------------------------------- */
    ret = mbedtls_net_connect(&server, HOST, PORT, MBEDTLS_NET_PROTO_TCP);
    if (ret != 0) { fail("3 tcp connect", ret); return 1; }
    printf("[ OK ] 3. TCP connected to %s:%s\n", HOST, PORT);

    /* --- 4. TLS handshake --------------------------------------------- */
    ret = mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                                      MBEDTLS_SSL_TRANSPORT_STREAM,
                                      MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) { fail("4 config", ret); return 1; }

    /* Verify but don't abort, so stage 5 can report the exact reason. */
    mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_OPTIONAL);
    mbedtls_ssl_conf_ca_chain(&conf, &cacert, NULL);
    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);

    ret = mbedtls_ssl_setup(&ssl, &conf);
    if (ret != 0) { fail("4 setup", ret); return 1; }
    ret = mbedtls_ssl_set_hostname(&ssl, HOST);   /* SNI — required */
    if (ret != 0) { fail("4 sni", ret); return 1; }
    mbedtls_ssl_set_bio(&ssl, &server, mbedtls_net_send, mbedtls_net_recv, NULL);

    while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
            fail("4 handshake", ret);
            return 1;
        }
    }
    printf("[ OK ] 4. TLS handshake: %s / %s\n",
           mbedtls_ssl_get_version(&ssl), mbedtls_ssl_get_ciphersuite(&ssl));

    /* --- 5. certificate ----------------------------------------------- */
    {
        uint32_t flags = mbedtls_ssl_get_verify_result(&ssl);
        if (flags == 0) {
            printf("[ OK ] 5. certificate verified against bundled roots\n");
        } else {
            char vrfy[512];
            mbedtls_x509_crt_verify_info(vrfy, sizeof(vrfy), "        ", flags);
            printf("[FAIL] 5. certificate rejected:\n%s", vrfy);
        }
    }

    /* --- 6. HTTPS request --------------------------------------------- */
    {
        char req[512];
        int len = snprintf(req, sizeof(req),
                           "GET %s HTTP/1.1\r\nHost: %s\r\n"
                           "User-Agent: dtf-ios6-probe\r\n"
                           "Connection: close\r\n\r\n", PATH, HOST);
        const unsigned char *p = (const unsigned char *)req;
        int left = len;
        while (left > 0) {
            ret = mbedtls_ssl_write(&ssl, p, left);
            if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
            if (ret <= 0) { fail("6 write", ret); return 1; }
            p += ret; left -= ret;
        }
        printf("[ OK ] 6. request sent\n");
    }

    /* --- 7. response --------------------------------------------------- */
    {
        unsigned char buf[2048];
        long total = 0;
        int printed_status = 0;
        for (;;) {
            ret = mbedtls_ssl_read(&ssl, buf, sizeof(buf) - 1);
            if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
            if (ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY || ret == 0) break;
            if (ret < 0) { fail("7 read", ret); break; }
            if (!printed_status) {
                buf[ret] = '\0';
                char *nl = strchr((char *)buf, '\r');
                if (nl) *nl = '\0';
                printf("[ OK ] 7. response: %s\n", (char *)buf);
                printed_status = 1;
            }
            total += ret;
        }
        printf("\n>>> received %ld bytes of feed data\n", total);
        printf(total > 1000 ? ">>> RESULT: SUCCESS — iOS 6 CAN talk to DTF\n"
                            : ">>> RESULT: connected but no data\n");
    }

    mbedtls_ssl_close_notify(&ssl);
    mbedtls_net_free(&server);
    mbedtls_x509_crt_free(&cacert);
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&conf);
    mbedtls_ctr_drbg_free(&ctr_drbg);
    mbedtls_entropy_free(&entropy);
    return 0;
}
