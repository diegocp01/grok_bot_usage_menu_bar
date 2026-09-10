#import "PersistentStartup.h"
#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>
#import <sqlite3.h>
#import <math.h>
#import "BatteryRenderer.h"
#import "GrokUsageParser.h"

static NSString * const DisplayModeKey = @"displayMode";
static NSString * const DisplayModePercent = @"percent";
static NSString * const DisplayModeBattery = @"battery";
static NSString * const TimeModeKey = @"timeMode";
static NSString * const TimeModeClock = @"clock";
static NSString * const TimeModeCountdown = @"countdown";
static NSString * const MetricModeKey = @"metricMode";
static NSString * const MetricModeLeft = @"left";
static NSString * const MetricModeUsed = @"used";
static NSString * const RefreshIntervalKey = @"refreshIntervalSeconds";
static NSString * const LaunchAtLoginPreferenceKey = @"launchAtLoginPreference";
static NSTimeInterval const DefaultRefreshIntervalSeconds = 60.0;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *pollTimer;
@property(nonatomic, strong) NSTimer *displayTimer;
@property(nonatomic, strong) NSDictionary *latestState;
@property(nonatomic, strong) NSImage *grokIcon;
@property(nonatomic, copy) NSString *launchAtLoginError;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        DisplayModeKey: DisplayModeBattery,
        TimeModeKey: TimeModeCountdown,
        MetricModeKey: MetricModeLeft,
        RefreshIntervalKey: @(DefaultRefreshIntervalSeconds),
        LaunchAtLoginPreferenceKey: @YES
    }];

    [self ensureLaunchAtLoginIfPreferred];

    self.grokIcon = [self makeGrokIcon];
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = self.grokIcon;
    self.statusItem.button.imagePosition = NSImageLeft;
    self.statusItem.button.title = @" --:--";
    self.statusItem.button.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize
                                                                  weight:NSFontWeightSemibold];
    self.statusItem.menu = [self menuForCurrentState];

    [self refresh];
    [self schedulePollTimer];
    self.displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updateStatusItem)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (NSImage *)makeGrokIcon {
    NSImage *icon = [[NSImage alloc] initWithSize:NSMakeSize(18.0, 18.0)];
    [icon lockFocus];
    [NSColor.blackColor setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1.0, 1.0, 16.0, 16.0)] fill];

    NSGraphicsContext.currentContext.compositingOperation = NSCompositingOperationClear;
    NSArray<NSDictionary *> *eyes = @[
        @{@"center": [NSValue valueWithPoint:NSMakePoint(9.8, 10.6)], @"width": @1.45, @"height": @3.35},
        @{@"center": [NSValue valueWithPoint:NSMakePoint(14.0, 11.5)], @"width": @1.65, @"height": @4.0}
    ];
    for (NSDictionary *eyeSpec in eyes) {
        NSPoint center = [eyeSpec[@"center"] pointValue];
        CGFloat width = [eyeSpec[@"width"] doubleValue];
        CGFloat height = [eyeSpec[@"height"] doubleValue];
        NSBezierPath *eye = [NSBezierPath bezierPathWithRoundedRect:
            NSMakeRect(center.x - width / 2.0, center.y - height / 2.0, width, height)
                                                         xRadius:width / 2.0 yRadius:width / 2.0];
        NSAffineTransform *rotation = [NSAffineTransform transform];
        [rotation translateXBy:center.x yBy:center.y];
        [rotation rotateByDegrees:20.0];
        [rotation translateXBy:-center.x yBy:-center.y];
        [eye transformUsingAffineTransform:rotation];
        [eye fill];
    }
    [icon unlockFocus];
    icon.template = YES;
    icon.accessibilityDescription = @"Grok Bot";
    return icon;
}

- (NSImage *)batteryIconForPercent:(double)percent {
    return GrokBatteryIcon(self.grokIcon, percent);
}

- (BOOL)renderPreviewAtPath:(NSString *)path error:(NSError **)error {
    if (self.grokIcon == nil) {
        self.grokIcon = [self makeGrokIcon];
    }
    NSDictionary *state = [self loadUsageState];
    if (![state[@"ok"] boolValue]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsagePreview" code:1
                                     userInfo:@{NSLocalizedDescriptionKey: state[@"error"] ?: @"Usage unavailable"}];
        }
        return NO;
    }

    NSImage *battery = [self batteryIconForPercent:[state[@"left_percent"] doubleValue]];
    NSString *countdown = [self countdownText:state] ?: @"--:--";
    NSImage *canvas = [[NSImage alloc] initWithSize:NSMakeSize(280.0, 44.0)];
    [canvas lockFocus];
    [[NSColor colorWithCalibratedRed:0.075 green:0.235 blue:0.365 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, 280.0, 44.0));

    NSImage *tintedBattery = [[NSImage alloc] initWithSize:battery.size];
    [tintedBattery lockFocus];
    [battery drawInRect:NSMakeRect(0.0, 0.0, battery.size.width, battery.size.height)];
    [NSColor.whiteColor setFill];
    NSRectFillUsingOperation(NSMakeRect(0.0, 0.0, battery.size.width, battery.size.height),
                             NSCompositingOperationSourceAtop);
    [tintedBattery unlockFocus];
    [tintedBattery drawInRect:NSMakeRect(18.0, 13.0, 67.0, 18.0)];

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:18.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.whiteColor
    };
    [countdown drawAtPoint:NSMakePoint(98.0, 11.0) withAttributes:attributes];
    [canvas unlockFocus];

    CGImageRef cgImage = [canvas CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage == NULL) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsagePreview" code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not render preview."}];
        }
        return NO;
    }
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:path options:NSDataWritingAtomic error:error];
}

- (void)menuWillOpen:(NSMenu *)menu {
    (void)menu;
    self.statusItem.menu = [self menuForCurrentState];
}

- (NSMenu *)menuForCurrentState {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Grok Bot Usage"];
    menu.delegate = self;

    NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:@"Grok Bot Usage" action:nil keyEquivalent:@""];
    header.enabled = NO;
    [menu addItem:header];
    [menu addItem:NSMenuItem.separatorItem];

    NSDictionary *state = self.latestState;
    if ([state[@"ok"] boolValue]) {
        double used = [state[@"used_percent"] doubleValue];
        double left = [state[@"left_percent"] doubleValue];
        [self addDisabledItem:[NSString stringWithFormat:@"Grok Bot: %.1f%% left, %.1f%% used", left, used]
                        toMenu:menu];
        [self addDisabledItem:[NSString stringWithFormat:@"Weekly reset: %@", [self resetDetailText:state] ?: @"unknown"]
                        toMenu:menu];
        [self addDisabledItem:[NSString stringWithFormat:@"Countdown: %@", [self countdownText:state] ?: @"unknown"]
                        toMenu:menu];
        [self addDisabledItem:[NSString stringWithFormat:@"Updated: %@", [self updatedText:state]] toMenu:menu];
        [self addDisabledItem:@"Source: Cursor Grok Bot weekly quota" toMenu:menu];
    } else {
        [self addDisabledItem:@"Grok Bot usage: unavailable" toMenu:menu];
        [self addDisabledItem:[NSString stringWithFormat:@"Error: %@", state[@"error"] ?: @"Waiting for first refresh"]
                        toMenu:menu];
    }

    if (self.launchAtLoginError.length > 0) {
        [self addDisabledItem:[NSString stringWithFormat:@"Login item: %@", self.launchAtLoginError] toMenu:menu];
    }

    [menu addItem:NSMenuItem.separatorItem];
    [self addChoice:@"Show Battery" selector:@selector(useBatteryDisplay)
             active:[[self displayMode] isEqualToString:DisplayModeBattery] menu:menu];
    [self addChoice:@"Show Percentage" selector:@selector(usePercentDisplay)
             active:[[self displayMode] isEqualToString:DisplayModePercent] menu:menu];

    [menu addItem:NSMenuItem.separatorItem];
    [self addChoice:@"Show % Left" selector:@selector(useLeftMetric)
             active:[[self metricMode] isEqualToString:MetricModeLeft] menu:menu];
    [self addChoice:@"Show % Used" selector:@selector(useUsedMetric)
             active:[[self metricMode] isEqualToString:MetricModeUsed] menu:menu];

    [menu addItem:NSMenuItem.separatorItem];
    [self addChoice:@"Show Countdown" selector:@selector(useCountdownTime)
             active:[[self timeMode] isEqualToString:TimeModeCountdown] menu:menu];
    [self addChoice:@"Show Reset Time" selector:@selector(useClockTime)
             active:[[self timeMode] isEqualToString:TimeModeClock] menu:menu];

    [menu addItem:NSMenuItem.separatorItem];
    [self addRefreshIntervalSubmenu:menu];
    [menu addItem:NSMenuItem.separatorItem];
    [self addChoice:@"Launch at Login & Keep Running" selector:@selector(toggleLaunchAtLogin)
             active:[self launchAtLoginEnabled] menu:menu];

    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *dashboard = [[NSMenuItem alloc] initWithTitle:@"Open Cursor Dashboard"
                                                       action:@selector(openDashboard)
                                                keyEquivalent:@""];
    dashboard.target = self;
    [menu addItem:dashboard];

    NSMenuItem *refresh = [[NSMenuItem alloc] initWithTitle:@"Refresh Now"
                                                     action:@selector(refresh)
                                              keyEquivalent:@"r"];
    refresh.target = self;
    [menu addItem:refresh];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                  action:@selector(quit)
                                           keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
    return menu;
}

- (void)addDisabledItem:(NSString *)title toMenu:(NSMenu *)menu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title ?: @"" action:nil keyEquivalent:@""];
    item.enabled = NO;
    [menu addItem:item];
}

- (void)addChoice:(NSString *)title selector:(SEL)selector active:(BOOL)active menu:(NSMenu *)menu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
    item.target = self;
    item.state = active ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:item];
}

- (void)addRefreshIntervalSubmenu:(NSMenu *)menu {
    NSTimeInterval current = [self refreshIntervalSeconds];
    NSMenuItem *root = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Refresh Every: %@",
                                                          [self refreshIntervalLabel:current]]
                                                  action:nil keyEquivalent:@""];
    NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"Refresh Every"];
    for (NSNumber *interval in @[@30.0, @60.0, @180.0, @300.0]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[self refreshIntervalLabel:interval.doubleValue]
                                                      action:@selector(useRefreshInterval:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = interval;
        item.state = fabs(interval.doubleValue - current) < 0.5 ? NSControlStateValueOn : NSControlStateValueOff;
        [submenu addItem:item];
    }
    root.submenu = submenu;
    [menu addItem:root];
}

- (void)updateStatusItem {
    NSDictionary *state = self.latestState;
    if (![state[@"ok"] boolValue]) {
        self.statusItem.button.image = self.grokIcon;
        self.statusItem.button.title = @" --:--";
        return;
    }

    double metric = [[self metricMode] isEqualToString:MetricModeUsed]
        ? [state[@"used_percent"] doubleValue]
        : [state[@"left_percent"] doubleValue];
    NSString *time = [[self timeMode] isEqualToString:TimeModeCountdown]
        ? [self countdownText:state]
        : [self resetClockText:state];
    if (time.length == 0) {
        time = @"--:--";
    }

    if ([[self displayMode] isEqualToString:DisplayModeBattery]) {
        self.statusItem.button.image = [self batteryIconForPercent:metric];
        self.statusItem.button.title = [@" " stringByAppendingString:time];
    } else {
        self.statusItem.button.image = self.grokIcon;
        NSString *suffix = [[self metricMode] isEqualToString:MetricModeUsed] ? @" used" : @" left";
        self.statusItem.button.title = [NSString stringWithFormat:@" %@ | %.0f%%%@", time, metric, suffix];
    }
}

- (NSString *)countdownText:(NSDictionary *)state {
    NSNumber *reset = state[@"resets_at"];
    if (![reset respondsToSelector:@selector(doubleValue)]) {
        return nil;
    }
    NSInteger remaining = MAX(0, (NSInteger)floor(reset.doubleValue - NSDate.date.timeIntervalSince1970));
    NSInteger hours = remaining / 3600;
    NSInteger minutes = (remaining % 3600) / 60;
    NSInteger seconds = remaining % 60;
    return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

- (NSString *)resetClockText:(NSDictionary *)state {
    NSNumber *reset = state[@"resets_at"];
    if (![reset respondsToSelector:@selector(doubleValue)]) {
        return nil;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterNoStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:reset.doubleValue]];
}

- (NSString *)resetDetailText:(NSDictionary *)state {
    NSNumber *reset = state[@"resets_at"];
    if (![reset respondsToSelector:@selector(doubleValue)]) {
        return nil;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"EEE, MMM d 'at' h:mm a";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:reset.doubleValue]];
}

- (NSString *)updatedText:(NSDictionary *)state {
    NSNumber *fetched = state[@"fetched_at"];
    if (![fetched respondsToSelector:@selector(doubleValue)]) {
        return @"unknown";
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterMediumStyle;
    formatter.dateStyle = NSDateFormatterNoStyle;
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:fetched.doubleValue]];
}

- (NSString *)displayMode {
    return [NSUserDefaults.standardUserDefaults stringForKey:DisplayModeKey] ?: DisplayModeBattery;
}

- (NSString *)timeMode {
    return [NSUserDefaults.standardUserDefaults stringForKey:TimeModeKey] ?: TimeModeCountdown;
}

- (NSString *)metricMode {
    return [NSUserDefaults.standardUserDefaults stringForKey:MetricModeKey] ?: MetricModeLeft;
}

- (NSTimeInterval)refreshIntervalSeconds {
    double value = [NSUserDefaults.standardUserDefaults doubleForKey:RefreshIntervalKey];
    for (NSNumber *allowed in @[@30.0, @60.0, @180.0, @300.0]) {
        if (fabs(value - allowed.doubleValue) < 0.5) {
            return allowed.doubleValue;
        }
    }
    return DefaultRefreshIntervalSeconds;
}

- (NSString *)refreshIntervalLabel:(NSTimeInterval)seconds {
    if (fabs(seconds - 30.0) < 0.5) {
        return @"30 sec";
    }
    return [NSString stringWithFormat:@"%.0f min", seconds / 60.0];
}

- (void)schedulePollTimer {
    [self.pollTimer invalidate];
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:[self refreshIntervalSeconds]
                                                      target:self
                                                    selector:@selector(refresh)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)refresh {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *state = [self loadUsageState];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.latestState = state;
            [self updateStatusItem];
            self.statusItem.menu = [self menuForCurrentState];
        });
    });
}

- (NSDictionary *)loadUsageState {
    NSError *authError = nil;
    NSDictionary *auth = [self cursorAuthentication:&authError];
    if (auth == nil) {
        return [self errorState:authError.localizedDescription ?: @"Cursor login was not found."];
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:@"https://cursor.com/api/dashboard/get-sand-usage-status"]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20.0;
    request.HTTPBody = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"https://cursor.com" forHTTPHeaderField:@"Origin"];
    [request setValue:@"https://cursor.com/dashboard" forHTTPHeaderField:@"Referer"];
    [request setValue:@"GrokUsageMenuBar/0.1" forHTTPHeaderField:@"User-Agent"];
    NSString *cookie = [NSString stringWithFormat:@"WorkosCursorSessionToken=%@%%3A%%3A%@",
                         auth[@"user_id"], auth[@"access_token"]];
    [request setValue:cookie forHTTPHeaderField:@"Cookie"];

    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.HTTPCookieStorage = nil;
    configuration.HTTPShouldSetCookies = NO;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *responseData = nil;
    __block NSHTTPURLResponse *httpResponse = nil;
    __block NSError *requestError = nil;

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        responseData = data;
        httpResponse = (NSHTTPURLResponse *)response;
        requestError = error;
        dispatch_semaphore_signal(done);
    }];
    [task resume];
    long timedOut = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 22 * NSEC_PER_SEC));
    [session finishTasksAndInvalidate];

    if (timedOut != 0) {
        [task cancel];
        return [self errorState:@"Cursor usage request timed out."];
    }
    if (requestError != nil) {
        return [self errorState:requestError.localizedDescription];
    }
    if (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
        return [self errorState:@"Cursor login expired. Sign in to Cursor again."];
    }
    if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
        return [self errorState:[NSString stringWithFormat:@"Cursor returned HTTP %ld.", (long)httpResponse.statusCode]];
    }

    NSError *parseError = nil;
    NSDictionary *state = GrokUsageStateFromData(responseData ?: NSData.data, NSDate.date, &parseError);
    return state ?: [self errorState:parseError.localizedDescription ?: @"Could not read Grok usage."];
}

- (NSDictionary *)cursorAuthentication:(NSError **)error {
    NSString *dbPath = [@"~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
                         stringByExpandingTildeInPath];
    sqlite3 *database = NULL;
    int result = sqlite3_open_v2(dbPath.fileSystemRepresentation, &database,
                                 SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL);
    if (result != SQLITE_OK || database == NULL) {
        if (database != NULL) sqlite3_close(database);
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsageAuth" code:result
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cursor local login database was not found."}];
        }
        return nil;
    }
    sqlite3_busy_timeout(database, 3000);

    NSString *query = @"SELECT key, value FROM ItemTable WHERE key IN "
                       "('cursorAuth/accessToken','glass.lastSignedInAuthId','cursorAuth/cachedScopedProfile')";
    sqlite3_stmt *statement = NULL;
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    if (sqlite3_prepare_v2(database, query.UTF8String, -1, &statement, NULL) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            const unsigned char *keyText = sqlite3_column_text(statement, 0);
            const unsigned char *valueText = sqlite3_column_text(statement, 1);
            if (keyText != NULL && valueText != NULL) {
                NSString *key = [NSString stringWithUTF8String:(const char *)keyText];
                NSString *value = [NSString stringWithUTF8String:(const char *)valueText];
                if (key.length > 0 && value.length > 0) values[key] = value;
            }
        }
    }
    if (statement != NULL) sqlite3_finalize(statement);
    sqlite3_close(database);

    NSString *token = [self normalizedStoredString:values[@"cursorAuth/accessToken"]];
    NSString *identity = [self normalizedStoredString:values[@"glass.lastSignedInAuthId"]];
    NSString *profile = [self normalizedStoredString:values[@"cursorAuth/cachedScopedProfile"]];
    NSString *userID = [self userIDFromText:identity] ?: [self userIDFromText:profile];
    if (token.length == 0 || userID.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsageAuth" code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cursor is not signed in on this Mac."}];
        }
        return nil;
    }
    return @{@"access_token": token, @"user_id": userID};
}

- (NSString *)normalizedStoredString:(NSString *)value {
    if (value.length == 0) return nil;
    if ([value hasPrefix:@"\""] && [value hasSuffix:@"\""]) {
        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
        id decoded = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
        if ([decoded isKindOfClass:[NSString class]]) return decoded;
    }
    return value;
}

- (NSString *)userIDFromText:(NSString *)text {
    if (text.length == 0) return nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"user_[A-Za-z0-9]{20,}"
                                                                            options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    return match != nil ? [text substringWithRange:match.range] : nil;
}

- (NSDictionary *)errorState:(NSString *)message {
    return @{@"ok": @NO, @"error": message ?: @"Unknown error"};
}

- (void)useBatteryDisplay {
    [NSUserDefaults.standardUserDefaults setObject:DisplayModeBattery forKey:DisplayModeKey];
    [self updateStatusItem];
}

- (void)usePercentDisplay {
    [NSUserDefaults.standardUserDefaults setObject:DisplayModePercent forKey:DisplayModeKey];
    [self updateStatusItem];
}

- (void)useCountdownTime {
    [NSUserDefaults.standardUserDefaults setObject:TimeModeCountdown forKey:TimeModeKey];
    [self updateStatusItem];
}

- (void)useClockTime {
    [NSUserDefaults.standardUserDefaults setObject:TimeModeClock forKey:TimeModeKey];
    [self updateStatusItem];
}

- (void)useLeftMetric {
    [NSUserDefaults.standardUserDefaults setObject:MetricModeLeft forKey:MetricModeKey];
    [self updateStatusItem];
}

- (void)useUsedMetric {
    [NSUserDefaults.standardUserDefaults setObject:MetricModeUsed forKey:MetricModeKey];
    [self updateStatusItem];
}

- (void)useRefreshInterval:(NSMenuItem *)sender {
    [NSUserDefaults.standardUserDefaults setDouble:[sender.representedObject doubleValue]
                                             forKey:RefreshIntervalKey];
    [self schedulePollTimer];
    self.statusItem.menu = [self menuForCurrentState];
}

- (PersistentStartup *)startup {
    return StartupController(@"com.local.autostart.grok-usage");
}

- (BOOL)launchAtLoginEnabled {
    return [NSFileManager.defaultManager fileExistsAtPath:self.startup.path] && self.startup.loaded;
}

- (NSString *)launchAtLoginStatusText {
    if ([self launchAtLoginEnabled]) return @"enabled";
    return [NSFileManager.defaultManager fileExistsAtPath:self.startup.path] ? @"inactive" : @"not_registered";
}

- (void)ensureLaunchAtLoginIfPreferred {
    NSError *error = nil;
    BOOL preferred = [NSUserDefaults.standardUserDefaults boolForKey:LaunchAtLoginPreferenceKey];
    BOOL ok = RemoveNativeLoginItem(&error) && [self.startup setEnabled:preferred error:&error];
    self.launchAtLoginError = ok ? nil : error.localizedDescription;
}

- (void)toggleLaunchAtLogin {
    NSError *error = nil;
    // A pending/blocked registration can also be turned off.
    BOOL wasPreferred = [NSUserDefaults.standardUserDefaults boolForKey:LaunchAtLoginPreferenceKey];
    BOOL ok = RemoveNativeLoginItem(&error) && [self.startup setEnabled:!wasPreferred error:&error];
    if (ok) [NSUserDefaults.standardUserDefaults setBool:!wasPreferred forKey:LaunchAtLoginPreferenceKey];
    self.launchAtLoginError = ok ? nil : error.localizedDescription;
    self.statusItem.menu = [self menuForCurrentState];
}

- (void)openDashboard {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://cursor.com/dashboard"]];
}

- (void)quit {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--pause-startup") == 0) {
            NSError *error = nil;
            BOOL ok = [StartupController(@"com.local.autostart.grok-usage") pause:&error];
            if (!ok) fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return ok ? 0 : 1;
        }
        if (argc > 1 && strcmp(argv[1], "--probe") == 0) {
            AppDelegate *probeDelegate = [[AppDelegate alloc] init];
            NSDictionary *state = [probeDelegate loadUsageState];
            NSData *json = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];
            if (json != nil) {
                fwrite(json.bytes, 1, json.length, stdout);
                fputc('\n', stdout);
            }
            return [state[@"ok"] boolValue] ? 0 : 1;
        }
        if (argc > 1 && strcmp(argv[1], "--launch-at-login-status") == 0) {
            AppDelegate *statusDelegate = [[AppDelegate alloc] init];
            NSString *status = [statusDelegate launchAtLoginStatusText];
            puts(status.UTF8String);
            return [status isEqualToString:@"enabled"] ? 0 : 1;
        }
        if (argc > 2 && strcmp(argv[1], "--render-preview") == 0) {
            AppDelegate *previewDelegate = [[AppDelegate alloc] init];
            NSError *previewError = nil;
            BOOL ok = [previewDelegate renderPreviewAtPath:[NSString stringWithUTF8String:argv[2]]
                                                     error:&previewError];
            if (!ok) {
                fprintf(stderr, "%s\n", previewError.localizedDescription.UTF8String);
            }
            return ok ? 0 : 1;
        }
        NSApplication *application = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
