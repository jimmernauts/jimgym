import common
import envoy
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import pog
import rada/date

pub type DbError {
  QueryError(pog.QueryError)
  EnvVarError
  TransactionError(pog.TransactionError)
  OtherError(String)
}

/// Read the DATABASE_URL environment variable.
/// Generate the pog.Config from that database URL.
/// Finally, connect to database.
pub fn connect_db() -> Result(pog.Connection, DbError) {
  envoy.get("DATABASE_URL")
  |> result.try(pog.url_config)
  |> echo
  |> result.map_error(fn(_) { EnvVarError })
  |> result.map(pog.connect)
}

pub fn get_all_sessions(
  db: pog.Connection,
) -> Result(List(common.GymSession), List(DbError)) {
  let exercise_record_decoder = {
    use date <- decode.field(0, pog.date_decoder())
    use name <- decode.field(1, decode.string)
    use reps <- decode.field(2, decode.optional(decode.int))
    use weight <- decode.field(3, decode.optional(decode.float))
    use duration <- decode.field(4, decode.optional(decode.int))
    decode.success(common.ExerciseRecord(
      date: date |> from_pog_date,
      name: name,
      reps: reps,
      weight: weight,
      duration: duration,
    ))
  }

  let gym_session_decoder = {
    use date <- decode.field(0, pog.date_decoder())
    use session_name <- decode.field(1, decode.string)
    use emoji <- decode.field(2, decode.string)
    decode.success(common.GymSession(
      date: date |> from_pog_date,
      session_name: session_name,
      emoji: emoji,
      exercises: dict.new(),
    ))
  }
  let sessions_query =
    pog.query(get_sessions_query) |> pog.returning(gym_session_decoder)

  let exercises_query =
    pog.query(get_exercises_query) |> pog.returning(exercise_record_decoder)

  let sessions =
    pog.execute(sessions_query, db)
    |> result.map(fn(returned_data) { returned_data.rows })
    |> result.map_error(fn(err) { QueryError(err) })

  let exercise_records =
    pog.execute(exercises_query, db)
    |> result.map(fn(returned_data) { returned_data.rows })
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

pub fn upsert_session(
  db: pog.Connection,
  session: common.GymSession,
) -> Result(Nil, DbError) {
  let sessions_query =
    pog.query(upsert_sessions_query)
    |> pog.parameter(session.date |> to_pog_date)
    |> pog.parameter(session.session_name |> pog.text)
    |> pog.parameter(session.emoji |> pog.text)

  let records_queries =
    session.exercises
    |> dict.values
    |> list.flatten
    |> list.map(fn(exercise) {
      case exercise {
        common.SetsExercise(name, reps, weight) ->
          pog.query(insert_records_query)
          |> pog.parameter(session.date |> to_pog_date)
          |> pog.parameter(name |> pog.text)
          |> pog.parameter(reps |> pog.int)
          |> pog.parameter(weight |> pog.float)
          |> pog.parameter(pog.null())
        common.TimedExercise(name, duration) ->
          pog.query(insert_records_query)
          |> pog.parameter(session.date |> to_pog_date)
          |> pog.parameter(name |> pog.text)
          |> pog.parameter(pog.null())
          |> pog.parameter(pog.null())
          |> pog.parameter(duration |> pog.int)
      }
    })

  let insert_session =
    db
    |> pog.execute(sessions_query, _)
    |> result.map_error(fn(err) { QueryError(err) })

  let delete_records =
    db
    |> pog.execute(
      pog.query(delete_records_query)
        |> pog.parameter(session.date |> to_pog_date),
      _,
    )
    |> result.map_error(fn(err) { QueryError(err) })

  let insert_records =
    records_queries
    |> list.map(fn(query) {
      db
      |> pog.execute(query, _)
      |> result.map_error(fn(err) { QueryError(err) })
    })
  let all_results = fn(_conn: pog.Connection) -> Result(Nil, String) {
    common.list_append_one(insert_records, delete_records)
    |> common.list_append_one(insert_session)
    |> common.flatten_errors
    |> result.map_error(string.inspect)
  }
  pog.transaction(db, all_results)
  |> result.map_error(TransactionError)
  |> echo
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

fn to_pog_date(date: date.Date) -> pog.Value {
  pog.Date(
    date.year(date),
    date.month(date) |> date.month_to_number,
    date.day(date),
  )
  |> pog.date
}

fn from_pog_date(date: pog.Date) -> date.Date {
  date.from_calendar_date(
    date.year,
    date.month |> date.number_to_month,
    date.day,
  )
}
