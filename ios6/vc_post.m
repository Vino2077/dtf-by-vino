#import "dtf_vcs.h"
#import "dtf_api.h"
#import "dtf_ui.h"
#import "dtf_net.h"

/* The reaction ids DTF offers first, with the CDN uuid of each picture.
   Carried over from the Android client registry. */
static NSArray *DTFReactionIds(void)
{
    return [NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", nil];
}

static NSString *DTFReactionUuid(NSInteger rid)
{
    static NSDictionary *map = nil;
    if (map == nil) {
        map = [[NSDictionary alloc] initWithObjectsAndKeys:
            @"5c63be49-162a-5e4e-adca-9b9c3f76314c", @"1",
            @"b9e9a5d6-cfbc-5d11-9b31-edad6bb6fbf0", @"2",
            @"3f5c49f9-22bc-521d-915a-a292f6210c67", @"3",
            @"15ad35e5-1708-58a5-a25a-d419cdd2d46a", @"4",
            @"0f3a998f-1441-5f0f-8a5b-549bbf170c65", @"5",
            @"2d62d1ab-8ec6-5f17-81f8-6f6f3312d283", @"6",
            @"ec72865d-ec4e-5299-b763-628cfd2539af", @"7",
            @"f8f6d0eb-8e72-50b1-af8e-c5a863a0c3b0", @"8",
            @"080e8489-f354-52f3-b495-d3901aa329b3", @"9",
            @"362a7194-57ee-5417-835e-bdc54d5394d4", @"10",
            @"b09f4923-5520-5ef9-b86d-668027a98d08", @"11",
            @"5862140b-90b1-5c28-b0f0-8bab45beb587", @"12",
            @"9368c0d2-e9e3-55c8-b633-c44c82095226", @"13",
            @"6aa490dc-b161-57ac-ad47-1f6a4946b513", @"14",
            @"898d07e7-06ea-5ff7-9ad6-8f74eb4e6f04", @"15",
            @"825e5ec2-bd20-5d7b-a681-f0fd66de0c21", @"16", nil];
    }
    return [map objectForKey:[NSString stringWithFormat:@"%d", (int)rid]];
}

@interface PostViewController ()
@property (nonatomic, retain) UIWebView *web;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@property (nonatomic, retain) NSDictionary *postData;
@property (nonatomic, retain) NSArray *commentData;
@property (nonatomic, retain) NSMutableDictionary *inlineImages;
@property (nonatomic, retain) UIView *reactionBar;
@property (nonatomic, assign) BOOL favorited;
@property (nonatomic, assign) NSInteger replyTo;      /* comment being answered */
@property (nonatomic, assign) NSInteger reactTarget;  /* comment being reacted to */
@end

@implementation PostViewController
@synthesize postId, headerTitle;
@synthesize web, spinner, postData, commentData, inlineImages, reactionBar, favorited;
@synthesize replyTo, reactTarget;

- (void)dealloc
{
    [headerTitle release]; [web release]; [spinner release];
    [postData release]; [commentData release]; [inlineImages release];
    [reactionBar release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Пост";
    self.view.backgroundColor = DTFPaper();
    self.inlineImages = [NSMutableDictionary dictionary];

    self.web = [[[UIWebView alloc] initWithFrame:self.view.bounds] autorelease];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.delegate = self;
    self.web.dataDetectorTypes = UIDataDetectorTypeNone;
    self.web.backgroundColor = DTFPaper();
    [self.view addSubview:self.web];

    self.spinner = [[[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0f, 80.0f);
    self.spinner.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithTitle:@"Блог" style:UIBarButtonItemStyleBordered
               target:self action:@selector(openBlog)] autorelease];

    UIBarButtonItem *space = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                             target:nil action:nil] autorelease];
    UIBarButtonItem *react = [[[UIBarButtonItem alloc]
        initWithTitle:@"♥ Реакция" style:UIBarButtonItemStyleBordered
               target:self action:@selector(showReactionsForPost)] autorelease];
    UIBarButtonItem *comment = [[[UIBarButtonItem alloc]
        initWithTitle:@"✎ Комментарий" style:UIBarButtonItemStyleBordered
               target:self action:@selector(writeComment)] autorelease];
    UIBarButtonItem *fav = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                             target:self action:@selector(toggleFavorite)] autorelease];
    self.toolbarItems = [NSArray arrayWithObjects:react, space, comment, space, fav, nil];
    DTFStyleToolbar(self.navigationController.toolbar);

    [self loadEverything];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
}

/* The web view has no working network of its own, so real links go to Safari.
   The private schemes below are how the article talks back to the app. */
- (BOOL)webView:(UIWebView *)wv
        shouldStartLoadWithRequest:(NSURLRequest *)request
        navigationType:(UIWebViewNavigationType)type
{
    NSURL *url = [request URL];
    NSString *scheme = [url scheme];

    if ([scheme isEqualToString:@"dtfreply"]) {
        self.replyTo = [[url resourceSpecifier] integerValue];
        [self writeComment];
        return NO;
    }
    if ([scheme isEqualToString:@"dtfreact"]) {
        self.reactTarget = [[url resourceSpecifier] integerValue];
        [self showReactions];
        return NO;
    }
    if (type == UIWebViewNavigationTypeLinkClicked) {
        [[UIApplication sharedApplication] openURL:url];
        return NO;
    }
    return YES;
}

/* ---------------- rendering ---------------- */

- (NSString *)imgTagFor:(NSString *)uuid
                pending:(NSMutableDictionary *)pending
                  width:(int)width
                  class:(NSString *)cls
{
    NSString *b64 = [self.inlineImages objectForKey:uuid];
    if (b64 != nil) {
        return [NSString stringWithFormat:@"<img class='%@' src='data:image/jpeg;base64,%@'>",
                cls ? cls : @"", b64];
    }
    if ([pending objectForKey:uuid] == nil) {
        [pending setObject:[NSNumber numberWithInt:width] forKey:uuid];
    }
    return [cls isEqualToString:@"rx"] ? @"" : @"<div class='note'>картинка загружается…</div>";
}

- (NSString *)reactionsHtmlPending:(NSMutableDictionary *)pending
{
    NSDictionary *reactions = DTFDict([self.postData objectForKey:@"reactions"]);
    NSArray *counters = DTFArr([reactions objectForKey:@"counters"]);
    if ([counters count] == 0) return @"";

    NSMutableString *h = [NSMutableString stringWithString:@"<div style='margin-top:14px'>"];
    for (id c in counters) {
        NSDictionary *cd = DTFDict(c);
        NSInteger n = DTFInt([cd objectForKey:@"count"]);
        if (n <= 0) continue;
        NSInteger rid = DTFInt([cd objectForKey:@"id"]);
        NSString *uuid = DTFReactionUuid(rid);
        NSString *pic = [uuid length] > 0
            ? [self imgTagFor:uuid pending:pending width:48 class:@"rx"]
            : [NSString stringWithFormat:@"#%d", (int)rid];
        [h appendFormat:@"<span class='pill'>%@ %d</span>", pic, (int)n];
    }
    [h appendString:@"</div>"];
    return h;
}

- (NSString *)bodyHtmlPending:(NSMutableDictionary *)pending
{
    NSDictionary *post = self.postData;
    NSMutableString *h = [NSMutableString string];

    NSString *title = DTFStr([post objectForKey:@"title"]);
    if ([title length] > 0) [h appendFormat:@"<h1>%@</h1>", title];

    NSString *who = DTFStr([DTFDict([post objectForKey:@"author"]) objectForKey:@"name"]);
    NSString *sub = DTFStr([DTFDict([post objectForKey:@"subsite"]) objectForKey:@"name"]);
    NSString *ago = DTFAgo((NSTimeInterval)DTFInt([post objectForKey:@"date"]));
    [h appendFormat:@"<div class='meta'>%@%@%@</div>",
        who ? who : @"",
        sub ? [NSString stringWithFormat:@" · %@", sub] : @"",
        [ago length] ? [NSString stringWithFormat:@" · %@", ago] : @""];

    for (id b in DTFArr([post objectForKey:@"blocks"])) {
        NSDictionary *bd = DTFDict(b);
        if (bd == nil) continue;
        NSString *type = DTFStr([bd objectForKey:@"type"]);
        NSDictionary *data = DTFDict([bd objectForKey:@"data"]);
        if (data == nil) continue;

        if ([type isEqualToString:@"text"]) {
            NSString *t = DTFStr([data objectForKey:@"text"]);
            if ([t length] > 0) [h appendFormat:@"<div>%@</div>", t];

        } else if ([type isEqualToString:@"header"]) {
            NSString *t = DTFStr([data objectForKey:@"text"]);
            if ([t length] > 0) [h appendFormat:@"<h2>%@</h2>", t];

        } else if ([type isEqualToString:@"quote"]) {
            NSString *t = DTFStr([data objectForKey:@"text"]);
            NSString *sl = DTFStr([data objectForKey:@"subline1"]);
            if ([t length] > 0) {
                [h appendFormat:@"<blockquote>%@%@</blockquote>", t,
                    [sl length] ? [NSString stringWithFormat:@"<div class='meta'>— %@</div>", sl] : @""];
            }

        } else if ([type isEqualToString:@"list"]) {
            NSArray *items = DTFArr([data objectForKey:@"items"]);
            if ([items count] > 0) {
                [h appendString:@"<ul>"];
                for (id it in items) [h appendFormat:@"<li>%@</li>", it];
                [h appendString:@"</ul>"];
            }

        } else if ([type isEqualToString:@"delimiter"]) {
            [h appendString:@"<div class='sep'>* * *</div>"];

        } else if ([type isEqualToString:@"media"]) {
            for (id it in DTFArr([data objectForKey:@"items"])) {
                NSDictionary *itd = DTFDict(it);
                NSDictionary *img = DTFDict([itd objectForKey:@"image"]);
                NSDictionary *idata = DTFDict([img objectForKey:@"data"]);
                NSString *uuid = DTFStr([idata objectForKey:@"uuid"]);
                if ([uuid length] == 0) continue;
                NSString *kind = DTFStr([idata objectForKey:@"type"]);

                [h appendString:[self imgTagFor:uuid pending:pending width:300 class:nil]];
                if ([kind isEqualToString:@"gif"] || [kind isEqualToString:@"mp4"]) {
                    /* Animation needs a player this screen does not have. */
                    [h appendFormat:@"<div class='note'>анимация — "
                        "<a href='https://leonardo.osnova.io/%@/-/format/mp4/'>открыть</a></div>",
                        uuid];
                }
                NSString *cap = DTFStr([itd objectForKey:@"title"]);
                if ([cap length] > 0) [h appendFormat:@"<div class='meta'>%@</div>", cap];
            }

        } else if ([type isEqualToString:@"link"]) {
            NSDictionary *ld = DTFDict([DTFDict([data objectForKey:@"link"]) objectForKey:@"data"]);
            NSString *url = DTFStr([ld objectForKey:@"url"]);
            NSString *ttl = DTFStr([ld objectForKey:@"title"]);
            NSString *desc = DTFStr([ld objectForKey:@"description"]);
            if ([url length] > 0) {
                [h appendFormat:@"<div class='card'><a href='%@'>%@</a>%@</div>",
                    url, [ttl length] ? ttl : url,
                    [desc length] ? [NSString stringWithFormat:@"<div class='meta'>%@</div>", desc] : @""];
            }

        } else if ([type isEqualToString:@"quiz"]) {
            NSString *q = DTFStr([data objectForKey:@"title"]);
            [h appendFormat:@"<div class='card'><b>%@</b>", q ? q : @"Опрос"];
            id items = [data objectForKey:@"items"];
            if ([items isKindOfClass:[NSDictionary class]]) {
                for (id k in (NSDictionary *)items) {
                    [h appendFormat:@"<div>• %@</div>", [(NSDictionary *)items objectForKey:k]];
                }
            } else {
                for (id it in DTFArr(items)) [h appendFormat:@"<div>• %@</div>", it];
            }
            [h appendString:@"</div>"];

        } else if ([type isEqualToString:@"audio"]) {
            NSString *t = DTFStr([data objectForKey:@"title"]);
            [h appendFormat:@"<div class='card'>♫ %@</div>", t ? t : @"Аудио"];

        } else if ([type isEqualToString:@"game"]) {
            NSString *entry = DTFStr([data objectForKey:@"entryUrl"]);
            [h appendFormat:@"<div class='card'>🎮 Мини-игра%@</div>",
                [entry length] ? [NSString stringWithFormat:@"<div class='meta'>"
                    "<a href='%@'>открыть в Safari</a></div>", entry] : @""];

        } else if ([type isEqualToString:@"person"]) {
            NSString *n = DTFStr([data objectForKey:@"name"]);
            NSString *d2 = DTFStr([data objectForKey:@"description"]);
            [h appendFormat:@"<div class='card'><b>%@</b><div class='meta'>%@</div></div>",
                n ? n : @"", d2 ? d2 : @""];

        } else if ([type isEqualToString:@"video"] || [type isEqualToString:@"embed"]
                   || [type isEqualToString:@"tweet"]) {
            [h appendString:@"<div class='card note'>Встроенное видео — открой пост на сайте</div>"];
        }
    }

    [h appendString:[self reactionsHtmlPending:pending]];
    return h;
}

- (NSString *)commentsHtmlPending:(NSMutableDictionary *)pending
{
    if ([self.commentData count] == 0) {
        return @"<h2>Комментарии</h2><div class='note'>Пока пусто</div>";
    }
    NSMutableString *h = [NSMutableString stringWithFormat:@"<h2>Комментарии (%d)</h2>",
                          (int)[self.commentData count]];
    for (id c in self.commentData) {
        NSDictionary *cd = DTFDict(c);
        if (cd == nil) continue;
        NSString *text = DTFStr([cd objectForKey:@"text"]);
        if ([[cd objectForKey:@"isRemoved"] boolValue]) text = @"<i>комментарий удалён</i>";
        if ([text length] == 0) continue;

        NSInteger cid = DTFInt([cd objectForKey:@"id"]);
        NSDictionary *au = DTFDict([cd objectForKey:@"author"]);
        NSString *who = DTFStr([au objectForKey:@"name"]);
        NSString *avatar = DTFStr([DTFDict([DTFDict([au objectForKey:@"avatar"])
                                            objectForKey:@"data"]) objectForKey:@"uuid"]);
        NSInteger level = DTFInt([cd objectForKey:@"level"]);
        if (level > 4) level = 4;
        NSInteger likes = DTFInt([DTFDict([cd objectForKey:@"likes"]) objectForKey:@"summ"]);
        NSString *ago = DTFAgo((NSTimeInterval)DTFInt([cd objectForKey:@"date"]));

        NSString *pic = [avatar length] > 0
            ? [self imgTagFor:avatar pending:pending width:48 class:@"rx"] : @"";

        [h appendFormat:@"<div class='card' style='margin-left:%dpx'>"
                         "<div class='who'>%@ %@ <span class='meta'>%@%@</span></div>"
                         "<div class='body'>%@</div>"
                         "<div class='meta'><a href='dtfreply:%d'>Ответить</a>"
                         " &nbsp; <a href='dtfreact:%d'>♥ Реакция</a></div></div>",
            (int)(level * 11), pic,
            who ? who : @"?",
            ago,
            likes != 0 ? [NSString stringWithFormat:@" · %+d", (int)likes] : @"",
            text, (int)cid, (int)cid];
    }
    return h;
}

- (void)renderFull
{
    NSMutableDictionary *ignore = [NSMutableDictionary dictionary];
    NSString *page = [NSString stringWithFormat:@"%@%@%@</body></html>",
        DTFHtmlHead(), [self bodyHtmlPending:ignore], [self commentsHtmlPending:ignore]];
    [self.web loadHTMLString:page baseURL:nil];
}

/* ---------------- loading ---------------- */

- (void)loadEverything
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSDictionary *post = [DTFApi post:self.postId error:&err];

        if (post == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                NSString *page = [NSString stringWithFormat:
                    @"%@<div class='note'>Не удалось загрузить пост:<br>%@</div></body></html>",
                    DTFHtmlHead(), err ? err : @"неизвестная ошибка"];
                [self.web loadHTMLString:page baseURL:nil];
            });
            return;
        }

        NSMutableDictionary *pending = [NSMutableDictionary dictionary];
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.postData = post;
            self.favorited = [[post objectForKey:@"isFavorited"] boolValue];
            [self.spinner stopAnimating];
            /* Text first — pictures and comments follow. */
            NSString *page = [NSString stringWithFormat:@"%@%@</body></html>",
                DTFHtmlHead(), [self bodyHtmlPending:pending]];
            [self.web loadHTMLString:page baseURL:nil];
        });

        NSArray *comments = [DTFApi comments:self.postId error:NULL];
        __block NSMutableDictionary *withComments = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.commentData = comments;
            withComments = [NSMutableDictionary dictionaryWithDictionary:pending];
            /* Collect the avatars the comments need, without rendering yet. */
            [self commentsHtmlPending:withComments];
        });

        /* Pictures last, capped so a photo essay cannot stall the screen for
           minutes on this hardware. */
        NSUInteger done = 0;
        for (NSString *uuid in withComments) {
            if (done >= 24) break;
            int w = [[withComments objectForKey:uuid] intValue];
            NSData *img = [DTFImages fetchUuid:uuid width:w];
            if ([img length] == 0) continue;
            NSString *b64 = DTFBase64(img);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.inlineImages setObject:b64 forKey:uuid];
            });
            done++;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ [self renderFull]; });
    });
}

/* ---------------- actions ---------------- */

- (void)needLogin
{
    [[[[UIAlertView alloc] initWithTitle:@"Нужен вход"
                                 message:@"Войди в аккаунт в разделе «Профиль»"
                                delegate:nil
                       cancelButtonTitle:@"Ясно"
                       otherButtonTitles:nil] autorelease] show];
}

- (void)openBlog
{
    NSDictionary *sub = DTFDict([self.postData objectForKey:@"subsite"]);
    if (sub == nil) sub = DTFDict([self.postData objectForKey:@"author"]);
    NSInteger sid = DTFInt([sub objectForKey:@"id"]);
    if (sid <= 0) return;

    SubsiteViewController *vc = [[[SubsiteViewController alloc]
        initWithStyle:UITableViewStylePlain] autorelease];
    vc.subsiteId = sid;
    vc.subsiteName = DTFStr([sub objectForKey:@"name"]);
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showReactionsForPost
{
    self.reactTarget = 0;
    [self showReactions];
}

- (void)showReactions
{
    if (![DTFApi isLoggedIn]) { [self needLogin]; return; }
    if (self.reactionBar != nil) { [self hideReactions]; return; }

    CGFloat w = self.view.bounds.size.width;
    UIView *bar = [[[UIView alloc] initWithFrame:
        CGRectMake(0.0f, self.view.bounds.size.height - 62.0f, w, 62.0f)] autorelease];
    bar.backgroundColor = [UIColor colorWithWhite:0.16f alpha:0.94f];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    NSArray *ids = DTFReactionIds();
    CGFloat step = w / (CGFloat)[ids count];
    for (NSUInteger i = 0; i < [ids count]; i++) {
        NSInteger rid = [[ids objectAtIndex:i] integerValue];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake((CGFloat)i * step, 6.0f, step, 50.0f);
        b.tag = rid;
        [b addTarget:self action:@selector(pickReaction:)
            forControlEvents:UIControlEventTouchUpInside];

        UIImageView *iv = [[[UIImageView alloc] initWithFrame:
            CGRectMake((step - 34.0f) / 2.0f, 4.0f, 34.0f, 34.0f)] autorelease];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled = NO;
        iv.image = DTFPlaceholder(34.0f);
        [b addSubview:iv];
        [DTFImages loadUuid:DTFReactionUuid(rid) width:64 into:iv];

        [bar addSubview:b];
    }

    UILabel *hint = [[[UILabel alloc] initWithFrame:
        CGRectMake(0.0f, 44.0f, w, 14.0f)] autorelease];
    hint.text = self.reactTarget > 0 ? @"реакция на комментарий" : @"реакция на пост";
    hint.font = [UIFont systemFontOfSize:10.0f];
    hint.textColor = [UIColor lightGrayColor];
    hint.backgroundColor = [UIColor clearColor];
    hint.textAlignment = UITextAlignmentCenter;
    [bar addSubview:hint];

    self.reactionBar = bar;
    [self.view addSubview:bar];
}

- (void)hideReactions
{
    [self.reactionBar removeFromSuperview];
    self.reactionBar = nil;
}

- (void)pickReaction:(UIButton *)sender
{
    NSInteger rid = sender.tag;
    NSInteger target = self.reactTarget;
    [self hideReactions];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi react:(target > 0 ? target : self.postId)
                      isComment:(target > 0)
                       reaction:rid];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.reactTarget = 0;
            [[[[UIAlertView alloc]
                initWithTitle:ok ? @"Готово" : @"Не вышло"
                      message:ok ? @"Реакция отправлена" : @"Реакция не отправилась"
                     delegate:nil cancelButtonTitle:@"Ок" otherButtonTitles:nil] autorelease] show];
        });
    });
}

- (void)toggleFavorite
{
    if (![DTFApi isLoggedIn]) { [self needLogin]; return; }
    BOOL add = !self.favorited;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi setFavorite:self.postId add:add];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) self.favorited = add;
            [[[[UIAlertView alloc]
                initWithTitle:ok ? (add ? @"В закладках" : @"Убрано из закладок") : @"Не вышло"
                      message:nil delegate:nil
                cancelButtonTitle:@"Ок" otherButtonTitles:nil] autorelease] show];
        });
    });
}

- (void)writeComment
{
    if (![DTFApi isLoggedIn]) { [self needLogin]; return; }
    UIAlertView *a = [[[UIAlertView alloc]
        initWithTitle:self.replyTo > 0 ? @"Ответ" : @"Комментарий"
              message:nil delegate:self
    cancelButtonTitle:@"Отмена" otherButtonTitles:@"Отправить", nil] autorelease];
    a.alertViewStyle = UIAlertViewStylePlainTextInput;
    [a show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index
{
    if (alertView.alertViewStyle != UIAlertViewStylePlainTextInput) return;
    if (index != 1) { self.replyTo = 0; return; }

    NSString *text = [[alertView textFieldAtIndex:0] text];
    NSInteger reply = self.replyTo;
    self.replyTo = 0;
    if ([text length] == 0) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi addComment:self.postId text:text replyTo:reply];
        NSArray *fresh = ok ? [DTFApi comments:self.postId error:NULL] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok && fresh != nil) {
                self.commentData = fresh;
                [self renderFull];
            }
            [[[[UIAlertView alloc]
                initWithTitle:ok ? @"Отправлено" : @"Не вышло"
                      message:nil delegate:nil
                cancelButtonTitle:@"Ок" otherButtonTitles:nil] autorelease] show];
        });
    });
}

@end
