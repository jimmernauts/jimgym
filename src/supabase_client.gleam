import gleam/option.{type Option, None, Some}
import gleam/result

// Keep for now, may become unused
import gleam/list

// Keep for now, may become unused
import gleam/string

import envoy
import pog

// Import DecodeError type along with Decoder and Dynamic.
// Constructors like PathDecode or CustomDecode might need to be qualified or imported differently.
import gleam/dynamic.{type DecodeError, type Decoder, type Dynamic}
import gleam/dynamic/decode
import rada/date

import common.{type ExerciseRecord}

const database_url_env_var = "DATABASE_URL"

fn from_pog_to_rada_date_result(pog_date: pog.Date) -> Result(date.Date, String) {
  date.from_calendar_date(
    pog_date.year,
    date.month(pog_date.month),
    pog_date.day,
  )
  |> result.map_error(fn(_) { "Failed to convert POG date to RADA date" })
}

pub fn establish_connection() -> Result(pog.Connection, String) {
  case envoy.get(database_url_env_var) {
    Some(db_url) -> {
      case pog.url_config(db_url) {
        Ok(config) -> {
          let connection_result = pog.connect(config)
          result.map_error(connection_result, fn(_err) { "pog.connect failed" })
        }
        Error(Nil) -> Error("Failed to parse database URL: " <> db_url)
      }
    }
    None ->
      Error("Environment variable " <> database_url_env_var <> " not set.")
  }
}

pub type GymSessionMetadata {
  GymSessionMetadata(id: String, date: date.Date, emoji: String)
}

fn gym_session_metadata_decoder() -> Decoder(GymSessionMetadata) {
  let rada_date_from_pog_decoder =
    pog.date_decoder()
    |> decode.then(fn(pog_date_value: pog.Date) -> Decoder(date.Date) {
      case from_pog_to_rada_date_result(pog_date_value) {
        Ok(rada_date) -> decode.success(rada_date)
        Error(msg) ->
          // Using two positional string arguments as per linter feedback cycle.
          decode.failure("rada.Date", msg)
      }
    })

  // USER NOTE: Persistent errors on decode.shape3 or decode.field arity might indicate
  // a Gleam environment or library version mismatch. This syntax is standard.
  decode.map3(
    GymSessionMetadata,
    decode.field("id", decode.string),
    decode.field("date", rada_date_from_pog_decoder),
    decode.field("emoji", decode.string),
  )
}

pub fn get_all_gym_sessions_metadata(
  conn: pog.Connection,
) -> Result(List(GymSessionMetadata), pog.QueryError) {
  let sql = "SELECT id, date, emoji FROM gym_sessions"
  let decoder = gym_session_metadata_decoder()
  // USER NOTE: pog.query(sql, decoder, params) is standard for pog v1.0.
  // Persistent arity errors may indicate environment issues.
  let query = pog.query(sql, decoder, [])

  pog.execute(query, conn)
  |> result.map(fn(returned_data) { returned_data.rows })
}

pub fn exercise_record_decoder() -> Decoder(ExerciseRecord) {
  fn(_d: Dynamic) -> Result(ExerciseRecord, List(DecodeError)) {
    // Using PathDecode and TypeMismatch, assuming they are brought into scope
    // by `import gleam/dynamic.{type DecodeError}`.
    Error([
      dynamic.PathDecode(
        [
          // No specific path, as it's a general failure for the whole decoder
        ],
        dynamic.TypeMismatch(
          expected: "ExerciseRecord",
          found: "Decoder not implemented",
        ),
      ),
    ])
  }
}
