//
//  Person.swift
//  TestKitExample
//
//  Created by Daniel Hall on 11/28/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import Foundation

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
