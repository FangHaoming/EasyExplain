//
//  MMLog.swift
//  ExampleDevelop
//
//  Created by ripper on 2019/6/20.
//  Copyright © 2019 picooc. All rights reserved.
//

/**
 ⚠️ 设置 dynamicLogLevel 会影响到日志输出
 */

import CocoaLumberjackSwift

#if DEBUG
@usableFromInline let swiftDefaultLogLevel = DDLogLevel.all
@usableFromInline let swiftDefaultLogAsyncEnabled = false
#else
@usableFromInline let swiftDefaultLogLevel = DDLogLevel.info
@usableFromInline let swiftDefaultLogAsyncEnabled = true
#endif

// Only log in debug mode, like MMLog.
@inlinable
public func log(
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    ddlog: DDLog = MMManagerForLog.sharedDDLog()
) {
    DDLogVerbose(
        message(),
        level: swiftDefaultLogLevel,
        file: file,
        function: function,
        line: line,
        asynchronous: swiftDefaultLogAsyncEnabled,
        ddlog: ddlog
    )
}

@inlinable
public func logInfo(
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    ddlog: DDLog = MMManagerForLog.sharedDDLog()
) {
    DDLogInfo(
        message(),
        level: swiftDefaultLogLevel,
        file: file,
        function: function,
        line: line,
        asynchronous: swiftDefaultLogAsyncEnabled,
        ddlog: ddlog
    )
}

@inlinable
public func logWarn(
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    ddlog: DDLog = MMManagerForLog.sharedDDLog()
) {
    DDLogWarn(
        message(),
        level: swiftDefaultLogLevel,
        file: file,
        function: function,
        line: line,
        asynchronous: swiftDefaultLogAsyncEnabled,
        ddlog: ddlog
    )
}

@inlinable
public func logError(
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    ddlog: DDLog = MMManagerForLog.sharedDDLog()
) {
    DDLogError(
        message(),
        level: swiftDefaultLogLevel,
        file: file,
        function: function,
        line: line,
        asynchronous: swiftDefaultLogAsyncEnabled,
        ddlog: ddlog
    )
}

@inlinable
public func MMAssert(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    ddlog: DDLog = MMManagerForLog.sharedDDLog()
) {
    if !condition() {
        DDLogError(
            message(),
            level: DDLogLevel.all,
            file: file,
            function: function,
            line: line,
            asynchronous: false,
            ddlog: ddlog
        )
        Swift.assertionFailure(message(), file: file, line: line)
    }
}
