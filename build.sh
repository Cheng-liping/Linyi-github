#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THEOS_DIR="$HOME/theos"
SDK_DIR="$THEOS_DIR/sdks/iPhoneOS15.6.sdk"
MAC_SDK=$(xcrun --show-sdk-path)

# ── Theos (只需要 vendor 里的头文件，不需要 logos) ──
if [ ! -d "$THEOS_DIR" ]; then
    echo "[*] 下载 Theos (仅头文件)..."
    git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS_DIR"
fi

# ── iOS SDK ──────────────────────────────────────
if [ ! -f "$SDK_DIR/SDKSettings.json" ]; then
    echo "[*] 创建最小 iOS SDK..."
    mkdir -p "$SDK_DIR"
    cp -Rl "$MAC_SDK/" "$SDK_DIR/" 2>/dev/null || cp -R "$MAC_SDK/" "$SDK_DIR/"
    rm -f "$SDK_DIR/SDKSettings.json"
    python3 -c "
import json
d={
    'CanonicalName':'iphoneos15.6','CustomProperties':{},
    'DefaultProperties':{'PLATFORM_NAME':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'15.0','DEFAULT_COMPILER':'com.apple.compilers.llvm.clang.1_0'},
    'DisplayName':'iOS 15.6','IsBaseSDK':'YES','MaximumDeploymentTarget':'15.6.99','MinimalDisplayName':'15.6',
    'PropertyConditionFallbackNames':['arm64'],
    'SupportedTargets':{'iphoneos':{'Archs':['arm64','arm64e'],'DefaultDeploymentTarget':'15.0','LLVMTargetTripleSys':'ios','LLVMTargetTripleEnvironment':'','LLVMTargetTripleVendor':'apple','MinimumDeploymentTarget':'12.0','MaximumDeploymentTarget':'15.6.99','ValidDeploymentTargets':['12.0','12.1','12.2','12.3','12.4','13.0','13.1','13.2','13.3','13.4','13.5','13.6','14.0','14.1','14.2','14.3','14.4','14.5','15.0','15.1','15.2','15.3','15.4','15.5','15.6']}},
    'Version':'15.6','DefaultDeploymentTarget':'15.0'
}
with open('$SDK_DIR/SDKSettings.json','w') as f: json.dump(d,f)
"
fi

# ── UIKit stubs ──────────────────────────────────
HDR="$SDK_DIR/System/Library/Frameworks/UIKit.framework/Headers"
mkdir -p "$HDR"
echo '#import <UIKit/UIKitCore.h>' > "$HDR/UIKit.h"

python3 -c "
h='''$(cat << 'ENDUIKIT'
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
@class UIColor, UIFont, UIScreen, UIWindow;
@class UINavigationController, UINavigationItem, UIBarButtonItem;
@class UIAlertAction, UITableView, UITableViewCell, UISearchBar;
@protocol UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate;
@protocol UITextInputTraits;

typedef NS_ENUM(NSInteger, UIViewAutoresizing) { UIViewAutoresizingNone=0,UIViewAutoresizingFlexibleWidth=1<<1,UIViewAutoresizingFlexibleHeight=1<<4 };
typedef NS_ENUM(NSInteger, UITableViewStyle) { UITableViewStylePlain,UITableViewStyleGrouped };
typedef NS_ENUM(NSInteger, UITableViewCellStyle) { UITableViewCellStyleDefault,UITableViewCellStyleSubtitle };
typedef NS_ENUM(NSInteger, UITableViewCellAccessoryType) { UITableViewCellAccessoryNone,UITableViewCellAccessoryDisclosureIndicator };
typedef NS_ENUM(NSInteger, UITableViewCellSelectionStyle) { UITableViewCellSelectionStyleNone,UITableViewCellSelectionStyleDefault };
typedef NS_ENUM(NSInteger, UITableViewCellEditingStyle) { UITableViewCellEditingStyleNone,UITableViewCellEditingStyleDelete };
typedef NS_ENUM(NSInteger, UITableViewRowAnimation) { UITableViewRowAnimationFade,UITableViewRowAnimationAutomatic=100 };
typedef NS_ENUM(NSInteger, UIAlertControllerStyle) { UIAlertControllerStyleActionSheet,UIAlertControllerStyleAlert };
typedef NS_ENUM(NSInteger, UIAlertActionStyle) { UIAlertActionStyleDefault,UIAlertActionStyleCancel };
typedef NS_ENUM(NSInteger, UIBarButtonItemStyle) { UIBarButtonItemStylePlain };
typedef NS_ENUM(NSInteger, UIReturnKeyType) { UIReturnKeyDefault,UIReturnKeyDone };
typedef NS_ENUM(NSInteger, UITextAutocorrectionType) { UITextAutocorrectionTypeDefault,UITextAutocorrectionTypeNo };
typedef NS_ENUM(NSInteger, UITextAutocapitalizationType) { UITextAutocapitalizationTypeNone };
@interface UIResponder : NSObject
- (BOOL)resignFirstResponder;
@end
@interface UIBarItem : NSObject @end
@interface UIColor : NSObject
+ (UIColor *)redColor; + (UIColor *)greenColor; + (UIColor *)grayColor;
+ (UIColor *)groupTableViewBackgroundColor;
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
@end
@interface UIFont : NSObject
+ (UIFont *)systemFontOfSize:(CGFloat)size;
@end
@interface UIView : UIResponder
@property(nonatomic) CGRect frame,bounds;
@property(nonatomic) UIViewAutoresizing autoresizingMask;
@property(nonatomic,copy) UIColor *backgroundColor;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
@end
@interface UIWindow : UIView @end
@interface UIScrollView : UIView @end
@interface UILabel : UIView
@property(nonatomic,copy) NSString *text;
@property(nonatomic,strong) UIColor *textColor;
@property(nonatomic,strong) UIFont *font;
@end
@interface UIControl : UIView @end
@interface UISearchBar : UIView @end
@protocol UITextFieldDelegate <NSObject> @end
@protocol UITextInputTraits <NSObject> @end
@interface UITextField : UIControl <UITextInputTraits>
- (instancetype)initWithFrame:(CGRect)frame;
@property(nonatomic,copy) NSString *placeholder,*text;
@property(nonatomic,strong) UIFont *font;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;
@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic,weak) id<UITextFieldDelegate> delegate;
@end
@interface UIViewController : UIResponder
@property(nonatomic,copy) NSString *title;
@property(nonatomic,readonly,strong) UIView *view;
@property(nonatomic,readonly,strong) UINavigationController *navigationController;
@property(nonatomic,readonly,strong) UINavigationItem *navigationItem;
- (void)viewDidLoad;
- (void)viewWillDisappear:(BOOL)animated;
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void(^)(void))completion;
@end
@interface UINavigationController : UIViewController
- (void)pushViewController:(UIViewController *)vc animated:(BOOL)animated;
@end
@interface UINavigationItem : NSObject
@property(nonatomic,retain) UIBarButtonItem *rightBarButtonItem;
@end
@interface UITableViewController : UIViewController @end
@interface UIBarButtonItem : UIBarItem
- (instancetype)initWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action;
@end
@protocol UITableViewDataSource <NSObject>
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip;
@optional
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv;
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section;
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip;
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip;
@end
@protocol UITableViewDelegate <NSObject>
@optional
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip;
@end
@interface UITableView : UIScrollView
@property(nonatomic,weak) id<UITableViewDataSource> dataSource;
@property(nonatomic,weak) id<UITableViewDelegate> delegate;
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
- (void)reloadData;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)anim;
- (void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)anim;
- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (__kindof UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;
@end
@interface UITableViewCell : UIView
@property(nonatomic,readonly,strong) UILabel *textLabel,*detailTextLabel;
@property(nonatomic) UITableViewCellAccessoryType accessoryType;
@property(nonatomic,strong) UIView *accessoryView;
@property(nonatomic) UITableViewCellSelectionStyle selectionStyle;
@property(nonatomic,readonly,strong) UIView *contentView;
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid;
@end
@interface UIAlertAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void(^)(UIAlertAction *))handler;
@end
@interface UIAlertController : UIViewController
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)msg preferredStyle:(UIAlertControllerStyle)style;
- (void)addAction:(UIAlertAction *)action;
- (void)addTextFieldWithConfigurationHandler:(void(^)(UITextField *))handler;
@property(nonatomic,readonly) NSArray<UITextField *> *textFields;
@end
@interface UIApplication : UIResponder
+ (UIApplication *)sharedApplication;
@end
@interface UIScreen : NSObject
+ (UIScreen *)mainScreen;
@property(nonatomic,readonly) CGRect bounds;
@end
@interface NSIndexPath (UIKit)
@property(nonatomic,readonly) NSInteger section,row;
@end
ENDUIKIT
)'''
with open('$HDR/UIKitCore.h','w') as f:
    f.write(h)
"

# ── 编译 ──────────────────────────────────────────
echo "[*] 编译 Tweak.m..."
clang -x objective-c -target arm64-apple-ios15.0 -isysroot "$SDK_DIR" \
  -fobjc-arc -fno-modules \
  -I"$HDR" -I"$THEOS_DIR/vendor/include" -I"$THEOS_DIR/include" -I"$SCRIPT_DIR" \
  -c "$SCRIPT_DIR/Tweak.m" -o /tmp/Tweak.o

echo "[*] 编译 QuarkAPI.m..."
clang -x objective-c -target arm64-apple-ios15.0 -isysroot "$SDK_DIR" \
  -fobjc-arc -fno-modules \
  -I"$HDR" -I"$THEOS_DIR/vendor/include" -I"$THEOS_DIR/include" -I"$SCRIPT_DIR" \
  -c "$SCRIPT_DIR/QuarkAPI.m" -o /tmp/QuarkAPI.o

echo "[*] 链接 dylib..."
clang -target arm64-apple-ios15.0 -isysroot "$SDK_DIR" -dynamiclib \
  -install_name @rpath/quarkd.dylib \
  -Xlinker -undefined -Xlinker dynamic_lookup \
  -Xlinker -platform_version -Xlinker ios -Xlinker 15.0 -Xlinker 15.0 \
  -L"$SDK_DIR/usr/lib" -lSystem \
  /tmp/Tweak.o /tmp/QuarkAPI.o \
  -o "$SCRIPT_DIR/quarkd.dylib"

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ quarkd.dylib 构建完成"
echo "  $(ls -lh "$SCRIPT_DIR/quarkd.dylib" | awk '{print $5}')  $(file "$SCRIPT_DIR/quarkd.dylib" | cut -d: -f2-)"
echo ""
echo "  注入方式 (签名 IPA):"
echo "  insert_dylib @rpath/quarkd.dylib WeChat.app/WeChat --strip-codesig"
echo "  cp quarkd.dylib WeChat.app/Frameworks/"
echo "  然后 zsign / ldid 重新签名"
echo "═══════════════════════════════════════════"
