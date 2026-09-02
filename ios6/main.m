/*
 * DTF by Vino — iOS 6 client, first milestone: the popular feed as a list.
 *
 * Written against UIKit of 2012 and built with manual retain/release (the ARC
 * runtime support library is no longer shipped for a 6.0 deployment target).
 * All networking goes through DTFGet — see dtf_net.h for why the system stack
 * cannot be used here.
 */
#import <UIKit/UIKit.h>
#import "dtf_net.h"

@interface DTFPost : NSObject
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subsite;
@property (nonatomic, assign) NSInteger comments;
@end

@implementation DTFPost
@synthesize title, subsite, comments;
- (void)dealloc { [title release]; [subsite release]; [super dealloc]; }
@end

@interface FeedViewController : UITableViewController
@property (nonatomic, retain) NSMutableArray *posts;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@property (nonatomic, retain) UILabel *statusLabel;
@end

@implementation FeedViewController
@synthesize posts, spinner, statusLabel;

- (void)dealloc { [posts release]; [spinner release]; [statusLabel release]; [super dealloc]; }

- (DTFPost *)postFrom:(id)dict
{
    DTFPost *p = [[[DTFPost alloc] init] autorelease];
    if (![dict isKindOfClass:[NSDictionary class]]) return p;

    id t = [dict objectForKey:@"title"];
    p.title = ([t isKindOfClass:[NSString class]] && [t length] > 0) ? t : @"(без заголовка)";

    id sub = [dict objectForKey:@"subsite"];
    if ([sub isKindOfClass:[NSDictionary class]]) {
        id name = [sub objectForKey:@"name"];
        if ([name isKindOfClass:[NSString class]]) p.subsite = name;
    }
    id counters = [dict objectForKey:@"counters"];
    if ([counters isKindOfClass:[NSDictionary class]]) {
        id c = [counters objectForKey:@"comments"];
        if ([c respondsToSelector:@selector(integerValue)]) p.comments = [c integerValue];
    }
    return p;
}

- (void)load
{
    [self.spinner startAnimating];
    self.statusLabel.hidden = NO;
    self.statusLabel.text = @"Загружаю ленту...";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSData *data = DTFGet(@"api.dtf.ru", @"/v2.31/feed?pageName=popular&count=30", &err);

        NSMutableArray *parsed = [NSMutableArray array];
        NSString *problem = err;

        if (data != nil) {
            NSError *jsonErr = nil;
            id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (![root isKindOfClass:[NSDictionary class]]) {
                problem = @"ответ не разобрался как JSON";
            } else {
                id items = [[root objectForKey:@"result"] objectForKey:@"items"];
                if ([items isKindOfClass:[NSArray class]]) {
                    for (id item in items) {
                        if (![item isKindOfClass:[NSDictionary class]]) continue;
                        id payload = [item objectForKey:@"data"];
                        if (![payload isKindOfClass:[NSDictionary class]]) continue;

                        /* A feed item is either one entry or a bundle of news. */
                        id news = [payload objectForKey:@"news"];
                        if ([news isKindOfClass:[NSArray class]]) {
                            for (id n in news) [parsed addObject:[self postFrom:n]];
                        } else {
                            [parsed addObject:[self postFrom:payload]];
                        }
                    }
                }
                if ([parsed count] == 0 && problem == nil) problem = @"лента пустая";
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            [self.posts removeAllObjects];
            [self.posts addObjectsFromArray:parsed];

            if ([self.posts count] > 0) {
                self.statusLabel.hidden = YES;
            } else {
                self.statusLabel.hidden = NO;
                self.statusLabel.text = [NSString stringWithFormat:@"Не вышло:\n%@",
                                         problem ? problem : @"неизвестная ошибка"];
            }
            [self.tableView reloadData];
        });
    });
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Популярное";
    self.posts = [NSMutableArray array];
    self.tableView.rowHeight = 68.0f;

    self.spinner = [[[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0f, 100.0f);
    [self.view addSubview:self.spinner];

    self.statusLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(10.0f, 130.0f, self.view.bounds.size.width - 20.0f, 70.0f)] autorelease];
    self.statusLabel.textAlignment = UITextAlignmentCenter;
    self.statusLabel.numberOfLines = 4;
    self.statusLabel.font = [UIFont systemFontOfSize:13.0f];
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.statusLabel];

    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self
                             action:@selector(load)] autorelease];
    [self load];
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
    }
    DTFPost *p = [self.posts objectAtIndex:(NSUInteger)ip.row];
    cell.textLabel.text = p.title;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %d комм.",
                                 p.subsite ? p.subsite : @"DTF", (int)p.comments];
    return cell;
}

@end

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
