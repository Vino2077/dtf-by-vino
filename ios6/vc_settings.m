#import "dtf_vcs.h"
#import "dtf_api.h"
#import "dtf_ui.h"
#import "dtf_net.h"

/* ------------------------------------------------------------------ */
/* Sign in                                                             */
/* ------------------------------------------------------------------ */

@interface LoginViewController ()
@property (nonatomic, retain) UIScrollView *scroll;
@property (nonatomic, retain) UITextField *emailField;
@property (nonatomic, retain) UITextField *passwordField;
@property (nonatomic, retain) UILabel *statusLabel;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@property (nonatomic, retain) UIButton *goButton;
@end

@implementation LoginViewController
@synthesize scroll, emailField, passwordField, statusLabel, spinner, goButton;

- (void)dealloc
{
    [scroll release]; [emailField release]; [passwordField release];
    [statusLabel release]; [spinner release];
    [goButton release];
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
    [self.scroll addSubview:f];
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
    [self.scroll addSubview:l];
    return l;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Вход 1.1";
    self.view.backgroundColor = DTFPaper();

    /* Everything lives in a scroll view: on a 3.5-inch screen with a tab bar
       there are only ~367 points of room, and the earlier fixed layout put the
       progress text and spinner below that — the sign-in looked like it did
       nothing at all when in fact it was running. */
    self.scroll = [[[UIScrollView alloc] initWithFrame:self.view.bounds] autorelease];
    self.scroll.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scroll.backgroundColor = DTFPaper();
    [self.view addSubview:self.scroll];

    CGFloat w = self.view.bounds.size.width;

    /* Status sits directly under the button, well inside the visible area. */
    self.statusLabel = [[[UILabel alloc] initWithFrame:
        CGRectMake(14.0f, 8.0f, w - 28.0f, 38.0f)] autorelease];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.statusLabel.textAlignment = UITextAlignmentCenter;
    self.statusLabel.textColor = [UIColor colorWithWhite:0.3f alpha:1.0f];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    DTFLetterpress(self.statusLabel);
    [self.scroll addSubview:self.statusLabel];

    self.spinner = [[[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.spinner.center = CGPointMake(w / 2.0f, 60.0f);
    self.spinner.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.scroll addSubview:self.spinner];

    [self captionAt:80.0f text:@"ПОЧТА И ПАРОЛЬ"];
    self.emailField = [self fieldAt:102.0f placeholder:@"email@example.com" secure:NO];
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.passwordField = [self fieldAt:142.0f placeholder:@"Пароль" secure:YES];

    self.goButton = DTFButton(@"Войти", self, @selector(loginWithPassword));
    self.goButton.frame = CGRectMake(14.0f, 184.0f, w - 28.0f, 42.0f);
    self.goButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scroll addSubview:self.goButton];

    self.scroll.contentSize = CGSizeMake(w, 250.0f);
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { [tf resignFirstResponder]; return YES; }

/* Progress is reported step by step: on this hardware each stage takes real
   seconds, and silence is indistinguishable from a dead button. */
- (void)say:(NSString *)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.textColor = [UIColor colorWithWhite:0.3f alpha:1.0f];
        self.statusLabel.text = text;
    });
}

- (void)startWork:(NSString *)text
{
    self.goButton.enabled = NO;
    [self.spinner startAnimating];
    [self say:text];
}

- (void)finishOk:(BOOL)ok message:(NSString *)message
{
    [self.spinner stopAnimating];
    self.goButton.enabled = YES;
    if (ok) {
        self.statusLabel.text = @"Готово";
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    self.statusLabel.textColor = [UIColor colorWithRed:0.7f green:0.1f blue:0.1f alpha:1.0f];
    self.statusLabel.text = message;
    /* Also as an alert, so the reason cannot be missed. */
    [[[[UIAlertView alloc] initWithTitle:@"Не удалось войти"
                                 message:message
                                delegate:nil
                       cancelButtonTitle:@"Понятно"
                       otherButtonTitles:nil] autorelease] show];
}

- (void)loginWithPassword
{
    NSString *email = self.emailField.text;
    NSString *pass = self.passwordField.text;
    if ([email length] == 0 || [pass length] == 0) {
        [self finishOk:NO message:@"Заполни почту и пароль"];
        return;
    }
    [self.emailField resignFirstResponder];
    [self.passwordField resignFirstResponder];
    [self startWork:@"Соединяюсь с сервером…"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self say:@"Передаю данные, проверяю ключи шифрования…"];
        NSString *err = nil;
        NSString *token = [DTFApi loginWithEmail:email password:pass error:&err];
        if ([token length] > 0) {
            [self say:@"Проверяю доступ…"];
            DTFSetToken(token);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishOk:[token length] > 0
                   message:err ? err : @"Сервер не принял почту и пароль"];
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
    return 2;               /* about, diagnostics */
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
    } else if (ip.row == 0) {
        cell.textLabel.text = @"DTF by Vino для iOS 6";
        cell.detailTextLabel.text = @"версия 1.1";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.textLabel.text = @"Диагностика";
        cell.detailTextLabel.text = @"проверить картинки, сеть и токен";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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

    if (ip.section == 2 && ip.row == 1) {
        [self.navigationController pushViewController:
            [[[DiagnosticsViewController alloc] init] autorelease] animated:YES];
        return;
    }
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

/* ------------------------------------------------------------------ */
/* Diagnostics                                                         */
/* ------------------------------------------------------------------ */

@interface DiagnosticsViewController ()
@property (nonatomic, retain) UITextView *out;
@property (nonatomic, retain) UIWebView *probe;
@end

@implementation DiagnosticsViewController
@synthesize out, probe;

- (void)dealloc { [out release]; [probe release]; [super dealloc]; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Диагностика";
    self.view.backgroundColor = DTFPaper();

    CGRect b = self.view.bounds;
    self.out = [[[UITextView alloc] initWithFrame:
        CGRectMake(0.0f, 0.0f, b.size.width, b.size.height - 120.0f)] autorelease];
    self.out.editable = NO;
    self.out.font = [UIFont systemFontOfSize:11.0f];
    self.out.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.out];

    /* A tiny page that reports back whether an embedded picture actually
       rendered — the one thing that cannot be checked from the outside. */
    self.probe = [[[UIWebView alloc] initWithFrame:
        CGRectMake(0.0f, b.size.height - 118.0f, b.size.width, 110.0f)] autorelease];
    self.probe.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.probe];

    [self run];
}

- (void)add:(NSString *)line
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.out.text = [NSString stringWithFormat:@"%@%@\n", self.out.text, line];
    });
}

- (void)run
{
    self.out.text = @"";
    [self add:@"— ИКОНКИ РЕАКЦИЙ В ПАКЕТЕ —"];

    NSString *rx1 = [[NSBundle mainBundle] pathForResource:@"rx1" ofType:@"png"];
    if (rx1 == nil) {
        [self add:@"rx1.png: НЕ НАЙДЕН в пакете"];
    } else {
        NSData *d = [NSData dataWithContentsOfFile:rx1];
        [self add:[NSString stringWithFormat:@"rx1.png: %d байт", (int)[d length]]];
        NSString *b64 = DTFBase64(d);
        [self add:[NSString stringWithFormat:@"base64: %d символов, начало %@",
                   (int)[b64 length],
                   [b64 length] > 16 ? [b64 substringToIndex:16] : b64]];

        /* Render it two ways and let the page itself say what worked. */
        NSString *html = [NSString stringWithFormat:
            @"<html><body style='font:12px Helvetica;margin:4px'>"
             "<style>.t{width:24px;height:24px;display:inline-block;"
             "background-size:contain;background-repeat:no-repeat;"
             "background-image:url(\"data:image/png;base64,%@\")}</style>"
             "тег: <img src='data:image/png;base64,%@' width='24' height='24'> &nbsp; "
             "фон: <i class='t'></i><br>"
             "как в посте: <span style='background:#e8e8e8;border:1px solid #ccc;"
             "border-radius:10px;padding:1px 8px;font-size:12px'>"
             "<img src='data:image/png;base64,%@' width='15' height='15' "
             "style='width:15px;height:15px;display:inline;vertical-align:-2px;"
             "margin:0 3px 0 0;border:0'>42</span>"
             "</body></html>", b64, b64, b64];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.probe loadHTMLString:html baseURL:nil];
        });
        [self add:@"внизу проверка: слева картинкой, справа фоном"];
    }

    [self add:@""];
    [self add:@"— КЭШ КАРТИНОК —"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"dtfimg"];
    [self add:dir];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self add:@"качаю тестовую аватарку…"];
        NSString *uuid = @"4a807844-802c-5362-9b9e-3064efee09e5";
        NSDate *t0 = [NSDate date];
        NSData *img = [DTFImages fetchUuid:uuid width:48];
        [self add:[NSString stringWithFormat:@"аватарка: %d байт за %.1f сек",
                   (int)[img length], -[t0 timeIntervalSinceNow]]];
        NSString *ready = [DTFImages readyPathFor:uuid width:48];
        [self add:[NSString stringWithFormat:@"файл на диске: %@",
                   ready ? @"есть" : @"НЕТ"]];

        [self add:@""];
        [self add:@"— СКОРОСТЬ СЕТИ —"];
        NSDate *t1 = [NSDate date];
        NSData *a = DTFGet(kApiHost, @"/v2.31/subsite?id=494450", NULL);
        [self add:[NSString stringWithFormat:@"1-й запрос: %d байт за %.1f сек",
                   (int)[a length], -[t1 timeIntervalSinceNow]]];
        NSDate *t2 = [NSDate date];
        NSData *b2 = DTFGet(kApiHost, @"/v2.31/subsite?id=494450", NULL);
        [self add:[NSString stringWithFormat:@"2-й запрос: %d байт за %.1f сек "
                   "(должен быть быстрее — сессия переиспользуется)",
                   (int)[b2 length], -[t2 timeIntervalSinceNow]]];

        [self add:@""];
        [self add:@"— ТОКЕН —"];
        [self add:DTFToken() ? @"сохранён" : @"нет"];
        if (DTFToken() != nil) {
            NSString *err = nil;
            NSDictionary *me = [DTFApi meWithError:&err];
            [self add:[NSString stringWithFormat:@"subsite/me: %@ (HTTP %d)%@",
                       me ? @"ok" : @"отказ", DTFLastStatus(), err ? err : @""]];
        }
    });
}

@end
