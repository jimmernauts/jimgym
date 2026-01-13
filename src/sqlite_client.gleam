import common
import envoy
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/order
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
  envoy.get("DATABASE_PATH")
  |> result.map_error(fn(_) { EnvVarError })
}

pub fn get_all_sessions() -> Result(List(common.GymSession), List(DbError)) {
  //use conn <- sqlight.with_connection(get_sqlite_path() |> result.unwrap(""))
  let open = sqlight.open(get_sqlite_path() |> result.unwrap(""))
  case open {
    Ok(conn) -> {
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
    Error(a) -> Error([OtherError(string.inspect(a))])
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

// ---- SESSION TEMPLATES ----

pub type SessionTemplateRow {
  SessionTemplateRow(id: Int, name: String, emoji: String)
}

pub type ExerciseTemplateRow {
  ExerciseTemplateRow(
    id: Int,
    session_template_id: Int,
    name: String,
    exercise_type: String,
    sets: option.Option(Int),
    reps: option.Option(Int),
    weight: option.Option(Float),
    duration: option.Option(Int),
    sort_order: Int,
  )
}

pub fn get_all_session_templates() -> Result(
  List(common.SessionTemplate),
  List(DbError),
) {
  let open = sqlight.open(get_sqlite_path() |> result.unwrap(""))
  case open {
    Ok(conn) -> {
      let session_template_decoder = {
        use id <- decode.field(0, decode.int)
        use name <- decode.field(1, decode.string)
        use emoji <- decode.field(2, decode.string)
        decode.success(SessionTemplateRow(id: id, name: name, emoji: emoji))
      }

      let exercise_template_decoder = {
        use id <- decode.field(0, decode.int)
        use session_template_id <- decode.field(1, decode.int)
        use name <- decode.field(2, decode.string)
        use exercise_type <- decode.field(3, decode.string)
        use sets <- decode.field(4, decode.optional(decode.int))
        use reps <- decode.field(5, decode.optional(decode.int))
        use weight <- decode.field(6, decode.optional(decode.float))
        use duration <- decode.field(7, decode.optional(decode.int))
        use sort_order <- decode.field(8, decode.int)
        decode.success(ExerciseTemplateRow(
          id: id,
          session_template_id: session_template_id,
          name: name,
          exercise_type: exercise_type,
          sets: sets,
          reps: reps,
          weight: weight,
          duration: duration,
          sort_order: sort_order,
        ))
      }

      let templates =
        sqlight.query(
          get_session_templates_query,
          conn,
          [],
          session_template_decoder,
        )
        |> result.map_error(fn(err) { QueryError(err) })

      let exercises =
        sqlight.query(
          get_exercise_templates_query,
          conn,
          [],
          exercise_template_decoder,
        )
        |> result.map_error(fn(err) { QueryError(err) })

      case templates, exercises {
        Ok(templates), Ok(exercises) ->
          templates
          |> list.map(fn(template) {
            let template_exercises =
              exercises
              |> list.filter(fn(ex) { ex.session_template_id == template.id })
              |> list.sort(fn(a, b) {
                case a.sort_order < b.sort_order {
                  True -> order.Lt
                  False ->
                    case a.sort_order > b.sort_order {
                      True -> order.Gt
                      False -> order.Eq
                    }
                }
              })
              |> list.map(fn(ex) {
                case ex.exercise_type {
                  "timed" ->
                    common.TimedExerciseTemplate(
                      ex.name,
                      option.unwrap(ex.duration, 0),
                    )
                  _ ->
                    common.SetsExerciseTemplate(
                      ex.name,
                      option.unwrap(ex.sets, 3),
                      option.unwrap(ex.reps, 10),
                      option.unwrap(ex.weight, 0.0),
                    )
                }
              })
            common.SessionTemplate(
              name: template.name,
              emoji: template.emoji,
              exercises: template_exercises,
            )
          })
          |> Ok
        Error(a), Ok(_) -> Error([a])
        Ok(_), Error(b) -> Error([b])
        Error(a), Error(b) -> Error([a, b])
      }
    }
    Error(a) -> Error([OtherError(string.inspect(a))])
  }
}

const get_session_templates_query = "SELECT id, name, emoji FROM session_templates ORDER BY id"

const get_exercise_templates_query = "SELECT id, session_template_id, name, exercise_type, sets, reps, weight, duration, sort_order FROM exercise_templates ORDER BY session_template_id, sort_order"

// Get a single session template by ID
pub fn get_session_template_by_id(
  id: Int,
) -> Result(common.SessionTemplate, List(DbError)) {
  get_all_session_templates()
  |> result.map(fn(templates) {
    templates
    |> list.find(fn(t) { t.name != "" })
    // For now, just return all and filter - we'll improve this later
  })
  |> result.map_error(fn(e) { e })
  |> result.try(fn(_templates) { Error([OtherError("Not implemented yet")]) })
}

// Delete a session template by name
pub fn delete_session_template(
  template_name: String,
) -> Result(Nil, List(DbError)) {
  let open = sqlight.open(get_sqlite_path() |> result.unwrap(""))
  case open {
    Ok(conn) -> {
      let id_decoder = {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      }
      let get_id_result =
        sqlight.query(
          "SELECT id FROM session_templates WHERE name = $1",
          conn,
          [sqlight.text(template_name)],
          id_decoder,
        )

      case get_id_result {
        Ok([id]) -> {
          // Delete exercise templates first (cascade should handle this but being explicit)
          let _ =
            sqlight.query(
              "DELETE FROM exercise_templates WHERE session_template_id = $1",
              conn,
              [sqlight.int(id)],
              nil_to_empty_list_decoder(),
            )
          // Then delete the session template
          sqlight.query(
            "DELETE FROM session_templates WHERE id = $1",
            conn,
            [sqlight.int(id)],
            nil_to_empty_list_decoder(),
          )
          |> result.map(fn(_) { Nil })
          |> result.map_error(fn(err) { [QueryError(err)] })
        }
        Ok(_) -> Error([OtherError("Template not found: " <> template_name)])
        Error(err) -> Error([QueryError(err)])
      }
    }
    Error(a) -> Error([OtherError(string.inspect(a))])
  }
}

// Create a new session template
pub fn create_session_template(
  name: String,
  emoji: String,
) -> Result(Int, List(DbError)) {
  let open = sqlight.open(get_sqlite_path() |> result.unwrap(""))
  case open {
    Ok(conn) -> {
      let id_decoder = {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      }
      sqlight.query(
        "INSERT INTO session_templates (name, emoji) VALUES ($1, $2) RETURNING id",
        conn,
        [sqlight.text(name), sqlight.text(emoji)],
        id_decoder,
      )
      |> result.map(fn(ids) { ids |> list.first |> result.unwrap(0) })
      |> result.map_error(fn(err) { [QueryError(err)] })
    }
    Error(a) -> Error([OtherError(string.inspect(a))])
  }
}

// Update a session template
pub fn update_session_template(
  old_name: String,
  new_name: String,
  emoji: String,
) -> Result(Nil, List(DbError)) {
  let open = sqlight.open(get_sqlite_path() |> result.unwrap(""))
  case open {
    Ok(conn) -> {
      sqlight.query(
        "UPDATE session_templates SET name = $1, emoji = $2 WHERE name = $3",
        conn,
        [sqlight.text(new_name), sqlight.text(emoji), sqlight.text(old_name)],
        nil_to_empty_list_decoder(),
      )
      |> result.map(fn(_) { Nil })
      |> result.map_error(fn(err) { [QueryError(err)] })
    }
    Error(a) -> Error([OtherError(string.inspect(a))])
  }
}

// Add an exercise to a template
pub fn add_exercise_to_template(
  template_name: String,
  exercise_name: String,
  exercise_type: String,
  sets: option.Option(Int),
  reps: option.Option(Int),
  weight: option.Option(Float),
  duration: option.Option(Int),
) -> Result(Nil, List(DbError)) {
  let open = sqlight.open(get_sqlite_path() |> result.unwrap(""))
  case open {
    Ok(conn) -> {
      let id_decoder = {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      }
      // Get the template id
      let template_id_result =
        sqlight.query(
          "SELECT id FROM session_templates WHERE name = $1",
          conn,
          [sqlight.text(template_name)],
          id_decoder,
        )

      case template_id_result {
        Ok([template_id]) -> {
          // Get max sort_order for this template
          let max_order_decoder = {
            use order <- decode.field(0, decode.optional(decode.int))
            decode.success(order)
          }
          let max_order_result =
            sqlight.query(
              "SELECT MAX(sort_order) FROM exercise_templates WHERE session_template_id = $1",
              conn,
              [sqlight.int(template_id)],
              max_order_decoder,
            )
          let next_order = case max_order_result {
            Ok([option.Some(max)]) -> max + 1
            _ -> 1
          }

          // Insert the exercise
          sqlight.query(
            "INSERT INTO exercise_templates (session_template_id, name, exercise_type, sets, reps, weight, duration, sort_order) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
            conn,
            [
              sqlight.int(template_id),
              sqlight.text(exercise_name),
              sqlight.text(exercise_type),
              case sets {
                option.Some(s) -> sqlight.int(s)
                option.None -> sqlight.null()
              },
              case reps {
                option.Some(r) -> sqlight.int(r)
                option.None -> sqlight.null()
              },
              case weight {
                option.Some(w) -> sqlight.float(w)
                option.None -> sqlight.null()
              },
              case duration {
                option.Some(d) -> sqlight.int(d)
                option.None -> sqlight.null()
              },
              sqlight.int(next_order),
            ],
            nil_to_empty_list_decoder(),
          )
          |> result.map(fn(_) { Nil })
          |> result.map_error(fn(err) { [QueryError(err)] })
        }
        Ok(_) -> Error([OtherError("Template not found: " <> template_name)])
        Error(err) -> Error([QueryError(err)])
      }
    }
    Error(a) -> Error([OtherError(string.inspect(a))])
  }
}

// Delete an exercise from a template by name
pub fn delete_exercise_from_template(
  template_name: String,
  exercise_name: String,
) -> Result(Nil, List(DbError)) {
  let open = sqlight.open(get_sqlite_path() |> result.unwrap(""))
  case open {
    Ok(conn) -> {
      let id_decoder = {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      }
      // Get the template id
      let template_id_result =
        sqlight.query(
          "SELECT id FROM session_templates WHERE name = $1",
          conn,
          [sqlight.text(template_name)],
          id_decoder,
        )

      case template_id_result {
        Ok([template_id]) -> {
          sqlight.query(
            "DELETE FROM exercise_templates WHERE session_template_id = $1 AND name = $2",
            conn,
            [sqlight.int(template_id), sqlight.text(exercise_name)],
            nil_to_empty_list_decoder(),
          )
          |> result.map(fn(_) { Nil })
          |> result.map_error(fn(err) { [QueryError(err)] })
        }
        Ok(_) -> Error([OtherError("Template not found: " <> template_name)])
        Error(err) -> Error([QueryError(err)])
      }
    }
    Error(a) -> Error([OtherError(string.inspect(a))])
  }
}
