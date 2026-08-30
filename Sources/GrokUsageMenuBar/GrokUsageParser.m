#import "GrokUsageParser.h"

static id FirstValue(NSDictionary *dictionary, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if (value != nil && value != NSNull.null) {
            return value;
        }
    }
    return nil;
}

static NSDate *DateFromValue(id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        double seconds = [value doubleValue];
        if (seconds > 100000000000.0) {
            seconds /= 1000.0;
        }
        return [NSDate dateWithTimeIntervalSince1970:seconds];
    }
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }

    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *date = [formatter dateFromString:value];
    if (date != nil) {
        return date;
    }
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    return [formatter dateFromString:value];
}

NSDictionary *GrokUsageStateFromData(NSData *data, NSDate *fetchedAt, NSError **error) {
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error != NULL && *error == nil) {
            *error = [NSError errorWithDomain:@"GrokUsageParser"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cursor returned an unexpected response."}];
        }
        return nil;
    }

    NSDictionary *payload = object;
    id remoteError = payload[@"error"];
    if ([remoteError isKindOfClass:[NSString class]] && [remoteError length] > 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsageParser"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: remoteError}];
        }
        return nil;
    }

    id percentValue = FirstValue(payload, @[@"usagePercent", @"usage_percent"]);
    if (![percentValue respondsToSelector:@selector(doubleValue)]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsageParser"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cursor omitted the Grok usage percentage."}];
        }
        return nil;
    }

    double used = [percentValue doubleValue];
    if (!isfinite(used)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsageParser"
                                         code:4
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cursor returned an invalid Grok usage percentage."}];
        }
        return nil;
    }
    used = MAX(0.0, MIN(100.0, used));

    NSDate *periodStart = DateFromValue(FirstValue(payload, @[@"currentPeriodStart", @"current_period_start"]));
    NSDate *reset = DateFromValue(FirstValue(payload, @[@"nextResetTimestampUtc", @"next_reset_timestamp_utc"]));
    if (reset == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"GrokUsageParser"
                                         code:5
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cursor omitted the Grok reset time."}];
        }
        return nil;
    }

    id includedValue = FirstValue(payload, @[@"hasNonZeroIncludedLimit", @"has_non_zero_included_limit"]);
    BOOL hasIncludedLimit = [includedValue respondsToSelector:@selector(boolValue)] ? [includedValue boolValue] : YES;

    NSMutableDictionary *state = [@{
        @"ok": @YES,
        @"used_percent": @(used),
        @"left_percent": @(100.0 - used),
        @"resets_at": @(reset.timeIntervalSince1970),
        @"fetched_at": @(fetchedAt.timeIntervalSince1970),
        @"has_included_limit": @(hasIncludedLimit),
        @"source": @"Cursor Grok Bot weekly usage"
    } mutableCopy];
    if (periodStart != nil) {
        state[@"period_started_at"] = @(periodStart.timeIntervalSince1970);
    }
    return state;
}
