import gleam/http
import gleam/http/request.{type Request}
import gleam/httpc
import gleam/json
import gleam/dynamic.{type Decoder}
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/list
import d1_gleamflare/types.{type Client}

pub type Envelope {
  Envelope(
    success: Bool,
    errors: List(types.CloudflareApiError),
    result: Option(dynamic.Dynamic),
  )
}

pub fn api_error_decoder() -> Decoder(types.CloudflareApiError) {
  dynamic.decode2(
    types.CloudflareApiError,
    dynamic.field("code", dynamic.int),
    dynamic.field("message", dynamic.string),
  )
}

pub fn optional_field(
  name: String,
  inner: Decoder(t),
) -> Decoder(Option(t)) {
  fn(d) {
    case dynamic.field(name, dynamic.optional(inner))(d) {
      Ok(opt) -> Ok(opt)
      Error([dynamic.DecodeError("field", "nothing", path)]) if path == [name] -> Ok(None)
      Error(errs) -> Error(errs)
    }
  }
}

pub fn envelope_decoder() -> Decoder(Envelope) {
  dynamic.decode3(
    Envelope,
    dynamic.field("success", dynamic.bool),
    dynamic.field("errors", dynamic.list(api_error_decoder())),
    optional_field("result", dynamic.dynamic),
  )
}

pub fn base_request(client: Client) -> Request(String) {
  request.new()
  |> request.set_scheme(http.Https)
  |> request.set_host("api.cloudflare.com")
  |> request.set_header("authorization", "Bearer " <> client.api_token)
  |> request.set_header("content-type", "application/json")
  |> request.set_header("accept", "application/json")
  |> request.set_body("")
}

pub fn stringify_errors(errors: List(dynamic.DecodeError)) -> String {
  errors
  |> list.map(fn(err) {
    err.expected <> " at " <> string.join(err.path, ".") <> " (found: " <> err.found <> ")"
  })
  |> string.join(", ")
}

pub fn send_request(
  req: Request(String),
  result_decoder: Decoder(t),
) -> Result(t, types.Error) {
  case httpc.send(req) {
    Ok(res) -> {
      case json.decode(res.body, envelope_decoder()) {
        Ok(envelope) -> {
          case envelope.success {
            True -> {
              case envelope.result {
                Some(res_dynamic) -> {
                  case result_decoder(res_dynamic) {
                    Ok(val) -> Ok(val)
                    Error(errs) -> {
                      Error(types.JsonError("Failed to decode response result: " <> stringify_errors(errs)))
                    }
                  }
                }
                None -> {
                  // Fallback: try decoding from Nil if result is absent
                  case result_decoder(dynamic.from(Nil)) {
                    Ok(val) -> Ok(val)
                    Error(errs) -> {
                      Error(types.JsonError("Expected result field but it was missing: " <> stringify_errors(errs)))
                    }
                  }
                }
              }
            }
            False -> {
              Error(types.ApiError(envelope.errors))
            }
          }
        }
        Error(json_err) -> {
          case res.status < 200 || res.status >= 300 {
            True -> Error(types.HttpError(res.status, res.body))
            False -> Error(types.JsonError("Failed to decode JSON: " <> string.inspect(json_err)))
          }
        }
      }
    }
    Error(httpc_err) -> {
      Error(types.NetworkError(stringify_httpc_error(httpc_err)))
    }
  }
}

pub fn stringify_httpc_error(err) -> String {
  string.inspect(err)
}
