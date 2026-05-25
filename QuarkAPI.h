#import <Foundation/Foundation.h>

@interface QuarkResult : NSObject
@property (nonatomic, assign) NSInteger rid;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *url;
@end

@interface QuarkAPI : NSObject
+ (NSArray<QuarkResult *> *)search:(NSString *)keyword;
+ (NSString *)transfer:(NSString *)shareURL cookie:(NSString *)cookie;
@end
