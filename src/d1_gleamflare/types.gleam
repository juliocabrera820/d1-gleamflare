import gleam/json

pub type Client {
  Client(
    account_id: String,
    api_token: String,
  )
}

pub type Database {
  Database(
    client: Client,
    uuid: String,
    name: String,
  )
}

pub type DatabaseInfo {
  DatabaseInfo(
    uuid: String,
    name: String,
    created_at: String,
    version: String,
  )
}

pub type Query {
  Query(
    sql: String,
    params: List(json.Json),
  )
}

pub type QueryMeta {
  QueryMeta(
    duration: Float,
    changes: Int,
    last_row_id: Int,
    rows_read: Int,
    rows_written: Int,
  )
}

pub type QueryResult(t) {
  QueryResult(
    results: List(t),
    success: Bool,
    meta: QueryMeta,
  )
}

pub type CloudflareApiError {
  CloudflareApiError(
    code: Int,
    message: String,
  )
}

pub type Error {
  HttpError(status: Int, body: String)
  NetworkError(reason: String)
  JsonError(reason: String)
  ApiError(errors: List(CloudflareApiError))
}
