#import "dtf_vcs.h"
#import "dtf_api.h"
#import "dtf_ui.h"
#import "dtf_net.h"

/* ------------------------------------------------------------------ */
/* Conversation list                                                   */
/* ------------------------------------------------------------------ */

@interface ChatsViewController ()
@property (nonatomic, retain) NSMutableArray *channels;
@property (nonatomic, retain) UILabel *status;
@end

@implementation ChatsViewController
@synthesize channels, status;

- (void)dealloc { [channels release]; [status release]; [super dealloc]; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Чаты";
    self.channels = [NSMutableArray array];
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
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self load];
}

- (void)load
{
    self.status.hidden = NO;
    self.status.text = @"Загружаю…";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSArray *fresh = [DTFApi channelsWithError:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.channels removeAllObjects];
            for (id c in fresh) if (DTFDict(c) != nil) [self.channels addObject:c];
            self.status.hidden = [self.channels count] > 0;
            self.status.text = err ? err : @"Диалогов нет";
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    return (NSInteger)[self.channels count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"chan";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:ident] autorelease];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.layer.cornerRadius = 5.0f;
        cell.imageView.clipsToBounds = YES;
        DTFGradientCell(cell);
    }

    NSDictionary *ch = DTFDict([self.channels objectAtIndex:(NSUInteger)ip.row]);
    cell.textLabel.text = DTFStr([ch objectForKey:@"title"]);

    NSDictionary *last = DTFDict([ch objectForKey:@"lastMessage"]);
    NSString *preview = DTFStr([last objectForKey:@"text"]);
    NSInteger unread = DTFInt([ch objectForKey:@"unreadCount"]);
    if ([[ch objectForKey:@"pendingAcceptance"] boolValue]) preview = @"Запрос на переписку";
    if ([preview length] == 0) preview = @"Вложение";
    cell.detailTextLabel.text = unread > 0
        ? [NSString stringWithFormat:@"● %@", preview] : preview;

    NSDictionary *pic = DTFDict([ch objectForKey:@"pictureData"]);
    NSString *uuid = DTFStr([DTFDict([pic objectForKey:@"data"]) objectForKey:@"uuid"]);
    cell.imageView.image = nil;
    if ([uuid length] > 0) [DTFImages loadUuid:uuid width:80 into:cell.imageView];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *ch = DTFDict([self.channels objectAtIndex:(NSUInteger)ip.row]);
    ChatViewController *vc = [[[ChatViewController alloc] init] autorelease];
    vc.channelId = DTFInt([ch objectForKey:@"id"]);
    vc.channelTitle = DTFStr([ch objectForKey:@"title"]);
    [self.navigationController pushViewController:vc animated:YES];
}

@end

/* ------------------------------------------------------------------ */
/* One conversation                                                    */
/* ------------------------------------------------------------------ */

@interface ChatViewController ()
@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) UITableView *table;
@property (nonatomic, retain) UITextField *input;
@property (nonatomic, retain) UIToolbar *composer;
@end

@implementation ChatViewController
@synthesize channelId, channelTitle, messages, table, input, composer;

- (void)dealloc
{
    [channelTitle release]; [messages release]; [table release];
    [input release]; [composer release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = [self.channelTitle length] > 0 ? self.channelTitle : @"Диалог";
    self.view.backgroundColor = DTFPaper();
    self.messages = [NSMutableArray array];

    CGRect b = self.view.bounds;
    self.table = [[[UITableView alloc] initWithFrame:
        CGRectMake(0.0f, 0.0f, b.size.width, b.size.height - 44.0f)
                                               style:UITableViewStylePlain] autorelease];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = DTFPaper();
    self.table.rowHeight = 58.0f;
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.table];

    self.composer = [[[UIToolbar alloc] initWithFrame:
        CGRectMake(0.0f, b.size.height - 44.0f, b.size.width, 44.0f)] autorelease];
    self.composer.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    DTFStyleToolbar(self.composer);

    self.input = [[[UITextField alloc] initWithFrame:
        CGRectMake(0.0f, 0.0f, b.size.width - 90.0f, 30.0f)] autorelease];
    self.input.borderStyle = UITextBorderStyleRoundedRect;
    self.input.placeholder = @"Сообщение";
    self.input.font = [UIFont systemFontOfSize:14.0f];
    self.input.delegate = self;
    self.input.returnKeyType = UIReturnKeySend;

    UIBarButtonItem *field = [[[UIBarButtonItem alloc]
        initWithCustomView:self.input] autorelease];
    UIBarButtonItem *send = [[[UIBarButtonItem alloc]
        initWithTitle:@"Отпр." style:UIBarButtonItemStyleDone
               target:self action:@selector(send)] autorelease];
    self.composer.items = [NSArray arrayWithObjects:field, send, nil];
    [self.view addSubview:self.composer];

    [self load];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self send]; return NO; }

- (void)load
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *fresh = [DTFApi messages:self.channelId error:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.messages removeAllObjects];
            for (id m in fresh) if (DTFDict(m) != nil) [self.messages addObject:m];
            [self.table reloadData];
            if ([self.messages count] > 0) {
                [self.table scrollToRowAtIndexPath:
                    [NSIndexPath indexPathForRow:(NSInteger)[self.messages count] - 1 inSection:0]
                                  atScrollPosition:UITableViewScrollPositionBottom animated:NO];
            }
        });
    });
}

- (void)send
{
    NSString *text = [self.input.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([text length] == 0) return;
    self.input.text = @"";
    [self.input resignFirstResponder];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi sendMessage:self.channelId text:text];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                [self load];
            } else {
                self.input.text = text;
                [[[[UIAlertView alloc] initWithTitle:@"Не отправилось" message:nil
                                            delegate:nil cancelButtonTitle:@"Ок"
                                   otherButtonTitles:nil] autorelease] show];
            }
        });
    });
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    return (NSInteger)[self.messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"msg";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:ident] autorelease];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.font = [UIFont systemFontOfSize:14.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        DTFGradientCell(cell);
    }
    NSDictionary *m = DTFDict([self.messages objectAtIndex:(NSUInteger)ip.row]);
    NSString *text = DTFStr([m objectForKey:@"text"]);
    cell.textLabel.text = [text length] > 0 ? text : @"[вложение]";
    NSString *who = DTFStr([DTFDict([m objectForKey:@"author"]) objectForKey:@"name"]);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
        who ? who : @"", DTFAgo((NSTimeInterval)DTFInt([m objectForKey:@"dtCreated"]))];
    return cell;
}

@end
