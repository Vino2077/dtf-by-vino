#import <Foundation/Foundation.h>

/// Every DTF endpoint the client uses, in one place.
///
/// Paths and request shapes are carried over verbatim from the Android client,
/// where they are proven against the live API — including the per-feature API
/// versions (DTF serves different routes on different versions).

extern NSString *const kApiHost;
extern NSString *const kCdnHost;

/* API versions, per feature. */
extern NSString *const kApiDefault;    /* v2.31 — feed, content, profile, search */
extern NSString *const kApiComments;   /* v2.10 — comment tree and reactions */
extern NSString *const kApiMessenger;  /* v2.1  — direct messages */

@interface DTFApi : NSObject

+ (BOOL)isLoggedIn;

/* Reading. `feedType` is popular / new / my / editorial. */
+ (NSDictionary *)feed:(NSString *)feedType
                lastId:(NSString *)lastId
           lastSorting:(NSString *)lastSorting
                 error:(NSString **)error;
+ (NSDictionary *)post:(NSInteger)postId error:(NSString **)error;
+ (NSArray *)comments:(NSInteger)postId error:(NSString **)error;

/* Acting on content — all require a token. */
+ (BOOL)react:(NSInteger)contentId isComment:(BOOL)isComment reaction:(NSInteger)reactionId;
+ (BOOL)setFavorite:(NSInteger)contentId add:(BOOL)add;
+ (BOOL)addComment:(NSInteger)postId text:(NSString *)text replyTo:(NSInteger)replyTo;
+ (BOOL)subscribe:(NSInteger)subsiteId add:(BOOL)add;

/* Discovery and account. */
+ (NSArray *)search:(NSString *)query error:(NSString **)error;
+ (NSArray *)bookmarksWithError:(NSString **)error;
+ (NSArray *)notificationsWithError:(NSString **)error;
+ (NSInteger)notificationCount;
+ (NSDictionary *)meWithError:(NSString **)error;
+ (NSDictionary *)subsite:(NSInteger)subsiteId error:(NSString **)error;
+ (NSDictionary *)subsiteTimeline:(NSInteger)subsiteId error:(NSString **)error;

/* Direct messages. */
+ (NSArray *)channelsWithError:(NSString **)error;
+ (NSArray *)messages:(NSInteger)channelId error:(NSString **)error;
+ (BOOL)sendMessage:(NSInteger)channelId text:(NSString *)text;

/* Sign-in. Returns the token, or nil with `error` set. */
+ (NSString *)loginWithEmail:(NSString *)email password:(NSString *)password
                       error:(NSString **)error;
+ (BOOL)validateToken:(NSString *)token;

@end

/* Small JSON helpers — every response is treated as untrusted. */
NSString *DTFStr(id v);
NSInteger DTFInt(id v);
NSDictionary *DTFDict(id v);
NSArray *DTFArr(id v);

@interface DTFApi (Editor)
/// Creates a draft and publishes it. Returns the new post id, or 0.
+ (NSInteger)publishTitle:(NSString *)title
                     text:(NSString *)text
                subsiteId:(NSInteger)subsiteId
                    error:(NSString **)error;
@end
