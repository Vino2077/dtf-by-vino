/*
 * DTF by Vino — iOS 6 client.
 *
 * Written against UIKit of 2012 and built with manual retain/release (the ARC
 * runtime support library is no longer shipped for a 6.0 deployment target).
 *
 * Everything on the wire goes through DTFGet — see dtf_net.h for why the
 * system networking stack cannot be used at all here. That has one important
 * consequence for the post screen: a UIWebView cannot fetch its own images
 * either, so images are downloaded by us and inlined into the HTML as data
 * URIs. Laying the article out as HTML also saves hand-computing text heights
 * with UIKit APIs that differ across these old SDKs.
 */
#import <UIKit/UIKit.h>
#import "dtf_net.h"

static NSString *const kApiHost = @"api.dtf.ru";
static NSString *const kCdnHost = @"leonardo.osnova.io";

/* iOS 6 predates base64EncodedStringWithOptions:, so encode it ourselves. */
static NSString *DTFBase64(NSData *data)
{
    static const char *tbl = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const unsigned char *in = (const unsigned char *)[data bytes];
    NSUInteger len = [data length];
    NSMutableData *out = [NSMutableData dataWithLength:((len + 2) / 3) * 4];
    char *o = (char *)[out mutableBytes];
    NSUInteger i = 0, j = 0;
    while (i + 2 < len) {
        unsigned int v = (in[i] << 16) | (in[i+1] << 8) | in[i+2];
        o[j++] = tbl[(v >> 18) & 63]; o[j++] = tbl[(v >> 12) & 63];
        o[j++] = tbl[(v >> 6) & 63];  o[j++] = tbl[v & 63];
        i += 3;
    }
    if (i + 1 == len) {
        unsigned int v = in[i] << 16;
        o[j++] = tbl[(v >> 18) & 63]; o[j++] = tbl[(v >> 12) & 63];
        o[j++] = '='; o[j++] = '=';
    } else if (i + 2 == len) {
        unsigned int v = (in[i] << 16) | (in[i+1] << 8);
        o[j++] = tbl[(v >> 18) & 63]; o[j++] = tbl[(v >> 12) & 63];
        o[j++] = tbl[(v >> 6) & 63];  o[j++] = '=';
    }
    return [[[NSString alloc] initWithData:out encoding:NSASCIIStringEncoding] autorelease];
}

/* A resized JPEG from the CDN. WebP is what DTF serves by default and iOS 6
   cannot decode it, so the format is pinned to jpeg. */
static NSString *DTFImagePath(NSString *uuid, int width)
{
    return [NSString stringWithFormat:@"/%@/-/preview/%d/-/format/jpeg/", uuid, width];
}

static NSString *DTFStr(id v)
{
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

static NSInteger DTFInt(id v)
{
    return [v respondsToSelector:@selector(integerValue)] ? [v integerValue] : 0;
}

/* ------------------------------------------------------------------ */
/* Image loading: one shared cache, one serial queue. A 600 MHz single-core
   phone must not run a dozen TLS handshakes at once.                   */
/* ------------------------------------------------------------------ */

@interface DTFImages : NSObject
+ (dispatch_queue_t)queue;
+ (UIImage *)cached:(NSString *)key;
+ (void)store:(UIImage *)img forKey:(NSString *)key;
+ (NSData *)fetchUuid:(NSString *)uuid width:(int)width;
@end

@implementation DTFImages

+ (dispatch_queue_t)queue
{
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("ru.vino.dtf.images", NULL); });
    return q;
}

+ (NSMutableDictionary *)store
{
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [[NSMutableDictionary alloc] init]; });
    return d;
}

+ (UIImage *)cached:(NSString *)key
{
    @synchronized ([self store]) { return [[self store] objectForKey:key]; }
}

+ (void)store:(UIImage *)img forKey:(NSString *)key
{
    if (img == nil || key == nil) return;
    @synchronized ([self store]) {
        /* Keep the cache small: this device has very little memory. */
        if ([[self store] count] > 60) [[self store] removeAllObjects];
        [[self store] setObject:img forKey:key];
    }
}

+ (NSData *)fetchUuid:(NSString *)uuid width:(int)width
{
    if ([uuid length] == 0) return nil;
    NSString *err = nil;
    return DTFGet(kCdnHost, DTFImagePath(uuid, width), &err);
}

@end

/* ------------------------------------------------------------------ */

@interface DTFPost : NSObject
@property (nonatomic, assign) NSInteger postId;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subsite;
@property (nonatomic, retain) NSString *author;
@property (nonatomic, retain) NSString *coverUuid;
@property (nonatomic, assign) NSInteger comments;
@property (nonatomic, assign) NSInteger reactions;
@end

@implementation DTFPost
@synthesize postId, title, subsite, author, coverUuid, comments, reactions;
- (void)dealloc
{
    [title release]; [subsite release]; [author release]; [coverUuid release];
    [super dealloc];
}
@end

static DTFPost *DTFPostFrom(id dict)
{
    DTFPost *p = [[[DTFPost alloc] init] autorelease];
    if (![dict isKindOfClass:[NSDictionary class]]) return p;

    p.postId = DTFInt([dict objectForKey:@"id"]);
    NSString *t = DTFStr([dict objectForKey:@"title"]);
    p.title = [t length] > 0 ? t : @"(без заголовка)";

    id sub = [dict objectForKey:@"subsite"];
    if ([sub isKindOfClass:[NSDictionary class]]) p.subsite = DTFStr([sub objectForKey:@"name"]);
    id au = [dict objectForKey:@"author"];
    if ([au isKindOfClass:[NSDictionary class]]) p.author = DTFStr([au objectForKey:@"name"]);

    id counters = [dict objectForKey:@"counters"];
    if ([counters isKindOfClass:[NSDictionary class]]) {
        p.comments = DTFInt([counters objectForKey:@"comments"]);
        p.reactions = DTFInt([counters objectForKey:@"reactions"]);
    }

    /* Cover thumbnail: the first image block in the post. */
    id blocks = [dict objectForKey:@"blocks"];
    if ([blocks isKindOfClass:[NSArray class]]) {
        for (id b in blocks) {
            if (![b isKindOfClass:[NSDictionary class]]) continue;
            if (![[b objectForKey:@"type"] isEqual:@"media"]) continue;
            id items = [[b objectForKey:@"data"] objectForKey:@"items"];
            if (![items isKindOfClass:[NSArray class]] || [items count] == 0) continue;
            id img = [[items objectAtIndex:0] objectForKey:@"image"];
            NSString *uuid = DTFStr([[img objectForKey:@"data"] objectForKey:@"uuid"]);
            if ([uuid length] > 0) { p.coverUuid = uuid; break; }
        }
    }
    return p;
}

/* ------------------------------------------------------------------ */
/* Post screen: the article rendered as HTML, images inlined.          */
/* ------------------------------------------------------------------ */

@interface PostViewController : UIViewController <UIWebViewDelegate>
@property (nonatomic, assign) NSInteger postId;
@property (nonatomic, retain) NSString *postTitle;
@property (nonatomic, retain) UIWebView *web;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@end

@implementation PostViewController
@synthesize postId, postTitle, web, spinner;

- (void)dealloc { [postTitle release]; [web release]; [spinner release]; [super dealloc]; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Пост";
    self.view.backgroundColor = [UIColor whiteColor];

    self.web = [[[UIWebView alloc] initWithFrame:self.view.bounds] autorelease];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.delegate = self;
    self.web.dataDetectorTypes = UIDataDetectorTypeNone;
    self.web.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.web];

    self.spinner = [[[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0f, 90.0f);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    [self loadPost];
}

/* Links cannot be followed inside the web view (it has no working network of
   its own), so hand them to Safari instead. */
- (BOOL)webView:(UIWebView *)wv
        shouldStartLoadWithRequest:(NSURLRequest *)request
        navigationType:(UIWebViewNavigationType)type
{
    if (type == UIWebViewNavigationTypeLinkClicked) {
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    }
    return YES;
}

- (NSString *)htmlHead
{
    return @"<html><head><meta name='viewport' content='width=device-width, initial-scale=1'>"
            "<style>"
            "body{font:15px/1.5 -apple-system,Helvetica,Arial;margin:0;padding:12px;color:#111;"
            "-webkit-text-size-adjust:none;word-wrap:break-word}"
            "h1{font-size:21px;line-height:1.25;margin:0 0 6px}"
            "h2{font-size:18px;margin:18px 0 6px}"
            ".meta{color:#888;font-size:12px;margin-bottom:14px}"
            "img{max-width:100%;height:auto;border-radius:4px;display:block;margin:12px 0}"
            "blockquote{margin:12px 0;padding:6px 0 6px 12px;border-left:3px solid #5b82f2;color:#555}"
            "a{color:#5b82f2;text-decoration:none}"
            ".sep{text-align:center;color:#bbb;letter-spacing:6px;margin:18px 0}"
            ".cmt{border-top:1px solid #eee;padding:10px 0}"
            ".cmt .who{font-weight:bold;font-size:13px}"
            ".cmt .when{color:#999;font-weight:normal;font-size:11px}"
            ".cmt .body{font-size:14px;margin-top:3px}"
            ".note{color:#999;font-size:12px;font-style:italic}"
            "</style></head><body>";
}

/* Renders the post body. Image uuids are collected into `uuids` so the caller
   can fetch them and re-render with the pictures inlined. */
- (NSString *)bodyHtmlFor:(NSDictionary *)post
                    uuids:(NSMutableArray *)uuids
                   images:(NSDictionary *)loaded
{
    NSMutableString *h = [NSMutableString string];
    NSString *title = DTFStr([post objectForKey:@"title"]);
    if ([title length] > 0) [h appendFormat:@"<h1>%@</h1>", title];

    NSString *who = nil;
    id au = [post objectForKey:@"author"];
    if ([au isKindOfClass:[NSDictionary class]]) who = DTFStr([au objectForKey:@"name"]);
    NSString *sub = nil;
    id sd = [post objectForKey:@"subsite"];
    if ([sd isKindOfClass:[NSDictionary class]]) sub = DTFStr([sd objectForKey:@"name"]);
    [h appendFormat:@"<div class='meta'>%@%@</div>",
        who ? who : @"", sub ? [NSString stringWithFormat:@" · %@", sub] : @""];

    id blocks = [post objectForKey:@"blocks"];
    if (![blocks isKindOfClass:[NSArray class]]) return h;

    for (id b in blocks) {
        if (![b isKindOfClass:[NSDictionary class]]) continue;
        NSString *type = DTFStr([b objectForKey:@"type"]);
        id data = [b objectForKey:@"data"];
        if (![data isKindOfClass:[NSDictionary class]]) continue;

        if ([type isEqualToString:@"text"]) {
            NSString *t = DTFStr([data objectForKey:@"text"]);
            if ([t length] > 0) [h appendFormat:@"<div>%@</div>", t];

        } else if ([type isEqualToString:@"header"]) {
            NSString *t = DTFStr([data objectForKey:@"text"]);
            if ([t length] > 0) [h appendFormat:@"<h2>%@</h2>", t];

        } else if ([type isEqualToString:@"quote"]) {
            NSString *t = DTFStr([data objectForKey:@"text"]);
            if ([t length] > 0) [h appendFormat:@"<blockquote>%@</blockquote>", t];

        } else if ([type isEqualToString:@"list"]) {
            id items = [data objectForKey:@"items"];
            if ([items isKindOfClass:[NSArray class]]) {
                [h appendString:@"<ul>"];
                for (id it in items) [h appendFormat:@"<li>%@</li>", it];
                [h appendString:@"</ul>"];
            }

        } else if ([type isEqualToString:@"delimiter"]) {
            [h appendString:@"<div class='sep'>* * *</div>"];

        } else if ([type isEqualToString:@"media"]) {
            id items = [data objectForKey:@"items"];
            if (![items isKindOfClass:[NSArray class]]) continue;
            for (id it in items) {
                id img = [it objectForKey:@"image"];
                id idata = [img objectForKey:@"data"];
                NSString *uuid = DTFStr([idata objectForKey:@"uuid"]);
                if ([uuid length] == 0) continue;
                NSString *b64 = [loaded objectForKey:uuid];
                if (b64 != nil) {
                    [h appendFormat:@"<img src='data:image/jpeg;base64,%@'>", b64];
                } else {
                    if (![uuids containsObject:uuid]) [uuids addObject:uuid];
                    [h appendString:@"<div class='note'>картинка загружается…</div>"];
                }
                NSString *cap = DTFStr([it objectForKey:@"title"]);
                if ([cap length] > 0) [h appendFormat:@"<div class='meta'>%@</div>", cap];
            }

        } else if ([type isEqualToString:@"link"]) {
            id ld = [[data objectForKey:@"link"] objectForKey:@"data"];
            NSString *url = DTFStr([ld objectForKey:@"url"]);
            NSString *ttl = DTFStr([ld objectForKey:@"title"]);
            if ([url length] > 0) {
                [h appendFormat:@"<div><a href='%@'>%@</a></div>", url, ttl ? ttl : url];
            }
        }
    }
    return h;
}

- (NSString *)commentsHtml:(id)items
{
    if (![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return @"<h2>Комментарии</h2><div class='note'>Пока пусто</div>";
    }
    NSMutableString *h = [NSMutableString stringWithFormat:@"<h2>Комментарии (%d)</h2>",
                          (int)[items count]];
    for (id c in items) {
        if (![c isKindOfClass:[NSDictionary class]]) continue;
        NSString *text = DTFStr([c objectForKey:@"text"]);
        if ([text length] == 0) continue;
        NSString *who = nil;
        id au = [c objectForKey:@"author"];
        if ([au isKindOfClass:[NSDictionary class]]) who = DTFStr([au objectForKey:@"name"]);
        NSInteger level = DTFInt([c objectForKey:@"level"]);
        NSInteger indent = level > 3 ? 3 : level;
        [h appendFormat:@"<div class='cmt' style='margin-left:%dpx'>"
                         "<div class='who'>%@</div><div class='body'>%@</div></div>",
                        (int)(indent * 12), who ? who : @"?", text];
    }
    return h;
}

- (void)loadPost
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSData *data = DTFGet(kApiHost,
            [NSString stringWithFormat:@"/v2.31/content?id=%d", (int)self.postId], &err);

        NSDictionary *post = nil;
        if (data != nil) {
            id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            id r = [root objectForKey:@"result"];
            if ([r isKindOfClass:[NSDictionary class]]) post = r;
        }

        if (post == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                NSString *page = [NSString stringWithFormat:
                    @"%@<div class='note'>Не удалось загрузить пост:<br>%@</div></body></html>",
                    [self htmlHead], err ? err : @"неизвестная ошибка"];
                [self.web loadHTMLString:page baseURL:nil];
            });
            return;
        }

        /* First pass: show the text straight away, images still pending. */
        NSMutableArray *uuids = [NSMutableArray array];
        NSString *body = [self bodyHtmlFor:post uuids:uuids images:[NSDictionary dictionary]];
        NSString *firstPass = [NSString stringWithFormat:@"%@%@</body></html>",
                               [self htmlHead], body];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            [self.web loadHTMLString:firstPass baseURL:nil];
        });

        /* Then the comments. */
        NSData *cdata = DTFGet(kApiHost,
            [NSString stringWithFormat:@"/v2.10/comments?contentId=%d&sorting=hotness&count=50",
             (int)self.postId], NULL);
        id citems = nil;
        if (cdata != nil) {
            id croot = [NSJSONSerialization JSONObjectWithData:cdata options:0 error:NULL];
            id r = [croot objectForKey:@"result"];
            citems = [r isKindOfClass:[NSDictionary class]] ? [r objectForKey:@"items"] : r;
        }
        NSString *cHtml = [self commentsHtml:citems];

        /* Finally the pictures, one at a time — this hardware cannot afford a
           burst of parallel TLS handshakes. Capped so a photo-heavy post does
           not stall for minutes. */
        NSMutableDictionary *loaded = [NSMutableDictionary dictionary];
        NSUInteger limit = [uuids count] < 8 ? [uuids count] : 8;
        for (NSUInteger i = 0; i < limit; i++) {
            NSString *uuid = [uuids objectAtIndex:i];
            NSData *img = [DTFImages fetchUuid:uuid width:300];
            if ([img length] > 0) [loaded setObject:DTFBase64(img) forKey:uuid];
        }

        NSString *body2 = [self bodyHtmlFor:post uuids:[NSMutableArray array] images:loaded];
        NSString *full = [NSString stringWithFormat:@"%@%@%@</body></html>",
                          [self htmlHead], body2, cHtml];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.web loadHTMLString:full baseURL:nil];
        });
    });
}

@end

/* ------------------------------------------------------------------ */
/* Feed screen                                                         */
/* ------------------------------------------------------------------ */

@interface FeedViewController : UITableViewController
@property (nonatomic, retain) NSMutableArray *posts;
@property (nonatomic, retain) UILabel *statusLabel;
@property (nonatomic, retain) NSString *feedName;
@property (nonatomic, retain) NSString *lastId;
@property (nonatomic, retain) NSString *lastSorting;
@property (nonatomic, assign) BOOL loading;
@end

@implementation FeedViewController
@synthesize posts, statusLabel, feedName, lastId, lastSorting, loading;

- (void)dealloc
{
    [posts release]; [statusLabel release]; [feedName release];
    [lastId release]; [lastSorting release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.posts = [NSMutableArray array];
    self.feedName = @"popular";
    self.tableView.rowHeight = 74.0f;

    UISegmentedControl *seg = [[[UISegmentedControl alloc]
        initWithItems:[NSArray arrayWithObjects:@"Популярное", @"Свежее", nil]] autorelease];
    seg.selectedSegmentIndex = 0;
    seg.segmentedControlStyle = UISegmentedControlStyleBar;
    [seg addTarget:self action:@selector(switchFeed:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = seg;

    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self
                             action:@selector(reload)] autorelease];

    self.statusLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(10.0f, 120.0f, self.view.bounds.size.width - 20.0f, 80.0f)] autorelease];
    self.statusLabel.textAlignment = UITextAlignmentCenter;
    self.statusLabel.numberOfLines = 5;
    self.statusLabel.font = [UIFont systemFontOfSize:13.0f];
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];

    [self reload];
}

- (void)switchFeed:(UISegmentedControl *)seg
{
    self.feedName = seg.selectedSegmentIndex == 0 ? @"popular" : @"new";
    [self reload];
}

- (void)reload
{
    self.lastId = nil;
    self.lastSorting = nil;
    [self.posts removeAllObjects];
    [self.tableView reloadData];
    self.statusLabel.hidden = NO;
    self.statusLabel.text = @"Загружаю ленту…";
    [self loadMore];
}

- (void)loadMore
{
    if (self.loading) return;
    self.loading = YES;

    NSString *feed = [[self.feedName copy] autorelease];
    NSString *lid = [[self.lastId copy] autorelease];
    NSString *lsort = [[self.lastSorting copy] autorelease];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableString *path = [NSMutableString stringWithFormat:
            @"/v2.31/feed?pageName=%@&count=30", feed];
        if ([lid length] > 0) [path appendFormat:@"&lastId=%@", lid];
        if ([lsort length] > 0) [path appendFormat:@"&lastSortingValue=%@", lsort];

        NSString *err = nil;
        NSData *data = DTFGet(kApiHost, path, &err);

        NSMutableArray *parsed = [NSMutableArray array];
        NSString *problem = err;
        NSString *newLastId = nil, *newLastSort = nil;

        if (data != nil) {
            id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            id result = [root objectForKey:@"result"];
            if (![result isKindOfClass:[NSDictionary class]]) {
                problem = @"ответ не разобрался";
            } else {
                id last = [result objectForKey:@"lastId"];
                if (last != nil && last != [NSNull null]) newLastId = [NSString stringWithFormat:@"%@", last];
                id ls = [result objectForKey:@"lastSortingValue"];
                if (ls != nil && ls != [NSNull null]) newLastSort = [NSString stringWithFormat:@"%@", ls];

                id items = [result objectForKey:@"items"];
                if ([items isKindOfClass:[NSArray class]]) {
                    for (id item in items) {
                        if (![item isKindOfClass:[NSDictionary class]]) continue;
                        id payload = [item objectForKey:@"data"];
                        if (![payload isKindOfClass:[NSDictionary class]]) continue;
                        id news = [payload objectForKey:@"news"];
                        if ([news isKindOfClass:[NSArray class]]) {
                            for (id n in news) [parsed addObject:DTFPostFrom(n)];
                        } else {
                            [parsed addObject:DTFPostFrom(payload)];
                        }
                    }
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.loading = NO;
            if (newLastId) self.lastId = newLastId;
            if (newLastSort) self.lastSorting = newLastSort;
            [self.posts addObjectsFromArray:parsed];

            if ([self.posts count] > 0) {
                self.statusLabel.hidden = YES;
            } else {
                self.statusLabel.hidden = NO;
                self.statusLabel.text = [NSString stringWithFormat:@"Не вышло:\n%@",
                                         problem ? problem : @"лента пустая"];
            }
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self.posts count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"post";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:ident] autorelease];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    DTFPost *p = [self.posts objectAtIndex:(NSUInteger)ip.row];
    cell.textLabel.text = p.title;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %d ♥ · %d 💬",
                                 p.subsite ? p.subsite : @"DTF",
                                 (int)p.reactions, (int)p.comments];

    /* Thumbnail, lazily and one at a time. */
    cell.imageView.image = nil;
    if ([p.coverUuid length] > 0) {
        UIImage *hit = [DTFImages cached:p.coverUuid];
        if (hit != nil) {
            cell.imageView.image = hit;
        } else {
            NSString *uuid = [[p.coverUuid copy] autorelease];
            NSInteger row = ip.row;
            dispatch_async([DTFImages queue], ^{
                if ([DTFImages cached:uuid] != nil) return;
                NSData *d = [DTFImages fetchUuid:uuid width:120];
                UIImage *img = [d length] > 0 ? [UIImage imageWithData:d] : nil;
                if (img == nil) return;
                [DTFImages store:img forKey:uuid];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSIndexPath *now = [NSIndexPath indexPathForRow:row inSection:0];
                    if (row < (NSInteger)[self.posts count]) {
                        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:now]
                                              withRowAnimation:UITableViewRowAnimationNone];
                    }
                });
            });
        }
    }

    /* Reaching the end pulls the next page. */
    if (ip.row == (NSInteger)[self.posts count] - 1) [self loadMore];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    DTFPost *p = [self.posts objectAtIndex:(NSUInteger)ip.row];
    PostViewController *vc = [[[PostViewController alloc] init] autorelease];
    vc.postId = p.postId;
    vc.postTitle = p.title;
    [self.navigationController pushViewController:vc animated:YES];
}

@end

/* ------------------------------------------------------------------ */

@interface AppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, retain) UIWindow *window;
@end

@implementation AppDelegate
@synthesize window;

- (void)dealloc { [window release]; [super dealloc]; }

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    FeedViewController *feed = [[[FeedViewController alloc]
        initWithStyle:UITableViewStylePlain] autorelease];
    UINavigationController *nav = [[[UINavigationController alloc]
        initWithRootViewController:feed] autorelease];
    self.window.rootViewController = nav;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int rc = UIApplicationMain(argc, argv, nil, @"AppDelegate");
    [pool release];
    return rc;
}
