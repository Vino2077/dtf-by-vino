#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

/// Shared presentation bits: the skeuomorphic palette of the iOS 6 era, image
/// loading, and the stylesheet used to lay articles out as HTML.
///
/// UIKit of 2012 is skeuomorphic out of the box — glossy bars, bezelled
/// buttons, inset grouped tables — so most of the look comes free from using
/// the stock controls and only tinting them. The helpers here add the parts
/// UIKit will not do on its own: gradient cell backgrounds, letterpress
/// labels, and matching CSS for the article view.

/* DTF blue, and the warm paper tone the article view sits on. */
UIColor *DTFBlue(void);
UIColor *DTFPaper(void);

/// Glossy navigation/tool bars in the app tint.
void DTFStyleBar(UINavigationBar *bar);
void DTFStyleToolbar(UIToolbar *bar);

/// The engraved-into-the-surface look iOS 6 used for section text.
void DTFLetterpress(UILabel *label);

/// A bezelled button in the style of the era.
UIButton *DTFButton(NSString *title, id target, SEL action);

/// Vertical gradient behind a table cell, so rows read as raised panels.
void DTFGradientCell(UITableViewCell *cell);

/// Image cache + fetch. Loading is serialised: a 600 MHz single core must not
/// run several TLS handshakes at once.
@interface DTFImages : NSObject
+ (dispatch_queue_t)queue;
+ (UIImage *)cached:(NSString *)key;
+ (void)store:(UIImage *)img forKey:(NSString *)key;
+ (NSData *)fetchUuid:(NSString *)uuid width:(int)width;
/// Loads into `view`, from cache when possible; `tag` guards cell reuse.
+ (void)loadUuid:(NSString *)uuid width:(int)width into:(UIImageView *)view;
@end

/// A neutral tile so rows reserve space before the real picture lands.
UIImage *DTFPlaceholder(CGFloat side);

/// base64 for inlining images into HTML (iOS 6 predates the NSData category).
NSString *DTFBase64(NSData *data);

/// Head + CSS for the article view, styled to match the rest of the app.
NSString *DTFHtmlHead(void);
