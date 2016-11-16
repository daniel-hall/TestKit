//
//  ViewController.swift
//  TestKitExample
//
//  Created by Daniel Hall on 11/6/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import UIKit

func isValidInt(int:Any) -> Bool {
    
    if let int = int as? NSNumber, int.stringValue.components(separatedBy:".").count > 1 {
        return false
    }
    
    guard let int = int as? Int else {
        return false
    }
    return int >= 0 && int <= 100
}

func matchingValue(for value:Int) -> String? {
    return value == 1 ? "One" : nil
}

struct Person {
    let firstName:String
    let lastName:String
    var age:Int
    
    var fullName:String { return firstName + " " + lastName }
    
    init(first:String, last:String, age:Int = 18) {
        firstName = first
        lastName = last
        self.age = age
    }
}


class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

