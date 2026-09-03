#import <UIKit/UIKit.h>

/// One post as the lists need it.
@interface DTFPost : NSObject
@property (nonatomic, assign) NSInteger postId;
@property (nonatomic, assign) NSInteger subsiteId;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subsite;
@property (nonatomic, retain) NSString *author;
@property (nonatomic, retain) NSString *coverUuid;
@property (nonatomic, retain) NSString *avatarUuid;
@property (nonatomic, assign) NSInteger comments;
@property (nonatomic, assign) NSInteger reactions;
@property (nonatomic, assign) NSTimeInterval date;
@end

DTFPost *DTFPostFrom(id dict);
/// Pulls posts out of any feed-shaped response (entries and news bundles).
NSArray *DTFPostsFromItems(NSArray *items);
/// "5 мин", "3 ч", "2 дн" — the compact form used across the app.
NSString *DTFAgo(NSTimeInterval unixTime);

/// Table of posts, with the row layout and tap handling shared by every list
/// in the app. Subclasses supply the data by overriding -loadPage.
@interface PostListViewController : UITableViewController
@property (nonatomic, retain) NSMutableArray *posts;
@property (nonatomic, retain) UILabel *statusLabel;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL canPaginate;
@property (nonatomic, assign) BOOL noMore;
- (void)reload;
- (void)loadPage;                       /* override */
- (void)finishWith:(NSArray *)fresh problem:(NSString *)problem;
- (void)openPost:(DTFPost *)post;
@end

@interface FeedViewController : PostListViewController
@property (nonatomic, retain) NSString *feedName;
@property (nonatomic, retain) NSString *lastId;
@property (nonatomic, retain) NSString *lastSorting;
@end

@interface PostViewController : UIViewController <UIWebViewDelegate,
                                                  UIActionSheetDelegate,
                                                  UIAlertViewDelegate>
@property (nonatomic, assign) NSInteger postId;
@property (nonatomic, retain) NSString *headerTitle;
@end

@interface SearchViewController : PostListViewController <UISearchBarDelegate>
@property (nonatomic, retain) UISearchBar *searchBar;
@property (nonatomic, retain) NSString *query;
@end

@interface BookmarksViewController : PostListViewController
@end

/// Another author's blog.
@interface SubsiteViewController : PostListViewController
@property (nonatomic, assign) NSInteger subsiteId;
@property (nonatomic, retain) NSString *subsiteName;
@end

@interface NotificationsViewController : UITableViewController
@end

@interface ProfileViewController : UITableViewController
@end

@interface ChatsViewController : UITableViewController
@end

@interface ChatViewController : UIViewController <UITableViewDataSource,
                                                  UITableViewDelegate,
                                                  UITextFieldDelegate>
@property (nonatomic, assign) NSInteger channelId;
@property (nonatomic, retain) NSString *channelTitle;
@end

@interface SettingsViewController : UITableViewController <UIAlertViewDelegate>
@end

@interface LoginViewController : UIViewController <UITextFieldDelegate>
@end

/// Compose and publish a text post.
@interface EditorViewController : UIViewController <UITextFieldDelegate>
@end

/// Reports what actually happens at each step, so faults stop being guesswork.
@interface DiagnosticsViewController : UIViewController
@end
