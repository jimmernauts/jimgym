import common.{type ExerciseRecord}
import envoy
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/result
import pog
import rada/date

pub type DbError {
  QueryError(pog.QueryError)
  EnvVarError
}

/// Read the DATABASE_URL environment variable.
/// Generate the pog.Config from that database URL.
/// Finally, connect to database.
pub fn connect_db() -> Result(pog.Connection, DbError) {
  envoy.get("DATABASE_URL")
  |> echo
  |> result.try(pog.url_config)
  |> echo
  |> result.map_error(fn(_) { EnvVarError })
  |> result.map(pog.connect)
}

pub fn get_all_sessions(
  db: pog.Connection,
) -> Result(List(common.GymSession), DbError) {
  let exercise_record_decoder = {
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

  let row_decoder = {
    use date <- decode.field(0, decode.string)
    use session_name <- decode.field(1, decode.string)
    use emoji <- decode.field(2, decode.string)
    use exercises <- decode.field(3, decode.list(exercise_record_decoder))
    decode.success(common.GymSession(
      date: date
        |> date.from_iso_string
        |> result.unwrap(date.from_calendar_date(1970, date.Jan, 1)),
      session_name: session_name,
      emoji: emoji,
      exercises: exercises |> common.group_records_into_exercises,
    ))
  }
  let query = pog.query(get_all_sessions_query) |> pog.returning(row_decoder)

  pog.execute(query, db)
  |> result.map(fn(returned_data) { returned_data.rows })
  |> result.map_error(fn(err) { QueryError(err) })
}

pub fn insert_session(
  db: pog.Connection,
  session: common.GymSession,
) -> Result(Nil, List(DbError)) {
  let sessions_query =
    pog.query(insert_sessions_query)
    |> pog.parameter(session.date |> to_pog_date)
    |> pog.parameter(session.session_name |> pog.text)
    |> pog.parameter(session.emoji |> pog.text)

  let records_queries =
    session.exercises
    |> dict.values
    |> list.flatten
    |> list.map(fn(exercise) {
      case exercise {
        common.SetsExercise(name, reps, weight, _rest) ->
          pog.query(insert_records_query)
          |> pog.parameter(session.date |> date.to_iso_string |> pog.text)
          |> pog.parameter(name |> pog.text)
          |> pog.parameter(reps |> pog.int)
          |> pog.parameter(weight |> pog.float)
          |> pog.parameter(pog.null())
        common.TimedExercise(name, duration) ->
          pog.query(insert_records_query)
          |> pog.parameter(session.date |> date.to_iso_string |> pog.text)
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

  let insert_records =
    records_queries
    |> list.map(fn(query) {
      db
      |> pog.execute(query, _)
      |> result.map_error(fn(err) { QueryError(err) })
    })

  case common.list_append_one(insert_records, insert_session) {
    [Ok(_)] -> Ok(Nil)
    a -> common.flatten_errors(a)
  }
  |> echo
}

const get_all_sessions_query = "SELECT
    g.session_name,
    g.date,
    g.emoji,
    array_agg(
      ROW(e.name, e.weight, e.duration, e.reps)
    ) AS exercises
  FROM
    gym_sessions g
  LEFT JOIN
    exercise_records e ON g.date = e.date
  GROUP BY
    g.session_name,
    g.date,
    g.emoji;"

const insert_sessions_query = "INSERT INTO gym_sessions (date, session_name, emoji)
VALUES ($1, $2, $3);"

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
