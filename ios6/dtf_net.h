#import <Foundation/Foundation.h>

/// Low-level HTTPS for the whole app, bypassing the system networking stack.
///
/// iOS 6 cannot reach DTF on its own: the server accepts only TLS 1.2 with
/// AES-GCM (which SecureTransport of that era does not implement) and its
/// Let's Encrypt root is absent from the 2012 trust store. Everything here
/// therefore runs over raw sockets with a bundled mbedTLS and the roots
/// compiled into the binary.
///
/// All calls block — never run them on the main thread.

/// GET. Returns the response body, or nil with `error` filled.
NSData *DTFGet(NSString *host, NSString *path, NSString **error);

/// POST with an application/x-www-form-urlencoded body built from `fields`.
NSData *DTFPostForm(NSString *host, NSString *path,
                    NSDictionary *fields, NSString **error);

/// POST with a multipart/form-data body — what DTF wants for comment/add,
/// the reaction endpoints and the editor.
NSData *DTFPostMultipart(NSString *host, NSString *path,
                         NSDictionary *fields, NSString **error);

/// The token sent as `X-Device-Token` on every request once signed in.
/// Stored in user defaults; nil when signed out.
NSString *DTFToken(void);
void DTFSetToken(NSString *token);

/// POST with a multipart body carrying one JSON part — the shape the editor
/// endpoint wants (`entry` = the whole post as application/json).
NSData *DTFPostJsonPart(NSString *host, NSString *path, NSString *partName,
                        NSData *json, NSString **error);

/// HTTP status of the most recent request on this thread — used to explain
/// failures ("HTTP 400" tells far more than a blank screen).
int DTFLastStatus(void);
