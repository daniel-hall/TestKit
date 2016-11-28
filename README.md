# TestKit
TestKit is a lightweight library that separates unit test input and expected output from actual unit test code, allowing many different inputs and expected outputs to be specified in an external JSON file, and expanded to include edge cases and failure cases without needing to write additional code or tests.

### Overview 

While "code coverage" requirements can be fulfilled by single and even useless unit tests, this doesn't actually result in well-tested code. [See my blog post regarding this](http://www.danielhall.io/code-coverage-is-a-terrible-metric)

Good unit tests should meet the following criteria:

1. They shouldn't mirror implementation details of the function under test, but rather should simply compare an expected result to the output from the function under test, given a specific input. This kind of "dumb" unit test allows the actual function to be refactored or changed at any time without needing to also rewrite the tests. In fact, this kind of test will _help_ you refactor functions safely by validating that they still produce the same expected results given the same inputs.
2. They should test not only the expected "happy path" cases, but a variety of valid cases, invalid cases, error cases, and edge cases.  In fact, a much better metric than code coverage is how many of each of these types of cases are being tested for your functions.
3. They should be updated any time a new edge case or bug condition is found to ensure that any future refactors or changes will not cause the function to fail again in the same way.

Most developers want to meet these criteria, but find it hard to write clean "dumb tests", find it burdensome and repetitive to write new test methods for every type of case or input that should be tested, and similarly can find it time-consuming to go back and add new unit tests when bugs are found.

TestKit makes things much better by:

1. Defining a clear unit test structure that simplifies and templates the writing of "dumb tests"
2. Separating the input values, and expected output values from the actual code and moving them into an external data file that can be updated by anyone without writing more code
3. Making it so that the often-repeated code that checks the properties of an actual output against the properties of an _expected_ output is only written one time, and is reused for all validation thereafter.

#### Example 

Let's say we have written a function with the signature `analyze(sentence:String) throws -> SentenceAnalysis` that takes a sentence, analyzes it, and returns a struct of the type `SentenceAnalysis` which contains the subject of the sentence, the action of the sentence, and average number of syllables per word in the sentence. This function can also throw a `SentenceAnalysisError` if it can't understand the input, or if the input is missing a subject or a verb.  Here is a what a small sampling of the unit tests that should be written would look like when written in the typical fashion:

```swift
class AnalyzeSentenceTests: XCTestCase {
    
    func testCatSentencePastTense() {
        let result = try? analyze(sentence: "The cat jumped on the sofa")
        XCTAssertEqual(result?.subject, "cat")
        XCTAssertEqual(result?.action, "jump")
    }
    
    func testCatSentencePresentTense() {
        let result = try? analyze(sentence: "The cat is jumping on the sofa")
        XCTAssertEqual(result?.subject, "cat")
        XCTAssertEqual(result?.action, "jump")
    }
    
    func testCatSentenceFutureTense() {
        let result = try? analyze(sentence: "The cat will jump onto the sofa")
        XCTAssertEqual(result?.subject, "cat")
        XCTAssertEqual(result?.action, "jump")
    }
    
    func testSentenceWithAdjectives() {
        let expectedResult = SentenceAnalysis(subject: "bikini", action: "dry", averageSyllablesPerWord: 2.18)
        let result = try? analyze(sentence: "The itsy-bitsy teeny-weeny yellow polkadot bikini was drying on the clothesline")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, expectedResult)
    }
    
    func testComplexVerb() {
        let expectedResult = SentenceAnalysis(subject: "we", action: "like", averageSyllablesPerWord: 1.14)
        let result = try? analyze(sentence: "We all would have liked more presents")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, expectedResult)
    }
    
    func testMissingSubject() {
        do {
            let _ = try analyze(sentence: "in the pantry")
            XCTFail("The sentence should have thrown an error")
        } catch {
            guard let error = error as? SentenceAnalysisError else {
                XCTFail("Got the wrong kind of error")
                return
            }
            XCTAssertEqual(error.type, SentenceAnalysisError.ErrorType.NoSubject)
        }
    }
    
    func testAnotherMissingSubjectExample() {
        do {
            let _ = try analyze(sentence: "can be twelve")
            XCTFail("The sentence should have thrown an error")
        } catch {
            guard let error = error as? SentenceAnalysisError else {
                XCTFail("Got the wrong kind of error")
                return
            }
            XCTAssertEqual(error.type, SentenceAnalysisError.ErrorType.NoSubject)
        }
    }
    
    func testMissingVerb() {
        do {
            let _ = try analyze(sentence: "The balloon good")
            XCTFail("The sentence should have thrown an error")
        } catch {
            guard let error = error as? SentenceAnalysisError else {
                XCTFail("Got the wrong kind of error")
                return
            }
            XCTAssertEqual(error.type, SentenceAnalysisError.ErrorType.NoVerb)
        }
    }
    
    func testAnotherMissingVerbExample() {
        do {
            let _ = try analyze(sentence: "Dog mans best friend")
            XCTFail("The sentence should have thrown an error")
        } catch {
            guard let error = error as? SentenceAnalysisError else {
                XCTFail("Got the wrong kind of error")
                return
            }
            XCTAssertEqual(error.type, SentenceAnalysisError.ErrorType.NoVerb)
        }
    }
}
```



That's about a hundred lines of code, for just a small subset of the tests that should be written.  The same test class using TestKit would look like this:



```swift
class AnalyzeSentenceTests: XCTestCase {
    func testAnalyze() {
        let spec = TestKitSpec.init(file: "AnalyzeSentence") { XCTFail($0.message) }
        spec.run(){
            (input:String) throws -> SentenceAnalysis in
            return try analyze(sentence: input)
        }
    }
}
```



And this test code would use the following TestKit JSON spec to achieve exactly the same results as the hundred lines of manual test code:



```json
{
	"test-description": "Test Cases for the method analyze(sentence:)",
	"test-cases": [
	{
		"name" : "Cat Conjugations",
		"inputs" : ["The cat jumped on the sofa", "The cat is jumping on the sofa", "The cat will jump onto the sofa"],
		"expected-output" : {"subject": "cat", "action": "jump"}
	},
	{
		"name" : "Adjectives",
		"inputs" : "The itsy-bitsy teeny-weeny yellow polkadot bikini was drying on the clothesline",
		"expected-output" : { "subject": "bikini", "action": "dry", "average-syllables": 2.18 }
	},
	{
		"name" : "Complex Verb",
		"inputs" : "We all would have liked more presents",
		"expected-output" : { "subject": "we", "action": "like", "average-syllables": 1.14 }
	},
	{
		"name" : "Missing Subjects",
		"inputs" : ["in the pantry", "can be twelve"],
		"expect-error" : true
		"expected-output" : { "type": "NoSubject" }
	},
	{
		"name" : "Missing Verbs",
		"inputs" : ["The balloon good", "Dog man's best friend"],
		"expect-error" : true
		"expected-output" : { "type": "NoVerb" }
	}
]
}
```



As you can see form this example, TestKit did the following:

- Eliminated the repetitive and boilerplate test code, and greatly reduced the total lines of code written across the boards, while still testing all the same cases
- Made the test data much more readable and clear by structuring it and labeling simply as `name`, `inputs` and `expected-output`.  This can easily be scanned, read and understood by anyone, including developers and QA team members who don't write Swift, business analysts, etc.
- Made it very very easy to add additional cases, or additional inputs to existing cases.  In fact, because it's so easy to do and doesn't require writing new code, TestKit actually encourages and rewards the addition of lots of new test inputs and cases.  And this makes your actual test coverage much much better.
- Because the actual inputs and expected outputs for these tests are captured in a JSON file, the majority of unit test content can be shared across platforms, for example with Android or web client apps. If the small TestKit library itself is ported to these other platforms, the test cases can be shared and reused across all platforms, and updated in a central repository by developers and QA working on any one of the platforms.  



### Installation

To install TestKit, simply copy the file `TestKit.swift` into your unit test target(s).  You don't need to and should _not_ include TestKit in your actual application code. It is only needed and relevant in the test bundle where your unit tests live.



### Quick Start

1. Copy the `TestKit.swift` file into your project's unit test bundle.

2. In your project, add the following example function:

   ```swift
   func isValidPassword(string:String) -> Bool {
       let hasValidLength = string.characters.count >= 8 && string.characters.count <= 16
       let isASCIIOnly = string.canBeConverted(to: String.Encoding.ascii)
       let containsNumber = string.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
       let containsLowercase = string.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
       let containsUppercase = string.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
       return hasValidLength && isASCIIOnly && containsNumber && containsLowercase && containsUppercase
   }
   ```

3. Create an empty file in your test bundle, name it `IsValidPassword.testkit` and copy/paste the following JSON into the file:

   ```json
   {
   "test-description": "Test cases to verify password validation logic",
   "test-cases": [
   	{
   		"name" : "Valid Passwords",
   		"inputs" : ["1sdfD8sFlk", "Happy763!"],
   		"expected-output" : true
   	},
   	{
   		"name" : "Valid: Min and Max Length",
   		"inputs" : ["Snd6HHus", "sDG$34DdfsfFs8aa"],
   		"expected-output" : true
   	},
   	{
   		"name" : "Invalid: One Below and One Above Allowed Length",
   		"inputs" : ["Snd6HHu", "sDG$34DdfsfFs8aa1"],
   		"expected-output" : false
   	},
   	{
   		"name" : "Invalid: Too Short",
   		"inputs" : ["", "Ask87d"],
   		"expected-output" : false
   	},
   	{
   		"name" : "Invalid: Too Long",
   		"inputs" : "Asdhalkjd234FSfdjflksj@fsffShkjdkjs5sdfkjh34",
   		"expected-output" : false
   	},
   	{
   		"name" : "Invalid: Non-ASCII",
   		"inputs" : ["WeirdThing77™", "Asd54Fsd!😀"],
   		"expected-output" : false
   	},
   	{
   		"name" : "Invalid: No Number",
   		"inputs" : "SfsdfEeEEff!",
   		"expected-output" : false
   	},
   	{
   		"name" : "Invalid: No Lowercase",
   		"inputs" : "ONLYC8PITALS!",
   		"expected-output" : false
   	},
   	{
   		"name" : "Invalid: No Uppercase",
   		"inputs" : "lowercase4thewin",
   		"expected-output" : false
   	}
   ]
   }
   ```

4. Somewhere in your test target, either in a `TestKitExtensions.swift` file, or in one of your `XCTestCase` subclass files, add the following extension to `Bool`, which tells TestKit how to validate a Bool value against an expected value from the JSON file:

   ```swift
   extension Bool : TestableOutput {
       typealias ExpectedOutputType = Bool
       func validate(expected output: Bool) -> Bool {
           return self == output
       }
   }
   ```

5. Add the following test method to on of the XCTest files in your test bundle. This code loads the test spec from the `IsValidPassword.testkit` file, provides a handler for XCTest failures, and then runs the spec with a closure that passes the each input from the test spec to the `isValidPassword` function in your project, and returns the output from that function for validation:

   ```swift
   func testIsValidPassword() {
           let spec = TestKitSpec.init(file: "IsValidPassword") { XCTFail($0.message) }
           spec.run(){
               (input:String) -> Bool in
               return isValidPassword(string: input)
           }
       }
   ```

6. Run the test method.  Note that it passes, but also check the console log where TestKit has output detailed information on the different cases that were run, and the status of each input that was verified. You've successfully set up TestKit and a verified a fairly detailed test spec, with 9 test cases and 13 different inputs! Note that adding additional cases or inputs to test in the future only requires adding them to the `IsValidPassword.testkit` JSON file. You or your QA team can add dozens of additional valid, invalid, or edge cases without having to modify any actual test code or application code.

### TestKit JSON Schema

Every TestKit test spec is described by a JSON file that gets loaded from the test bundle. This file must have the extension `.testkit` and conform to the following schema:

- The root element of the file is a dictionary.  The dictionary has 1 required and one optional key:
  - `test-description` (String, Optional):  A description of this test specification, which is helpful for people who are reading the json file and want to understand what the spec is intended to test.
  - `test-cases` (Array, Required): The `test-cases` key must contain an array of dictionaries, each one representing a test case that should be verified. Each test case dictionary, should contain a combination of the following required and optional key-value pairs:
    - `name` (String, Required): The name of this test case.  Should describe what types of inputs are being tested, e.g. "Large Strings", "Invalid Values", "Legacy Account With Old Style ID", etc.
    - `description` (String, Optional): A more detailed description of this test case, possibly containing information about what types of inputs are being selected, etc. Used as needed to make the test spec more readable on its own.
    - `Inputs` (Any valid JSON value including `null`, Required): One or more values that will be passed into the unit test to generate a verifiable output. If a single value is specified, then the case will test a single input and verify it against a single output. If any array of values in passed in, then each value in the array will be passed into the unit test, and each value will be expected to generate the same expected output.  For example, in a unit test that exercises a method that accepts a password string and returns a Boolean representing whether the password in valid or not, a test case for "Valid Passwords" may have 20 different examples of input that should all result in a result of true from the method under test.  Thus, these would be represented as an array of strings under the "inputs" key, and they would all have the same `expected-output`, specified a single time as the Boolean value `true`
    - `expect-error` (Bool, Optional): A boolean (`true` or `false`) which indicates that the given input(s) are expected to result in a thrown error, and not a successful result. Omitting this key is the same as setting it to `false` (the default)
    - `expected-output` (Any valid JSON value including `nul`, Optional if `expect-error` == `true` otherwise Required):  A representation of what the test closure is expected to produce as output, given the specified input(s).  This `expected-output` will be passed into the `validate(expected:)` method on whatever `TestableOutput`-conforming value is returned from the test closure inside the actual unit test. In the case that `expect-error == true`, this can either be left empty to match _any_ error, or it can be a dictionary value and the error thrown inside the test closure will be expected to conform to `TestableError` and will have the protocol method `validate(expected:)` called on it with the dictionary passed in to validate that the error thrown matches the expected error.



### API Overview



#### TestKitSpec

The primary API in TestKit is the `TestKitSpec` struct.  Your unit test will initialize an instance of this type from a file in your test bundle.  The file must be json that follows the TestKit json schema.

- You initialize a `TestKitSpec` by calling `TestKitSpec(file:failureHandler:)`.  The `file` parameter expects the name of your `.testkit` JSON file, and the `failureHandler` parameter expects a closure of type `(TestKitFailure)->()`.  Any failures encountered while running the spec will be passed to this closure, which typically should call `XCTFail($0.message)` at a minimum.  However, the closure can also examine additional information about the failure and either print it to the console, or make decisions regarding continuing the test or not.

- Once you have an initialized `TestKitSpec`, you then call its `run(testClosure:)` method to execute the spec using a provided closure.  The test closure has a very simply responsibility: it takes the input it is provided by TestKit, runs the function that is to be tested using that input, and returns the output from that function.  This is usually a single line of code.  For example, a test closure that is testing a function defined as `parseInt(from json:[String: Any]) -> Int ` would look like this:

  ```swift
          spec.run(testClosure:{
              (input:[String:Any]) -> Int in
              return parseInt(from: input)
          })
  ```

- There are four overloads of the `run(testClosure:)` method, each one handles a slightly different type of test closure:

  - (Input) -> Output — For testing functions that take an input and always return an output, with no error thrown
  - (Input) -> Output? — For testing functions that return an optional result, and which may have an `expected-output` of `null` (nil) defined in its TestKit spec file.
  - (Input) throws -> Output — For testing functions that return a non-optional, never-nil result, but which may also throw an error. This type of test closure is required when a TestKit spec expects and validates an error
  - (Input) throws -> Output? — For testing functions that return a optional, possibly nil result, but which may also throw an error. This type of test closure is required when a TestKit spec expects and validates an error and may also have an `expected-output` of `nill` (nil)



#### TestableOutput

This is a protocol that has an associated type called `ExpectedOutputType` and a single method: `func validate(expected output: ExpectedOutputType) -> Bool`.  In order to test the output from one of your application's functions, you need to declare an extension in your test bundle that conforms your function's output type to the `TestableOutput` protocol.  For example, if your application has a type called `Person` defined as follows:

```swift
struct Person {
  let firstName: String
  let lastName: String
  let age: Int
}
```

Then in order to validate this type of output against expected output in the TestKit spec, you would need to write an extension like this:

```swift
extension Person: TestableOutput {
  typealias ExpectedOutputType = TestKitDictionary
  func validate(expected output: ExpectedOutputType) -> Bool {
    guard let firstName = output["first-name"] as? String, let lastName = output["last-name"] as? String, let age = output["age"] as? Int else {
      print("Could not find all needed values in the expected output dictionary")
      return false
    }
    return self.firstName == firstName && self.lastName == lastName && self.age == age
  }
}
```

This extension adds a method on any instance of `Person` that can take a dictionary of expected output from TestKit, and verify its own properties against the keys defined in the TestKit expected output dictionary.

With the above extension declared, your TestKit specs can know specify expected output for Person values as follows:

```json
"expected-output" : { "first-name":"Jo", "last-name":"Schmo", "age":30 }
```



> Important Note: For simple JSON types like String, Bool, or a Number, you can define the ExpectedOutputType to be a Swift primitive like String, Bool, Int, Float, etc.  and you can validate directly against that value, e.g. `return self == output`. For any complex type, where you have to define multiple properties for the expected output as a JSON dictionary, the ExpectedOutputType must always be `TestKitDictionary`.  You can access values for keys on this type just like a normal Swift dictionary, but it has an extra feature: if you don't examine / retrieve ALL of its keys during validation, it will create a test failure, because validation can't be guaranteed if all the expected output key-values weren't considered.



#### TestableError

A protocol that your `Error` types must conform to if you want to validate them against expected ouput.  For example, if your application has a function that can throw a `ParsingError` which is defined like this:

```swift
struct ParsingError: Error {
  enum ParsingErrorType: String {
    case WrongType, MissingKey
  }
  let type: ParsingErrorType
  let message: String
}
```

You can set up you TestKit specs to validate that the correct error is thrown like this:

```json
{
	"test-description": "Test Throwing Error",
	"test-cases": [
	{
		"name" : "Valid",
		"inputs" : {"test-key" : 50},
		"expected-output" : 50
	},
	{
		"name" : "Missing Key Error",
		"inputs" : {"other-key" : "something"},
		"expect-error" : true,
		"expected-output" : { "type": "MissingKey"}
	},
	{
		"name" : "Wrong Type Error",
		"inputs" : {"test-key" : "something"},
		"expect-error" : true,
		"expected-output" : { "type": "WrongType"}
	}
	]
}
```

In order to validate these expected errors, you must write an extension in your test bundle that conforms `ParsingError` to the `TestableError` protocol, like this:

```swift
extension ParsingError: TestableError {
    func validate(expected output: TestKitDictionary) -> Bool {
        guard let type = output["type"] as? String, let typeEnum = ParsingError.ParsingErrorType.init(rawValue: type) else {
            return false
        }
        return self.type == typeEnum
    }
}
```



#### TestKitFailure

The failure handling closure that you pass into a `TestKitSpec` upon intialization will receive a `TestKitFailure` instance any time a test case or input fails for any reason.  The `TestKitFailure` instance contains various properties that describe the state of the test at the point of failure.  The most important property is `message`, which described that the cause of the failure was.  This message is typically passed directly to `XCTFail()` inside the failure handling closure.



#### TestKitCase

You will not need to interact directly with `TestKitCase`, but the current `TestKitCase` is provided inside a `TestKitFailure` instance, in the event that you want to introspect further into the details of the failing case or print additional information about it.



#### TestKitDictionary

Any time one of your TestKit cases has `expected-output` in the form of a JSON dictionary, that dictionary will be converted into a TestKitDictionary instance. This will be passed into the `validate(expected output:)` method of any `TestableOutput` conforming value, or the `validate(expected output:)` method of a `TestableError`. Inside your validation method, you interact with a `TestKitDictionary` by accessing its values through subscripting, just like a normal Swift dictionary. However, `TestKitDictionary` has one additional feature, which is that it will trigger an test failure if your validation method fails to check every key that was specificed in the `expected-output` field of the JSON spec.



### Troubleshooting

If you encounter any difficulties or bugs using TestKit, please feel free to open an issue in this GitHub project, or email me directly.  I will also maintain a list of common issues here:

- When calling `TestKitSpec.run()` and passing in a test closure, if you are seeing the Swift compiler give  an error saying that you can't call the run() function with your closure's type as a parameter, it is most likely that you forgot to make the output of your closure conform to `TestableOutput`.  For example, even if your function under test returns a simple String value, you need to ensure that you define something like this somewhere in your test bundle:

  ```swift
  extension String: TestableOutput {
    typealias ExpectedOutputType = String
    func validate(expected output: String) -> Bool {
      return self == output
    }
  }
  ```

  ​