import common
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/string_tree
import pages/get_session
import pages/list_sessions
import pages/setup
import rada/date
import workout_pages

pub fn render_page(
  page: String,
  year: Int,
  month: Int,
  action: String,
  payload: String,
) -> Result(String, Nil) {
  let decoder = {
    use sessions <- decode.field("sessions", decode.list(session_decoder()))
    use templates <- decode.field("templates", decode.list(template_decoder()))
    decode.success(#(sessions, templates))
  }
  use model <- result.try(
    json.parse(payload, decoder) |> result.replace_error(Nil),
  )
  let #(sessions, templates) = model
  case page, sessions {
    "home", _ ->
      Ok(
        workout_pages.view(workout_pages.home(sessions, templates), [])
        |> string_tree.to_string,
      )
    "calendar", _ ->
      Ok(
        workout_pages.view(
          list_sessions.list_sessions(sessions, year, month, templates),
          [],
        )
        |> string_tree.to_string,
      )
    "setup", _ ->
      Ok(
        workout_pages.view(setup.setup_page(templates), [])
        |> string_tree.to_string,
      )
    "preview", [session] ->
      Ok(
        workout_pages.view_fragment(get_session.get_session_mini(session))
        |> string_tree.to_string,
      )
    "editor", [session] -> Ok(editor(session, action))
    _, _ -> Error(Nil)
  }
}

pub fn new_workout(
  iso: String,
  action: String,
  payload: String,
) -> Result(String, Nil) {
  use workout_date <- result.try(
    date.from_iso_string(iso) |> result.replace_error(Nil),
  )
  use template <- result.map(
    json.parse(payload, template_decoder()) |> result.replace_error(Nil),
  )
  editor(
    common.GymSession(
      workout_date,
      template.name,
      common.exercises_from_template(template.exercises),
      template.emoji,
    ),
    action,
  )
}

fn editor(session: common.GymSession, action: String) -> String {
  workout_pages.view(get_session.get_session(session, action), [
    workout_pages.add_input_button(),
    workout_pages.save_session_button(),
  ])
  |> string_tree.to_string
}

fn session_decoder() -> decode.Decoder(common.GymSession) {
  use iso <- decode.field("date", decode.string)
  case date.from_iso_string(iso) {
    Error(_) ->
      decode.failure(
        common.GymSession(
          date.from_rata_die(1),
          "",
          common.exercises_from_template([]),
          "",
        ),
        "ISO date",
      )
    Ok(workout_date) -> {
      use name <- decode.field("session_name", decode.optional(decode.string))
      use emoji <- decode.field("emoji", decode.optional(decode.string))
      use exercises <- decode.field(
        "exercises",
        decode.list(exercise_decoder(workout_date)),
      )
      decode.success(common.GymSession(
        workout_date,
        option.unwrap(name, "Workout"),
        common.group_records_into_exercises(exercises),
        option.unwrap(emoji, "💪"),
      ))
    }
  }
}

fn exercise_decoder(
  workout_date: date.Date,
) -> decode.Decoder(common.ExerciseRecord) {
  use name <- decode.field("name", decode.string)
  use reps <- decode.field("reps", decode.optional(decode.int))
  use weight <- decode.field("weight", decode.optional(decode.float))
  use duration <- decode.field("duration", decode.optional(decode.int))
  decode.success(common.ExerciseRecord(
    workout_date,
    name,
    reps,
    weight,
    duration,
  ))
}

fn template_decoder() -> decode.Decoder(common.SessionTemplate) {
  use name <- decode.field("name", decode.string)
  use emoji <- decode.field("emoji", decode.string)
  use exercises <- decode.field(
    "exercises",
    decode.list(template_exercise_decoder()),
  )
  decode.success(common.SessionTemplate(name, emoji, exercises))
}

fn template_exercise_decoder() -> decode.Decoder(common.ExerciseTemplate) {
  use name <- decode.field("name", decode.string)
  use kind <- decode.field("exercise_type", decode.string)
  case kind {
    "timed" -> {
      use duration <- decode.field("duration", decode.optional(decode.int))
      decode.success(common.TimedExerciseTemplate(
        name,
        option.unwrap(duration, 0),
      ))
    }
    _ -> {
      use sets <- decode.field("sets", decode.optional(decode.int))
      use reps <- decode.field("reps", decode.optional(decode.int))
      use weight <- decode.field("weight", decode.optional(decode.float))
      decode.success(common.SetsExerciseTemplate(
        name,
        option.unwrap(sets, 3),
        option.unwrap(reps, 10),
        option.unwrap(weight, 0.0),
      ))
    }
  }
}
