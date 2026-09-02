#import <Foundation/Foundation.h>

/// Fetches an https URL, bypassing the system networking stack entirely.
///
/// iOS 6's own stack cannot reach DTF (it has no AES-GCM and lacks the modern
/// Let's Encrypt roots), so everything goes through a bundled mbedTLS over raw
/// sockets, with the roots compiled into the binary.
///
/// Returns nil and fills `error` on failure. Blocking — call off the main thread.
NSData *DTFGet(NSString *host, NSString *path, NSString **error);
