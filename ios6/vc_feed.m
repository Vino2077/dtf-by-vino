#import "dtf_vcs.h"
#import "dtf_api.h"
#import "dtf_ui.h"

@implementation DTFPost
@synthesize postId, subsiteId, title, subsite, author, coverUuid, avatarUuid;
@synthesize comments, reactions, date;
- (void)dealloc
{
    [title release]; [subsite release]; [author release];
    [coverUuid release]; [avatarUuid release];
    [super dealloc];
}
@end

NSString *DTFAgo(NSTimeInterval unixTime)
{
    if (unixTime <= 0) return @"";
    NSTimeInterval diff = [[NSDate date] timeIntervalSince1970] - unixTime;
    if (diff < 60) return @"только что";
    if (diff < 3600) return [NSString stringWithFormat:@"%d мин", (int)(diff / 60)];
    if (diff < 86400) return [NSString stringWithFormat:@"%d ч", (int)(diff / 3600)];
    if (diff < 86400 * 30) return [NSString stringWithFormat:@"%d дн", (int)(diff / 86400)];
    return [NSString stringWithFormat:@"%d мес", (int)(diff / (86400 * 30))];
}

DTFPost *DTFPostFrom(id dict)
{
    DTFPost *p = [[[DTFPost alloc] init] autorelease];
    NSDictionary *d = DTFDict(dict);
    if (d == nil) return p;

    p.postId = DTFInt([d objectForKey:@"id"]);
    NSString *t = DTFStr([d objectForKey:@"title"]);
    p.title = [t length] > 0 ? t : @"(без заголовка)";
    p.date = (NSTimeInterval)DTFInt([d objectForKey:@"date"]);

    NSDictionary *sub = DTFDict([d objectForKey:@"subsite"]);
    if (sub != nil) {
        p.subsite = DTFStr([sub objectForKey:@"name"]);
        p.subsiteId = DTFInt([sub objectForKey:@"id"]);
    }
    NSDictionary *au = DTFDict([d objectForKey:@"author"]);
    if (au != nil) {
        p.author = DTFStr([au objectForKey:@"name"]);
        if (p.subsiteId == 0) p.subsiteId = DTFInt([au objectForKey:@"id"]);
        NSDictionary *av = DTFDict([au objectForKey:@"avatar"]);
        p.avatarUuid = DTFStr([DTFDict([av objectForKey:@"data"]) objectForKey:@"uuid"]);
    }

    NSDictionary *counters = DTFDict([d objectForKey:@"counters"]);
    if (counters != nil) {
        p.comments = DTFInt([counters objectForKey:@"comments"]);
        p.reactions = DTFInt([counters objectForKey:@"reactions"]);
    }

    /* Thumbnail: the first image in the body. */
    for (id b in DTFArr([d objectForKey:@"blocks"])) {
        NSDictionary *bd = DTFDict(b);
        if (![[bd objectForKey:@"type"] isEqual:@"media"]) continue;
        NSArray *items = DTFArr([DTFDict([bd objectForKey:@"data"]) objectForKey:@"items"]);
        if ([items count] == 0) continue;
        NSDictionary *img = DTFDict([DTFDict([items objectAtIndex:0]) objectForKey:@"image"]);
        NSString *uuid = DTFStr([DTFDict([img objectForKey:@"data"]) objectForKey:@"uuid"]);
        if ([uuid length] > 0) { p.coverUuid = uuid; break; }
    }
    return p;
}

NSArray *DTFPostsFromItems(NSArray *items)
{
    NSMutableArray *out = [NSMutableArray array];
    for (id item in items) {
        NSDictionary *w = DTFDict(item);
        id payload = w != nil ? [w objectForKey:@"data"] : nil;
        NSDictionary *pd = DTFDict(payload);
        if (pd == nil) { /* already a bare post */
            if (DTFDict(item) != nil) [out addObject:DTFPostFrom(item)];
            continue;
        }
        NSArray *news = DTFArr([pd objectForKey:@"news"]);
        if (news != nil) {
            for (id n in news) [out addObject:DTFPostFrom(n)];
        } else {
            [out addObject:DTFPostFrom(pd)];
        }
    }
    return out;
}

/* ------------------------------------------------------------------ */

@implementation PostListViewController
@synthesize posts, statusLabel, loading, canPaginate, noMore;

- (void)dealloc { [posts release]; [statusLabel release]; [super dealloc]; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.posts = [NSMutableArray array];
    self.tableView.rowHeight = 76.0f;
    self.tableView.backgroundColor = DTFPaper();
    self.tableView.separatorColor = [UIColor colorWithWhite:0.80f alpha:1.0f];

    self.statusLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(10.0f, 100.0f, self.view.bounds.size.width - 20.0f, 90.0f)] autorelease];
    self.statusLabel.textAlignment = UITextAlignmentCenter;
    self.statusLabel.numberOfLines = 5;
    self.statusLabel.font = [UIFont systemFontOfSize:13.0f];
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(self.statusLabel);
    [self.view addSubview:self.statusLabel];
}

- (void)reload
{
    [self.posts removeAllObjects];
    self.noMore = NO;
    [self.tableView reloadData];
    self.statusLabel.hidden = NO;
    self.statusLabel.text = @"Загружаю…";
    [self loadPage];
}

- (void)loadPage { /* subclasses */ }

- (void)finishWith:(NSArray *)fresh problem:(NSString *)problem
{
    self.loading = NO;
    if ([fresh count] == 0) self.noMore = YES;
    if ([fresh count] > 0) [self.posts addObjectsFromArray:fresh];
    if ([self.posts count] > 0) {
        self.statusLabel.hidden = YES;
    } else {
        self.statusLabel.hidden = NO;
        self.statusLabel.text = problem ? problem : @"Пусто";
    }
    [self.tableView reloadData];
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
        cell.textLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.8f];
        cell.textLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0f];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.42f alpha:1.0f];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.clipsToBounds = YES;
        cell.imageView.layer.cornerRadius = 4.0f;
        cell.imageView.layer.borderWidth = 1.0f;
        cell.imageView.layer.borderColor = [[UIColor colorWithWhite:0.75f alpha:1.0f] CGColor];
        DTFGradientCell(cell);
    }

    if (ip.row >= (NSInteger)[self.posts count]) return cell;
    DTFPost *p = [self.posts objectAtIndex:(NSUInteger)ip.row];
    cell.textLabel.text = p.title;

    NSMutableString *sub = [NSMutableString string];
    if ([p.subsite length] > 0) [sub appendFormat:@"%@", p.subsite];
    NSString *ago = DTFAgo(p.date);
    if ([ago length] > 0) [sub appendFormat:@"%@%@", [sub length] ? @" · " : @"", ago];
    [sub appendFormat:@"  ♥ %d   ✎ %d", (int)p.reactions, (int)p.comments];
    cell.detailTextLabel.text = sub;

    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    if ([p.coverUuid length] > 0) {
        [DTFImages loadUuid:p.coverUuid width:120 into:cell.imageView];
    } else if ([p.avatarUuid length] > 0) {
        [DTFImages loadUuid:p.avatarUuid width:80 into:cell.imageView];
    } else {
        cell.imageView.image = nil;
    }

    if (self.canPaginate && !self.noMore && !self.loading &&
        ip.row == (NSInteger)[self.posts count] - 1) {
        [self loadPage];
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.row >= (NSInteger)[self.posts count]) return;
    [self openPost:[self.posts objectAtIndex:(NSUInteger)ip.row]];
}

- (void)openPost:(DTFPost *)post
{
    PostViewController *vc = [[[PostViewController alloc] init] autorelease];
    vc.postId = post.postId;
    vc.headerTitle = post.title;
    [self.navigationController pushViewController:vc animated:YES];
}

@end

/* ------------------------------------------------------------------ */

@implementation FeedViewController
@synthesize feedName, lastId, lastSorting;

- (void)dealloc { [feedName release]; [lastId release]; [lastSorting release]; [super dealloc]; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.feedName = @"popular";
    self.canPaginate = YES;

    UISegmentedControl *seg = [[[UISegmentedControl alloc] initWithItems:
        [NSArray arrayWithObjects:@"Топ", @"Свежее", @"Моя", @"Ред.", nil]] autorelease];
    seg.selectedSegmentIndex = 0;
    seg.segmentedControlStyle = UISegmentedControlStyleBar;
    seg.tintColor = DTFBlue();
    [seg addTarget:self action:@selector(switchFeed:)
        forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = seg;

    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self action:@selector(reload)] autorelease];
    [self reload];
}

- (void)switchFeed:(UISegmentedControl *)seg
{
    NSArray *names = [NSArray arrayWithObjects:@"popular", @"new", @"my", @"editorial", nil];
    NSInteger i = seg.selectedSegmentIndex;
    self.feedName = [names objectAtIndex:(NSUInteger)(i < 0 ? 0 : i)];
    [self reload];
}

- (void)reload
{
    self.lastId = nil;
    self.lastSorting = nil;
    [super reload];
}

- (void)loadPage
{
    if (self.loading) return;
    self.loading = YES;

    NSString *feed = [[self.feedName copy] autorelease];
    NSString *lid = [[self.lastId copy] autorelease];
    NSString *lsort = [[self.lastSorting copy] autorelease];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSDictionary *result = [DTFApi feed:feed lastId:lid lastSorting:lsort error:&err];

        NSArray *fresh = DTFPostsFromItems(DTFArr([result objectForKey:@"items"]));
        id li = [result objectForKey:@"lastId"];
        id ls = [result objectForKey:@"lastSortingValue"];
        NSString *newId = (li != nil && li != [NSNull null])
            ? [NSString stringWithFormat:@"%@", li] : nil;
        NSString *newSort = (ls != nil && ls != [NSNull null])
            ? [NSString stringWithFormat:@"%@", ls] : nil;

        NSString *problem = err;
        if (problem == nil && [fresh count] == 0 && [feed isEqualToString:@"my"]
            && ![DTFApi isLoggedIn]) {
            problem = @"«Моя лента» доступна после входа в аккаунт";
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (newId) self.lastId = newId;
            if (newSort) self.lastSorting = newSort;
            [self finishWith:fresh problem:problem];
        });
    });
}

@end
