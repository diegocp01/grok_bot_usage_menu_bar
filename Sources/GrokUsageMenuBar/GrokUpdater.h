#ifndef GrokUpdater_h
#define GrokUpdater_h

#import <Foundation/Foundation.h>

static NSString * const GrokDefaultGitRemote = @"https://github.com/diegocp01/grok_bot_usage_menu_bar.git";
static NSString * const GrokSourceRepoPathKey = @"sourceRepoPath";

static NSString *GrokTrimGitSHA(NSString *sha) {
    return [sha isKindOfClass:NSString.class]
        ? [[sha stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString] : @"";
}

static BOOL GrokGitSHAsEqual(NSString *left, NSString *right) {
    NSString *a = GrokTrimGitSHA(left), *b = GrokTrimGitSHA(right);
    if (a.length == 0 || b.length == 0) return NO;
    NSUInteger length = MIN(a.length, b.length);
    return length < 7 ? [a isEqualToString:b]
                      : [[a substringToIndex:length] isEqualToString:[b substringToIndex:length]];
}

static NSString *GrokShortGitSHA(NSString *sha) {
    NSString *value = GrokTrimGitSHA(sha);
    return value.length >= 7 ? [value substringToIndex:7] : value;
}

static NSDictionary<NSString *, NSString *> *GrokGitHubRepoFromRemote(NSString *remote) {
    NSString *value = remote.length > 0 ? remote : GrokDefaultGitRemote;
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([value hasSuffix:@".git"]) value = [value substringToIndex:value.length - 4];
    value = [value stringByReplacingOccurrencesOfString:@"git@github.com:" withString:@"https://github.com/"];
    value = [value stringByReplacingOccurrencesOfString:@"ssh://git@github.com/" withString:@"https://github.com/"];
    NSArray *parts = [NSURL URLWithString:value].path.pathComponents;
    if (parts.count < 3) return @{ @"owner": @"diegocp01", @"name": @"grok_bot_usage_menu_bar" };
    return @{ @"owner": parts[parts.count - 2], @"name": parts.lastObject };
}

static BOOL GrokRemotePointsAtAppRepo(NSString *remote) {
    return [GrokGitHubRepoFromRemote(remote)[@"name"] isEqualToString:@"grok_bot_usage_menu_bar"];
}

static NSString *GrokFirstLine(NSString *text) {
    for (NSString *line in [text ?: @"" componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length > 0) return trimmed;
    }
    return @"";
}

static NSArray<NSString *> *GrokCommitSummariesFromGitHub(id commits) {
    NSMutableArray *items = NSMutableArray.array;
    if (![commits isKindOfClass:NSArray.class]) return items;
    for (id commit in commits) {
        if (![commit isKindOfClass:NSDictionary.class]) continue;
        id detail = commit[@"commit"];
        NSString *message = [detail isKindOfClass:NSDictionary.class] ? detail[@"message"] : commit[@"message"];
        NSString *line = GrokFirstLine(message);
        if (line.length > 0) [items addObject:line];
    }
    return items;
}

static NSDictionary *GrokParseGitHubUpdatePayload(id json, NSString *currentSHA) {
    if (![json isKindOfClass:NSDictionary.class]) return @{ @"ok": @NO, @"error": @"GitHub returned invalid JSON" };
    NSString *remoteSHA = [json[@"sha"] isKindOfClass:NSString.class] ? json[@"sha"] : nil;
    NSInteger ahead = [json[@"ahead_by"] respondsToSelector:@selector(integerValue)] ? MAX(0, [json[@"ahead_by"] integerValue]) : 0;
    NSArray *summaries = remoteSHA.length > 0 ? GrokCommitSummariesFromGitHub(@[json]) : @[];
    if ([json[@"commits"] isKindOfClass:NSArray.class]) {
        NSArray *commits = json[@"commits"];
        summaries = GrokCommitSummariesFromGitHub(commits);
        NSDictionary *last = commits.lastObject;
        if ([last[@"sha"] isKindOfClass:NSString.class]) remoteSHA = last[@"sha"];
    }
    NSString *status = [json[@"status"] isKindOfClass:NSString.class] ? json[@"status"] : nil;
    if ([status isEqualToString:@"identical"] || ([status isEqualToString:@"behind"] && ahead == 0)) remoteSHA = currentSHA;
    if (remoteSHA.length == 0 && ahead == 0 && currentSHA.length > 0) remoteSHA = currentSHA;
    if (remoteSHA.length == 0) return @{ @"ok": @NO, @"error": @"GitHub response had no commit SHA" };
    BOOL same = GrokGitSHAsEqual(currentSHA, remoteSHA);
    if (same) ahead = 0; else if (ahead == 0) ahead = MAX(1, (NSInteger)summaries.count);
    return @{ @"ok": @YES, @"updateAvailable": @(ahead > 0 && !same), @"aheadBy": @(ahead),
              @"currentSHA": currentSHA ?: @"", @"remoteSHA": remoteSHA, @"commits": summaries };
}

static NSString *GrokUpdatePromptText(NSDictionary *update) {
    NSInteger ahead = [update[@"aheadBy"] integerValue];
    NSArray *commits = [update[@"commits"] isKindOfClass:NSArray.class] ? update[@"commits"] : @[];
    NSMutableArray *lines = NSMutableArray.array;
    for (NSUInteger i = 0; i < MIN(commits.count, (NSUInteger)8); i++) [lines addObject:[@"• " stringByAppendingString:commits[i]]];
    if (commits.count > 8) [lines addObject:[NSString stringWithFormat:@"• … %lu more", commits.count - 8]];
    NSString *count = ahead == 1 ? @"1 new commit" : [NSString stringWithFormat:@"%ld new commits", (long)ahead];
    NSString *body = lines.count ? [lines componentsJoinedByString:@"\n"] : @"New commits, including merged PRs, are on main.";
    return [NSString stringWithFormat:@"%@ on GitHub main.\n\n%@\n\nPull, rebuild, and restart now?", count, body];
}

static NSString *GrokRunProcess(NSString *executable, NSArray *arguments, NSString *directory, NSInteger *status) {
    NSTask *task = NSTask.new; task.executableURL = [NSURL fileURLWithPath:executable]; task.arguments = arguments;
    if (directory.length) task.currentDirectoryURL = [NSURL fileURLWithPath:directory];
    NSPipe *pipe = NSPipe.pipe; task.standardOutput = pipe; task.standardError = pipe;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) { if (status) *status = -1; return error.localizedDescription ?: @"Could not start process"; }
    [task waitUntilExit]; if (status) *status = task.terminationStatus;
    NSString *output = [[NSString alloc] initWithData:[pipe.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding] ?: @"";
    return [output stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *GrokGit(NSString *repo, NSArray *arguments, NSInteger *status) {
    NSMutableArray *args = [@[@"-C", repo] mutableCopy]; [args addObjectsFromArray:arguments];
    return GrokRunProcess(@"/usr/bin/git", args, nil, status);
}

static BOOL GrokDirectoryHasGit(NSString *path) {
    return path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingPathComponent:@".git"]];
}

static NSString *GrokOriginURL(NSString *repo) {
    NSInteger status = 0; NSString *url = GrokGit(repo, @[@"remote", @"get-url", @"origin"], &status); return status == 0 ? url : nil;
}

static NSString *GrokManagedClonePath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Grok Usage Menu Bar/src"];
}

static NSString *GrokBundledGitCommit(void) {
    return GrokTrimGitSHA(NSBundle.mainBundle.infoDictionary[@"GrokGitCommit"]);
}

static NSString *GrokBundledGitRemote(void) {
    NSString *remote = NSBundle.mainBundle.infoDictionary[@"GrokGitRemote"];
    return remote.length > 0 ? remote : GrokDefaultGitRemote;
}

static NSString *GrokFindSourceRepo(void) {
    NSString *saved = [NSUserDefaults.standardUserDefaults stringForKey:GrokSourceRepoPathKey];
    if (GrokDirectoryHasGit(saved) && GrokRemotePointsAtAppRepo(GrokOriginURL(saved))) return saved.stringByStandardizingPath;
    NSString *home = NSHomeDirectory();
    for (NSString *path in @[[home stringByAppendingPathComponent:@"Documents/code_projects/menu_bar_widgets/grok_bot_usage"],
                              [home stringByAppendingPathComponent:@"Documents/grok_bot_usage"], GrokManagedClonePath()]) {
        if (GrokDirectoryHasGit(path) && GrokRemotePointsAtAppRepo(GrokOriginURL(path))) return path.stringByStandardizingPath;
    }
    return nil;
}

static NSString *GrokEnsureSourceRepo(NSString *remote, NSError **error) {
    NSString *repo = GrokFindSourceRepo();
    if (repo.length) { [NSUserDefaults.standardUserDefaults setObject:repo forKey:GrokSourceRepoPathKey]; return repo; }
    NSString *destination = GrokManagedClonePath();
    [NSFileManager.defaultManager createDirectoryAtPath:destination.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error];
    NSInteger status = 0;
    NSString *output = GrokRunProcess(@"/usr/bin/git", @[@"clone", @"--branch", @"main", remote ?: GrokDefaultGitRemote, destination], nil, &status);
    if (status != 0) { if (error) *error = [NSError errorWithDomain:@"GrokUpdater" code:1 userInfo:@{NSLocalizedDescriptionKey: output ?: @"git clone failed"}]; return nil; }
    [NSUserDefaults.standardUserDefaults setObject:destination forKey:GrokSourceRepoPathKey]; return destination;
}

static NSDictionary *GrokCheckGitHubForUpdates(NSString *currentSHA, NSString *remote) {
    NSDictionary *repo = GrokGitHubRepoFromRemote(remote); NSString *sha = GrokTrimGitSHA(currentSHA);
    NSString *url = sha.length >= 7
        ? [NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/compare/%@...main", repo[@"owner"], repo[@"name"], sha]
        : [NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/commits/main", repo[@"owner"], repo[@"name"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.timeoutInterval = 20; [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"GrokUsageMenuBar/0.1" forHTTPHeaderField:@"User-Agent"];
    dispatch_semaphore_t done = dispatch_semaphore_create(0); __block NSData *data; __block NSHTTPURLResponse *response; __block NSError *requestError;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) { data=d; response=(id)r; requestError=e; dispatch_semaphore_signal(done); }];
    [task resume]; long timeout = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 22 * NSEC_PER_SEC)); [session finishTasksAndInvalidate];
    if (timeout || requestError || response.statusCode < 200 || response.statusCode >= 300)
        return @{ @"ok": @NO, @"error": requestError.localizedDescription ?: (timeout ? @"GitHub request timed out" : [NSString stringWithFormat:@"GitHub HTTP %ld", (long)response.statusCode]) };
    id json = [NSJSONSerialization JSONObjectWithData:data ?: NSData.data options:0 error:&requestError];
    return requestError ? @{ @"ok": @NO, @"error": requestError.localizedDescription } : GrokParseGitHubUpdatePayload(json, sha);
}

static NSString *GrokCurrentCommitSHA(NSString *repo) {
    NSString *bundled = GrokBundledGitCommit(); if (bundled.length >= 7) return bundled;
    NSInteger status = 0; NSString *head = repo.length ? GrokGit(repo, @[@"rev-parse", @"HEAD"], &status) : @"";
    return status == 0 ? GrokTrimGitSHA(head) : bundled;
}

static NSDictionary *GrokCheckForUpdates(void) {
    NSString *repo = GrokFindSourceRepo(); NSMutableDictionary *result = [GrokCheckGitHubForUpdates(GrokCurrentCommitSHA(repo), GrokBundledGitRemote()) mutableCopy];
    if (repo.length) result[@"repoPath"] = repo; return result;
}

static NSDictionary *GrokApplyGitPullAndRebuild(NSString *installAppPath, NSError **error) {
    NSString *repo = GrokEnsureSourceRepo(GrokBundledGitRemote(), error);
    if (!repo.length) {
        NSString *message = (error && *error) ? (*error).localizedDescription : @"Could not find source checkout";
        return @{ @"ok": @NO, @"error": message };
    }
    NSInteger status = 0; NSString *output = GrokGit(repo, @[@"fetch", @"origin", @"main"], &status);
    if (status == 0) output = GrokGit(repo, @[@"pull", @"--ff-only", @"origin", @"main"], &status);
    if (status != 0) return @{ @"ok": @NO, @"error": output.length ? output : @"git pull failed" };
    NSString *outDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"grok-usage-update-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSString *script = [repo stringByAppendingPathComponent:@"scripts/build.sh"];
    NSTask *build = NSTask.new; build.executableURL = [NSURL fileURLWithPath:@"/bin/bash"]; build.arguments = @[script]; build.currentDirectoryURL = [NSURL fileURLWithPath:repo];
    NSMutableDictionary *environment = NSProcessInfo.processInfo.environment.mutableCopy; environment[@"OUT_DIR"] = outDir; build.environment = environment;
    NSPipe *pipe = NSPipe.pipe; build.standardOutput = pipe; build.standardError = pipe; NSError *launchError = nil;
    if (![build launchAndReturnError:&launchError]) return @{ @"ok": @NO, @"error": launchError.localizedDescription };
    [build waitUntilExit]; NSString *log = [[NSString alloc] initWithData:[pipe.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding] ?: @"";
    if (build.terminationStatus != 0) return @{ @"ok": @NO, @"error": [@"Build failed:\n" stringByAppendingString:log.length > 800 ? [log substringFromIndex:log.length-800] : log] };
    NSString *builtApp = [outDir stringByAppendingPathComponent:@"Grok Usage Menu Bar.app"];
    NSString *destination = installAppPath.length ? installAppPath : [NSHomeDirectory() stringByAppendingPathComponent:@"Applications/Grok Usage Menu Bar.app"];
    output = GrokRunProcess(@"/usr/bin/ditto", @[@"--noqtn", builtApp, destination], nil, &status);
    if (status != 0) return @{ @"ok": @NO, @"error": output.length ? output : @"Could not replace app" };
    GrokRunProcess(@"/usr/bin/xattr", @[@"-cr", destination], nil, &status);
    GrokRunProcess(@"/usr/bin/codesign", @[@"--force", @"--sign", @"-", @"--options", @"runtime", destination], nil, &status);
    [NSFileManager.defaultManager removeItemAtPath:outDir error:nil];
    return @{ @"ok": @YES, @"appPath": destination, @"repoPath": repo };
}

#endif
