//
//  GherkinParsing.swift
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

func description(for keywords: [Gherkin.Keyword], in line: String) -> String? {
    return keywords.compactMap{ description(for: $0, in: line) }.first
}

func doesLineStartWithKeyword(_ line: String) -> Bool {
    return description(for: Gherkin.Keyword.allCases, in: line) != nil
}

func blankLine(in context: ParsingState.ParsingContext) -> ParsingState.ParsingContext? {
    return context.remainingToParse.first.flatMap { currentLine in
        currentLine.isEmpty ? context.modified() : nil
    }
}

func comment(in context: ParsingState.ParsingContext) -> ParsingState.ParsingContext? {
    return context.remainingToParse.first.flatMap { currentLine in
        return currentLine.hasPrefix("#") ? context.modified() : nil
    }
}

func description(in context: ParsingState.ParsingContext, and modifyContextWithDescription: @escaping (inout ParsingState.ParsingContext, String) -> ()) -> ParsingState.ParsingContext? {
    return context.remainingToParse.first.flatMap { currentLine in
        guard currentLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && currentLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") == false && doesLineStartWithKeyword(currentLine) == false && currentLine.hasPrefix("@") == false && currentLine.hasPrefix("|") == false
            && context.example?.steps.isEmpty != false
            && context.rule?.examples.isEmpty != false
            && ( context.feature?.background != nil && context.rule == nil && context.feature?.rules.isEmpty != false ? context.feature?.background?.steps.isEmpty != false : true )
            else { return nil }
        return context.modified { modifyContextWithDescription(&$0, currentLine) }
    }
}

func tags(in context: ParsingState.ParsingContext) -> ParsingState.ParsingContext? {
    return context.remainingToParse.first.flatMap { currentLine in
        let tags = currentLine.hasPrefix("@") ? currentLine.split(separator: "@").map { $0.trimmingCharacters(in: .whitespaces) } : []
        return tags.isEmpty ? nil : context.modified {
            context in
            context.tags = context.tags + tags
        }
    }
}

func section(in context: ParsingState.ParsingContext, from keywords: [Gherkin.Keyword],and modifyContextWithDescription: ((inout ParsingState.ParsingContext, String) -> ())? = nil) -> ParsingState.ParsingContext? {
    return context.remainingToParse.first.flatMap { currentLine in
        guard let description = description(for: keywords, in: currentLine) else { return nil }
        return modifyContextWithDescription.flatMap { closure in context.modified { closure(&$0, description) } }
    }
}

func nextStep(in context: ParsingState.ParsingContext) -> ParsingState.ParsingContext? {
    return context.remainingToParse.first.flatMap { currentLine in
        if let description = description(for: .given, in: currentLine)
            ?? description(for: .when, in: currentLine)
            ?? description(for: .then, in: currentLine) {
            return context.modified { $0.step = Gherkin.Feature.Step(description: description, argument: nil) }
        } else if let description = description(for: [.and, .but], in: currentLine) {
            let isBackgroundStep = context.rule == nil && context.feature?.rules.isEmpty == true && context.feature?.background != nil
            guard (context.example?.steps.last ?? (isBackgroundStep ? context.feature?.background?.steps.last : nil)) != nil else { return nil }
            return context.modified { $0.step = Gherkin.Feature.Step(description: description, argument: nil) }
        }
        return nil
    }
}

private func description(for keyword: Gherkin.Keyword, in line: String) -> String? {
    guard line.hasPrefix(keyword.rawValue + " ") || line.hasPrefix(keyword.rawValue + ":") || line.hasPrefix(keyword.rawValue + "\n") else { return nil }
    return line
}

enum ParsingState {
    case start(Start)
    case feature(Feature)
    case background(Background)
    case rule(Rule)
    case example(Example)
    case step(Step)
    case argument(Argument)
    case error(Gherkin.ParsingError)
    case complete(Gherkin.Feature)
    
    init(gherkin: String) {
        let toParse = gherkin.split(separator: "\n")
            // Trim leading and trailing whitespace
            .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            // Filter out blank lines and comments
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        let context = ParsingContext(remainingToParse: Array(toParse), tags: nil, feature: nil, rule: nil, example: nil, step: nil)
        self = .start(Start(context: context))
    }
    
    /// Parsing state is at the beginning of the gherkin feature file. Valid operations are parsing comments, blank lines, tags for the feature, or the beginning of the feature itself
    struct Start {
        fileprivate var context: ParsingContext
        
        func parseTag() -> ParsingState? {
            return tags(in: context).flatMap { .start(Start(context: $0)) }
        }
        
        func parseFeature() -> ParsingState? {
            let hasFeature = context.feature != nil
            let feature = section(in: context, from: .feature){ context, description in
                context.feature = Gherkin.Feature(description: description, tags: context.tags, background: nil, rules: [])
                context.tags = nil
            }.flatMap { ParsingState.feature(Feature(context: $0)) }
            guard feature != nil else { return nil }
            guard hasFeature == false else { return .error(Gherkin.ParsingError("Cannot have multiple Features in a single Gherkin file")) }
            return feature
        }
    }
    
    
    /// Parsing state has reached a Feature keyword. Valid operations are parsing comments, blank lines, additional lines of feature description, tags, the background keyword, scenario keyword, scenario outline (or template) keyword, or rule keyword
    struct Feature {
        var context: ParsingContext
        
        func parseTag() -> ParsingState? {
            return tags(in: context).flatMap { .feature(Feature(context: $0)) }
        }
        
        func parseDescription() -> ParsingState? {
            return description(in: context) { context, description in
                let newDescription = ((context.feature?.description ?? "") + " " + description).trimmingCharacters(in: .whitespaces)
                context.feature?.description = newDescription
            }.flatMap { .feature(Feature(context: $0)) }
        }
        
        func parseBackground() -> ParsingState? {
            let hasBackground = context.feature?.background != nil
            let background = section(in: context, from: .background) { context, description in
                context.feature?.background = Gherkin.Feature.Background(description: description, steps: [])
            }.flatMap { ParsingState.background(Background(context: $0)) }
            guard background != nil else { return nil }
            guard hasBackground == false else { return .error(Gherkin.ParsingError("Cannot have more than one Background section in a single Gherkin feature"))}
            // If we have already parsed the first rule or example, then it's too late to parse a Background section and an error to have one
            guard context.feature?.rules.isEmpty == true && [context.rule as Any?, context.example, context.step].compactMap({ $0 }).isEmpty else { return .error(Gherkin.ParsingError("Cannot declare a Background section after the first Rule/Scenario/Example in a Gherkin feature")) }
            return background
        }
        
        func parseRule() -> ParsingState? {
            return section(in: context, from: .rule) {
                context, description in
                context.rule = Gherkin.Feature.Rule(tags: context.tags , description: description, examples: [])
                context.tags = nil
            }.flatMap { .rule(Rule(context: $0)) }
        }
        
        func parseExample() -> ParsingState? {
            // If we are not already parsing a Rule, then we are parsing a legacy-style Scenario.  We will create a container Rule for it and transition to an .example state within that placeholder Rule.
            return section(in: context, from: .example) {
                context, description in
                let example = ParsingContext.Example(tags: context.tags, description: description, steps: [], data: [])
                context.rule = Gherkin.Feature.Rule(tags: nil, description: nil, examples: [])
                context.example = example
                context.tags = nil
            }.flatMap { .example(Example(context: $0)) }
        }
        
        func parseComplete() -> ParsingState? {
            if let feature = context.feature, context.remainingToParse.count == 0 {
                return .complete(feature)
            }
            return nil
        }
        
    }
    
    struct Background {
        var context: ParsingContext
        
        func parseDescription() -> ParsingState? {
            return description(in: context) { context, description in
                let newDescription = ((context.feature?.background?.description ?? "") + " " + description).trimmingCharacters(in: .whitespaces)
                context.feature?.background?.description = newDescription
            }.flatMap { .background(Background(context: $0)) }
        }
        
        func parseStep() -> ParsingState? {
            return nextStep(in: context).flatMap {
                let hasGivenPrefix = $0.step?.description.lowercased().hasPrefix(Gherkin.Keyword.given.rawValue.lowercased()) == true
                let hasAndOrButPrefix = ($0.step?.description.lowercased().hasPrefix(Gherkin.Keyword.and.rawValue.lowercased()) == true
                    || $0.step?.description.lowercased().hasPrefix(Gherkin.Keyword.but.rawValue.lowercased()) == true)
                    && $0.feature?.background?.steps.first?.description.lowercased().hasPrefix(Gherkin.Keyword.given.rawValue.lowercased()) == true
                
                return  hasGivenPrefix || hasAndOrButPrefix ? .step(Step(context: $0)) : .error(.init("Background steps can only consist of Givens"))
            }
        }
        
        func parseComplete() -> ParsingState? {
            guard context.feature?.background != nil else { return nil }
            guard context.feature?.background?.steps.count ?? 0 > 0 else { return .error(.init("A Background section must have at least one step")) }
            return .feature(Feature(context: context))
        }
    }
    
    struct Rule {
        var context: ParsingContext
        
        func parseTag() -> ParsingState? {
            return tags(in: context).flatMap { .rule(Rule(context: $0)) }
        }
        
        func parseDescription() -> ParsingState? {
            return description(in: context) { context, description in
                let newDescription = ((context.rule?.description ?? "") + " " + description).trimmingCharacters(in: .whitespaces)
                context.rule?.description = newDescription
            }.flatMap { .rule(Rule(context: $0)) }
        }
        
        func parseExample() -> ParsingState? {
            return section(in: context, from: .example) {
                context, description in
                context.example = ParsingContext.Example(tags: context.tags, description: description, steps: [], data: [])
                context.tags = nil
            }.flatMap { .example(Example(context: $0)) }
        }
        
        func parseComplete() -> ParsingState? {
            var context = self.context
            context.rule.flatMap{ context.feature?.rules.append($0) }
            return .feature(Feature(context: context))
        }
    }
    
    struct Example {
        var context: ParsingContext
        
        func parseTag() -> ParsingState? {
            return tags(in: context).flatMap { .example(Example(context: $0)) }
        }
        
        func parseDescription() -> ParsingState? {
            return description(in: context) { context, description in
                let newDescription = ((context.example?.description ?? "") + " " + description).trimmingCharacters(in: .whitespaces)
                context.example?.description = newDescription
            }.flatMap { .example(Example(context: $0)) }
        }
        
        func parseStep() -> ParsingState? {
            return nextStep(in: context).flatMap { .step(Step(context: $0)) }
        }
        
        func parseData() -> ParsingState? {
            var error: Gherkin.ParsingError?
            var data = section(in: context, from: .data) {
                context, description in
                context.example?.data.append(.init(tags: context.tags, rows: []))
                context.tags = nil
            }
            data = data ?? context.remainingToParse.first.flatMap {
                currentLine in
                guard currentLine.hasPrefix("|") == true else { return nil }
                let row = currentLine.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                return context.modified {
                    context in
                    guard var currentData = context.example?.data.popLast(), row.isEmpty == false else {
                        error = .init("Error parsing Example Data")
                        return
                    }
                    currentData.rows.append(row)
                    context.example?.data.append(currentData)
                }
            }
            return data.flatMap { return error.flatMap{ .error($0) } ?? .example(Example(context: $0)) }
        }
        
        func parseComplete() -> ParsingState? {
            var context = self.context
            guard let example = context.example else { return nil }
            // If we have empty Data, then this isn't a template-style Example.  Just create a single Example and add it to the Rule.
            guard !example.data.isEmpty else {
                context.rule?.examples.append(.init(tags: example.tags, description: example.description, steps: example.steps))
                context.example = nil
                return .rule(Rule(context: context))
            }
            
            let string = ([example.description] + example.steps.map({ $0.description }) + example.steps.map({
                (step) -> String in
                switch step.argument {
                case .some(.dataTable(let table)):
                    return table.rows.map({ $0.joined(separator: " ")}).joined(separator: " ")
                case .some(.docString(let string)):
                    return string
                case .none:
                    return ""
                }
            })).joined(separator: " ")
            
            let regex = try! NSRegularExpression(pattern: "<.*?>", options: [])
            let matches = regex.matches(in: string, options: [], range: NSMakeRange(0, string.count)).map { match in
                return String(string[Range(match.range, in: string)!])
            }
            let uniqueTokenCount = Set(matches).count
            guard example.data.reduce(true, { return $1.rows.reduce(true, { return $1.count == uniqueTokenCount ? $0 : false }) }) else {
                return .error(.init("Data values must be provided for all \(uniqueTokenCount) different tokens that were specified in the Example, and there should be no additional data values"))
            }
            
            example.data.forEach {
                data in
                guard let headers = data.rows.first, data.rows.count > 1 else { return }
                let rows = Array(data.rows.dropFirst())
                let substitutions = rows.map {
                    return Dictionary(uniqueKeysWithValues: $0.enumerated().map { (headers[$0.offset], $0.element) })
                }
                let examples: [Gherkin.Feature.Example] = substitutions.map {
                    var description = example.description
                    var steps = example.steps
                    $0.forEach {
                        key, value in
                        description = description.replacingOccurrences(of: "<" + key + ">", with: value)
                        steps = steps.map { return Gherkin.Feature.Step(description: $0.description.replacingOccurrences(of: "<" + key + ">", with: value), argument: $0.argument.map {
                            switch $0 {
                            case .dataTable(let dataTable):
                                return .dataTable(Gherkin.Feature.Step.DataTable(rows: dataTable.rows.map { $0.map { $0.replacingOccurrences(of: "<" + key + ">", with: value) } }))
                            case .docString(let string):
                                return .docString(string.replacingOccurrences(of: "<" + key + ">", with: value))
                            }
                        })
                        }
                    }
                    return Gherkin.Feature.Example(tags: data.tags + example.tags, description: description, steps: steps)
                }
                context.rule?.examples.append(contentsOf: examples)
            }
            context.example = nil
            return .rule(Rule(context: context))
        }
    }
    
    
    struct Step {
        var context: ParsingContext
        
        func parseArgument() -> ParsingState? {
            return context.remainingToParse.first.flatMap {
                currentLine in
                if currentLine == "\"\"\"" {
                    return .argument(Argument(context: context.modified {
                        $0.step?.argument = .docString("")
                    }))
                }
                let row = currentLine.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                return row.count <= 1 ? nil : .argument(Argument(context: context.modified {
                    let dataTable = Gherkin.Feature.Step.DataTable(rows: [row])
                    $0.step?.argument = .dataTable(dataTable)
                }))
            }
        }
        
        func parseComplete() -> ParsingState? {
            var context = self.context
            guard let step = context.step else { return nil }
            // If we are in the middle of parsing a background, add the step to the background, otherwise add it to the currently being parsed example
            let isBackgroundStep = context.feature?.background != nil && context.feature?.rules.isEmpty == true && context.rule == nil
            if isBackgroundStep {
                context.feature?.background?.steps.append(step)
            } else {
                context.example?.steps.append(step)
            }
            context.step = nil
            return isBackgroundStep ? .background(Background(context: context)) : .example(Example(context: context))
        }
    }
    
    struct Argument {
        var context: ParsingContext
        
        func parseArgument() -> ParsingState? {
            return context.remainingToParse.first.flatMap {
                currentLine in
                switch context.step?.argument {
                case .some(.docString(let docString)):
                    return currentLine == "\"\"\"" ? .step(Step(context: context.modified())) : .argument(Argument(context: context.modified {
                        $0.step?.argument = .docString(docString + currentLine)
                    }))
                case .some(.dataTable(let dataTable)):
                    let row = currentLine.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    return row.isEmpty || row.first == currentLine ? nil : .argument(Argument(context: context.modified {
                        let dataTable = Gherkin.Feature.Step.DataTable(rows: dataTable.rows + [row])
                        $0.step?.argument = .dataTable(dataTable)
                    }))
                default:
                    return nil
                }
            }
        }
        
        func parseComplete() -> ParsingState? {
            if case .some(.dataTable(let table)) = context.step?.argument {
                guard let first = table.rows.first else { return .error(.init("Can't have a data table argument with no rows")) }
                let equalCounts = table.rows.reduce(true) { return $1.count == first.count ? $0 : false }
                return equalCounts ? .step(Step(context: context)) : .error(.init("Data table arguments should have the same number of elements per row"))
            }
            return .step(Step(context: context))
        }
    }
    
    
    struct ParsingContext {
        var remainingToParse: [String]
        var tags: [String]? {
            didSet {
                let unique = tags.flatMap { Array(Set($0)) }
                tags = unique?.isEmpty == false ? unique : nil
            }
        }
        var feature: Gherkin.Feature?
        var rule: Gherkin.Feature.Rule?
        var example: Example?
        var step: Gherkin.Feature.Step?
        
        func modified(by closure: ((inout ParsingContext) -> ())? = nil) -> ParsingContext {
            var context = self
            context.remainingToParse = Array(context.remainingToParse.dropFirst())
            closure?(&context)
            return context
        }
        
        struct Example {
            var tags: [String]?
            var description: String
            var steps: [Gherkin.Feature.Step]
            var data: [Data]
            
            struct Data {
                var tags: [String]?
                var rows: [[String]]
            }
        }
    }
    
}

// Combine arrays with optional arrays
internal func +<T>(left: [T]?, right: [T]?) -> [T]? {
    switch (left, right) {
    case (.some(let left), .some(let right)): return left + right
    case (.some(let left), .none): return left
    case (.none, .some(let right)): return right
    case (.none, .none): return nil
    }
}
