#import "dtf_net.h"

#include <sys/time.h>
#include <sys/socket.h>
#include <pthread.h>
#include <string.h>
#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/error.h"
#include "mbedtls/platform_time.h"
#include "psa/crypto.h"

#include "ca_bundle.h"

static NSString *const kTokenKey = @"dtf_token";
static NSString *const kUserAgent = @"dtf-app/2.0.0 (iOS6; ru)";

/* iOS gained clock_gettime only in 10.0, so the mbedTLS millisecond clock
   cannot compile against a 6.0 deployment target. */
mbedtls_ms_time_t mbedtls_ms_time(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (mbedtls_ms_time_t)tv.tv_sec * 1000 + (mbedtls_ms_time_t)tv.tv_usec / 1000;
}

NSString *DTFToken(void)
{
    NSString *t = [[NSUserDefaults standardUserDefaults] objectForKey:kTokenKey];
    return [t length] > 0 ? t : nil;
}

void DTFSetToken(NSString *token)
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([token length] > 0) {
        [d setObject:token forKey:kTokenKey];
    } else {
        [d removeObjectForKey:kTokenKey];
    }
    [d synchronize];
}

static int gLastStatus = 0;

int DTFLastStatus(void) { return gLastStatus; }

/* Reusing the TLS session between requests.
 *
 * A full handshake means an ECDHE key exchange and a certificate chain check,
 * which on a 600 MHz single core costs seconds — and every screen makes
 * several requests. Keeping the negotiated session per host lets the next
 * connection resume it: no key exchange, no chain rebuild, just a couple of
 * round trips. This is the single biggest speed-up available here. */
#define DTF_HOST_SLOTS 4

typedef struct {
    char host[64];
    mbedtls_ssl_session session;
    int valid;
} DTFSessionSlot;

static DTFSessionSlot gSessions[DTF_HOST_SLOTS];
static pthread_mutex_t gSessionLock = PTHREAD_MUTEX_INITIALIZER;

static DTFSessionSlot *DTFSlotFor(const char *host)
{
    for (int i = 0; i < DTF_HOST_SLOTS; i++) {
        if (gSessions[i].host[0] != 0 && strcmp(gSessions[i].host, host) == 0) {
            return &gSessions[i];
        }
    }
    for (int i = 0; i < DTF_HOST_SLOTS; i++) {
        if (gSessions[i].host[0] == 0) {
            strncpy(gSessions[i].host, host, sizeof(gSessions[i].host) - 1);
            mbedtls_ssl_session_init(&gSessions[i].session);
            return &gSessions[i];
        }
    }
    return NULL;
}

static NSString *DTFErrText(const char *stage, int ret)
{
    char buf[192];
    mbedtls_strerror(ret, buf, sizeof(buf));
    return [NSString stringWithFormat:@"%s: -0x%04x (%s)", stage, (unsigned int)-ret, buf];
}

/* One request/response cycle over a fresh TLS connection. HTTP/1.0 is used so
   the server answers with a plain body and closes — no chunked decoding. */
static NSData *DTFRequest(NSString *host, NSString *path, NSString *method,
                          NSData *body, NSString *contentType, NSString **error)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{ psa_crypto_init(); });

    NSData *result = nil;
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

#define DTF_FAIL(stage, code) do { if (error) *error = DTFErrText(stage, code); goto cleanup; } while (0)

    ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                                (const unsigned char *)"dtf-ios6", 8);
    if (ret != 0) DTF_FAIL("rng", ret);

    ret = mbedtls_x509_crt_parse(&cacert, (const unsigned char *)CA_BUNDLE_PEM,
                                 sizeof(CA_BUNDLE_PEM));
    if (ret != 0) DTF_FAIL("roots", ret);

    ret = mbedtls_net_connect(&server, chost, "443", MBEDTLS_NET_PROTO_TCP);
    if (ret != 0) DTF_FAIL("connect", ret);

    /* Without these a stalled server leaves the caller waiting forever, and
       the screen just sits there with a spinner and no explanation. */
    {
        struct timeval tv;
        tv.tv_sec = 25;
        tv.tv_usec = 0;
        setsockopt(server.fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        setsockopt(server.fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
    }

    ret = mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                                      MBEDTLS_SSL_TRANSPORT_STREAM,
                                      MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) DTF_FAIL("config", ret);

    mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_REQUIRED);
    mbedtls_ssl_conf_ca_chain(&conf, &cacert, NULL);
    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);
    mbedtls_ssl_conf_read_timeout(&conf, 25000);

    ret = mbedtls_ssl_setup(&ssl, &conf);
    if (ret != 0) DTF_FAIL("setup", ret);
    ret = mbedtls_ssl_set_hostname(&ssl, chost);
    if (ret != 0) DTF_FAIL("sni", ret);
    mbedtls_ssl_set_bio(&ssl, &server, mbedtls_net_send, NULL, mbedtls_net_recv_timeout);

    /* Resume the previous session with this host when we have one. */
    pthread_mutex_lock(&gSessionLock);
    {
        DTFSessionSlot *slot = DTFSlotFor(chost);
        if (slot != NULL && slot->valid) mbedtls_ssl_set_session(&ssl, &slot->session);
    }
    pthread_mutex_unlock(&gSessionLock);

    while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
            DTF_FAIL("handshake", ret);
        }
    }

    pthread_mutex_lock(&gSessionLock);
    {
        DTFSessionSlot *slot = DTFSlotFor(chost);
        if (slot != NULL) {
            mbedtls_ssl_session_free(&slot->session);
            mbedtls_ssl_session_init(&slot->session);
            slot->valid = (mbedtls_ssl_get_session(&ssl, &slot->session) == 0);
        }
    }
    pthread_mutex_unlock(&gSessionLock);

    {
        NSMutableString *head = [NSMutableString stringWithFormat:
            @"%@ %@ HTTP/1.0\r\nHost: %@\r\nUser-Agent: %@\r\nAccept: application/json\r\n",
            method, path, host, kUserAgent];
        NSString *token = DTFToken();
        if (token != nil) [head appendFormat:@"X-Device-Token: %@\r\n", token];
        if (body != nil) {
            [head appendFormat:@"Content-Type: %@\r\nContent-Length: %d\r\n",
                contentType, (int)[body length]];
        }
        [head appendString:@"\r\n"];

        NSMutableData *out = [NSMutableData dataWithData:
            [head dataUsingEncoding:NSUTF8StringEncoding]];
        if (body != nil) [out appendData:body];

        const unsigned char *p = (const unsigned char *)[out bytes];
        size_t left = [out length];
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
            if (ret < 0) break;    /* closed mid-stream: keep what arrived */
            [raw appendBytes:buf length:(NSUInteger)ret];
        }

        const char *bytes = (const char *)[raw bytes];
        NSUInteger len = [raw length];

        /* "HTTP/1.1 400 Bad Request" -> 400, so failures can name themselves. */
        gLastStatus = 0;
        if (len > 12 && strncmp(bytes, "HTTP/", 5) == 0) {
            gLastStatus = atoi(bytes + 9);
        }

        NSUInteger start = 0;
        for (NSUInteger i = 0; i + 3 < len; i++) {
            if (bytes[i] == '\r' && bytes[i+1] == '\n' &&
                bytes[i+2] == '\r' && bytes[i+3] == '\n') { start = i + 4; break; }
        }
        if (start == 0 || start >= len) {
            if (error) *error = @"пустой ответ сервера";
        } else {
            result = [NSData dataWithBytes:bytes + start length:len - start];
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
    return result;
}

NSData *DTFGet(NSString *host, NSString *path, NSString **error)
{
    return DTFRequest(host, path, @"GET", nil, nil, error);
}

static NSString *DTFEscape(NSString *s)
{
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(
        NULL, (CFStringRef)s, NULL, CFSTR(":/?#[]@!$&'()*+,;="),
        kCFStringEncodingUTF8) autorelease];
}

NSData *DTFPostForm(NSString *host, NSString *path, NSDictionary *fields, NSString **error)
{
    NSMutableString *b = [NSMutableString string];
    for (NSString *k in fields) {
        if ([b length] > 0) [b appendString:@"&"];
        [b appendFormat:@"%@=%@", k, DTFEscape([[fields objectForKey:k] description])];
    }
    return DTFRequest(host, path, @"POST",
                      [b dataUsingEncoding:NSUTF8StringEncoding],
                      @"application/x-www-form-urlencoded; charset=utf-8", error);
}

NSData *DTFPostMultipart(NSString *host, NSString *path, NSDictionary *fields, NSString **error)
{
    NSString *boundary = @"----dtfios6boundary7a1c";
    NSMutableData *body = [NSMutableData data];
    for (NSString *k in fields) {
        NSString *part = [NSString stringWithFormat:
            @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n",
            boundary, k, [[fields objectForKey:k] description]];
        [body appendData:[part dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary]
                        dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *ctype = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    return DTFRequest(host, path, @"POST", body, ctype, error);
}

NSData *DTFPostJsonPart(NSString *host, NSString *path, NSString *partName,
                        NSData *json, NSString **error)
{
    NSString *boundary = @"----dtfios6boundary7a1c";
    NSMutableData *body = [NSMutableData data];
    NSString *head = [NSString stringWithFormat:
        @"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"entry.json\"\r\n"
         "Content-Type: application/json\r\n\r\n", boundary, partName];
    [body appendData:[head dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:json];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary]
                        dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *ctype = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    return DTFRequest(host, path, @"POST", body, ctype, error);
}
