#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

NSImage *GrokBatteryIcon(NSImage * _Nullable grokIcon, double percent);
NSImage *GrokBatteryIconWithLabel(NSImage * _Nullable grokIcon,
                                  double percent,
                                  NSString *label);

NS_ASSUME_NONNULL_END
