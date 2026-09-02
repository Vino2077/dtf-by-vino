#import "dtf_vcs.h"
#import "dtf_api.h"
#import "dtf_ui.h"
#import "dtf_net.h"

/* ------------------------------------------------------------------ */
/* Sign in                                                             */
/* ------------------------------------------------------------------ */

@interface LoginViewController ()
@property (nonatomic, retain) UITextField *emailField;
@property (nonatomic, retain) UITextField *passwordField;
@property (nonatomic, retain) UITextView *tokenField;
@property (nonatomic, retain) UILabel *errorLabel;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@end

@implementation LoginViewController
@synthesize emailField, passwordField, tokenField, errorLabel, spinner;

- (void)dealloc
{
    [emailField release]; [passwordField release]; [tokenField release];
    [errorLabel release]; [spinner release];
    [super dealloc];
}

- (UITextField *)fieldAt:(CGFloat)y placeholder:(NSString *)ph secure:(BOOL)secure
{
    UITextField *f = [[[UITextField alloc] initWithFrame:
        CGRectMake(14.0f, y, self.view.bounds.size.width - 28.0f, 32.0f)] autorelease];
    f.borderStyle = UITextBorderStyleRoundedRect;
    f.placeholder = ph;
    f.font = [UIFont systemFontOfSize:15.0f];
    f.secureTextEntry = secure;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.delegate = self;
    f.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:f];
    return f;
}

- (UILabel *)captionAt:(CGFloat)y text:(NSString *)text
{
    UILabel *l = [[[UILabel alloc] initWithFrame:
        CGRectMake(16.0f, y, self.view.bounds.size.width - 32.0f, 18.0f)] autorelease];
    l.text = text;
    l.font = [UIFont boldSystemFontOfSize:12.0f];
    l.textColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(l);
    [self.view addSubview:l];
    return l;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Вход";
    self.view.backgroundColor = DTFPaper();

    [self captionAt:12.0f text:@"ПОЧТА И ПАРОЛЬ"];
    self.emailField = [self fieldAt:34.0f placeholder:@"email@example.com" secure:NO];
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.passwordField = [self fieldAt:74.0f placeholder:@"Пароль" secure:YES];

    UIButton *go = DTFButton(@"Войти", self, @selector(loginWithPassword));
    go.frame = CGRectMake(14.0f, 116.0f, self.view.bounds.size.width - 28.0f, 40.0f);
    go.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:go];

    [self captionAt:172.0f text:@"ИЛИ ТОКЕН"];
    UILabel *hint = [[[UILabel alloc] initWithFrame:
        CGRectMake(16.0f, 192.0f, self.view.bounds.size.width - 32.0f, 46.0f)] autorelease];
    hint.text = @"На сайте: Профиль → Настройки → внизу «Инструменты для разработчика».";
    hint.numberOfLines = 3;
    hint.font = [UIFont systemFontOfSize:12.0f];
    hint.textColor = [UIColor grayColor];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(hint);
    [self.view addSubview:hint];

    self.tokenField = [[[UITextView alloc] initWithFrame:
        CGRectMake(14.0f, 240.0f, self.view.bounds.size.width - 28.0f, 58.0f)] autorelease];
    self.tokenField.font = [UIFont systemFontOfSize:11.0f];
    self.tokenField.layer.borderColor = [[UIColor colorWithWhite:0.7f alpha:1.0f] CGColor];
    self.tokenField.layer.borderWidth = 1.0f;
    self.tokenField.layer.cornerRadius = 6.0f;
    self.tokenField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.tokenField];

    UIButton *useToken = DTFButton(@"Войти по токену", self, @selector(loginWithToken));
    useToken.frame = CGRectMake(14.0f, 304.0f, self.view.bounds.size.width - 28.0f, 38.0f);
    useToken.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:useToken];

    self.errorLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(14.0f, 348.0f, self.view.bounds.size.width - 28.0f, 60.0f)] autorelease];
    self.errorLabel.numberOfLines = 3;
    self.errorLabel.font = [UIFont systemFontOfSize:13.0f];
    self.errorLabel.textColor = [UIColor colorWithRed:0.7f green:0.1f blue:0.1f alpha:1.0f];
    self.errorLabel.textAlignment = UITextAlignmentCenter;
    self.errorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(self.errorLabel);
    [self.view addSubview:self.errorLabel];

    self.spinner = [[[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0f, 410.0f);
    [self.view addSubview:self.spinner];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { [tf resignFirstResponder]; return YES; }

- (void)finishOk:(BOOL)ok message:(NSString *)message
{
    [self.spinner stopAnimating];
    if (ok) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        self.errorLabel.text = message;
    }
}

- (void)loginWithPassword
{
    NSString *email = self.emailField.text;
    NSString *pass = self.passwordField.text;
    if ([email length] == 0 || [pass length] == 0) {
        self.errorLabel.text = @"Заполни почту и пароль";
        return;
    }
    self.errorLabel.text = @"";
    [self.spinner startAnimating];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *err = nil;
        NSString *token = [DTFApi loginWithEmail:email password:pass error:&err];
        if ([token length] > 0) DTFSetToken(token);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishOk:[token length] > 0
                   message:err ? err : @"Не удалось войти"];
        });
    });
}

- (void)loginWithToken
{
    NSString *t = [self.tokenField.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([t length] < 10) { self.errorLabel.text = @"Вставь токен"; return; }
    self.errorLabel.text = @"";
    [self.spinner startAnimating];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = [DTFApi validateToken:t];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishOk:ok message:@"Токен не подошёл"];
        });
    });
}

@end

/* ------------------------------------------------------------------ */
/* Settings                                                            */
/* ------------------------------------------------------------------ */

static NSString *const kHideCompany = @"dtf_hide_company";
static NSString *const kImagesOn = @"dtf_images_on";

@implementation SettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Настройки";
    self.tableView.backgroundColor = DTFPaper();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    if (s == 0) return 2;   /* images, company filter */
    if (s == 1) return 1;   /* clear cache */
    return 1;               /* about */
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s
{
    if (s == 0) return @"Лента";
    if (s == 1) return @"Хранилище";
    return @"О приложении";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s
{
    if (s == 0) {
        return @"Отключение картинок заметно ускоряет ленту на старых устройствах.";
    }
    if (s == 2) {
        return @"Своё шифрование внутри приложения — трафик идёт напрямую к DTF, "
                "без посредников.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"set";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:ident] autorelease];
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

    if (ip.section == 0) {
        UISwitch *sw = [[[UISwitch alloc] init] autorelease];
        if (ip.row == 0) {
            cell.textLabel.text = @"Показывать картинки";
            sw.on = [d objectForKey:kImagesOn] == nil ? YES : [d boolForKey:kImagesOn];
            sw.tag = 1;
        } else {
            cell.textLabel.text = @"Скрывать посты компаний";
            sw.on = [d boolForKey:kHideCompany];
            sw.tag = 2;
        }
        [sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (ip.section == 1) {
        cell.textLabel.text = @"Очистить кэш картинок";
    } else {
        cell.textLabel.text = @"DTF by Vino для iOS 6";
        cell.detailTextLabel.text = @"версия 0.2";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)toggle:(UISwitch *)sw
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:sw.on forKey:(sw.tag == 1 ? kImagesOn : kHideCompany)];
    [d synchronize];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 1) return;

    NSArray *paths = NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"dtfimg"];
    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    [[[[UIAlertView alloc] initWithTitle:@"Кэш очищен" message:nil delegate:nil
                       cancelButtonTitle:@"Ок" otherButtonTitles:nil] autorelease] show];
}

@end

/* ------------------------------------------------------------------ */
/* Compose a post                                                      */
/* ------------------------------------------------------------------ */

@interface EditorViewController ()
@property (nonatomic, retain) UITextField *titleField;
@property (nonatomic, retain) UITextView *bodyView;
@property (nonatomic, retain) UILabel *statusLabel;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@end

@implementation EditorViewController
@synthesize titleField, bodyView, statusLabel, spinner;

- (void)dealloc
{
    [titleField release]; [bodyView release];
    [statusLabel release]; [spinner release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Новый пост";
    self.view.backgroundColor = DTFPaper();

    CGFloat w = self.view.bounds.size.width;

    self.titleField = [[[UITextField alloc] initWithFrame:
        CGRectMake(12.0f, 12.0f, w - 24.0f, 34.0f)] autorelease];
    self.titleField.borderStyle = UITextBorderStyleRoundedRect;
    self.titleField.placeholder = @"Заголовок";
    self.titleField.font = [UIFont boldSystemFontOfSize:16.0f];
    self.titleField.delegate = self;
    self.titleField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.titleField];

    self.bodyView = [[[UITextView alloc] initWithFrame:
        CGRectMake(12.0f, 54.0f, w - 24.0f, 170.0f)] autorelease];
    self.bodyView.font = [UIFont systemFontOfSize:15.0f];
    self.bodyView.layer.borderColor = [[UIColor colorWithWhite:0.7f alpha:1.0f] CGColor];
    self.bodyView.layer.borderWidth = 1.0f;
    self.bodyView.layer.cornerRadius = 6.0f;
    self.bodyView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.bodyView];

    UILabel *hint = [[[UILabel alloc] initWithFrame:
        CGRectMake(14.0f, 228.0f, w - 28.0f, 32.0f)] autorelease];
    hint.text = @"Каждая строка станет отдельным абзацем.";
    hint.font = [UIFont systemFontOfSize:12.0f];
    hint.numberOfLines = 2;
    hint.textColor = [UIColor grayColor];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    DTFLetterpress(hint);
    [self.view addSubview:hint];

    self.statusLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(14.0f, 262.0f, w - 28.0f, 48.0f)] autorelease];
    self.statusLabel.numberOfLines = 3;
    self.statusLabel.font = [UIFont systemFontOfSize:13.0f];
    self.statusLabel.textAlignment = UITextAlignmentCenter;
    self.statusLabel.textColor = [UIColor colorWithRed:0.7f green:0.1f blue:0.1f alpha:1.0f];
    self.statusLabel.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    DTFLetterpress(self.statusLabel);
    [self.view addSubview:self.statusLabel];

    self.spinner = [[[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.spinner.center = CGPointMake(w / 2.0f, 318.0f);
    self.spinner.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.spinner];

    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
        initWithTitle:@"Опубликовать" style:UIBarButtonItemStyleDone
               target:self action:@selector(publish)] autorelease];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf
{
    [self.bodyView becomeFirstResponder];
    return NO;
}

- (void)publish
{
    NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *body = self.bodyView.text;
    if ([body length] == 0) {
        self.statusLabel.text = @"Нечего публиковать";
        return;
    }
    [self.titleField resignFirstResponder];
    [self.bodyView resignFirstResponder];
    self.statusLabel.text = @"";
    [self.spinner startAnimating];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *me = [DTFApi meWithError:NULL];
        NSInteger sid = DTFInt([me objectForKey:@"id"]);
        NSString *err = nil;
        NSInteger newId = sid > 0
            ? [DTFApi publishTitle:title text:body subsiteId:sid error:&err]
            : 0;
        if (sid <= 0 && err == nil) err = @"не удалось определить твой блог";

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (newId > 0) {
                [[[[UIAlertView alloc] initWithTitle:@"Опубликовано"
                                             message:nil delegate:nil
                                   cancelButtonTitle:@"Ок"
                                   otherButtonTitles:nil] autorelease] show];
                [self.navigationController popViewControllerAnimated:YES];
            } else {
                self.statusLabel.text = err ? err : @"Не удалось опубликовать";
            }
        });
    });
}

@end
