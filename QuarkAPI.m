#import "QuarkAPI.h"

// ═══════════════════════════════════════════════════════
//  夸克 API — 进程内直调，无需外部服务器
// ═══════════════════════════════════════════════════════

@implementation QuarkResult
@end

// ── 请求工具 ────────────────────────────────────────

static NSString *GET(NSString *url, NSDictionary *headers, NSTimeInterval timeout) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                   timeoutInterval:timeout];
    for (NSString *k in headers)
        [req setValue:headers[k] forHTTPHeaderField:k];
    NSHTTPURLResponse *resp = nil;
    NSError *err = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
    NSLog(@"[quarkd] GET %ld %@ err=%@", (long)resp.statusCode, url, err ?: @"nil");
    if (err || resp.statusCode >= 400) return nil;
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

static NSString *POST(NSString *url, NSDictionary *body, NSDictionary *headers) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                   timeoutInterval:30];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    for (NSString *k in headers)
        [req setValue:headers[k] forHTTPHeaderField:k];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSHTTPURLResponse *resp = nil;
    NSError *err = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
    NSLog(@"[quarkd] POST %ld %@ err=%@", (long)resp.statusCode, url, err ?: @"nil");
    if (err || resp.statusCode >= 400) return nil;
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

static id JSON(NSString *s) {
    if (!s) return nil;
    return [NSJSONSerialization JSONObjectWithData:[s dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

// ── 搜索 ────────────────────────────────────────────

@implementation QuarkAPI

+ (NSArray<QuarkResult *> *)search:(NSString *)keyword {
    NSString *encoded = [keyword stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *url = [NSString stringWithFormat:@"https://www.kuakeso.net/s/%@", encoded];
    NSDictionary *headers = @{
        @"User-Agent": @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        @"Accept-Language": @"zh-CN,zh;q=0.9",
    };
    NSString *html = GET(url, headers, 15);
    if (!html) return @[];

    // 提取 copyText url+title 配对
    NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern:
        @"copyText\\(\\$event,\\s*'([^']+)'\\s*,\\s*'(https://pan\\.quark\\.cn/s/[a-zA-Z0-9]+)"
        options:0 error:nil];
    NSArray *matches = [rx matchesInString:html options:0 range:NSMakeRange(0, html.length)];

    NSMutableArray *results = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSTextCheckingResult *m in matches) {
        NSString *title = [html substringWithRange:[m rangeAtIndex:1]];
        NSString *qurl  = [html substringWithRange:[m rangeAtIndex:2]];
        if ([seen containsObject:qurl]) continue;
        [seen addObject:qurl];
        QuarkResult *r = [QuarkResult new];
        r.rid = results.count;
        r.title = title;
        r.url = qurl;
        [results addObject:r];
    }
    return results;
}

// ── 转存 ────────────────────────────────────────────

+ (NSString *)transfer:(NSString *)shareURL cookie:(NSString *)cookie {
    if (cookie.length == 0) return @"请先设置 Cookie: /ck 你的Cookie";

    NSDictionary *h = @{
        @"Accept": @"application/json, text/plain, */*",
        @"User-Agent": @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        @"Referer": @"https://pan.quark.cn/",
        @"Cookie": cookie,
    };
    NSString *pr = @"pr=ucpro&fr=pc&uc_param_str=";

    // 提取 shareID
    NSRange r = [shareURL rangeOfString:@"pan.quark.cn/s/"];
    if (r.location == NSNotFound) return @"无法解析链接";
    NSString *sid = [shareURL substringFromIndex:r.location + r.length];
    sid = [[sid componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] firstObject];

    // Step 1: getStoken
    NSString *u1 = [NSString stringWithFormat:@"https://drive-pc.quark.cn/1/clouddrive/share/sharepage/token?%@", pr];
    id d1 = JSON(POST(u1, @{@"passcode":@"", @"pwd_id":sid}, h));
    if (!d1 || !d1[@"data"]) return @"获取 stoken 失败，Cookie 可能已过期";

    NSString *stoken = [[[d1[@"data"] objectForKey:@"stoken"] ?: @"" stringByReplacingOccurrencesOfString:@" " withString:@"+"] stringByReplacingOccurrencesOfString:@"%20" withString:@"+"];
    if (stoken.length == 0) return @"stoken 为空，可能需要提取码";

    // Step 2: getShare detail
    NSString *u2 = [NSString stringWithFormat:@"https://drive-pc.quark.cn/1/clouddrive/share/sharepage/detail?%@&pwd_id=%@&stoken=%@&pdir_fid=0&force=0&_page=1&_size=100&_fetch_banner=1&_fetch_share=1&_fetch_total=1&_sort=file_type:asc,updated_at:desc", pr, sid, stoken];
    id d2 = JSON(GET(u2, h, 30));
    if (!d2 || !d2[@"data"]) return @"获取分享详情失败";

    NSArray *list = d2[@"data"][@"list"];
    if (!list.count) return @"分享内容为空";
    NSString *title = d2[@"data"][@"share"][@"title"] ?: sid;

    NSMutableArray *fids = [NSMutableArray array];
    NSMutableArray *ftokens = [NSMutableArray array];
    for (id item in list) {
        [fids addObject:item[@"fid"]];
        [ftokens addObject:item[@"share_fid_token"]];
    }

    // Step 3: saveShare
    NSString *u3 = [NSString stringWithFormat:@"https://drive-pc.quark.cn/1/clouddrive/share/sharepage/save?%@", pr];
    id d3 = JSON(POST(u3, @{@"pwd_id":sid, @"stoken":stoken, @"fid_list":fids, @"fid_token_list":ftokens, @"to_pdir_fid":@"0"}, h));
    NSString *tid = d3[@"data"][@"task_id"];
    if (!tid) return @"转存请求失败";

    // Step 4: waitTask
    id saved = [QuarkAPI waitTask:tid headers:h baseParams:pr];
    if (!saved) return @"转存任务超时";
    NSArray *top = saved[@"save_as"][@"save_as_top_fids"];
    if (!top.count) return @"转存完成但无文件";

    // Step 5: shareFiles
    NSString *u5 = [NSString stringWithFormat:@"https://drive-pc.quark.cn/1/clouddrive/share?%@", pr];
    id d5 = JSON(POST(u5, @{@"fid_list":top, @"title":title, @"url_type":@1, @"expired_type":@1}, h));
    NSString *s_tid = d5[@"data"][@"task_id"];
    if (!s_tid) return @"创建分享任务失败";

    // Step 6: waitTask
    id shared = [QuarkAPI waitTask:s_tid headers:h baseParams:pr];
    if (!shared) return @"分享任务超时";
    NSString *new_sid = shared[@"share_id"];
    if (!new_sid) return @"未能获取分享 ID";

    // Step 7: getPassword
    NSString *u7 = [NSString stringWithFormat:@"https://drive-pc.quark.cn/1/clouddrive/share/password?%@", pr];
    id d7 = JSON(POST(u7, @{@"share_id":new_sid}, h));
    return d7[@"data"][@"share_url"] ?: @"分享链接获取失败";
}

+ (id)waitTask:(NSString *)tid headers:(NSDictionary *)h baseParams:(NSString *)pr {
    for (int i = 0; i < 50; i++) {
        NSString *u = [NSString stringWithFormat:@"https://drive-pc.quark.cn/1/clouddrive/task?%@&task_id=%@&retry_index=%d&__dt=21192&__t=%lld", pr, tid, i, (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
        id d = JSON(GET(u, h, 30));
        if ([d[@"data"][@"status"] intValue] == 2)
            return d[@"data"];
        [NSThread sleepForTimeInterval:2.0];
    }
    return nil;
}

@end
