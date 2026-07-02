//
//  MMConsoleLogFormatter.h
//  ExampleDevelop
//
//  Created by ripper on 2019/6/19.
//  Copyright © 2019 picooc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/DDLog.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMConsoleLogFormatter : NSObject <DDLogFormatter>

- (NSString *)logMessageEmoji:(DDLogMessage *)logMessage;

@end

NS_ASSUME_NONNULL_END
