#import "dtf_vcs.h"
#import "dtf_api.h"
#import "dtf_ui.h"
#import "dtf_net.h"

/// Strips tags so a snippet fits one table row (defined below).
static NSString *DTFPlain(NSString *html);

/* ------------------------------------------------------------------ */
/* Search                                                              */
/* ------------------------------------------------------------------ */

@implementation SearchViewController
@synthesize searchBar, query;

- (void)dealloc { [searchBar release]; [query release]; [super dealloc]; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Поиск";

    self.searchBar = [[[UISearchBar alloc] initWithFrame:
        CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, 44.0f)] autorelease];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Поиск по DTF";
    self.searchBar.tintColor = DTFBlue();
    self.tableView.tableHeaderView = self.searchBar;

    self.statusLabel.text = @"Введи запрос";
    self.statusLabel.hidden = NO;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar
{
    [bar resignFirstResponder];
    self.query = bar.text;
    if ([self.query length] == 0) return;
    [self reload];
}

- (void)loadPage
{
    if (self.loading || [self.query length] == 0) return;
    self.loading = YES;
    NSString *q = [[self.query copy] autorelease];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSArray *raw = [DTFApi search:q error:&err];
        NSMutableArray *found = [NSMutableArray array];
        for (id r in raw) if (DTFDict(r) != nil) [found addObject:DTFPostFrom(r)];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishWith:found problem:err ? err : @"Ничего не найдено"];
        });
    });
}

@end

/* ------------------------------------------------------------------ */
/* Bookmarks                                                           */
/* ------------------------------------------------------------------ */

@implementation BookmarksViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Закладки";
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self action:@selector(reload)] autorelease];
    [self reload];
}

- (void)loadPage
{
    if (self.loading) return;
    self.loading = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSArray *raw = [DTFApi bookmarksWithError:&err];
        NSMutableArray *found = [NSMutableArray array];
        for (id r in raw) if (DTFDict(r) != nil) [found addObject:DTFPostFrom(r)];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishWith:found problem:err ? err : @"Закладок нет"];
        });
    });
}

@end

/* ------------------------------------------------------------------ */
/* Someone else's blog                                                 */
/* ------------------------------------------------------------------ */

@interface SubsiteViewController ()
@property (nonatomic, retain) NSDictionary *info;
@property (nonatomic, retain) NSMutableArray *authorComments;
@property (nonatomic, assign) BOOL commentsMode;
@property (nonatomic, retain) UILabel *nameLabel;
@property (nonatomic, retain) UILabel *descLabel;
@property (nonatomic, retain) UILabel *countersLabel;
@property (nonatomic, retain) UIImageView *avatarView;
@property (nonatomic, retain) UIImageView *coverView;
@end

@implementation SubsiteViewController
@synthesize subsiteId, subsiteName;
@synthesize info, authorComments, commentsMode;
@synthesize nameLabel, descLabel, countersLabel, avatarView, coverView;

- (void)dealloc
{
    [subsiteName release]; [info release]; [authorComments release];
    [nameLabel release]; [descLabel release]; [countersLabel release];
    [avatarView release]; [coverView release];
    [super dealloc];
}

/* Banner, avatar, name, description, counters and the posts/comments switch —
   the same shape the blog has on the site. */
- (UIView *)buildHeader
{
    CGFloat w = self.view.bounds.size.width;
    UIView *head = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 216.0f)] autorelease];
    head.backgroundColor = [UIColor colorWithWhite:0.98f alpha:1.0f];

    self.coverView = [[[UIImageView alloc] initWithFrame:
        CGRectMake(0.0f, 0.0f, w, 84.0f)] autorelease];
    self.coverView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverView.clipsToBounds = YES;
    self.coverView.backgroundColor = [UIColor colorWithWhite:0.80f alpha:1.0f];
    self.coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [head addSubview:self.coverView];

    self.avatarView = [[[UIImageView alloc] initWithFrame:
        CGRectMake(12.0f, 50.0f, 64.0f, 64.0f)] autorelease];
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.layer.cornerRadius = 8.0f;
    self.avatarView.layer.borderWidth = 2.0f;
    self.avatarView.layer.borderColor = [[UIColor whiteColor] CGColor];
    self.avatarView.image = DTFPlaceholder(64.0f);
    [head addSubview:self.avatarView];

    self.nameLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(86.0f, 88.0f, w - 98.0f, 22.0f)] autorelease];
    self.nameLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    self.nameLabel.text = [self.subsiteName length] > 0 ? self.subsiteName : @"Блог";
    self.nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(self.nameLabel);
    [head addSubview:self.nameLabel];

    self.countersLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(12.0f, 120.0f, w - 24.0f, 18.0f)] autorelease];
    self.countersLabel.font = [UIFont systemFontOfSize:12.0f];
    self.countersLabel.textColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
    self.countersLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(self.countersLabel);
    [head addSubview:self.countersLabel];

    self.descLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(12.0f, 140.0f, w - 24.0f, 32.0f)] autorelease];
    self.descLabel.font = [UIFont systemFontOfSize:12.0f];
    self.descLabel.numberOfLines = 2;
    self.descLabel.textColor = [UIColor colorWithWhite:0.28f alpha:1.0f];
    self.descLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(self.descLabel);
    [head addSubview:self.descLabel];

    UISegmentedControl *seg = [[[UISegmentedControl alloc] initWithItems:
        [NSArray arrayWithObjects:@"Посты", @"Комментарии", nil]] autorelease];
    seg.frame = CGRectMake(12.0f, 176.0f, w - 24.0f, 30.0f);
    seg.selectedSegmentIndex = 0;
    seg.segmentedControlStyle = UISegmentedControlStyleBar;
    seg.tintColor = DTFBlue();
    seg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [seg addTarget:self action:@selector(switchMode:)
        forControlEvents:UIControlEventValueChanged];
    [head addSubview:seg];

    return head;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = [self.subsiteName length] > 0 ? self.subsiteName : @"Блог";
    self.authorComments = [NSMutableArray array];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithTitle:@"Подписаться" style:UIBarButtonItemStyleBordered
               target:self action:@selector(subscribe)] autorelease];

    self.tableView.tableHeaderView = [self buildHeader];
    [self loadInfo];
    [self reload];
}

- (void)loadInfo
{
    NSInteger sid = self.subsiteId;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *s = [DTFApi subsite:sid error:NULL];
        if (s == nil) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.info = s;
            NSString *name = DTFStr([s objectForKey:@"name"]);
            if ([name length] > 0) { self.nameLabel.text = name; self.title = name; }

            NSString *desc = DTFStr([s objectForKey:@"description"]);
            self.descLabel.text = [desc length] > 0 ? desc : @"";

            NSDictionary *c = DTFDict([s objectForKey:@"counters"]);
            self.countersLabel.text = [NSString stringWithFormat:
                @"Рейтинг %d   ·   %d подписчиков   ·   %d подписок",
                (int)DTFInt([s objectForKey:@"rating"]),
                (int)DTFInt([c objectForKey:@"subscribers"]),
                (int)DTFInt([c objectForKey:@"subscriptions"])];

            NSString *av = DTFStr([DTFDict([DTFDict([s objectForKey:@"avatar"])
                                    objectForKey:@"data"]) objectForKey:@"uuid"]);
            if ([av length] > 0) [DTFImages loadUuid:av width:128 into:self.avatarView];
            NSString *cover = DTFStr([DTFDict([DTFDict([s objectForKey:@"cover"])
                                       objectForKey:@"data"]) objectForKey:@"uuid"]);
            if ([cover length] > 0) [DTFImages loadUuid:cover width:640 into:self.coverView];
        });
    });
}

- (void)switchMode:(UISegmentedControl *)seg
{
    self.commentsMode = (seg.selectedSegmentIndex == 1);
    if (self.commentsMode && [self.authorComments count] == 0) {
        [self loadAuthorComments];
    } else {
        [self.tableView reloadData];
    }
}

- (void)loadAuthorComments
{
    self.statusLabel.hidden = NO;
    self.statusLabel.text = @"Загружаю комментарии…";
    NSInteger sid = self.subsiteId;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSArray *fresh = [DTFApi subsiteComments:sid error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.authorComments removeAllObjects];
            for (id c in fresh) if (DTFDict(c) != nil) [self.authorComments addObject:c];
            self.statusLabel.hidden = [self.authorComments count] > 0;
            self.statusLabel.text = err ? err : @"Комментариев нет";
            [self.tableView reloadData];
        });
    });
}

/* In comments mode the table shows the author's comments instead of posts. */
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    if (self.commentsMode) return (NSInteger)[self.authorComments count];
    return [super tableView:tv numberOfRowsInSection:s];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    if (!self.commentsMode) return [super tableView:tv cellForRowAtIndexPath:ip];

    static NSString *ident = @"acmt";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:ident] autorelease];
        cell.textLabel.numberOfLines = 3;
        cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        DTFGradientCell(cell);
    }
    NSDictionary *c = DTFDict([self.authorComments objectAtIndex:(NSUInteger)ip.row]);
    cell.textLabel.text = DTFPlain(DTFStr([c objectForKey:@"text"]));
    cell.detailTextLabel.text = DTFAgo((NSTimeInterval)DTFInt([c objectForKey:@"date"]));
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    if (!self.commentsMode) { [super tableView:tv didSelectRowAtIndexPath:ip]; return; }
    [tv deselectRowAtIndexPath:ip animated:YES];

    NSDictionary *c = DTFDict([self.authorComments objectAtIndex:(NSUInteger)ip.row]);
    NSInteger pid = DTFInt([c objectForKey:@"contentId"]);
    if (pid <= 0) pid = DTFInt([DTFDict([c objectForKey:@"content"]) objectForKey:@"id"]);
    if (pid <= 0) return;

    PostViewController *vc = [[[PostViewController alloc] init] autorelease];
    vc.postId = pid;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)subscribe
{
    if (![DTFApi isLoggedIn]) {
        [[[[UIAlertView alloc] initWithTitle:@"Нужен вход" message:nil delegate:nil
                           cancelButtonTitle:@"Ок" otherButtonTitles:nil] autorelease] show];
        return;
    }
    NSInteger sid = self.subsiteId;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi subscribe:sid add:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[[UIAlertView alloc] initWithTitle:ok ? @"Подписка оформлена" : @"Не вышло"
                                         message:nil delegate:nil
                               cancelButtonTitle:@"Ок" otherButtonTitles:nil] autorelease] show];
        });
    });
}

- (void)loadPage
{
    if (self.loading) return;
    self.loading = YES;
    NSInteger sid = self.subsiteId;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSDictionary *r = [DTFApi subsiteTimeline:sid error:&err];
        NSArray *found = DTFPostsFromItems(DTFArr([r objectForKey:@"items"]));
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishWith:found problem:err ? err : @"Записей нет"];
        });
    });
}

@end

/* ------------------------------------------------------------------ */
/* Notifications                                                       */
/* ------------------------------------------------------------------ */

/* Strips tags so a notification fits one table row. */
static NSString *DTFPlain(NSString *html)
{
    if ([html length] == 0) return @"";
    NSMutableString *s = [NSMutableString stringWithString:html];
    NSRange open;
    while ((open = [s rangeOfString:@"<"]).location != NSNotFound) {
        NSRange rest = NSMakeRange(open.location, [s length] - open.location);
        NSRange close = [s rangeOfString:@">" options:0 range:rest];
        if (close.location == NSNotFound) break;
        [s deleteCharactersInRange:NSMakeRange(open.location,
                                               close.location - open.location + 1)];
    }
    [s replaceOccurrencesOfString:@"&nbsp;" withString:@" "
                          options:0 range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"&quot;" withString:@"\""
                          options:0 range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"&amp;" withString:@"&"
                          options:0 range:NSMakeRange(0, [s length])];
    return s;
}

/* dtf.ru/gamedev/12345-slug → 12345 */
static NSInteger DTFPostIdFromUrl(NSString *url)
{
    if ([url length] == 0) return 0;
    NSArray *parts = [url componentsSeparatedByString:@"/"];
    for (NSString *part in [parts reverseObjectEnumerator]) {
        NSString *head = [[part componentsSeparatedByString:@"-"] objectAtIndex:0];
        NSString *digits = [head stringByTrimmingCharactersInSet:
            [[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
        if ([digits length] >= 4) return [digits integerValue];
    }
    return 0;
}

@interface NotificationsViewController ()
@property (nonatomic, retain) NSMutableArray *items;
@property (nonatomic, retain) UILabel *status;
@end

@implementation NotificationsViewController
@synthesize items, status;

- (void)dealloc { [items release]; [status release]; [super dealloc]; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Уведомления";
    self.items = [NSMutableArray array];
    self.tableView.rowHeight = 62.0f;
    self.tableView.backgroundColor = DTFPaper();

    self.status = [[[UILabel alloc] initWithFrame:
        CGRectMake(10.0f, 100.0f, self.view.bounds.size.width - 20.0f, 80.0f)] autorelease];
    self.status.textAlignment = UITextAlignmentCenter;
    self.status.numberOfLines = 4;
    self.status.font = [UIFont systemFontOfSize:13.0f];
    self.status.textColor = [UIColor grayColor];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(self.status);
    [self.view addSubview:self.status];

    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self action:@selector(load)] autorelease];
    [self load];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.items count] == 0) [self load];
}

- (void)load
{
    self.status.hidden = NO;
    self.status.text = @"Загружаю…";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSArray *fresh = [DTFApi notificationsWithError:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.items removeAllObjects];
            for (id it in fresh) if (DTFDict(it) != nil) [self.items addObject:it];
            self.status.hidden = [self.items count] > 0;
            self.status.text = err ? err : @"Уведомлений нет";
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    return (NSInteger)[self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"note";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:ident] autorelease];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        DTFGradientCell(cell);
    }
    NSDictionary *n = DTFDict([self.items objectAtIndex:(NSUInteger)ip.row]);
    cell.textLabel.text = DTFPlain(DTFStr([n objectForKey:@"text"]));
    cell.detailTextLabel.text = DTFAgo((NSTimeInterval)DTFInt([n objectForKey:@"dateCreated"]));
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *n = DTFDict([self.items objectAtIndex:(NSUInteger)ip.row]);
    NSString *url = DTFStr([n objectForKey:@"url"]);
    NSInteger pid = DTFPostIdFromUrl(url);
    if (pid > 0) {
        PostViewController *vc = [[[PostViewController alloc] init] autorelease];
        vc.postId = pid;
        [self.navigationController pushViewController:vc animated:YES];
    } else if ([url length] > 0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}

@end

/* ------------------------------------------------------------------ */
/* Profile                                                             */
/* ------------------------------------------------------------------ */

@interface ProfileViewController ()
@property (nonatomic, retain) NSDictionary *me;
@end

@implementation ProfileViewController
@synthesize me;

- (void)dealloc { [me release]; [super dealloc]; }

- (id)initWithStyle:(UITableViewStyle)style
{
    /* Grouped tables are what give the inset, rounded panels of this era. */
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Профиль";
    self.tableView.backgroundColor = DTFPaper();
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    if ([DTFApi isLoggedIn] && self.me == nil) [self loadMe];
}

- (void)loadMe
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *m = [DTFApi meWithError:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.me = m;
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    if (s == 0) return 1;                       /* account */
    /* signed in: compose, bookmarks, settings, sign out */
    return [DTFApi isLoggedIn] ? 4 : 2;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s
{
    return s == 0 ? @"Аккаунт" : @"Разделы";
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"prof";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:ident] autorelease];
    }
    cell.imageView.image = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.detailTextLabel.text = nil;

    if (ip.section == 0) {
        if ([DTFApi isLoggedIn]) {
            NSString *name = DTFStr([self.me objectForKey:@"name"]);
            cell.textLabel.text = [name length] > 0 ? name : @"Загружаю…";
            NSInteger rating = DTFInt([self.me objectForKey:@"rating"]);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"Рейтинг: %d", (int)rating];
            NSDictionary *av = DTFDict([self.me objectForKey:@"avatar"]);
            NSString *uuid = DTFStr([DTFDict([av objectForKey:@"data"]) objectForKey:@"uuid"]);
            if ([uuid length] > 0) [DTFImages loadUuid:uuid width:80 into:cell.imageView];
        } else {
            cell.textLabel.text = @"Войти в DTF";
            cell.detailTextLabel.text = @"Реакции, закладки, комментарии, чаты";
        }
        return cell;
    }

    cell.textLabel.textColor = [UIColor blackColor];
    /* The compose row only exists when signed in, so everything below it
       shifts by one. */
    NSInteger row = [DTFApi isLoggedIn] ? ip.row : ip.row + 1;
    if (row == 0) { cell.textLabel.text = @"Написать пост"; }
    else if (row == 1) { cell.textLabel.text = @"Закладки"; }
    else if (row == 2) { cell.textLabel.text = @"Настройки"; }
    else {
        cell.textLabel.text = @"Выйти из аккаунта";
        cell.textLabel.textColor = [UIColor colorWithRed:0.75f green:0.13f blue:0.13f alpha:1.0f];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];

    if (ip.section == 0) {
        if (![DTFApi isLoggedIn]) {
            LoginViewController *vc = [[[LoginViewController alloc] init] autorelease];
            [self.navigationController pushViewController:vc animated:YES];
        }
        return;
    }
    NSInteger row = [DTFApi isLoggedIn] ? ip.row : ip.row + 1;
    if (row == 0) {
        EditorViewController *vc = [[[EditorViewController alloc] init] autorelease];
        [self.navigationController pushViewController:vc animated:YES];
    } else if (row == 1) {
        BookmarksViewController *vc = [[[BookmarksViewController alloc]
            initWithStyle:UITableViewStylePlain] autorelease];
        [self.navigationController pushViewController:vc animated:YES];
    } else if (row == 2) {
        SettingsViewController *vc = [[[SettingsViewController alloc]
            initWithStyle:UITableViewStyleGrouped] autorelease];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        DTFSetToken(nil);
        self.me = nil;
        [self.tableView reloadData];
    }
}

@end
