# Overview

TestKit has been upgraded to a full solution for implementing Behavior-Driven Development (BDD) in Swift iOS apps.  

In a nutshell, BDD means that anyone on your team (not just developers or technical people) can write a plain-English specification for a certain feature or behavior in  the app, and that specification will be executed and verified as an automated test by the TestKit framework. 

## Example

A developer receives the following requirement for refund behavior:

> Scenario: Refunds return money to user’s account
> Given I am a user named Mary Smith with a $20.00 balance on my account
> And I have previously purchased a $15.00 book
> When I navigate to my purchases page
> And request a refund on the book
> And the refund is approved
> Then I have a $35.00 balance on my account

This requirement can be copied and pasted into a .feature file inside the application’s test target. When the test target runs, TestKit will read and parse the scenario, and execute the steps, attempting to validate them. Developers create “hooks” or “step handlers” which connect the statements in the scenario to actual functionality in the app.  If there are step handlers missing for the scenario, the test will fail.  If the step handlers exist, but the requirements in the scenario are not validated by the test results, the test will fail.

This gives your team an easy path to some of the basic principles of test-driven development.  Specifically, the test is written and will run and fail before any coding starts.  When the code is written to meet the requirement, the test will pass and the task is done.

Step handlers are also written inside of your test target, not in your production code. Step handlers that use XCUITesting to simulation user input with the app like tapping buttons, swiping through a table, or navigating to different screens are added in the application’s UI test target.  Step handlers that read and set data inside the application directly, not through UI interactions, are added in the application normal (unit) test target.

An example of a step handler in TestKit for the above scenario could look this:

```
TestKit.given("I am a user named (?<userName>.*) with a $(?<dollarAmount>.*) balance on my account") {
   let userName: String = $0["userName"]
   let balance: Float = ($0["dollarAmount"] as NSString).floatValue
   let user = User(name: userName)
   user.currentBalance = balance
   User.setCurrentUser(to: user) 
}
```

This step handler would be defined in the unit test target for the application, and specifies a pattern to match in a scenario step, as well as code that runs when the pattern matches the currently executing step.  As you can see, it’s easy to capture dynamic values in the step description (like the user’s name and their balance) as named variables, and then reference those dynamic values in the code that runs for the step. 

The step handler for the step “When I navigate to my purchases page” would probably involve UI interaction and so would be defined in the UI test target, and might look something like this:

```
TestKit.when("I navigate to my purchases page") {
  let app = XCUIApplication()
  app.buttons["My Account"].tap()
  app.buttons["Purchases"].tap()
}
```

## More Examples

For more examples of how to write scenarios and step handlers, open and examine and run the code in the TestKitExampleProject that is part of this repo.  

# Installation

Add TestKit as a dependency for your test target only (not the actual app or framework target) using Swift Package Manager.

## Adding a Test Case

# Reference

## Gherkin Syntax

## Step Handler Pattern Matching Syntax

# Writing Unit Tests With TestKit

You may know that TestKit started as a unit testing framework which separated out test inputs and outputs into an external JSON file which could then be modified to add new test cases without writing additional code.  

The latest version of TestKit still adheres to this same principle and the same goals, but now uses a broad standard (Gherkin) instead of a custom JSON schema for defining the test inputs and outputs. In fact, not only are the .feature files of the new version of TestKit much more concise and easily readable than the old .testkit files, but the process of adding step handlers and the code needed to validate unit test output in Swift has also been simplified.  

The TestKitExample project includes an example of unit testing a function with multiple inputs and expected outputs, which can be used as a reference. The advantages of writing unit tests in this way, instead of completely in code are:

1. Unit tests can be described by tech leads or fellow developers as scenarios and immediately checked by TestKit. Developers often aren’t sure _what_ unit tests to write, and TestKit allows the actual requirements for a function which describe happy path cases, edge cases, failure cases, etc. to be provided by QA,  developers or tech leads and run directly as the tests.

2. New test cases, inputs and expected outputs can be added in plain English at any time without needing to touch actual code.  

3. Because Gherkin is a standard already used by testing tools on most platforms (like Cucumber, which is available for many platforms and languages), unit tests written with TestKit can be shared across platforms and used to ensure that the same logic is implemented for any given function on Web, Android, iOS, etc.   

4. Writing unit tests in Gherkin with TestKit documents the expectations and requirements for your functions and business logic in plain English, is always up-to-date by definition (because out of date documentation == a failing test), and clearly described edge cases and examples of how the code is expected to work.