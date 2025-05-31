import common.{SessionTemplate, SetsExerciseTemplate, TimedExerciseTemplate}
import gleam/int
import gleam/list
import gleam/result
import rada/date
import sqlite_client
import wisp.{type Request, type Response}

const session_templates = [
  SessionTemplate(
    "Whole Body A",
    "💪",
    [
      SetsExerciseTemplate("Sled Drag", 1, 5, 20.0),
      SetsExerciseTemplate("Sled Push", 1, 3, 20.0),
      SetsExerciseTemplate("Bench Press", 3, 10, 35.0),
      SetsExerciseTemplate("Rows", 3, 10, 25.0),
    ],
  ),
  SessionTemplate(
    "Whole Body B",
    "🏋️",
    [
      SetsExerciseTemplate("Sled Drag", 1, 5, 20.0),
      SetsExerciseTemplate("ATG Squat", 3, 10, 0.0),
      SetsExerciseTemplate("Pull-ups", 3, 8, 14.0),
      SetsExerciseTemplate("Shoulder Press", 3, 8, 20.0),
    ],
  ),
  SessionTemplate(
    "Rehab",
    "🧎",
    [
      SetsExerciseTemplate("Sled Drag", 1, 5, 20.0),
      SetsExerciseTemplate("Patrick Step", 3, 20, 0.0),
    ],
  ),
  SessionTemplate(
    "Cardio",
    "🏃",
    [
      TimedExerciseTemplate("Backwards Treadmill", 20),
      TimedExerciseTemplate("Rowing", 10),
    ],
  ),
]

pub fn new_session(req: Request) -> Response {
  let template_name =
    wisp.get_query(req)
    |> list.key_find("template")
  let find_template_in_cache = fn(template_name: String) -> Result(
    common.SessionTemplate,
    Nil,
  ) {
    list.find(session_templates, fn(template: common.SessionTemplate) {
      template.name == template_name
    })
  }
  let sessions = sqlite_client.get_all_sessions()
  let get_last_session_matching_template = fn(template: common.SessionTemplate) -> Result(
    common.GymSession,
    Nil,
  ) {
    sessions
    |> result.unwrap([])
    |> list.find(fn(session: common.GymSession) {
      session.session_name == template.name
    })
  }
  let fallback_session = fn() -> Result(common.GymSession, Nil) {
    template_name
    |> result.try(find_template_in_cache)
    |> result.map(fn(t) { #(t.name, t.emoji, t.exercises) })
    |> result.map(fn(t) {
      common.GymSession(
        date: date.today(),
        session_name: t.0,
        emoji: t.1,
        exercises: t.2 |> common.exercises_from_template,
      )
    })
  }

  let insert_session = fn(matching_session: common.GymSession) -> Result(
    Nil,
    List(sqlite_client.DbError),
  ) {
    let new_session =
      common.GymSession(
        date: date.today(),
        session_name: matching_session.session_name,
        emoji: matching_session.emoji,
        exercises: matching_session.exercises,
      )
    sqlite_client.upsert_session(new_session)
  }

  let return_response = fn(result: Result(a, b)) -> Response {
    case result {
      Ok(_) ->
        wisp.redirect(
          date.today() |> date.year |> int.to_string
          <> "/"
          <> date.today() |> date.month_number |> int.to_string
          <> "/"
          <> date.today() |> date.day |> int.to_string,
        )
      Error(_) -> wisp.internal_server_error()
    }
  }

  template_name
  |> result.try(find_template_in_cache)
  |> result.try(get_last_session_matching_template)
  |> result.lazy_or(fallback_session)
  |> result.map(insert_session)
  |> result.map(return_response)
  |> result.unwrap(wisp.internal_server_error())
}
