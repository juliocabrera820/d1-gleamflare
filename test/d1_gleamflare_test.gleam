import gleeunit
import gleam/dynamic
import gleam/json
import gleam/option.{Some, None}
import d1_gleamflare
import d1_gleamflare/types.{Query, CloudflareApiError}
import d1_gleamflare/internal
import d1_gleamflare/database

pub fn main() {
  gleeunit.main()
}

pub fn envelope_success_test() {
  let json_str = "{\"success\":true,\"errors\":[],\"messages\":[],\"result\":{\"foo\":\"bar\"}}"
  let assert Ok(envelope) = json.decode(json_str, internal.envelope_decoder())
  
  let assert True = envelope.success
  let assert [] = envelope.errors
  let assert Some(res_dynamic) = envelope.result
  
  let assert Ok(foo_val) = dynamic.field("foo", dynamic.string)(res_dynamic)
  let assert "bar" = foo_val
}

pub fn envelope_success_null_test() {
  let json_str = "{\"success\":true,\"errors\":[],\"messages\":[],\"result\":null}"
  let assert Ok(envelope) = json.decode(json_str, internal.envelope_decoder())
  
  let assert True = envelope.success
  let assert [] = envelope.errors
  let assert None = envelope.result
}

pub fn envelope_success_missing_test() {
  let json_str = "{\"success\":true,\"errors\":[],\"messages\":[]}"
  let assert Ok(envelope) = json.decode(json_str, internal.envelope_decoder())
  
  let assert True = envelope.success
  let assert [] = envelope.errors
  let assert None = envelope.result
}

pub fn envelope_error_test() {
  let json_str = "{\"success\":false,\"errors\":[{\"code\":1001,\"message\":\"Database not found\"}],\"messages\":[]}"
  let assert Ok(envelope) = json.decode(json_str, internal.envelope_decoder())
  
  let assert False = envelope.success
  let assert [CloudflareApiError(code: 1001, message: "Database not found")] = envelope.errors
}

pub fn database_info_decoder_test() {
  let json_str = "{\"uuid\":\"some-uuid\",\"name\":\"my-db\",\"created_at\":\"2026-01-01T00:00:00Z\",\"version\":\"alpha\"}"
  let assert Ok(db_info) = json.decode(json_str, d1_gleamflare.database_info_decoder())
  
  let assert "some-uuid" = db_info.uuid
  let assert "my-db" = db_info.name
  let assert "2026-01-01T00:00:00Z" = db_info.created_at
  let assert "alpha" = db_info.version
}

pub fn query_result_decoder_test() {
  let json_str = "{\"results\":[{\"id\":1,\"name\":\"Alice\"}],\"success\":true,\"meta\":{\"duration\":0.012,\"changes\":1,\"last_row_id\":1,\"rows_read\":1,\"rows_written\":1}}"
  
  let row_decoder = dynamic.decode2(
    fn(id, name) { #(id, name) },
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
  )
  
  let assert Ok(query_res) = json.decode(json_str, database.query_result_decoder(row_decoder))
  
  let assert [#(1, "Alice")] = query_res.results
  let assert True = query_res.success
  let assert 0.012 = query_res.meta.duration
  let assert 1 = query_res.meta.changes
  let assert 1 = query_res.meta.last_row_id
  let assert 1 = query_res.meta.rows_read
  let assert 1 = query_res.meta.rows_written
}

pub fn query_result_decoder_missing_results_test() {
  let json_str = "{\"success\":true,\"meta\":{\"duration\":0.005,\"changes\":0,\"last_row_id\":0}}"
  
  let assert Ok(query_res) = json.decode(json_str, database.query_result_decoder(dynamic.dynamic))
  
  let assert [] = query_res.results
  let assert True = query_res.success
  let assert 0.005 = query_res.meta.duration
  let assert 0 = query_res.meta.changes
  let assert 0 = query_res.meta.last_row_id
  let assert 0 = query_res.meta.rows_read
  let assert 0 = query_res.meta.rows_written
}

pub fn query_to_json_test() {
  let q = Query(
    sql: "SELECT * FROM users WHERE age > ? AND active = ?",
    params: [json.int(18), json.bool(True)],
  )
  
  let json_data = database.query_to_json(q)
  let serialized = json.to_string(json_data)
  
  let assert "{\"sql\":\"SELECT * FROM users WHERE age > ? AND active = ?\",\"params\":[18,true]}" = serialized
}

pub fn raw_results_decoder_test() {
  let json_str = "{\"results\":[{\"rows\":[[1,\"Alice\"],[2,\"Bob\"]]}]}"
  
  let decoder = dynamic.field("results", dynamic.list(dynamic.field("rows", dynamic.list(dynamic.list(dynamic.dynamic)))))
  
  let assert Ok(results) = json.decode(json_str, decoder)
  
  let assert [rows] = results
  let assert [[id1, name1], [id2, name2]] = rows
  
  let assert Ok(1) = dynamic.int(id1)
  let assert Ok("Alice") = dynamic.string(name1)
  let assert Ok(2) = dynamic.int(id2)
  let assert Ok("Bob") = dynamic.string(name2)
}
