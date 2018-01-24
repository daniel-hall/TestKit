//
//  TestKitFeature.swift
//  TestKit
//
// Copyright (c) 2018 Daniel Hall
// Twitter: @_danielhall
// GitHub: https://github.com/daniel-hall
// Website: http://danielhall.io
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//


import UIKit


@objc open class TestKitFeature: NSObject {
    
    // Required override in subclasses to add hooks for different given, when, and then statements
    open class func registerStepHandlers() {
        assertionFailure("You must override the registerStepHandlers class method")
    }
    
    /// Optional override in subclasses to add notification handlers, which can be used to set up testing conditions in the target app before steps are executed
    open class func registerNotificationHandlers() {
        // Override as desired in subclasses
    }
    
    /// Add a handler for a "given" step that matches the provided regex string and performs the specified action closure.
    public static func given(_ expression:String, action:@escaping (StepInput) throws ->()) {
        TestKit.givenHandlers.append(Handler(expression){
            do {
                try action($0)
                $1.succeed()
            } catch {
                $1.fail(reason: String(describing: error))
            }
        })
    }
    
    /// Add a handler for a "given" step that matches the provided regex string and performs the specified action closure. This version can have a timeout specified and must call succeed or fail on the passed in StepCallback within the timeout period
    public static func given(_ expression:String, timeout: TimeInterval, action:@escaping (StepInput, StepCallback)->()) {
        TestKit.givenHandlers.append(Handler(expression, timeout:timeout, action: action))
    }
    
    /// Add a handler for a "when" step that matches the provided regex string and performs the specified action closure.
    public static func when(_ expression:String, action:@escaping (StepInput) throws ->()) {
        TestKit.whenHandlers.append(Handler(expression){
            do {
                try action($0)
                $1.succeed()
            } catch {
                $1.fail(reason: String(describing: error))
            }
        })
    }
    
    /// Add a handler for a "when" step that matches the provided regex string and performs the specified action closure. This version can have a timeout specified and must call succeed or fail on the passed in StepCallback within the timeout period
    public static func when(_ expression:String, timeout: TimeInterval, action:@escaping (StepInput, StepCallback)->()) {
        TestKit.whenHandlers.append(Handler(expression, timeout:timeout, action: action))
    }
    
    /// Add a handler for a "then" step that matches the provided regex string and performs the specified action closure.
    public static func then(_ expression:String, action:@escaping (StepInput) throws ->()) {
        TestKit.thenHandlers.append(Handler(expression){
            do {
                try action($0)
                $1.succeed()
            } catch {
                $1.fail(reason: String(describing: error))
            }
        })
    }
    
      /// Add a handler for a "then" step that matches the provided regex string and performs the specified action closure. This version can have a timeout specified and must call succeed or fail on the passed in StepCallback within the timeout period
    public static func then(_ expression:String, timeout: TimeInterval, action:@escaping (StepInput, StepCallback)->()) {
        TestKit.thenHandlers.append(Handler(expression, timeout:timeout, action: action))
    }
    
    /// Register a notification handler for for the specified notification name
    public static func handleNotification(_ name: String, with closure: @escaping([String: Any]) -> ()) {
        let qualifiedName = "TestKit.Notification.Custom." + name
        TestKit.notificationHandlers[qualifiedName] = closure
        let notificationCallback: CFNotificationCallback = {
            (center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) in
            guard let notificationName = name else { return }
            let notificationInfo: [String: Any] = TestKit.notificationInfo ?? [:]
            TestKit.notificationHandlers[notificationName.rawValue as String]?(notificationInfo)
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, notificationCallback, qualifiedName as CFString, nil, .deliverImmediately)
    }
    
    /// Sends a notification, usually from a step in the UI Test target to a handler in the target app
    public static func sendNotification(name:String, info:[String:Any]?) {
        let qualifiedName = "TestKit.Notification.Custom." + name
        TestKit.postNotification(name: qualifiedName, info: info)
    }
    
    /// Convenience method for step handlers in the target app to get an array of views in the current window that are the specified type or a subclass of the specified type, optionally matching a provided accessibilityIdentifier
    public static func views<T: UIView>(ofType:T.Type, accessibilityIdentifier: String? = nil, inView:UIView = (UIApplication.shared.delegate?.window ?? nil) ?? UIView()) -> [T] {
        let viewArray = Array(inView.subviews.map { views(ofType: ofType, accessibilityIdentifier: accessibilityIdentifier, inView: $0) }.joined())
        guard let inViewTyped = inView as? T, accessibilityIdentifier == nil || inView.accessibilityIdentifier == accessibilityIdentifier else {
            return viewArray
        }
        return viewArray + [inViewTyped]
    }
    
    /// Convenience method for step handlers in the target app to get an array of views in the current window that are exactly the specified type, optionally matching a provided accessibilityIdentifier
    public static func views<T: UIView>(ofExactType:T.Type, accessibilityIdentifier: String? = nil, inView:UIView = (UIApplication.shared.delegate?.window ?? nil) ?? UIView()) -> [T] {
        let viewArray = Array(inView.subviews.map { views(ofExactType: ofExactType, accessibilityIdentifier: accessibilityIdentifier, inView: $0) }.joined())
        guard let inViewTyped = inView as? T, accessibilityIdentifier == nil || inView.accessibilityIdentifier == accessibilityIdentifier, type(of:inView) == ofExactType else {
            return viewArray
        }
        return viewArray + [inViewTyped]
    }
    
    /// Convenience method for step handlers in the target app to get an array of views in the current window that have the specified accessibility identifier
    public static func views(withAccessibilityIdentifier:String? = nil, inView: UIView = (UIApplication.shared.delegate?.window ?? nil) ?? UIView()) -> [UIView] {
        let viewArray = Array(inView.subviews.map { views(withAccessibilityIdentifier: withAccessibilityIdentifier, inView: $0) }.joined())
        guard withAccessibilityIdentifier == nil || inView.accessibilityIdentifier == withAccessibilityIdentifier else {
            return viewArray
        }
        return viewArray + [inView]
    }
}
