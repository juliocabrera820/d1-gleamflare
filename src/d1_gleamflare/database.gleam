import gleam/http
import gleam/http/request
import gleam/json
import gleam/dynamic.{type Decoder, type Dynamic}
import gleam/option.{type Option}
import gleam/list
import d1_gleamflare/types.{type Database, type Query, type QueryMeta, type QueryResult, QueryMeta, QueryResult}
import d1_gleamflare/internal

pub fn query_to_json(q: Query) -> json.Json {
  json.object([
    #("sql", json.string(q.sql)),
    #("params", json.array(q.params, fn(x) { x })),
  ])
}

pub fn query_meta_decoder() -> Decoder(QueryMeta) {
  dynamic.decode5(
    QueryMeta,
    dynamic.field("duration", dynamic.float),
    dynamic.field("changes", dynamic.int),
    dynamic.field("last_row_id", dynamic.int),
    internal.optional_field("rows_read", dynamic.int) |> map_option_default(0),
    internal.optional_field("rows_written", dynamic.int) |> map_option_default(0),
  )
}

fn map_option_default(decoder: Decoder(Option(t)), default: t) -> Decoder(t) {
  fn(d) {
    case decoder(d) {
      Ok(opt) -> Ok(option.unwrap(opt, default))
      Error(errs) -> Error(errs)
    }
  }
}

pub fn query_result_decoder(row_decoder: Decoder(t)) -> Decoder(QueryResult(t)) {
  dynamic.decode3(
    QueryResult,
    internal.optional_field("results", dynamic.list(row_decoder))
      |> map_option_default([]),
    dynamic.field("success", dynamic.bool),
    dynamic.field("meta", query_meta_decoder()),
  )
}

pub fn query(
  db: Database,
  sql: String,
  params: List(json.Json),
  decoder: Decoder(t),
) -> Result(QueryResult(t), types.Error) {
  let body =
    json.object([
      #("sql", json.string(sql)),
      #("params", json.array(params, fn(x) { x })),
    ])
    |> json.to_string

  let req =
    internal.base_request(db.client)
    |> request.set_method(http.Post)
    |> request.set_path(
      "/client/v4/accounts/"
      <> db.client.account_id
      <> "/d1/database/"
      <> db.uuid
      <> "/query",
    )
    |> request.set_body(body)

  case internal.send_request(req, dynamic.list(query_result_decoder(decoder))) {
    Ok(results) -> {
      case list.first(results) {
        Ok(res) -> Ok(res)
        Error(_) -> Error(types.JsonError("Cloudflare API returned an empty result list"))
      }
    }
    Error(err) -> Error(err)
  }
}

pub fn query_dynamic(
  db: Database,
  sql: String,
  params: List(json.Json),
) -> Result(QueryResult(Dynamic), types.Error) {
  query(db, sql, params, dynamic.dynamic)
}

pub fn raw_query(
  db: Database,
  sql: String,
  params: List(json.Json),
) -> Result(List(List(Dynamic)), types.Error) {
  let body =
    json.object([
      #("sql", json.string(sql)),
      #("params", json.array(params, fn(x) { x })),
    ])
    |> json.to_string

  let req =
    internal.base_request(db.client)
    |> request.set_method(http.Post)
    |> request.set_path(
      "/client/v4/accounts/"
      <> db.client.account_id
      <> "/d1/database/"
      <> db.uuid
      <> "/raw",
    )
    |> request.set_body(body)

  let decoder = dynamic.list(dynamic.field("results", dynamic.field("rows", dynamic.list(dynamic.list(dynamic.dynamic)))))
  
  case internal.send_request(req, decoder) {
    Ok(results) -> {
      case list.first(results) {
        Ok(res) -> Ok(res)
        Error(_) -> Error(types.JsonError("Cloudflare API returned an empty result list"))
      }
    }
    Error(err) -> Error(err)
  }
}

pub fn batch(
  db: Database,
  queries: List(Query),
) -> Result(List(QueryResult(Dynamic)), types.Error) {
  let body =
    json.object([#("batch", json.array(queries, query_to_json))])
    |> json.to_string

  let req =
    internal.base_request(db.client)
    |> request.set_method(http.Post)
    |> request.set_path(
      "/client/v4/accounts/"
      <> db.client.account_id
      <> "/d1/database/"
      <> db.uuid
      <> "/query",
    )
    |> request.set_body(body)

  internal.send_request(req, dynamic.list(query_result_decoder(dynamic.dynamic)))
}

pub fn delete(db: Database) -> Result(Nil, types.Error) {
  let req =
    internal.base_request(db.client)
    |> request.set_method(http.Delete)
    |> request.set_path(
      "/client/v4/accounts/"
      <> db.client.account_id
      <> "/d1/database/"
      <> db.uuid,
    )

  internal.send_request(req, fn(_) { Ok(Nil) })
}
