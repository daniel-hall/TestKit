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
        if ProcessInfo.processInfo.arguments.contains("RunTestKit") {
            _ = (Bundle(path: "\(Bundle.main.builtInPlugInsPath!)/TestKitExampleTests.xctest")?.principalClass as? NSObject.Type)?.init()
        }
        return true
    }

}

