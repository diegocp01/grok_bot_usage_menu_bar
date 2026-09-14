#import "GrokUpdater.h"

int main(void) {
    @autoreleasepool {
        NSCAssert(GrokGitSHAsEqual(@"217185e", @"217185ef00aabb"), @"Short SHA matches long SHA");
        NSCAssert(!GrokGitSHAsEqual(@"217185e", @"deadbeef"), @"Different SHAs");
        NSDictionary *repo = GrokGitHubRepoFromRemote(@"git@github.com:diegocp01/grok_bot_usage_menu_bar.git");
        NSCAssert([repo[@"owner"] isEqual:@"diegocp01"] && [repo[@"name"] isEqual:@"grok_bot_usage_menu_bar"], @"SSH remote");
        NSDictionary *identical = GrokParseGitHubUpdatePayload(@{@"status":@"identical", @"ahead_by":@0, @"commits":@[]}, @"217185eadd");
        NSCAssert([identical[@"ok"] boolValue] && ![identical[@"updateAvailable"] boolValue], @"Identical compare");
        NSDictionary *ahead = GrokParseGitHubUpdatePayload(@{@"status":@"ahead", @"ahead_by":@2, @"commits":@[
            @{@"sha":@"aaa1111", @"commit":@{@"message":@"Fix usage parse\nDetails"}},
            @{@"sha":@"bbb2222deadbeef", @"commit":@{@"message":@"Merge pull request #9"}}
        ]}, @"217185eadd");
        NSCAssert([ahead[@"updateAvailable"] boolValue] && [ahead[@"aheadBy"] integerValue] == 2, @"Ahead compare");
        NSCAssert([GrokUpdatePromptText(ahead) containsString:@"Merge pull request #9"], @"Prompt summaries");
        puts("Updater tests passed");
    }
    return 0;
}
