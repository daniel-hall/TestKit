Feature: Example

Scenario: Login button is disabled when username and password are empty
Given I launch the app
When I tap the Start button
Then the login button is disabled
And the login button color is light gray

Scenario: Typing text in the username and password field enables the login button
When I enter the username testuser
And I enter the password password123
Then the login button is enabled
And the login button color is green

Scenario: Logging into the app arrives at the welcome screen
Given I launch the app
When I tap the Start button
And I log in as user testuser with password password123
Then I am on the Welcome screen

Scenario: When not yet logged in, the isLoggedIn value is false
Given I launch the app
When I tap the Start button
Then isLoggedIn is false

Scenario: After login, the isLoggedIn value is true
When I log in as user testuser with password password123
Then isLoggedIn is true

Scenario: After logging out, the isLoggedIn value is false again
When I tap the Log Out button
Then isLoggedIn is false
