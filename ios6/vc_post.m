#import "dtf_vcs.h"
#import "dtf_api.h"
#import "dtf_ui.h"
#import "dtf_net.h"

/* The reaction ids DTF shows first, with the CDN uuid of each picture.
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
            @"f8f6d0eb-8e72-50b1-af8e-c5a863a0c3b0", @"8", nil];
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
@end

@implementation PostViewController
@synthesize postId, headerTitle;
@synthesize web, spinner, postData, commentData, inlineImages, reactionBar, favorited;

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

    UIBarButtonItem *space = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                             target:nil action:nil] autorelease];
    UIBarButtonItem *react = [[[UIBarButtonItem alloc]
        initWithTitle:@"♥ Реакция" style:UIBarButtonItemStyleBordered
               target:self action:@selector(showReactions)] autorelease];
    UIBarButtonItem *comment = [[[UIBarButtonItem alloc]
        initWithTitle:@"✎ Комментарий" style:UIBarButtonItemStyleBordered
               target:self action:@selector(writeComment)] autorelease];
    UIBarButtonItem *fav = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                             target:self action:@selector(toggleFavorite)] autorelease];
    self.toolbarItems = [NSArray arrayWithObjects:react, space, comment, space, fav, nil];
    [self.navigationController setToolbarHidden:NO animated:NO];
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

/* The web view has no working network of its own, so links go to Safari. */
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

/* ---------------- rendering ---------------- */

- (NSString *)imgTagFor:(NSString *)uuid pending:(NSMutableArray *)pending
{
    NSString *b64 = [self.inlineImages objectForKey:uuid];
    if (b64 != nil) {
        return [NSString stringWithFormat:@"<img src='data:image/jpeg;base64,%@'>", b64];
    }
    if (![pending containsObject:uuid]) [pending addObject:uuid];
    return @"<div class='note'>картинка загружается…</div>";
}

- (NSString *)bodyHtmlPending:(NSMutableArray *)pending
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
                if ([kind isEqualToString:@"gif"] || [kind isEqualToString:@"mp4"]) {
                    /* Animated media would need a player; show the frame only. */
                    [h appendString:[self imgTagFor:uuid pending:pending]];
                    [h appendString:@"<div class='note'>анимация — только первый кадр</div>"];
                } else {
                    [h appendString:[self imgTagFor:uuid pending:pending]];
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

    /* Reaction tallies as pills. */
    NSDictionary *reactions = DTFDict([post objectForKey:@"reactions"]);
    NSArray *counters = DTFArr([reactions objectForKey:@"counters"]);
    if ([counters count] > 0) {
        [h appendString:@"<div style='margin-top:14px'>"];
        for (id c in counters) {
            NSDictionary *cd = DTFDict(c);
            NSInteger n = DTFInt([cd objectForKey:@"count"]);
            if (n <= 0) continue;
            [h appendFormat:@"<span class='pill'>#%d · %d</span>",
                (int)DTFInt([cd objectForKey:@"id"]), (int)n];
        }
        [h appendString:@"</div>"];
    }
    return h;
}

- (NSString *)commentsHtml
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
        BOOL removed = [[cd objectForKey:@"isRemoved"] boolValue];
        if (removed) text = @"<i>комментарий удалён</i>";
        if ([text length] == 0) continue;

        NSString *who = DTFStr([DTFDict([cd objectForKey:@"author"]) objectForKey:@"name"]);
        NSInteger level = DTFInt([cd objectForKey:@"level"]);
        if (level > 4) level = 4;
        NSInteger likes = DTFInt([DTFDict([cd objectForKey:@"likes"]) objectForKey:@"summ"]);
        NSString *ago = DTFAgo((NSTimeInterval)DTFInt([cd objectForKey:@"date"]));

        [h appendFormat:@"<div class='card' style='margin-left:%dpx'>"
                         "<div class='who'>%@ <span class='meta'>%@%@</span></div>"
                         "<div class='body'>%@</div></div>",
            (int)(level * 11),
            who ? who : @"?",
            ago,
            likes != 0 ? [NSString stringWithFormat:@" · %+d", (int)likes] : @"",
            text];
    }
    return h;
}

- (void)renderFull
{
    NSString *page = [NSString stringWithFormat:@"%@%@%@</body></html>",
        DTFHtmlHead(), [self bodyHtmlPending:[NSMutableArray array]], [self commentsHtml]];
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

        NSMutableArray *pending = [NSMutableArray array];
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
        dispatch_async(dispatch_get_main_queue(), ^{ self.commentData = comments; });

        /* Pictures last, one at a time, capped so a photo essay cannot stall
           the screen for minutes on this hardware. */
        NSUInteger limit = [pending count] < 10 ? [pending count] : 10;
        for (NSUInteger i = 0; i < limit; i++) {
            NSString *uuid = [pending objectAtIndex:i];
            NSData *img = [DTFImages fetchUuid:uuid width:300];
            if ([img length] == 0) continue;
            NSString *b64 = DTFBase64(img);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.inlineImages setObject:b64 forKey:uuid];
            });
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

- (void)showReactions
{
    if (![DTFApi isLoggedIn]) { [self needLogin]; return; }
    if (self.reactionBar != nil) { [self hideReactions]; return; }

    CGFloat w = self.view.bounds.size.width;
    UIView *bar = [[[UIView alloc] initWithFrame:
        CGRectMake(0.0f, self.view.bounds.size.height - 60.0f, w, 60.0f)] autorelease];
    bar.backgroundColor = [UIColor colorWithWhite:0.16f alpha:0.92f];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    NSArray *ids = DTFReactionIds();
    CGFloat step = w / (CGFloat)[ids count];
    for (NSUInteger i = 0; i < [ids count]; i++) {
        NSInteger rid = [[ids objectAtIndex:i] integerValue];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake((CGFloat)i * step + 4.0f, 8.0f, step - 8.0f, 44.0f);
        b.tag = rid;
        [b setTitle:[NSString stringWithFormat:@"%d", (int)rid] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        [b addTarget:self action:@selector(pickReaction:)
            forControlEvents:UIControlEventTouchUpInside];
        [bar addSubview:b];

        UIImageView *iv = [[[UIImageView alloc] initWithFrame:
            CGRectMake(b.frame.origin.x + (b.frame.size.width - 32.0f) / 2.0f,
                       12.0f, 32.0f, 32.0f)] autorelease];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled = NO;
        [bar addSubview:iv];
        [DTFImages loadUuid:DTFReactionUuid(rid) width:64 into:iv];
    }

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
    [self hideReactions];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi react:self.postId isComment:NO reaction:rid];
        dispatch_async(dispatch_get_main_queue(), ^{
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
                initWithTitle:ok ? (add ? @"В закладках" : @"Убрано") : @"Не вышло"
                      message:nil delegate:nil
                cancelButtonTitle:@"Ок" otherButtonTitles:nil] autorelease] show];
        });
    });
}

- (void)writeComment
{
    if (![DTFApi isLoggedIn]) { [self needLogin]; return; }
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:@"Комментарий"
                                                 message:nil
                                                delegate:self
                                       cancelButtonTitle:@"Отмена"
                                       otherButtonTitles:@"Отправить", nil] autorelease];
    a.alertViewStyle = UIAlertViewStylePlainTextInput;
    [a show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index
{
    if (index != 1 || alertView.alertViewStyle != UIAlertViewStylePlainTextInput) return;
    NSString *text = [[alertView textFieldAtIndex:0] text];
    if ([text length] == 0) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi addComment:self.postId text:text replyTo:0];
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
