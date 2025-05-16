import common.{type ExerciseRecord}
import envoy
import gleam/bool
import gleam/dynamic.{type DecodeError, type Decoder, type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import pog

pub type DbError {
  QueryError(pog.QueryError)
  EnvVarError
  ConnectionError(String)
}

/// Read the DATABASE_URL environment variable.
/// Generate the pog.Config from that database URL.
/// Finally, connect to database.
pub fn db() -> Result(pog.Connection, DbError) {
  envoy.get("DATABASE_URL")
  |> result.try(pog.url_config)
  |> result.map_error(fn(_) { EnvVarError })
  |> result.map(pog.connect)
}

pub fn get_all_exercise_records() -> Result(List(ExerciseRecord), DbError) {
  let sql_query = "select date,name,weight,duration,reps from exercise_records"

  let row_decoder = {
    use date <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use weight <- decode.field(2, decode.optional(decode.float))
    use reps <- decode.field(3, decode.optional(decode.int))
    use duration <- decode.field(4, decode.optional(decode.int))
    decode.success(common.ExerciseRecord(
      date: date,
      name: name,
      reps: reps,
      weight: weight,
      duration: duration,
    ))
  }
  let query = pog.query(sql_query) |> pog.returning(row_decoder)

  db()
  |> result.map(pog.execute(query, _))
  |> g
}
