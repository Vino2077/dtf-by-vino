#import "dtf_ui.h"
#import "dtf_net.h"
#import "dtf_api.h"
#import <QuartzCore/QuartzCore.h>

UIColor *DTFBlue(void)
{
    return [UIColor colorWithRed:0.357f green:0.510f blue:0.949f alpha:1.0f]; /* #5B82F2 */
}

UIColor *DTFPaper(void)
{
    return [UIColor colorWithRed:0.965f green:0.961f blue:0.945f alpha:1.0f];
}

void DTFStyleBar(UINavigationBar *bar)
{
    if (bar == nil) return;
    bar.tintColor = DTFBlue();   /* iOS 6 renders the gloss and bevel itself */
    bar.barStyle = UIBarStyleDefault;
}

void DTFStyleToolbar(UIToolbar *bar)
{
    if (bar == nil) return;
    bar.tintColor = DTFBlue();
    bar.barStyle = UIBarStyleDefault;
}

void DTFLetterpress(UILabel *label)
{
    if (label == nil) return;
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
    label.shadowOffset = CGSizeMake(0.0f, 1.0f);
}

UIButton *DTFButton(NSString *title, id target, SEL action)
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    [b setTitleColor:DTFBlue() forState:UIControlStateNormal];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

void DTFGradientCell(UITableViewCell *cell)
{
    if (cell == nil) return;
    UIView *bg = [[[UIView alloc] initWithFrame:cell.bounds] autorelease];
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = cell.bounds;
    g.colors = [NSArray arrayWithObjects:
        (id)[[UIColor colorWithWhite:1.0f alpha:1.0f] CGColor],
        (id)[[UIColor colorWithWhite:0.937f alpha:1.0f] CGColor], nil];
    [bg.layer insertSublayer:g atIndex:0];
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cell.backgroundView = bg;
}

/* ------------------------------------------------------------------ */

@implementation DTFImages

/* A concurrent queue with a small semaphore instead of one serial queue: a
   single line got saturated by a screenful of feed thumbnails, and avatars or
   reaction icons queued behind them never arrived. Three at a time is what
   this CPU can handle without the UI stuttering. */
+ (dispatch_queue_t)queue
{
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("ru.vino.dtf.images", DISPATCH_QUEUE_CONCURRENT);
    });
    return q;
}

+ (dispatch_semaphore_t)slots
{
    static dispatch_semaphore_t s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = dispatch_semaphore_create(3); });
    return s;
}

/* Keys currently being fetched, so a cell scrolling in and out again does not
   queue the same picture over and over. */
+ (NSMutableSet *)inFlight
{
    static NSMutableSet *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[NSMutableSet alloc] init]; });
    return s;
}

+ (BOOL)beginFetch:(NSString *)key
{
    @synchronized ([self inFlight]) {
        if ([[self inFlight] containsObject:key]) return NO;
        [[self inFlight] addObject:key];
        return YES;
    }
}

+ (void)endFetch:(NSString *)key
{
    @synchronized ([self inFlight]) { [[self inFlight] removeObject:key]; }
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
    if (key == nil) return nil;
    @synchronized ([self store]) { return [[self store] objectForKey:key]; }
}

+ (void)store:(UIImage *)img forKey:(NSString *)key
{
    if (img == nil || key == nil) return;
    @synchronized ([self store]) {
        /* This device has very little memory to spare. */
        if ([[self store] count] > 50) [[self store] removeAllObjects];
        [[self store] setObject:img forKey:key];
    }
}

+ (NSString *)diskPathFor:(NSString *)uuid width:(int)width
{
    static NSString *dir = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(
            NSCachesDirectory, NSUserDomainMask, YES);
        dir = [[[paths objectAtIndex:0] stringByAppendingPathComponent:@"dtfimg"] retain];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
    return [dir stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@_%d.jpg", uuid, width]];
}

+ (NSData *)fetchUuid:(NSString *)uuid width:(int)width
{
    if ([uuid length] == 0) return nil;

    /* Re-downloading over a fresh TLS handshake each time would be painful on
       this hardware, so finished images are kept on disk. */
    NSString *file = [self diskPathFor:uuid width:width];
    NSData *onDisk = [NSData dataWithContentsOfFile:file];
    if ([onDisk length] > 0) return onDisk;

    /* jpeg, not the default webp — iOS 6 cannot decode webp at all. */
    NSString *path = [NSString stringWithFormat:@"/%@/-/preview/%d/-/format/jpeg/",
                      uuid, width];
    NSData *d = DTFGet(kCdnHost, path, NULL);
    if ([d length] > 0) [d writeToFile:file atomically:YES];
    return d;
}

+ (void)loadUuid:(NSString *)uuid width:(int)width into:(UIImageView *)view
{
    if ([uuid length] == 0 || view == nil) return;
    UIImage *hit = [self cached:uuid];
    if (hit != nil) { view.image = hit; return; }

    NSString *key = [[uuid copy] autorelease];
    UIImageView *target = [[view retain] autorelease];
    NSInteger stamp = ++target.tag;

    dispatch_async([self queue], ^{
        dispatch_semaphore_wait([self slots], DISPATCH_TIME_FOREVER);

        UIImage *img = [self cached:key];
        if (img == nil) {
            if ([self beginFetch:key]) {
                NSData *d = [self fetchUuid:key width:width];
                img = [d length] > 0 ? [UIImage imageWithData:d] : nil;
                if (img != nil) [self store:img forKey:key];
                [self endFetch:key];
            } else {
                /* Someone else is already fetching it; take the cached copy
                   when it lands rather than opening a second connection. */
                for (int i = 0; i < 40 && img == nil; i++) {
                    usleep(150000);
                    img = [self cached:key];
                }
            }
        }
        dispatch_semaphore_signal([self slots]);
        if (img == nil) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            /* The cell may have been reused for another row meanwhile. */
            if (target.tag != stamp) return;
            target.image = img;
            /* A table cell lays its image view out at zero size when there was
               no image at layout time, so ask for another pass. */
            [target setNeedsLayout];
            [target.superview setNeedsLayout];
        });
    });
}

/* A neutral tile so rows reserve space before the picture arrives. */
UIImage *DTFPlaceholder(CGFloat side)
{
    static NSMutableDictionary *cache = nil;
    if (cache == nil) cache = [[NSMutableDictionary alloc] init];
    NSString *key = [NSString stringWithFormat:@"%d", (int)side];
    UIImage *img = [cache objectForKey:key];
    if (img != nil) return img;

    CGSize size = CGSizeMake(side, side);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx,
        [[UIColor colorWithWhite:0.87f alpha:1.0f] CGColor]);
    CGContextFillRect(ctx, CGRectMake(0.0f, 0.0f, side, side));
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (img != nil) [cache setObject:img forKey:key];
    return img;
}

@end

/* ------------------------------------------------------------------ */

NSString *DTFBase64(NSData *data)
{
    static const char *tbl = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const unsigned char *in = (const unsigned char *)[data bytes];
    NSUInteger len = [data length];
    if (len == 0) return @"";
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

NSString *DTFHtmlHead(void)
{
    /* Paper tone, engraved headings and bevelled blocks, to sit with the rest
       of the skeuomorphic chrome. */
    return @"<html><head>"
            "<meta name='viewport' content='width=device-width, initial-scale=1'>"
            "<style>"
            "body{font:15px/1.55 Helvetica,Arial;margin:0;padding:12px;color:#1a1a1a;"
            "background:#f6f5f1;-webkit-text-size-adjust:none;word-wrap:break-word}"
            "h1{font-size:21px;line-height:1.25;margin:0 0 8px;color:#222;"
            "text-shadow:0 1px 0 #fff}"
            "h2{font-size:17px;margin:20px 0 6px;color:#333;text-shadow:0 1px 0 #fff;"
            "border-bottom:1px solid #ddd;padding-bottom:4px}"
            ".meta{color:#8a8a8a;font-size:12px;margin-bottom:14px;text-shadow:0 1px 0 #fff}"
            "img{max-width:100%;height:auto;display:block;margin:12px 0;"
            "border:1px solid #cfcfcf;border-radius:5px;"
            "box-shadow:0 1px 3px rgba(0,0,0,.25)}"
            "blockquote{margin:14px 0;padding:8px 12px;border-left:4px solid #5b82f2;"
            "background:#eceaf6;border-radius:0 4px 4px 0;color:#444}"
            "a{color:#3a63d8;text-decoration:none}"
            "ul{padding-left:22px}"
            ".sep{text-align:center;color:#bbb;letter-spacing:7px;margin:20px 0;"
            "text-shadow:0 1px 0 #fff}"
            ".card{background:#fff;border:1px solid #d8d8d8;border-radius:6px;"
            "box-shadow:0 1px 2px rgba(0,0,0,.12);padding:9px 11px;margin:8px 0}"
            ".who{font-weight:bold;font-size:13px;color:#33489c}"
            ".body{font-size:14px;margin-top:3px}"
            ".note{color:#999;font-size:12px;font-style:italic}"
            ".pill{display:inline-block;background:#e8e8e8;border:1px solid #ccc;"
            ".av{width:22px;height:22px;display:inline-block;vertical-align:-6px;"
            "margin:0 5px 0 0;border-radius:4px;background:#dcdcdc;border:0;"
            "box-shadow:none;object-fit:cover}"
            ".rxrow{margin:6px 0 2px}"
            ".rx{width:19px;height:19px;display:inline;vertical-align:-4px;margin:0;"
            "border:0;box-shadow:none;border-radius:3px}"
            "border-radius:10px;padding:1px 8px;font-size:12px;color:#555;margin-right:5px}"
            "</style></head><body>";
}

@implementation DTFImages (Paths)

+ (NSString *)readyPathFor:(NSString *)uuid width:(int)width
{
    if ([uuid length] == 0) return nil;
    NSString *p = [self diskPathFor:uuid width:width];
    return [[NSFileManager defaultManager] fileExistsAtPath:p] ? p : nil;
}

@end
