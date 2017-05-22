Feature: Example Unit Tests
Scenario Outline: The validatePassword function passes unit tests
Given the unit test input is <input>
When I call the function validatePassword
Then the unit test output is <output>

Examples:
|input|output|
|sfgh234sdfj|false|
|aAbBcC99|true|
