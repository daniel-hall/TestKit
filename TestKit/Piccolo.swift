//
//  Piccolo.swift
//  Piccolo
//
// Copyright (c) 2017 Daniel Hall
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


//Piccolo is a Swift-based parser for Gherkin feature files

import Foundation


public struct Feature {
    let name: String
    let description: String?
    let scenarios: [Scenario]
    let tags: [String]
}

public struct Scenario {
    let name: String
    let description: String?
    let givens: [Step]
    let whens: [Step]
    let thens: [Step]
    let tags: [String]
}

public struct Step {
    let description: String
    let docString: String?
    let dataTable: [[String: String]]?
}

public struct PiccoloParseError: Error, CustomStringConvertible {
    public let description: String
    init(description:String) {
        self.description = description
    }
    init(lineNumber: Int, description: String) {
        self.init(description: "Invalid Gherkin syntax on line \(lineNumber). \(description)")
    }
}

public func parse(gherkin:String) throws -> Feature {
    
    enum PiccoloParseContext {
        case start
        case parsedFeatureName
        case parsingBackground
        case parsedBackgroundKeyword
        case readyToParseScenario
        case parsedScenarioName
        case parsedScenarioOutlineName
        case parsingScenarioGiven
        case parsingScenarioWhen
        case parsingScenarioThen
        case parsingScenarioOutlineGiven
        case parsingScenarioOutlineWhen
        case parsingScenarioOutlineThen
        case parsingScenarioOutlineExample
    }
    
    var context = PiccoloParseContext.start
    var featureName = ""
    var featureTags = [String]()
    var featureDescription = ""
    
    var backgroundGivens = [Step]()
    var scenarios = [Scenario]()
    
    var pendingTags = [String]()
    var scenarioName = ""
    var scenarioDescription = ""
    var scenarioTags = [String]()
    
    var givens = [Step]()
    var whens = [Step]()
    var thens = [Step]()
    
    var stepDescription = ""
    var dataTableHeaders = [String]()
    var dataTable = [[String: String]]()
    var docString = ""
    
    var parsingDocString = false
    var currentLine = ""
    var currentLineNumber = 0
    
    
    func parseTagName(success: ((String) throws -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^@)\\w+$", options: .regularExpression) {
            try success?(currentLine.substring(with: range).trimmingCharacters(in: .whitespaces))
            return true
        }
        if currentLine.hasPrefix("@") {
            throw PiccoloParseError(lineNumber: currentLineNumber, description: "Invalid syntax for tag.")
        }
        return false
    }
    
    func parseFeatureName(success: ((String) throws -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^feature:)\\s*\\S+.*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range).trimmingCharacters(in: .whitespaces))
            return true
        }
        return false
    }
    
    func parseBackground(success: (() throws -> ())? = nil) throws -> Bool {
        if currentLine.lowercased().hasPrefix("background:") {
            try success?()
            return true
        }
        return false
    }
    
    func parseComment() throws -> Bool {
        if currentLine.hasPrefix("#") {
            return true
        }
        return false
    }
    
    func parseBlankLine() throws -> Bool {
        if currentLine == "" {
            return true
        }
        return false
    }
    
    func parseGiven(success: ((String) throws -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^given ).*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range).trimmingCharacters(in: .whitespaces))
            return true
        }
        return false
    }
    
    func parseAndOrBut(success: ((String) throws -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^and ).*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range))
            return true
        }
        if let range = currentLine.range(of:"(?<=^but ).*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range))
            return true
        }
        return false
    }
    
    func parseWhen(success: ((String)throws  -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^when ).*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range))
            return true
        }
        return false
    }
    
    func parseThen(success: ((String) throws -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^then ).*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range))
            return true
        }
        return false
    }
    
    func parseDocString(success: ((String) throws -> ())? = nil) throws -> Bool {
        if currentLine == "\"\"\"" {
            parsingDocString = !parsingDocString
            return true
        }
        if parsingDocString {
            docString += currentLine + "\n"
            try success?(currentLine)
            return true
        }
        return false
    }
    
    func parseDataTable(success: (() throws -> ())? = nil) throws -> Bool {
        func parseDataTableRow() throws -> [String]? {
            guard currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("|") && currentLine.trimmingCharacters(in: .whitespaces).hasSuffix("|") else {
                return nil
            }
            let fields = currentLine.components(separatedBy: "|")
            return fields.count > 0 ? fields : nil
        }
        if dataTableHeaders.count > 0 {
            if let row = try parseDataTableRow() {
                guard row.count == dataTableHeaders.count else {
                    throw PiccoloParseError(lineNumber: currentLineNumber, description: "Mismatch in number of columns in this Data Table Row")
                }
                dataTable.append(row.enumerated().reduce([:]){
                    var dictionary = $0.0
                    dictionary[dataTableHeaders[$0.1.offset]] = $0.1.element
                    return dictionary
                    }
                )
                try success?()
                return true
            }
            return false
        } else if dataTableHeaders.count == 0 {
            if let row = try parseDataTableRow() {
                dataTableHeaders = row
                try success?()
                return true
            }
        }
        return false
    }
    
    func parseScenarioOutlineName(success: ((String) throws -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^scenario outline:)\\s*\\S+.*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range).trimmingCharacters(in: .whitespaces))
            return true
        }
        return false
    }
    
    func parseScenarioOutlineExampleKeyword(success: (() throws -> ())? = nil) throws -> Bool {
        if let _ = currentLine.range(of:"(?<=^examples:)\\s*$", options: [.regularExpression, .caseInsensitive]) {
            try success?()
            return true
        }
        return false
    }
    
    func parseScenarioName(success: ((String) throws -> ())? = nil) throws -> Bool {
        if let range = currentLine.range(of:"(?<=^scenario:)\\s*\\S+.*$", options: [.regularExpression, .caseInsensitive]) {
            try success?(currentLine.substring(with: range).trimmingCharacters(in: .whitespaces))
            return true
        }
        return false
    }
    
    func parseDescription(success: ((String) throws -> ())? = nil) throws -> Bool {
        let hasKeyword = try parseGiven() || parseComment() || parseDataTable() || parseScenarioOutlineExampleKeyword() || parseBackground() || parseThen() || parseWhen() || parseAndOrBut() || parseTagName() || parseFeatureName() || parseScenarioName() || parseScenarioOutlineName() || currentLine == "\"\"\"" || parsingDocString
        if !hasKeyword {
            try success?(currentLine.trimmingCharacters(in: .whitespaces))
            return true
        }
        return false
    }
    
    func finalizeStep() throws -> Step {
        guard !parsingDocString else {
            throw PiccoloParseError(lineNumber: currentLineNumber, description: "Unterminated doc string")
        }
        let step = Step(description: stepDescription, docString: docString.isEmpty ? nil : docString, dataTable: dataTable.count == 0 ? nil : dataTable)
        stepDescription = ""
        dataTableHeaders = []
        dataTable = []
        docString = ""
        return step
    }
    
    func finalizeScenario() throws -> Scenario {
        let scenario = Scenario(name: scenarioName, description: scenarioDescription.isEmpty ? nil : scenarioDescription, givens: backgroundGivens + givens, whens: whens, thens: thens, tags: scenarioTags)
        scenarioDescription = ""
        scenarioTags = []
        givens = []
        whens = []
        thens = []
        return scenario
    }
    
    func finalizeScenarioOutline() throws -> [Scenario] {
        guard dataTable.count > 0 else {
            throw PiccoloParseError(lineNumber: currentLineNumber, description: "Scenario Outline must have a valid data table under the keyword Examples:")
        }
        let generatedScenarios = dataTable.map {
            (example:[String:String]) -> Scenario in
            var name = scenarioName
            var description = scenarioDescription
            var scenarioGivens = givens
            var scenarioWhens = whens
            var scenarioThens = thens
            example.forEach {
                (variable:(name:String, value:String)) in
                let stepClosure:(Step)->Step = {
                    let description = $0.description.replacingOccurrences(of: "<\(variable.name)>", with: variable.value)
                    let docString = $0.docString?.replacingOccurrences(of: "<\(variable.name)>", with: variable.value)
                    let dataTable = $0.dataTable?.map {
                        dataRow -> [String : String] in
                        var dictionary = [String:String]()
                        dataRow.forEach {
                            dictionary[$0.0.replacingOccurrences(of: "<\(variable.name)>", with: variable.value)] = $0.1.replacingOccurrences(of: "<\(variable.name)>", with: variable.value)
                        }
                        return dictionary
                    }
                    return Step(description: description, docString: docString, dataTable:dataTable)
                }
                name = name.replacingOccurrences(of: "<\(variable.name)>", with: variable.value)
                description = description.replacingOccurrences(of: "<\(variable.name)>", with: variable.value)
                scenarioGivens = scenarioGivens.map(stepClosure)
                scenarioWhens = scenarioWhens.map(stepClosure)
                scenarioThens = scenarioThens.map(stepClosure)
            }
            return Scenario(name: name, description: description.isEmpty ? nil : description, givens: backgroundGivens + scenarioGivens, whens: scenarioWhens, thens: scenarioThens, tags: scenarioTags)
        }
        scenarioDescription = ""
        scenarioTags = []
        givens = []
        whens = []
        thens = []
        return generatedScenarios
    }
    
    func finalizeScenarioOrScenarioOrOutline() throws -> () {
        guard !scenarioName.isEmpty else { return }
        try thens.append(finalizeStep())
        if context == .parsingScenarioThen {
            try scenarios.append(finalizeScenario())
        } else {
            try scenarios += finalizeScenarioOutline()
        }
    }
    
    func finalizeBackground() throws -> () {
        try backgroundGivens.append(finalizeStep())
        guard backgroundGivens.count > 0 else {
            throw PiccoloParseError(lineNumber: currentLineNumber, description: "Background section must contain at least one Given")
        }
    }
    
    let lines = gherkin.components(separatedBy: "\n")
    
    try lines.forEach {
        currentLineNumber += 1
        currentLine = $0
        
        switch context {
        case .start:
            let success = try
                parseComment() ||
                parseBlankLine() ||
                parseTagName() { featureTags.append($0) } ||
                parseFeatureName() { featureName = $0; context = .parsedFeatureName }
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, tag or Feature:")
            }
        case .parsedBackgroundKeyword:
            let success = try
                parseComment() ||
                parseBlankLine() ||
                parseGiven() {
                    stepDescription = $0
                    context = .parsingBackground
            }
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line or Given:")
            }
        case .parsingBackground:
            let success = try
                parseGiven(){
                    try backgroundGivens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseAndOrBut(){
                    try backgroundGivens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseTagName() {
                    try finalizeBackground()
                    pendingTags.append($0)
                    context = .readyToParseScenario
                } ||
                parseScenarioName() {
                    try finalizeBackground()
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioName
                } ||
                parseScenarioOutlineName() {
                    try finalizeBackground()
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioOutlineName
                } ||
                parseDataTable() ||
                parseDocString() ||
                parseComment() ||
                parseBlankLine()
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, Data Table, Doc String, Given, And, But or When")
            }
        case .parsedFeatureName:
            let success = try
                parseComment() ||
                parseBlankLine() ||
                parseBackground() { context = .parsedBackgroundKeyword } ||
                parseTagName() { pendingTags.append($0) } ||
                parseScenarioName() {
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioName
                } ||
                parseScenarioOutlineName() {
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioOutlineName
                } ||
                parseDescription() {
                    featureDescription += $0 + "\n"
            }
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, tag, description, Background:, Scenario: or Scenario Outline:")
            }
        case .parsedScenarioName, .parsedScenarioOutlineName:
            let success = try
                parseComment() ||
                parseBlankLine() ||
                parseGiven() {
                    stepDescription = $0
                    context = .parsingScenarioGiven
                } ||
                parseWhen(){
                    stepDescription = $0
                    context = .parsingScenarioWhen
                } ||
                parseDescription() {
                    scenarioDescription += $0 + "\n"
            }
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, description, or Given")
            }
        case .parsingScenarioGiven, .parsingScenarioOutlineGiven:
            let success = try
                parseGiven(){
                    try givens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseAndOrBut(){
                    try givens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseWhen(){
                    try givens.append(finalizeStep())
                    stepDescription = $0
                    context = .parsingScenarioWhen
                } ||
                
                parseDataTable() ||
                parseDocString() ||
                parseComment() ||
                parseBlankLine()
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, Data Table, Doc String, Given, And, But or When")
            }
        case .parsingScenarioWhen, .parsingScenarioOutlineWhen:
            let success = try
                parseWhen(){
                    try whens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseAndOrBut(){
                    try whens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseThen(){
                    try whens.append(finalizeStep())
                    stepDescription = $0
                    context = .parsingScenarioThen
                } ||
                parseDataTable() ||
                parseDocString() ||
                parseComment() ||
                parseBlankLine()
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, Data Table, Doc String, When, And, But or Then")
            }
        case .readyToParseScenario:
            let success = try
                parseComment() ||
                parseBlankLine() ||
                parseTagName() { pendingTags.append($0) } ||
                parseScenarioName() {
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioName
                } ||
                parseScenarioOutlineName() {
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioOutlineName
            }
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, tag, Scenario: or Scenario Outline:")
            }
        case .parsingScenarioThen, .parsingScenarioOutlineThen:
            let success = try
                parseThen(){
                    try thens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseAndOrBut(){
                    try thens.append(finalizeStep())
                    stepDescription = $0
                } ||
                parseScenarioOutlineExampleKeyword () {
                    try thens.append(finalizeStep())
                    context = .parsingScenarioOutlineExample
                } ||
                parseTagName() {
                    try finalizeScenarioOrScenarioOrOutline()
                    pendingTags.append($0)
                    context = .readyToParseScenario
                } ||
                parseScenarioName() {
                    try finalizeScenarioOrScenarioOrOutline()
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioName
                } ||
                parseScenarioOutlineName() {
                    try finalizeScenarioOrScenarioOrOutline()
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioOutlineName
                } ||
                parseDataTable() ||
                parseDocString() ||
                parseComment() ||
                parseBlankLine()
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, Data Table, Doc String, When, And, But or Then")
            }
        case .parsingScenarioOutlineExample:
            let success = try
                parseDataTable() ||
                parseDescription() ||
                parseComment() ||
                parseBlankLine() ||
                parseScenarioOutlineExampleKeyword () {
                    context = .parsingScenarioOutlineExample
                } ||
                parseTagName() {
                    try finalizeScenarioOrScenarioOrOutline()
                    pendingTags.append($0)
                    context = .readyToParseScenario
                } ||
                parseScenarioName() {
                    try finalizeScenarioOrScenarioOrOutline()
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioName
                } ||
                parseScenarioOutlineName() {
                    try finalizeScenarioOrScenarioOrOutline()
                    scenarioName = $0
                    scenarioTags = featureTags + pendingTags
                    pendingTags = []
                    context = .parsedScenarioOutlineName
            }
            if !success {
                throw PiccoloParseError(lineNumber: currentLineNumber, description: "Expected a comment, blank line, Data Table, Tag, Scenario, or Scenario Outline")
            }
        }
    }
    
    if context == .parsingScenarioThen {
        try thens.append(finalizeStep())
        try scenarios.append(finalizeScenario())
        return Feature(name: featureName, description: !featureDescription.isEmpty ? featureDescription : nil, scenarios: scenarios, tags: featureTags)
    }
    if context == .parsingScenarioOutlineExample {
        try scenarios += finalizeScenarioOutline()
        return Feature(name: featureName, description: featureDescription.isEmpty ? nil : featureDescription, scenarios: scenarios, tags: featureTags)
    }
    
    throw PiccoloParseError(description: "Invalid syntax. Gherkin feature file must end with a complete valid Scenario or Scenario Outline")
}
