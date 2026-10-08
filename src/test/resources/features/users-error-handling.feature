@user @isolated
Feature: Users api error handling tests
  Every scenario starts from (and leaves behind) an empty user store, so each one sets up its own data.

  Background:
    Given http baseUri is /api/
    And I set Accept-Language http header to en-US
    And I set http headers to:
      | Accept        | application/json  |
      | Content-Type  | application/json  |

  # HEAD /api/authenticated
  Scenario: Unauthenticated HEAD request does not echo an Authorization header
    When I HEAD /authenticated
    Then http response code should be 401
    And http response header Authorization should not exist

  # POST /api/users
  Scenario: Creating a user with an already existing id is rejected
    Given I set http body to {"id":"100","firstName":"Peter","lastName":"Parker","age":22}
    And I POST /users
    And http response code should be 201
    When I set http body to {"id":"100","firstName":"Miles","lastName":"Morales","age":17}
    And I POST /users
    Then http response code should be 400
    When I GET /users
    Then http response body is typed as array using path $ with length 1
    And http response body path $.[0].firstName should be Peter

  Scenario: Creating a user with a non numeric age is rejected
    Given I set http body to {"id":"101","firstName":"Peter","lastName":"Parker","age":"twenty-two"}
    When I POST /users
    Then http response code should be 400
    When I GET /users
    Then http response body is typed as array using path $ with length 0

  # GET /api/users/{id}
  Scenario: Getting a user fails when the third party details api returns a server error
    Given I set http body to {"id":"102","firstName":"Peter","lastName":"Parker","age":22}
    And I POST /users
    And http response code should be 201
    And I mock third party api call GET /public/characters/102 with return code 500, content type: application/json and body: {"error": "internal"}
    When I GET /users/102
    Then http response code should be 400

  Scenario: Getting a user fails when the third party details api does not know the user
    Given I set http body to {"id":"103","firstName":"Peter","lastName":"Parker","age":22}
    And I POST /users
    And http response code should be 201
    And I mock third party api call GET /public/characters/103 with return code 404, content type: application/json and body: {}
    When I GET /users/103
    Then http response code should be 400

  Scenario: A deleted user can no longer be retrieved
    Given I set http body to {"id":"104","firstName":"Peter","lastName":"Parker","age":22}
    And I POST /users
    And http response code should be 201
    And I DELETE /users/104
    And http response code should be 200
    When I GET /users/104
    Then http response code should be 404

  # PUT /api/users/{id}
  Scenario: Updating an unknown user returns not found
    Given I set http body to {"id":"105","firstName":"Peter","lastName":"Parker","age":22}
    When I PUT /users/105
    Then http response code should be 404
    When I GET /users
    Then http response body is typed as array using path $ with length 0

  Scenario: Updating a user with a non numeric age is rejected
    Given I set http body to {"id":"106","firstName":"Peter","lastName":"Parker","age":22}
    And I POST /users
    And http response code should be 201
    When I set http body to {"id":"106","firstName":"Peter","lastName":"Parker","age":"old"}
    And I PUT /users/106
    Then http response code should be 400
    When I GET /users
    Then http response body path $.[0].age should be 22

  # PATCH /api/users/{id}
  Scenario: Patching an unknown user returns not found
    Given I set http body to {"lastName":"PARKER"}
    When I PATCH /users/107
    Then http response code should be 404

  # DELETE /api/users/{id}
  Scenario: Deleting the same user twice returns not found the second time
    Given I set http body to {"id":"108","firstName":"Peter","lastName":"Parker","age":22}
    And I POST /users
    And http response code should be 201
    When I DELETE /users/108
    Then http response code should be 200
    When I DELETE /users/108
    Then http response code should be 404

  # Unmapped HTTP methods on /api/users
  Scenario Outline: Unsupported <method> on the users collection is rejected
    Given I set http body to {"id":"109","firstName":"Peter","lastName":"Parker","age":22}
    When I <method> /users
    Then http response code should be 405

    Examples:
      | method |
      | PUT    |
      | PATCH  |
      | DELETE |
