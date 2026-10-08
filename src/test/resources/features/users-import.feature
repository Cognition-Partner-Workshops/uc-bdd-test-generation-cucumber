@user
Feature: Users import api tests

  @import
  Scenario: Should import users csv file
    When I send a multipart POST request to /api/users with:
      | Name               | Filepath             |   Content-Type        |
      | file               | upload/users.csv     |   text/csv            |
    Then http response code should be 200
    And http response body is typed as array using path $ with length 2
    And http response body path $.[0].id should be 123
    And http response body path $.[0].firstName should be Peter
    And http response body path $.[0].lastName should be Parker
    And http response body path $.[0].age should be 22

  @import
  Scenario: Imported users are persisted and searchable
    When I send a multipart POST request to /api/users with:
      | Name               | Filepath             |   Content-Type        |
      | file               | upload/users.csv     |   text/csv            |
    Then http response code should be 200
    When I set Content-Type http header to application/json
    And I set http query parameter name to rogers
    And I GET /api/users
    Then http response code should be 200
    And http response body is typed as array using path $ with length 1
    And http response body path $.[0].id should be 4334

  @import
  Scenario: Should import a csv file containing a single user
    When I send a multipart POST request to /api/users with:
      | Name               | Filepath                       |   Content-Type        |
      | file               | upload/users-single-row.csv    |   text/csv            |
    Then http response code should be 200
    And http response body is typed as array using path $ with length 1
    And http response body path $.[0].id should be 777
    And http response body path $.[0].lastName should be Romanoff

  @import
  Scenario: Should import a csv file containing only the header row
    When I send a multipart POST request to /api/users with:
      | Name               | Filepath                       |   Content-Type        |
      | file               | upload/users-header-only.csv   |   text/csv            |
    Then http response code should be 200
    And http response body is typed as array using path $ with length 0

  @import
  Scenario: Should reject a multipart request without a file part
    When I send a multipart POST request to /api/users with:
      | Name               | Filepath             |   Content-Type        |
      | document           | upload/users.csv     |   text/csv            |
    Then http response code should be 400

  @import
  Scenario: Should not import a csv file with a non numeric age
    When I send a multipart POST request to /api/users with:
      | Name               | Filepath                       |   Content-Type        |
      | file               | upload/users-invalid-age.csv   |   text/csv            |
    Then http response code should not be 200
    When I set Content-Type http header to application/json
    And I GET /api/users
    Then http response body is typed as array using path $ with length 0
