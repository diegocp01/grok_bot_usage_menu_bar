#import "GrokUsageFormatter.h"
#import <math.h>

NSString *GrokCountdownTextForInterval(NSTimeInterval interval) {
    NSInteger remaining = MAX(0, (NSInteger)floor(interval));
    NSInteger days = remaining / 86400;
    NSInteger hours = (remaining % 86400) / 3600;
    NSInteger minutes = (remaining % 3600) / 60;
    NSInteger seconds = remaining % 60;

    if (days > 0) {
        return [NSString stringWithFormat:@"%ldd %02ld:%02ld:%02ld",
                (long)days, (long)hours, (long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%ld:%02ld:%02ld",
            (long)hours, (long)minutes, (long)seconds];
}
