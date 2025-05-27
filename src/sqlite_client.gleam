import common
import envoy
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import rada/date
import sqlight

pub type DbError {
  QueryError(sqlight.Error)
  EnvVarError
  OtherError(String)
}

pub fn get_sqlite_path() -> Result(String, DbError) {
  envoy.get("SQLITE_DB")
  |> echo
  |> result.map_error(fn(_) { EnvVarError })
}

pub fn get_all_sessions() -> Result(List(common.GymSession), List(DbError)) {
  use conn <- sqlight.with_connection(get_sqlite_path() |> result.unwrap(""))
  {
    let exercise_record_decoder = {
      use date <- decode.field(0, string_date_decoder())
      use name <- decode.field(1, decode.string)
      use reps <- decode.field(2, decode.optional(decode.int))
      use weight <- decode.field(3, decode.optional(decode.float))
      use duration <- decode.field(4, decode.optional(decode.int))
      decode.success(common.ExerciseRecord(
        date: date,
        name: name,
        reps: reps,
        weight: weight,
        duration: duration,
      ))
    }

    let gym_session_decoder = {
      use date <- decode.field(0, string_date_decoder())
      use session_name <- decode.field(1, decode.string)
      use emoji <- decode.field(2, decode.string)
      decode.success(common.GymSession(
        date: date,
        session_name: session_name,
        emoji: emoji,
        exercises: dict.new(),
      ))
    }
    let sessions =
      sqlight.query(get_sessions_query, conn, [], gym_session_decoder)
      |> result.map_error(fn(err) { QueryError(err) })

    let exercise_records =
      sqlight.query(get_exercises_query, conn, [], exercise_record_decoder)
      |> result.map_error(fn(err) { QueryError(err) })

    case sessions, exercise_records {
      Ok(sessions), Ok(exercise_records) ->
        sessions
        |> list.map(fn(session) {
          let exercises =
            list.filter(exercise_records, fn(exercise) {
              exercise.date == session.date
            })
          common.GymSession(
            ..session,
            exercises: exercises |> common.group_records_into_exercises,
          )
        })
        |> Ok
      Error(a), Ok(_) -> Error([a])
      Ok(_), Error(b) -> Error([b])
      Error(a), Error(b) -> Error([a, b])
    }
  }
}

pub fn upsert_session(session: common.GymSession) -> Result(Nil, List(DbError)) {
  use conn <- sqlight.with_connection(get_sqlite_path() |> result.unwrap(""))
  {
    let insert_session =
      sqlight.query(
        upsert_sessions_query,
        conn,
        [
          session.date |> date.to_iso_string |> sqlight.text,
          session.session_name |> sqlight.text,
          session.emoji |> sqlight.text,
        ],
        nil_to_empty_list_decoder(),
      )
      |> result.map_error(fn(err) { QueryError(err) })

    let delete_exercises =
      sqlight.query(
        delete_records_query,
        conn,
        [session.date |> date.to_iso_string |> sqlight.text],
        nil_to_empty_list_decoder(),
      )
      |> result.map_error(fn(err) { QueryError(err) })

    let insert_exercises =
      session.exercises
      |> dict.values
      |> list.flatten
      |> list.map(fn(exercise) {
        case exercise {
          common.SetsExercise(name, reps, weight) ->
            sqlight.query(
              insert_records_query,
              conn,
              [
                session.date |> date.to_iso_string |> sqlight.text,
                name |> sqlight.text,
                reps |> sqlight.int,
                weight |> sqlight.float,
                sqlight.null(),
              ],
              nil_to_empty_list_decoder(),
            )
            |> result.map_error(fn(err) { QueryError(err) })
          common.TimedExercise(name, duration) ->
            sqlight.query(
              insert_records_query,
              conn,
              [
                session.date |> date.to_iso_string |> sqlight.text,
                name |> sqlight.text,
                sqlight.null(),
                sqlight.null(),
                duration |> sqlight.int,
              ],
              nil_to_empty_list_decoder(),
            )
            |> result.map_error(fn(err) { QueryError(err) })
        }
      })

    case insert_session, delete_exercises, insert_exercises |> result.all {
      Ok(_), Ok(_), Ok(_) -> Ok(Nil)
      _, _, _ ->
        common.flatten_errors([
          insert_session,
          delete_exercises,
          ..insert_exercises
        ])
    }
  }
}

const get_sessions_query = "SELECT
    g.date,
    g.session_name,
    g.emoji
  FROM
    gym_sessions g"

const get_exercises_query = "SELECT
    e.date,
    e.name,
    e.reps,
    e.weight,
    e.duration
  FROM
    exercise_records e"

const upsert_sessions_query = "INSERT INTO gym_sessions (date, session_name, emoji)
VALUES ($1, $2, $3)
ON CONFLICT(date)
DO UPDATE SET
session_name = EXCLUDED.session_name,
emoji = EXCLUDED.emoji;"

const delete_records_query = "DELETE FROM exercise_records WHERE date = $1;"

const insert_records_query = "INSERT INTO exercise_records (date, name, reps, weight, duration)
VALUES ($1, $2, $3, $4, $5);"

pub fn string_date_decoder() -> decode.Decoder(date.Date) {
  decode.string
  |> decode.then(fn(s) {
    case date.from_iso_string(s) {
      Ok(date) -> decode.success(date)
      Error(str) ->
        decode.failure(date.from_calendar_date(01, date.Jan, 1970), str)
    }
  })
}

pub fn nil_to_empty_list_decoder() -> decode.Decoder(List(a)) {
  decode.success([])
}
