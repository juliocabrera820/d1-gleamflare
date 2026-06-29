# d1_gleamflare

[![Hex Package](https://img.shields.io/hexpm/v/d1_gleamflare.svg)](https://hex.pm/packages/d1_gleamflare)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/d1_gleamflare/)
[![License](https://img.shields.io/hexpm/l/d1_gleamflare)](https://github.com/juliocabrera820/d1-gleamflare/blob/main/LICENSE)
[![Gleam](https://img.shields.io/badge/gleam-%3E%3D%201.3.0-FFAFF3)](https://gleam.run)
[![Target](https://img.shields.io/badge/target-erlang-B83998?logo=erlang)](https://www.erlang.org/)

A modern, type-safe Gleam library to integrate with the Cloudflare D1 REST API. Specifically built to target the Erlang VM (BEAM) using `gleam_httpc`.

## Installation

Add `d1_gleamflare` to your `gleam.toml` dependencies:

```toml
[dependencies]
d1_gleamflare = ">= 1.0.3"
```

## Quick Start

### 1. Initialize the Client

To interact with the Cloudflare API, you need your Cloudflare Account ID and a Cloudflare API Token with permissions to access D1.

```gleam
import d1_gleamflare

let client = d1_gleamflare.new("your-account-id", "your-api-token")
```

### 2. Manage Databases (Account-Level)

Create, list, or retrieve metadata for your databases:

```gleam
// List all databases
let assert Ok(databases) = d1_gleamflare.list_databases(client)

// Create a new database
let assert Ok(db_info) = d1_gleamflare.create_database(client, "my-production-db")
io.println("Created database: " <> db_info.uuid)

// Get database metadata by UUID
let assert Ok(db_info) = d1_gleamflare.get_database(client, "some-database-uuid")
```

### 3. Querying a Database

To query a database, instantiate a `Database` record using `d1_gleamflare.database`, then use the fluent, database-centric functions.

```gleam
import d1_gleamflare/database
import gleam/json
import gleam/dynamic

let db = d1_gleamflare.database(client, "database-uuid", "database-name")
```

#### Run Parameterized Queries with Custom Decoders

It is highly recommended to decode query results directly into typed structures:

```gleam
type User {
  User(id: Int, name: String, email: String)
}

fn user_decoder() {
  dynamic.decode3(
    User,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("email", dynamic.string),
  )
}

// Execute SELECT query
let sql = "SELECT id, name, email FROM users WHERE active = ? AND age >= ?"
let params = [json.bool(True), json.int(21)]

let assert Ok(query_result) = 
  db
  |> database.query(sql, params, user_decoder())

// query_result.results has type List(User)
let users = query_result.results
```

#### Run Dynamic Queries

If you don't want to use a specific decoder, you can retrieve results as raw `Dynamic` values:

```gleam
let assert Ok(query_result) = 
  db
  |> database.query_dynamic("SELECT * FROM settings", [])

// query_result.results has type List(dynamic.Dynamic)
```

#### Run Raw (Performance-Optimized) Queries

The `/raw` endpoint is optimized for performance by returning arrays of values rather than objects with keys:

```gleam
let assert Ok(query_result) = 
  db
  |> database.raw_query("SELECT id, name FROM users", [])

// Each row is returned as a List(Dynamic)
// query_result.results has type List(List(dynamic.Dynamic))
```

#### Run Batch Queries

You can execute multiple SQL queries in a single round-trip:

```gleam
import d1_gleamflare/types.{Query}

let batch_queries = [
  Query(
    "INSERT INTO logs (message, level) VALUES (?, ?)", 
    [json.string("Server started"), json.string("INFO")]
  ),
  Query(
    "UPDATE stats SET value = value + 1 WHERE key = ?", 
    [json.string("connections")]
  ),
]

let assert Ok(batch_results) = 
  db
  |> database.batch(batch_queries)

// batch_results has type List(QueryResult(dynamic.Dynamic))
```

#### Delete a Database

```gleam
let assert Ok(Nil) = database.delete(db)
```

## Error Handling

All actions return a `Result(t, types.Error)`. The library maps connection, HTTP, JSON decoding, and Cloudflare API-level errors cleanly:

```gleam
import d1_gleamflare/types

case d1_gleamflare.list_databases(client) {
  Ok(databases) -> // Use databases...
  Error(types.ApiError(errors)) -> // Cloudflare API-level errors (e.g. code: 10001, message: "Authentication failed")
  Error(types.HttpError(status, body)) -> // Non-2xx HTTP responses without standard envelope
  Error(types.JsonError(reason)) -> // Malformed JSON or type mismatch during decoding
  Error(types.NetworkError(reason)) -> // TCP or TLS connection issues
}
```
