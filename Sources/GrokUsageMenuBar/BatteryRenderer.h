#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT double GrokOnPacePercent(NSTimeInterval now,
                                           NSTimeInterval periodStart,
                                           NSTimeInterval reset);

NSImage *GrokBatteryIcon(NSImage * _Nullable grokIcon, double percent);
NSImage *GrokBatteryIconWithLabel(NSImage * _Nullable grokIcon,
                                  double percent,
                                  NSString *label);
NSImage *GrokBatteryIconWithOnPaceLine(NSImage * _Nullable grokIcon,
                                      double percent,
                                      NSString *label,
                                      double onPacePercent);

NS_ASSUME_NONNULL_END
