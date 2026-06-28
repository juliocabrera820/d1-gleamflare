import gleam/http
import gleam/http/request
import gleam/json
import gleam/dynamic
import d1_gleamflare/types.{type Client, type Database, type DatabaseInfo, Client, Database, DatabaseInfo}
import d1_gleamflare/internal

pub fn new(account_id: String, api_token: String) -> Client {
  Client(account_id: account_id, api_token: api_token)
}

pub fn database(client: Client, uuid: String, name: String) -> Database {
  Database(client: client, uuid: uuid, name: name)
}

pub fn database_info_decoder() -> dynamic.Decoder(DatabaseInfo) {
  dynamic.decode4(
    DatabaseInfo,
    dynamic.field("uuid", dynamic.string),
    dynamic.field("name", dynamic.string),
    dynamic.field("created_at", dynamic.string),
    dynamic.field("version", dynamic.string),
  )
}

pub fn list_databases(client: Client) -> Result(List(DatabaseInfo), types.Error) {
  let req =
    internal.base_request(client)
    |> request.set_method(http.Get)
    |> request.set_path("/client/v4/accounts/" <> client.account_id <> "/d1/database")

  internal.send_request(req, dynamic.list(database_info_decoder()))
}

pub fn create_database(client: Client, name: String) -> Result(DatabaseInfo, types.Error) {
  let body =
    json.object([#("name", json.string(name))])
    |> json.to_string

  let req =
    internal.base_request(client)
    |> request.set_method(http.Post)
    |> request.set_path("/client/v4/accounts/" <> client.account_id <> "/d1/database")
    |> request.set_body(body)

  internal.send_request(req, database_info_decoder())
}

pub fn get_database(client: Client, uuid: String) -> Result(DatabaseInfo, types.Error) {
  let req =
    internal.base_request(client)
    |> request.set_method(http.Get)
    |> request.set_path("/client/v4/accounts/" <> client.account_id <> "/d1/database/" <> uuid)

  internal.send_request(req, database_info_decoder())
}
