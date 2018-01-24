//
//  AppDelegate.swift
//  TestKitExample
//
//  Created by Daniel Hall on 5/21/17.
//  Copyright © 2017 Daniel Hall. All rights reserved.
//

import UIKit


var isLoggedIn = false

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // If this process was launched by TestKit, load the unit test bundle and initialize its principlat class (TestKit)
        Bundle(path: ProcessInfo.processInfo.environment["TestKitUnitTestBundlePath"] ?? "")?.load()
        _ = (NSClassFromString("TestKit.TestKit") as AnyObject?)?.perform(Selector(("startup")))
        return true
    }

}

