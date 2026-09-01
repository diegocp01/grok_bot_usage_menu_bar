#import <Foundation/Foundation.h>
#import "GrokUsageParser.h"
#import <math.h>

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message.UTF8String);
        exit(1);
    }
}

static NSData *JSON(NSString *string) {
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

int main(void) {
    @autoreleasepool {
        NSError *error = nil;
        NSDate *fetched = [NSDate dateWithTimeIntervalSince1970:1000];
        NSDictionary *camel = GrokUsageStateFromData(JSON(@"{\"usagePercent\":47.708223,\"currentPeriodStart\":\"2026-08-27T01:57:34.980Z\",\"nextResetTimestampUtc\":\"2026-09-03T01:57:34.980Z\",\"hasNonZeroIncludedLimit\":true}"), fetched, &error);
        Assert(camel != nil && error == nil, @"camelCase payload should parse");
        Assert(fabs([camel[@"used_percent"] doubleValue] - 47.708223) < 0.000001, @"used percentage is preserved");
        Assert(fabs([camel[@"left_percent"] doubleValue] - 52.291777) < 0.000001, @"left percentage is derived");
        Assert([camel[@"has_included_limit"] boolValue], @"included-limit flag is preserved");

        error = nil;
        NSDictionary *snake = GrokUsageStateFromData(JSON(@"{\"usage_percent\":101.25,\"next_reset_timestamp_utc\":1788400654980}"), fetched, &error);
        Assert(snake != nil && error == nil, @"snake_case payload should parse");
        Assert([snake[@"used_percent"] doubleValue] == 100.0, @"percentage is clamped");
        Assert([snake[@"left_percent"] doubleValue] == 0.0, @"left percentage is clamped");

        error = nil;
        NSDictionary *missing = GrokUsageStateFromData(JSON(@"{\"usagePercent\":12}"), fetched, &error);
        Assert(missing == nil && error != nil, @"missing reset should fail closed");

        error = nil;
        NSDictionary *remoteError = GrokUsageStateFromData(JSON(@"{\"error\":\"Invalid origin\"}"), fetched, &error);
        Assert(remoteError == nil && [error.localizedDescription isEqualToString:@"Invalid origin"], @"server error should be surfaced");

        puts("Parser tests passed");
    }
    return 0;
}
