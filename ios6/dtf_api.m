#import "dtf_api.h"
#import "dtf_net.h"

NSString *const kApiHost = @"api.dtf.ru";
NSString *const kCdnHost = @"leonardo.osnova.io";

NSString *const kApiDefault = @"v2.31";
NSString *const kApiComments = @"v2.10";
NSString *const kApiMessenger = @"v2.1";

NSString *DTFStr(id v) { return [v isKindOfClass:[NSString class]] ? v : nil; }
NSInteger DTFInt(id v) { return [v respondsToSelector:@selector(integerValue)] ? [v integerValue] : 0; }
NSDictionary *DTFDict(id v) { return [v isKindOfClass:[NSDictionary class]] ? v : nil; }
NSArray *DTFArr(id v) { return [v isKindOfClass:[NSArray class]] ? v : nil; }

/* Decodes a response body and hands back its `result`, which is where every
   Osnova endpoint puts the payload. */
static id DTFResult(NSData *data, NSString **error)
{
    if (data == nil) return nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![root isKindOfClass:[NSDictionary class]]) {
        if (error && *error == nil) *error = @"ответ не разобрался";
        return nil;
    }
    id msg = [root objectForKey:@"message"];
    id result = [root objectForKey:@"result"];
    if (result == nil && [msg isKindOfClass:[NSString class]] && [msg length] > 0) {
        if (error) *error = msg;
    }
    return result;
}

static NSString *DTFPath(NSString *version, NSString *rest)
{
    return [NSString stringWithFormat:@"/%@/%@", version, rest];
}

static id DTFApiGet(NSString *version, NSString *rest, NSString **error)
{
    NSString *err = nil;
    NSData *d = DTFGet(kApiHost, DTFPath(version, rest), &err);
    if (err != nil && error) *error = err;
    return DTFResult(d, error);
}

@implementation DTFApi

+ (BOOL)isLoggedIn { return DTFToken() != nil; }

+ (NSDictionary *)feed:(NSString *)feedType
                lastId:(NSString *)lastId
           lastSorting:(NSString *)lastSorting
                 error:(NSString **)error
{
    NSMutableString *rest;
    if ([feedType isEqualToString:@"editorial"]) {
        rest = [NSMutableString stringWithString:
                @"search/posts?editorial=true&sorting=date&count=30"];
    } else {
        rest = [NSMutableString stringWithFormat:@"feed?pageName=%@&count=30", feedType];
    }
    if ([lastId length] > 0) [rest appendFormat:@"&lastId=%@", lastId];
    if ([lastSorting length] > 0) [rest appendFormat:@"&lastSortingValue=%@", lastSorting];

    id result = DTFApiGet(kApiDefault, rest, error);
    NSDictionary *d = DTFDict(result);
    if (d != nil) return d;
    /* Editorial search answers with a bare list. */
    NSArray *a = DTFArr(result);
    if (a != nil) return [NSDictionary dictionaryWithObject:a forKey:@"items"];
    return nil;
}

+ (NSDictionary *)post:(NSInteger)postId error:(NSString **)error
{
    id r = DTFApiGet(kApiDefault,
        [NSString stringWithFormat:@"content?id=%d", (int)postId], error);
    return DTFDict(r);
}

+ (NSArray *)comments:(NSInteger)postId error:(NSString **)error
{
    id r = DTFApiGet(kApiComments,
        [NSString stringWithFormat:@"comments?contentId=%d&sorting=hotness&count=100",
         (int)postId], error);
    NSDictionary *d = DTFDict(r);
    return d != nil ? DTFArr([d objectForKey:@"items"]) : DTFArr(r);
}

+ (BOOL)react:(NSInteger)contentId isComment:(BOOL)isComment reaction:(NSInteger)reactionId
{
    if (![self isLoggedIn]) return NO;
    NSString *kind = isComment ? @"comment" : @"content";
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat:@"%d", (int)reactionId], @"type",
        isComment ? @"comments" : @"feed", @"referer", nil];
    NSString *err = nil;
    NSData *d = DTFPostMultipart(kApiHost,
        DTFPath(kApiComments, [NSString stringWithFormat:@"%@/%d/react", kind, (int)contentId]),
        fields, &err);
    return d != nil && err == nil;
}

+ (BOOL)setFavorite:(NSInteger)contentId add:(BOOL)add
{
    if (![self isLoggedIn]) return NO;
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat:@"%d", (int)contentId], @"id", @"1", @"type", nil];
    NSString *err = nil;
    NSData *d = DTFPostForm(kApiHost,
        DTFPath(kApiDefault, add ? @"favorite" : @"unfavorite"), fields, &err);
    return d != nil && err == nil;
}

+ (BOOL)addComment:(NSInteger)postId text:(NSString *)text replyTo:(NSInteger)replyTo
{
    if (![self isLoggedIn] || [text length] == 0) return NO;
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat:@"%d", (int)postId], @"id", text, @"text", nil];
    if (replyTo > 0) {
        [fields setObject:[NSString stringWithFormat:@"%d", (int)replyTo] forKey:@"reply_to"];
    }
    NSString *err = nil;
    NSData *d = DTFPostMultipart(kApiHost, DTFPath(kApiDefault, @"comment/add"), fields, &err);
    if (d == nil) return NO;
    id root = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    return [root objectForKey:@"result"] != nil;
}

+ (BOOL)subscribe:(NSInteger)subsiteId add:(BOOL)add
{
    if (![self isLoggedIn]) return NO;
    /* The web client posts JSON here; form fields are accepted too. */
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat:@"%d", (int)subsiteId], @"id",
        add ? @"subscribe" : @"unsubscribe", @"action",
        @"false", @"isSubscribedToNotifications", nil];
    NSString *err = nil;
    NSData *d = DTFPostForm(kApiHost,
        DTFPath(kApiDefault, @"subsite/subscription"), fields, &err);
    return d != nil && err == nil;
}

+ (NSArray *)search:(NSString *)query error:(NSString **)error
{
    NSString *esc = [(NSString *)CFURLCreateStringByAddingPercentEscapes(
        NULL, (CFStringRef)query, NULL, CFSTR(":/?#[]@!$&'()*+,;="),
        kCFStringEncodingUTF8) autorelease];
    id r = DTFApiGet(kApiDefault,
        [NSString stringWithFormat:@"search?query=%@&section=entries&count=30", esc], error);
    NSArray *contents = DTFArr([DTFDict(r) objectForKey:@"contents"]);
    NSMutableArray *out = [NSMutableArray array];
    for (id c in contents) {
        NSDictionary *d = DTFDict(c);
        id payload = d != nil ? [d objectForKey:@"data"] : nil;
        [out addObject:payload != nil ? payload : c];
    }
    return out;
}

+ (NSArray *)bookmarksWithError:(NSString **)error
{
    if (![self isLoggedIn]) { if (error) *error = @"нужен вход в аккаунт"; return nil; }
    id r = DTFApiGet(kApiDefault, @"bookmarks?type=all&count=30&offset=0", error);
    NSDictionary *d = DTFDict(r);
    NSArray *items = d != nil ? DTFArr([d objectForKey:@"items"]) : DTFArr(r);
    NSMutableArray *out = [NSMutableArray array];
    for (id it in items) {
        NSDictionary *w = DTFDict(it);
        id payload = w != nil ? [w objectForKey:@"data"] : nil;
        [out addObject:payload != nil ? payload : it];
    }
    return out;
}

+ (NSArray *)notificationsWithError:(NSString **)error
{
    if (![self isLoggedIn]) { if (error) *error = @"нужен вход в аккаунт"; return nil; }
    id r = DTFApiGet(kApiDefault, @"subsite/me/updates?html=true&is_read=2", error);
    NSDictionary *d = DTFDict(r);
    return d != nil ? DTFArr([d objectForKey:@"items"]) : DTFArr(r);
}

+ (NSInteger)notificationCount
{
    if (![self isLoggedIn]) return 0;
    id r = DTFApiGet(kApiDefault, @"subsite/me/updates/count", NULL);
    NSDictionary *d = DTFDict(r);
    return d != nil ? DTFInt([d objectForKey:@"count"]) : DTFInt(r);
}

+ (NSDictionary *)meWithError:(NSString **)error
{
    if (![self isLoggedIn]) { if (error) *error = @"нужен вход в аккаунт"; return nil; }
    return DTFDict(DTFApiGet(kApiDefault, @"subsite/me", error));
}

+ (NSDictionary *)subsite:(NSInteger)subsiteId error:(NSString **)error
{
    id r = DTFApiGet(kApiDefault,
        [NSString stringWithFormat:@"subsite?id=%d", (int)subsiteId], error);
    NSDictionary *d = DTFDict(r);
    NSDictionary *inner = DTFDict([d objectForKey:@"subsite"]);
    return inner != nil ? inner : d;
}

+ (NSDictionary *)subsiteTimeline:(NSInteger)subsiteId error:(NSString **)error
{
    id r = DTFApiGet(kApiDefault,
        [NSString stringWithFormat:@"timeline?subsitesIds=%d&sorting=new&count=30",
         (int)subsiteId], error);
    return DTFDict(r);
}

+ (NSArray *)channelsWithError:(NSString **)error
{
    if (![self isLoggedIn]) { if (error) *error = @"нужен вход в аккаунт"; return nil; }
    id r = DTFApiGet(kApiMessenger, @"m/channels?page=1", error);
    NSDictionary *d = DTFDict(r);
    return d != nil ? DTFArr([d objectForKey:@"channels"]) : DTFArr(r);
}

+ (NSArray *)messages:(NSInteger)channelId error:(NSString **)error
{
    if (![self isLoggedIn]) return nil;
    id r = DTFApiGet(kApiMessenger,
        [NSString stringWithFormat:@"m/messages?channelId=%d&beforeTime=0", (int)channelId],
        error);
    NSDictionary *d = DTFDict(r);
    return d != nil ? DTFArr([d objectForKey:@"messages"]) : DTFArr(r);
}

+ (BOOL)sendMessage:(NSInteger)channelId text:(NSString *)text
{
    if (![self isLoggedIn] || [text length] == 0) return NO;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat:@"%d", (int)channelId], @"channelId",
        text, @"text",
        @"[]", @"media",
        [NSString stringWithFormat:@"%d", (int)(now * 1000) % 1000000000], @"idTmp",
        [NSString stringWithFormat:@"%.3f", now], @"ts", nil];
    NSString *err = nil;
    NSData *d = DTFPostForm(kApiHost, DTFPath(kApiMessenger, @"m/send"), fields, &err);
    return d != nil && err == nil;
}

+ (NSString *)loginWithEmail:(NSString *)email password:(NSString *)password
                       error:(NSString **)error
{
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
        email, @"email", password, @"password", nil];
    NSString *err = nil;
    NSData *d = DTFPostForm(kApiHost, @"/v3.0/auth/email/login", fields, &err);
    if (d == nil) { if (error) *error = err ? err : @"нет ответа"; return nil; }

    id root = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    NSDictionary *result = DTFDict([DTFDict(root) objectForKey:@"result"]);
    /* The token field has moved around between versions, so try the plausible
       names and keep the first one the server actually accepts. */
    NSArray *keys = [NSArray arrayWithObjects:@"token", @"accessToken",
                     @"access_token", @"jwt", @"deviceToken", nil];
    for (NSString *k in keys) {
        NSString *t = DTFStr([result objectForKey:k]);
        if ([t length] > 10 && [self validateToken:t]) return t;
    }
    if (error) {
        id msg = [DTFDict(root) objectForKey:@"message"];
        *error = [msg isKindOfClass:[NSString class]] && [msg length] > 0
                 ? msg : @"почта или пароль не подошли";
    }
    return nil;
}

+ (BOOL)validateToken:(NSString *)token
{
    NSString *saved = DTFToken();
    DTFSetToken(token);
    NSString *err = nil;
    id r = DTFApiGet(kApiDefault, @"subsite/me", &err);
    BOOL ok = DTFDict(r) != nil;
    if (!ok) DTFSetToken(saved);
    return ok;
}

@end

@implementation DTFApi (Editor)

+ (NSInteger)publishTitle:(NSString *)title
                     text:(NSString *)text
                subsiteId:(NSInteger)subsiteId
                    error:(NSString **)error
{
    if (![self isLoggedIn]) { if (error) *error = @"нужен вход в аккаунт"; return 0; }

    /* One text block per non-empty line — the editor stores post bodies as a
       list of blocks, same as the Android client builds. */
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSString *para in [text componentsSeparatedByString:@"\n"]) {
        NSString *t = [para stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([t length] == 0) continue;
        [blocks addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            @"text", @"type",
            [NSDictionary dictionaryWithObject:
                [NSString stringWithFormat:@"<p>%@</p>", t] forKey:@"text"], @"data",
            [NSNumber numberWithBool:NO], @"hidden",
            @"", @"anchor", nil]];
    }
    if ([blocks count] == 0) { if (error) *error = @"пустой текст"; return 0; }

    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:0], @"id",
        title ? title : @"", @"title",
        [NSNumber numberWithInt:0], @"user_id",
        [NSNumber numberWithInt:(int)subsiteId], @"subsite_id",
        [NSNumber numberWithBool:NO], @"is_adult",
        [NSDictionary dictionaryWithObject:blocks forKey:@"blocks"], @"entry", nil];

    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    if (json == nil) { if (error) *error = @"не собрался запрос"; return 0; }

    NSString *err = nil;
    NSData *d = DTFPostJsonPart(kApiHost, @"/v2.11/editor", @"entry", json, &err);
    if (d == nil) { if (error) *error = err ? err : @"нет ответа"; return 0; }

    id root = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    NSDictionary *result = DTFDict([DTFDict(root) objectForKey:@"result"]);
    NSInteger newId = DTFInt([result objectForKey:@"id"]);
    if (newId == 0) newId = DTFInt([DTFDict([result objectForKey:@"entry"]) objectForKey:@"id"]);
    if (newId == 0) {
        id msg = [DTFDict(root) objectForKey:@"message"];
        if (error) {
            *error = ([msg isKindOfClass:[NSString class]] && [msg length] > 0)
                     ? msg : @"черновик не создался";
        }
        return 0;
    }

    NSData *pub = DTFPostForm(kApiHost,
        [NSString stringWithFormat:@"/v2.11/editor/%d/publish", (int)newId],
        [NSDictionary dictionary], &err);
    if (pub == nil && error) *error = @"черновик создан, но не опубликовался";
    return newId;
}

@end
