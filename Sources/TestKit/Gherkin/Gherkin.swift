//
//  Gherkin.swift
//  TestKit
//
//  Created by Daniel Hall on 1/24/20.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Foundation

public enum Gherkin {
        
    public struct ParsingError: LocalizedError {
        private let description: String
        init(_ description: String) {
            self.description = description
        }
        public var errorDescription: String? {
            return description
        }
    }
    
    // A native struct representation of a Gherkin Feature, with the various possible rules, examples, scenarios, tags, background, etc. that can be described by a Gherkin feature file.
    public struct Feature: Codable, Equatable {
        public internal(set) var description: String?
        public internal(set) var tags: [String]?
        public internal(set) var background: Background?
        public internal(set) var rules: [Rule]
        
        internal init(description: String?, tags: [String]?, background: Background?, rules: [Rule]) {
            self.description = description
            self.tags = tags
            self.background = background
            self.rules = rules
        }
        
        public init(_ gherkinURL: URL) throws {
            try self.init(Data(contentsOf: gherkinURL))
        }
        
        public init(_ gherkinData: Data) throws {
            guard let string = String(data: gherkinData, encoding: .utf8) else {
                throw ParsingError("The provided Gherkin data could not be decoded as a UTF8 string")
            }
            try self.init(string)
        }
        
        public init(_ gherkinString: String) throws {
            let feature = try Gherkin.parse(gherkinString)
            self.description = feature.description
            self.tags = feature.tags
            self.background = feature.background
            self.rules = feature.rules
        }
        
        public struct Background: Codable, Equatable {
            public internal(set) var description: String?
            public internal(set) var steps: [Step]
        }
        
        public struct Rule: Codable, Equatable {
            public internal(set) var tags: [String]?
            public internal(set) var description: String?
            public internal(set) var examples: [Example]
        }
        
        public struct Example: Codable, Equatable {
            public internal(set) var tags: [String]?
            public internal(set) var description: String?
            public internal(set) var steps: [Step]
        }
        
        public struct Step: Codable, Equatable {
            public internal(set) var description: String
            public internal(set) var argument: Argument?
            
            public enum Argument: Codable, Equatable {
                case docString(String)
                case dataTable(DataTable)
                
                enum CodingKeys: CodingKey {
                    case docString
                    case dataTable
                }
                
                public var docString: String? {
                    if case .docString(let string) = self {
                        return string
                    }
                    return nil
                }
                
                public var dataTable: DataTable? {
                    if case .dataTable(let table) = self {
                        return table
                    }
                    return nil
                }
                
                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    switch self {
                    case .docString(let value):
                        try container.encode(value, forKey: .docString)
                    case .dataTable(let value):
                        try container.encode(value, forKey: .dataTable)
                    }
                }
                
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    do {
                        let string = try container.decode(String.self, forKey: .docString)
                        self = .docString(string)
                    } catch {
                        let dataTable = try container.decode(DataTable.self, forKey: .dataTable)
                        self = .dataTable(dataTable)
                    }
                }
            }
            
            public struct DataTable: Codable, Equatable {
                var rows: [[String]] = []
                
                public func formatted<T: DataTableFormatter>(using formatter: T) throws -> T.OutputFormat {
                    return try formatter.format(rows)
                }
                
                public enum Formatter {
                    public struct Error: Swift.Error {
                        let localizedDescription: String
                        init(_ description: String) {
                            localizedDescription = description
                        }
                    }
                    
                    public struct FirstRowAsKeys: DataTableFormatter {
                        
                        public init(){}
                        
                        public func format(_ rows: [[String]]) throws -> [[String: String]] {
                            var rows = Array(rows.reversed())
                            guard let keys = rows.popLast() else {
                                throw(Error("Can't format DataTable with FirstRowAsKeys Formatter because the table contains no rows"))
                            }
                            guard !rows.isEmpty else {
                                return []
                            }
                            guard rows.reversed().reduce(true, { $1.count == keys.count ? $0 : false }) else {
                                throw(Error("Can't format DataTable with FirstRowAsKeys Formatter because not all the rows have the same number of values"))
                            }
                            return rows.reversed().map { Dictionary(zip(keys, $0), uniquingKeysWith: { $1 }) }
                        }
                    }
                    public struct FirstColumnAsKeys: DataTableFormatter {
                        
                        public init(){}

                        public func format(_ rows: [[String]]) throws -> [String: [String]] {
                            guard rows.reduce(true, { $1.isEmpty ? false : $0 }) else {
                                throw(Error("Can't format DataTable with FirstColumnAsKeys Formatter because one or more rows have no values"))
                            }
                            return Dictionary(rows.reduce([(String, [String])]()){ $0 + [($1.first!, Array($1.dropFirst()))] }, uniquingKeysWith: { $1 })
                        }
                    }
                    
                    public struct FirstColumnAsKeysAndFirstRowAsPropertyNames: DataTableFormatter {
                        
                        public init(){}

                        public func format(_ rows: [[String]]) throws -> [String: [String: String]] {
                            var rows = Array(rows.reversed())
                            guard let keys = rows.popLast() else {
                                throw(Error("Can't format DataTable with FirstColumnAsKeysAndFirstRowAsPropertyNames Formatter because the table contains no rows"))
                            }
                            guard !rows.isEmpty else {
                                return [:]
                            }
                            guard rows.reversed().reduce(true, { $1.count == keys.count ? $0 : false }) else {
                                throw(Error("Can't format DataTable with FirstColumnAsKeysAndFirstRowAsPropertyNames Formatter because not all the rows have the same number of values"))
                            }
                            
                            let tuples = rows.reduce([(String, [String : String])]()){
                                let keyValues = zip(keys.dropFirst(), $1.dropFirst())
                                let tuple = ($1.first!, Dictionary(keyValues, uniquingKeysWith: { $1 }))
                                return $0 + [tuple]
                            }
                            return Dictionary(tuples, uniquingKeysWith: { $1 })
                        }
                    }
                    
                    public struct KeyValueMap: DataTableFormatter {
                        
                        public init(){}

                        public func format(_ rows: [[String]]) throws -> [String: String] {
                            guard rows.reduce(true, { $1.count == 2 ? $0 : false }) else {
                                throw(Error("Can't format DataTable with KeyValueMap Formatter because not all the rows have exactly 2 values (key, value)"))
                            }
                            return Dictionary(rows.map{ ($0[0], $0[1]) }, uniquingKeysWith: { $1 })
                        }
                    }
                    
                    public struct List: DataTableFormatter {
                        
                        public init(){}

                        public func format(_ rows: [[String]]) -> [String] {
                            return Array(rows.joined())
                        }
                    }
                }
            }
        }
    }
}

internal extension Gherkin {
    /// An internal type that strongly types the various Gherkin keywords to avoid magic stings and mistyping
    enum Keyword: String, CaseIterable {
        case given = "Given"
        case when = "When"
        case then = "Then"
        case and = "And"
        case but = "But"
        case scenario = "Scenario"
        case scenarios = "Scenarios"
        case scenarioOutline = "Scenario Outline"
        case scenarioTemplate = "Scenario Template"
        case example = "Example"
        case examples = "Examples"
        case data = "Data"
        case background = "Background"
        case rule = "Rule"
        case feature = "Feature"
    }
}

public protocol DataTableFormatter {
    associatedtype OutputFormat
    func format(_ rows: [[String]]) throws -> OutputFormat
}

/// A number of parsing functions expect an array of possible Gherkin Keywords to expect.  This gives a convenient way to specify common groupings of those keywords (particularly since Gherkin has synonyms that mean the same thing, like "Examples" and "Scenarios", or "Scenario Outline" and "Scenario Template". In fact, for the latest version of Gherkin, all FOUR of those keywords are now synonyms.
internal extension Array where Element == Gherkin.Keyword {
    static var feature: [Gherkin.Keyword] { return [.feature] }
    static var background: [Gherkin.Keyword] { return [.background] }
    static var rule: [Gherkin.Keyword] { return [.rule] }
    static var example: [Gherkin.Keyword] { return [.example, .scenario, .scenarioOutline, .scenarioTemplate] }
    static var step: [Gherkin.Keyword] { return [.given, .when, .then, .and, .but] }
    static var data: [Gherkin.Keyword] { return [.examples, .scenarios, .data] }
}


public extension Gherkin {
    
    static func parse(_ gherkinURL: URL) throws -> Gherkin.Feature {
        return try parse(Data(contentsOf: gherkinURL))
    }
    
    static func parse(_ gherkinData: Data) throws -> Gherkin.Feature {
        guard let string = String(data: gherkinData, encoding: .utf8) else {
            throw ParsingError("The provided Gherkin data could not be decoded as a UTF8 string")
        }
        return try parse(string)
    }
    
    static func parse(_ gherkinString: String) throws -> Gherkin.Feature {
        var parsingState = ParsingState(gherkin: gherkinString)
        var error: ParsingError?
        var feature: Feature?
        var line = ""
        
        while error == nil && feature == nil {
            let defaultError = ParsingState.error(ParsingError("Unable to parse invalid Gherkin: \(line)"))
            switch parsingState {
            case .start(let state):
                parsingState = state.parseFeature() ?? state.parseTag() ?? defaultError
            case .feature(let state):
                line = state.context.remainingToParse.first ?? ""
                parsingState = state.parseDescription() ?? state.parseBackground() ?? state.parseTag() ?? state.parseRule() ?? state.parseExample() ?? state.parseComplete() ??  defaultError
            case .step(let state):
                line = state.context.remainingToParse.first ?? ""
                parsingState = state.parseArgument() ?? state.parseComplete() ?? defaultError
            case .error(let state):
                error = state
            case .complete(let state):
                feature = state
            case .background(let state):
                line = state.context.remainingToParse.first ?? ""
                parsingState = state.parseDescription() ?? state.parseStep() ?? state.parseComplete() ?? defaultError
            case .rule(let state):
                line = state.context.remainingToParse.first ?? ""
                parsingState = state.parseDescription() ?? state.parseTag() ?? state.parseExample() ?? state.parseComplete() ?? defaultError
            case .example(let state):
                line = state.context.remainingToParse.first ?? ""
                parsingState = state.parseDescription() ?? state.parseTag() ?? state.parseStep() ?? state.parseData() ?? state.parseComplete() ?? defaultError
            case .argument(let state):
                line = state.context.remainingToParse.first ?? ""
                parsingState = state.parseArgument() ?? state.parseComplete() ?? defaultError
            }
        }
        if case .complete(let feature) = parsingState {
            return feature
        }
        if case .error(let error) = parsingState {
            throw error
        }
        throw error ?? ParsingError("An unknown parsing error occurred")
    }
}
