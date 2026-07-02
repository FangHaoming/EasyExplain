//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "EZConstKey.h"
#import "EZConst.h"
#import "NSColor+MyColors.h"
#import "entry.h"
#import "AppDelegate.h"
#import "EZWindowManager.h"
#import "NSViewController+EZWindow.h"
#import "EZLanguageManager.h"
#import "EZToast.h"

#import "MMCrash.h"
#import "DictionaryKit.h"
#import "EZAudioPlayer.h"

#import "EZWebViewManager.h"
#import "EZOCRResult.h"
#import "EZWindowPatch.h"

#import "EZLabel.h"
#import "EZHoverButton.h"

@class DDLog;

#ifndef MM_MANAGER_FOR_LOG_DECLARED
#define MM_MANAGER_FOR_LOG_DECLARED

@interface MMManagerForLog : NSObject

+ (DDLog *)sharedDDLog;
+ (DDLog *)createADDLogWithName:(NSString *)name;
+ (NSString *)rootLogDirectory;
+ (NSString *)defaultLogDirectory;
+ (NSString *)logDirectoryWithName:(NSString *)name;

@end

#endif
