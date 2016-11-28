//
//  Functions.swift
//  TestKitExample
//
//  Created by Daniel Hall on 11/28/16.
//  Copyright © 2016 Daniel Hall. All rights reserved.
//

import Foundation


struct ParsingError: Error {
    enum ParsingErrorType: String {
        case WrongType, MissingKey
    }
    let type: ParsingErrorType
    let message: String
}

func stringValue(for int:Int) -> String? {
    return int == 1 ? "One" : nil
}

func isValidPassword(string:String) -> Bool {
    let hasValidLength = string.characters.count >= 8 && string.characters.count <= 16
    let isASCIIOnly = string.canBeConverted(to: String.Encoding.ascii)
    let containsNumber = string.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
    let containsLowercase = string.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
    let containsUppercase = string.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
    return hasValidLength && isASCIIOnly && containsNumber && containsLowercase && containsUppercase
}

func parseInt(from dictionary:[String: Any], key:String) throws -> Int {
    guard dictionary.index(forKey: key) != nil else {
        throw ParsingError(type: .MissingKey, message: "Missing Key: \(key)")
    }
    // Value must cast to a non-nil Int, and also have 64-bit Int encoding (to weed out NSNumber boolean values, etc.) otherwise, wrong type
    guard let value = dictionary[key] as? Int, let cString = (dictionary[key] as? NSNumber)?.objCType, String(cString:cString) == "q" else {
        throw ParsingError(type: .WrongType, message: "Wrong Type of Value for Key: \(key)")
    }
    return value
}
