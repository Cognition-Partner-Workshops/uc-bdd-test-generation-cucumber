@user @isolated
Feature: Users api boundary condition tests
  Every scenario starts from (and leaves behind) an empty user store, so each one sets up its own data.

  Background:
    Given http baseUri is /api/
    And I set Accept-Language http header to en-US
    And I set http headers to:
      | Accept        | application/json  |
      | Content-Type  | application/json  |

  # HEAD /api/authenticated
  Scenario: Any non blank Authorization header is accepted and echoed back
    Given I set Authorization http header to Bearer some-opaque-token
    When I HEAD /authenticated
    Then http response code should be 200
    And http response header Authorization should be Bearer some-opaque-token

  # GET /api/users
  Scenario: Listing users on an empty store returns an empty array
    When I GET /users
    Then http response code should be 200
    And http response body should be valid json
    And http response body is typed as array using path $ with length 0

  Scenario: Search by name is case insensitive
    Given I set http body to {"id":"200","firstName":"Bruce","lastName":"Wayne","age":50}
    And I POST /users
    And http response code should be 201
    And I set http query parameter name to WAYNE
    When I GET /users
    Then http response code should be 200
    And http response body is typed as array using path $ with length 1
    And http response body path $.[0].id should be 200

  Scenario: Search by name matches partial first and last names
    Given I set http body to {"id":"201","firstName":"Bruce","lastName":"Wayne","age":50}
    And I POST /users
    And I set http body to {"id":"202","firstName":"Bruce","lastName":"Banner","age":45}
    And I POST /users
    And I set http body to {"id":"203","firstName":"Tony","lastName":"Stark","age":40}
    And I POST /users
    And I set http query parameter name to ruc
    When I GET /users
    Then http response code should be 200
    And http response body is typed as array using path $ with length 2
    And http response body path $.[0].id should be 201
    And http response body path $.[1].id should be 202

  Scenario: A blank name filter returns every user
    Given I set http body to {"id":"204","firstName":"Bruce","lastName":"Wayne","age":50}
    And I POST /users
    And I set http body to {"id":"205","firstName":"Tony","lastName":"Stark","age":40}
    And I POST /users
    When I GET /users?name=
    Then http response code should be 200
    And http response body is typed as array using path $ with length 2

  # POST /api/users
  Scenario: A user with only an id is created with default values
    Given I set http body to {"id":"206"}
    When I POST /users
    Then http response code should be 201
    And http response body path $.id should be 206
    And http response body path $.age should be 0

  Scenario Outline: Age accepts the full integer range (<age>)
    Given I set http body to {"id":"<id>","firstName":"Edge","lastName":"Case","age":<age>}
    When I POST /users
    Then http response code should be 201
    And http response body path $.age should be <age>

    Examples:
      | id  | age        |
      | 207 | 0          |
      | 208 | 2147483647 |

  Scenario: Age above the integer range is rejected
    Given I set http body to {"id":"209","firstName":"Edge","lastName":"Case","age":2147483648}
    When I POST /users
    Then http response code should be 400
    When I GET /users
    Then http response body is typed as array using path $ with length 0

  Scenario: Unicode names are stored and returned unchanged
    Given I set http body to {"id":"210","firstName":"Zoë","lastName":"Ångström-Núñez","age":30}
    When I POST /users
    Then http response code should be 201
    And http response body path $.firstName should be Zoë
    And http response body path $.lastName should be Ångström-Núñez

  # GET /api/users/{id}
  Scenario: A blank format query parameter is not forwarded to the third party api
    Given I set http body to {"id":"211","firstName":"Tony","lastName":"Stark","age":40}
    And I POST /users
    And I mock third party api call GET /public/characters/211 with return code 200, content type: application/json and body: {"comicName": "IronMan", "city": "New York"}
    When I GET /users/211?format=
    Then http response code should be 200
    And http response body path $.details.comicName should be IronMan

  Scenario: User ids are matched exactly
    Given I set http body to {"id":"212","firstName":"Tony","lastName":"Stark","age":40}
    And I POST /users
    When I GET /users/2120
    Then http response code should be 404
    When I GET /users/21
    Then http response code should be 404

  # PUT /api/users/{id}
  Scenario: Updating a user replaces every field, including omitted ones
    Given I set http body to {"id":"213","firstName":"Tony","lastName":"Stark","age":40}
    And I POST /users
    And I set http body to {"id":"213","lastName":"Stark"}
    When I PUT /users/213
    Then http response code should be 200
    When I GET /users
    Then http response body path $.[0].lastName should be Stark
    And http response body path $.[0].age should be 0

  # PATCH /api/users/{id}
  Scenario: Patching only changes the last name and ignores other fields
    Given I set http body to {"id":"214","firstName":"Bruce","lastName":"Wayne","age":50}
    And I POST /users
    And I set http body to {"firstName":"Batman","lastName":"WAYNE","age":99}
    When I PATCH /users/214
    Then http response code should be 200
    And http response body path $.firstName should be Bruce
    And http response body path $.lastName should be WAYNE
    And http response body path $.age should be 50

  # DELETE /api/users/{id}
  Scenario: Deleting one user leaves the other users untouched
    Given I set http body to {"id":"215","firstName":"Bruce","lastName":"Wayne","age":50}
    And I POST /users
    And I set http body to {"id":"216","firstName":"Tony","lastName":"Stark","age":40}
    And I POST /users
    When I DELETE /users/215
    Then http response code should be 200
    When I GET /users
    Then http response body is typed as array using path $ with length 1
    And http response body path $.[0].id should be 216
