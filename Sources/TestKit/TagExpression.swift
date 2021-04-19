//
//  TagExpression.swift
//  TestKit
//
//  Created by Hall, Daniel on 7/12/19.
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


public indirect enum TagExpression {
    case tag(String)
    case not(String)
    case orTag(TagExpression, String)
    case andTag(TagExpression, String)
    case orNotTag(TagExpression, String)
    case andNotTag(TagExpression, String)
    case orExpression(TagExpression, TagExpression)
    case andExpression(TagExpression, TagExpression)
    case orNotExpression(TagExpression, TagExpression)
    case andNotExpression(TagExpression, TagExpression)
    
    public func or(_ string: String) -> TagExpression {
        return .orTag(self, string)
    }
    
    public func and(_ string: String) -> TagExpression {
        return .andTag(self, string)
    }
    
    public func orNot(_ string: String) -> TagExpression {
        return .orNotTag(self, string)
    }
    
    public func andNot(_ string: String) -> TagExpression {
        return .andNotTag(self, string)
    }
    
    public func or(_ expression: TagExpression) -> TagExpression {
        return .orExpression(self, expression)
    }
    
    public func and(_ expression: TagExpression) -> TagExpression {
        return .andExpression(self, expression)
    }
    
    public func orNot(_ expression: TagExpression) -> TagExpression {
        return .orNotExpression(self, expression)
    }
    
    public func andNot(_ expression: TagExpression) -> TagExpression {
        return .andNotExpression(self, expression)
    }
    
    private enum MatchResult {
        case success
        case notIncluded
        case excluded
        case notIncludedAndExcluded
        case failure
    }
    
    private func matchResult(_ tags: [String]) -> MatchResult {
        switch self {
            
        case .tag(let string):
            return tags.contains(string) ? .success : .notIncluded
            
        case .not(let string):
            return !tags.contains(string) ? .success : .excluded
            
        case .andTag(let expression, let string):
            switch expression.matchResult(tags) {
            case .success: return tags.contains(string) ? .success : .notIncluded
            case .excluded: return tags.contains(string) ? .excluded : .notIncludedAndExcluded
            case .notIncluded: return .notIncluded
            case .notIncludedAndExcluded: return .notIncludedAndExcluded
            case .failure: return .failure
            }
            
        case .orTag(let expression, let string):
            switch expression.matchResult(tags) {
            case .success: return .success
            case .excluded: return tags.contains(string) ? .excluded : .notIncludedAndExcluded
            case .notIncluded: return tags.contains(string) ? .success : .notIncluded
            case .notIncludedAndExcluded: return tags.contains(string) ? .excluded : .notIncludedAndExcluded
            case .failure: return .failure
            }
            
        case .orNotTag(let expression, let string):
            switch expression.matchResult(tags) {
            case .success: return .success
            case .excluded: return !tags.contains(string) ? .success : .excluded
            case .notIncluded: return .notIncluded
            case .notIncludedAndExcluded: return !tags.contains(string) ? .notIncluded : .notIncludedAndExcluded
            case .failure: return .failure
            }
            
        case .andNotTag(let expression, let string):
            switch expression.matchResult(tags) {
            case .success: return !tags.contains(string) ? .success : .excluded
            case .excluded: return .excluded
            case .notIncluded: return !tags.contains(string) ? .notIncluded : .notIncludedAndExcluded
            case .notIncludedAndExcluded: return .notIncludedAndExcluded
            case .failure: return .failure
            }
            
        case .orExpression(let first, let second):
            return first.matchResult(tags) == .success || second.matchResult(tags) == .success ? .success : .failure
            
        case .andExpression(let first, let second):
            return first.matchResult(tags) == .success && second.matchResult(tags) == .success ? .success : .failure
            
        case .orNotExpression(let first, let second):
            return first.matchResult(tags) == .success || second.matchResult(tags) != .success ? .success : .failure
            
        case .andNotExpression(let first, let second):
            return first.matchResult(tags) == .success && second.matchResult(tags) == .success ? .success : .failure
        }
    }
    
    public func matches(_ tags: [String]?) -> Bool {
        return matchResult(tags ?? []) == .success
    }
    
    public func matches(_ tag: String) -> Bool {
        return matches([tag])
    }
}
