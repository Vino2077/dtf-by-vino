/*
 * DTF by Vino — iOS 6 client.
 *
 * Built with manual retain/release: the ARC runtime support library is no
 * longer shipped for a 6.0 deployment target.
 *
 * Everything on the wire goes through dtf_net, never the system stack — see
 * that header for why. The look is the stock skeuomorphism of this UIKit
 * (glossy bars, bevelled buttons, inset grouped tables), only tinted; the
 * extra gradients and letterpress live in dtf_ui.
 */
#import <UIKit/UIKit.h>
#import "dtf_vcs.h"
#import "dtf_ui.h"
#import "dtf_api.h"

@interface AppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UITabBarController *tabs;
@end

@implementation AppDelegate
@synthesize window, tabs;

- (void)dealloc { [window release]; [tabs release]; [super dealloc]; }

- (UINavigationController *)wrap:(UIViewController *)vc
                           title:(NSString *)title
                          system:(UITabBarSystemItem)item
{
    UINavigationController *nav = [[[UINavigationController alloc]
        initWithRootViewController:vc] autorelease];
    DTFStyleBar(nav.navigationBar);
    nav.tabBarItem = [[[UITabBarItem alloc] initWithTabBarSystemItem:item tag:0] autorelease];
    nav.tabBarItem.title = title;
    return nav;
}

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

    FeedViewController *feed = [[[FeedViewController alloc]
        initWithStyle:UITableViewStylePlain] autorelease];
    SearchViewController *search = [[[SearchViewController alloc]
        initWithStyle:UITableViewStylePlain] autorelease];
    ChatsViewController *chats = [[[ChatsViewController alloc]
        initWithStyle:UITableViewStylePlain] autorelease];
    NotificationsViewController *notes = [[[NotificationsViewController alloc]
        initWithStyle:UITableViewStylePlain] autorelease];
    ProfileViewController *profile = [[[ProfileViewController alloc]
        initWithStyle:UITableViewStyleGrouped] autorelease];

    self.tabs = [[[UITabBarController alloc] init] autorelease];
    self.tabs.viewControllers = [NSArray arrayWithObjects:
        [self wrap:feed    title:@"Лента"       system:UITabBarSystemItemMostRecent],
        [self wrap:search  title:@"Поиск"       system:UITabBarSystemItemSearch],
        [self wrap:chats   title:@"Чаты"        system:UITabBarSystemItemContacts],
        [self wrap:notes   title:@"Уведомления" system:UITabBarSystemItemHistory],
        [self wrap:profile title:@"Профиль"     system:UITabBarSystemItemMore],
        nil];

    self.window.rootViewController = self.tabs;
    self.window.backgroundColor = DTFPaper();
    [self.window makeKeyAndVisible];

    [self refreshBadge];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)app { [self refreshBadge]; }

/* Unread count on the notifications tab. */
- (void)refreshBadge
{
    if (![DTFApi isLoggedIn]) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger n = [DTFApi notificationCount];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *vc = [self.tabs.viewControllers objectAtIndex:3];
            vc.tabBarItem.badgeValue = n > 0
                ? [NSString stringWithFormat:@"%d", (int)n] : nil;
        });
    });
}

@end

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int rc = UIApplicationMain(argc, argv, nil, @"AppDelegate");
    [pool release];
    return rc;
}
