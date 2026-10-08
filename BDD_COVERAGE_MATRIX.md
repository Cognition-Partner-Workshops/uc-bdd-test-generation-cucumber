# BDD Coverage Matrix

Maps every REST endpoint exposed by the sample API under test
(`src/test/java/fr/redfroggy/bdd/restapi/user/UserController.java`, base path `/api`)
to the Gherkin scenarios in `src/test/resources/features` that exercise it.

Scenario categories:

- **Happy path**: valid request, expected 2xx outcome.
- **Error**: request that must be rejected (4xx/5xx) or a failing dependency.
- **Boundary**: edges of the input domain (empty/blank/min/max values, exact matching, partial updates, empty collections).

`(new)` marks a scenario added to close a gap identified in the baseline analysis below.

## Feature files

| Feature file | Tags | Isolation | Scenarios |
|---|---|---|---|
| `users.feature` | — | Shared state: scenarios depend on each other, in order | 14 |
| `users-import.feature` | `@user`, `@import` | Store cleared after each `@import` scenario | 1 → 6 |
| `users-error-handling.feature` (new) | `@user`, `@isolated` | Store cleared before and after each scenario | 13 (incl. 3 outline examples) |
| `users-boundary.feature` (new) | `@user`, `@isolated` | Store cleared before and after each scenario | 15 (incl. 2 outline examples) |

The `@isolated` tag uses a new `@Before`/`@After` hook in `DefaultRestApiStepDefinitionTest` that clears
`UserController.users`. That makes the new scenarios independent of execution order and of each other.

## Summary

| # | Endpoint | Happy (before → after) | Error (before → after) | Boundary (before → after) | Baseline gap |
|---|---|---|---|---|---|
| 1 | `HEAD /api/authenticated` | 1 → 1 | 1 → 2 | 0 → 1 | No boundary tests |
| 2 | `GET /api/users` (`?name=`) | 2 → 3 | n/a¹ | 1 → 5 | Boundary coverage was thin (only "no match") |
| 3 | `GET /api/users/{id}` (`?format=`) | 2 → 2 | 1 → 4 | 0 → 2 | Third-party failure path (→ 400) not tested; no boundary tests |
| 4 | `POST /api/users` (JSON) | 3 → 3 | 0 → 3 | 0 → 4 | **Happy path only** |
| 5 | `POST /api/users` (multipart CSV import) | 1 → 2 | 0 → 2 | 0 → 2 | **Happy path only** |
| 6 | `PUT /api/users/{id}` | 1 → 1 | 0 → 2 | 0 → 1 | **Happy path only** |
| 7 | `PATCH /api/users/{id}` | 1 → 1 | 0 → 1 | 0 → 1 | **Happy path only** |
| 8 | `DELETE /api/users/{id}` | 1 → 1 | 1 → 2 | 0 → 1 | No boundary tests |
| — | Unmapped methods on `/api/users` (`PUT`, `PATCH`, `DELETE`) | — | 0 → 3 | — | 405 handling not tested |

¹ `GET /api/users` has no error branch in the controller; any `name` value is accepted.

Baseline findings:

- **Endpoints with no BDD scenarios:** none. All 8 endpoint/method combinations had at least one scenario.
- **Happy-path only (no error scenarios):** `POST /api/users` (JSON), `POST /api/users` (multipart),
  `PUT /api/users/{id}`, `PATCH /api/users/{id}`.
- **No boundary tests:** every endpoint except `GET /api/users`, which only covered a search with no matches.

Totals: 15 → 48 Cucumber scenarios. All pass with `mvn test`.

## Detailed matrix

### 1. `HEAD /api/authenticated`
Returns 200 and echoes the `Authorization` header when it is non-blank, otherwise 401.

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users.feature` | Should be authenticated (200 after basic auth) |
| Error | `users.feature` | Should be authenticated (401 without credentials) |
| Error | `users-error-handling.feature` | (new) Unauthenticated HEAD request does not echo an Authorization header |
| Boundary | `users-boundary.feature` | (new) Any non blank Authorization header is accepted and echoed back |

### 2. `GET /api/users`
Lists users. The optional `name` filter does a case-insensitive substring match on first or last name.

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users.feature` | Get users |
| Happy | `users.feature` | Search for valid users |
| Boundary | `users.feature` | Search for invalid users (no match → `[]`) |
| Boundary | `users-boundary.feature` | (new) Listing users on an empty store returns an empty array |
| Boundary | `users-boundary.feature` | (new) Search by name is case insensitive |
| Boundary | `users-boundary.feature` | (new) Search by name matches partial first and last names |
| Boundary | `users-boundary.feature` | (new) A blank name filter returns every user |
| Happy | `users-import.feature` | (new) Imported users are persisted and searchable |

### 3. `GET /api/users/{id}`
Looks up the user, then enriches it with details from the third-party API `GET /public/characters/{id}` (mocked by WireMock).

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users.feature` | Get user Tony Stark (`?format=json` forwarded) |
| Happy | `users.feature` | Get user Bruce Wayne (fixture body) |
| Error | `users.feature` | Get wrong user (404) |
| Error | `users-error-handling.feature` | (new) Getting a user fails when the third party details api returns a server error (→ 400) |
| Error | `users-error-handling.feature` | (new) Getting a user fails when the third party details api does not know the user (→ 400) |
| Error | `users-error-handling.feature` | (new) A deleted user can no longer be retrieved (404) |
| Boundary | `users-boundary.feature` | (new) A blank format query parameter is not forwarded to the third party api |
| Boundary | `users-boundary.feature` | (new) User ids are matched exactly (prefix/superstring → 404) |

### 4. `POST /api/users` (`application/json`)
Creates a user. Returns 400 if the id already exists.

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users.feature` | Add tony stark user |
| Happy | `users.feature` | Add bruce wayne user (with `relatedTo`, scenario variables) |
| Happy | `users.feature` | Add bruce banner user (body from fixture file) |
| Error | `users-error-handling.feature` | (new) Creating a user with an already existing id is rejected (400, original kept) |
| Error | `users-error-handling.feature` | (new) Creating a user with a non numeric age is rejected (400) |
| Error | `users-boundary.feature` | (new) Age above the integer range is rejected (`2147483648` → 400) |
| Boundary | `users-boundary.feature` | (new) A user with only an id is created with default values |
| Boundary | `users-boundary.feature` | (new) Age accepts the full integer range (`0`, `2147483647`), outline with 2 examples |
| Boundary | `users-boundary.feature` | (new) Unicode names are stored and returned unchanged |

### 5. `POST /api/users` (`multipart/form-data`, CSV import)
Parses a `;`-separated CSV from the `file` part and appends its users to the store.

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users-import.feature` | Should import users csv file |
| Happy | `users-import.feature` | (new) Imported users are persisted and searchable |
| Error | `users-import.feature` | (new) Should reject a multipart request without a file part (400) |
| Error | `users-import.feature` | (new) Should not import a csv file with a non numeric age (non-2xx, store unchanged) |
| Boundary | `users-import.feature` | (new) Should import a csv file containing a single user |
| Boundary | `users-import.feature` | (new) Should import a csv file containing only the header row (→ `[]`) |

New fixtures: `upload/users-single-row.csv`, `upload/users-header-only.csv`, `upload/users-invalid-age.csv`.

### 6. `PUT /api/users/{id}`
Replaces `firstName`, `lastName`, `age` and `relatedTo` for an existing user. Returns 404 if the user doesn't exist.

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users.feature` | Update tony stark user |
| Error | `users-error-handling.feature` | (new) Updating an unknown user returns not found (404, nothing created) |
| Error | `users-error-handling.feature` | (new) Updating a user with a non numeric age is rejected (400, original kept) |
| Boundary | `users-boundary.feature` | (new) Updating a user replaces every field, including omitted ones |

### 7. `PATCH /api/users/{id}`
Updates only `lastName`. Returns 404 if the user doesn't exist.

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users.feature` | Patch bruce wayne user |
| Error | `users-error-handling.feature` | (new) Patching an unknown user returns not found |
| Boundary | `users-boundary.feature` | (new) Patching only changes the last name and ignores other fields |

### 8. `DELETE /api/users/{id}`
Removes the user. Returns 404 if the user doesn't exist.

| Type | Feature file | Scenario |
|---|---|---|
| Happy | `users.feature` | Delete user |
| Error | `users.feature` | Delete wrong user (404) |
| Error | `users-error-handling.feature` | (new) Deleting the same user twice returns not found the second time |
| Boundary | `users-boundary.feature` | (new) Deleting one user leaves the other users untouched |

### Unmapped methods on `/api/users`

| Type | Feature file | Scenario |
|---|---|---|
| Error | `users-error-handling.feature` | (new) Unsupported `<method>` on the users collection is rejected (405), outline with `PUT`, `PATCH`, `DELETE` |

## Observations about the API (not changed by this work)

These came up during the analysis. They are noted here so they can be fixed in the API itself; the tests do not lock the questionable behavior in place.

| Observation | Source | Evidence |
|---|---|---|
| A CSV row with a non-numeric `Age` causes an unhandled exception (500) instead of a 400. The scenario only asserts non-200, so it still passes once validation is added. | Observed in test run | `users-import.feature` |
| `GET /api/users/{id}` maps any third-party failure (404, 500) to 400. A 502/424 would describe the failure more accurately. | Observed in test run | `users-error-handling.feature` |
| There is no input validation: negative ages and a body without `id` are accepted. A `null` id would make later `u.getId().equals(...)` lookups throw an NPE. | Inferred from code | `UserController#addUser` |
| The CSV import skips the duplicate-id check that the JSON `POST` enforces. | Inferred from code | `UserController#uploadFile` |
| `PUT` returns the request body rather than the stored entity, and ignores a body `id` that differs from the path `id`. | Inferred from code | `UserController#updateUser` |
| Step library quirk: after `I send a multipart ... request`, the multipart `Content-Type` header stays set for the rest of the scenario. Later JSON requests must reset it with `I set Content-Type http header to application/json`. | Observed in test run | `AbstractBddStepDefinition#postMultipart` |

## Running

```bash
mvn test
```
