# Agent Context: d1_gleamflare

This file serves as a reference for AI coding assistants working on the `d1_gleamflare` codebase.

## Technology Stack

- **Language:** Gleam v1.4.0 (targeting the Erlang BEAM runtime).
- **HTTP Client:** `gleam_httpc` (standard Erlang VM client).
- **JSON Serialization:** `gleam_json` and `gleam_stdlib`'s `gleam/dynamic` module.
- **Testing:** `gleeunit` for running unit tests on Erlang.

## Project Structure

- `src/d1_gleamflare.gleam`: Main entrance module containing the `Client` and account-level management APIs (listing, creating, and retrieving database metadata).
- `src/d1_gleamflare/database.gleam`: Operations performed on a specific database instance (executing single queries, raw queries, batching, and database deletions).
- `src/d1_gleamflare/types.gleam`: Core data types representing credentials, query statements, execution statistics, results, and custom library error mappings.
- `src/d1_gleamflare/internal.gleam`: HTTP client helpers and the JSON decoding envelope logic.
- `test/d1_gleamflare_test.gleam`: Unit test suite testing JSON decoders and request layout mapping.

## Key Design Patterns & Caveats

### 1. Cloudflare REST API Response Wrapping
All responses from the Cloudflare API v4 are wrapped in a standard JSON envelope:
```json
{
  "success": true,
  "errors": [],
  "messages": [],
  "result": ...
}
```
If `"success"` is false, the error details are parsed from the `"errors"` field and returned as `types.ApiError`.

### 2. Single and Batch Queries
Cloudflare's `/query` and `/raw` endpoints return an array/list of results inside the `"result"` envelope field, *even for single query operations*.
- Single queries receive a list of size 1 (e.g., `[ { "results": [...], "success": true, "meta": {...} } ]`).
- Batch queries receive a list matching the query count.
To normalize this, `database.query` and `database.raw_query` extract the first element of the returned result list. `database.batch` returns the full list.

### 3. Dynamic and Custom Row Decoders
The library provides:
- Strongly typed querying via `database.query(..., decoder)` which maps rows using a custom dynamic decoder.
- Dynamically typed querying via `database.query_dynamic` which returns `Dynamic` values.
- Array-based querying via `database.raw_query` (hitting the `/raw` endpoint) which decodes rows into a `List(List(Dynamic))`. Unlike the `/query` endpoint, `/raw` does not wrap results in the standard Cloudflare envelope, but rather returns the raw JSON directly (e.g., `{ "results": [{ "rows": [...] }] }`).

### 4. Custom Option Mapping
Because the project runs on an older `gleam_stdlib` compatible with Gleam 1.4.0 (where the new `gleam/dynamic/decode` module is not fully featured), we implement a manual `map_option_default` helper inside `database.gleam` to transform `Option` types and unwrap values safely:
```gleam
fn map_option_default(decoder: Decoder(Option(t)), default: t) -> Decoder(t) {
  fn(d) {
    case decoder(d) {
      Ok(opt) -> Ok(option.unwrap(opt, default))
      Error(errs) -> Error(errs)
    }
  }
}
```
If you modify decoding behavior, follow this pattern instead of using `dynamic.map`.

### 5. Stringify Errors via inspect
To remain fully compatible across minor version upgrades of dependencies (like changes in the `json.DecodeError` or `httpc.HttpError` constructors), we use `string.inspect` to format parse/network errors into human-readable strings, which prevents build breaks on constructor changes.
