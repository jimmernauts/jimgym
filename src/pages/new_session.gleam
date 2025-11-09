import common.{session_templates}
import gleam/int
import gleam/list
import gleam/result
import lustre/attribute.{attribute, class, id, styles}
import lustre/element.{type Element}
import lustre/element/html.{text}
import rada/date
import sqlite_client
import wisp.{type Request, type Response}

pub fn new_session(req: Request) -> Response {
  let template_name =
    wisp.get_query(req)
    |> list.key_find("template")
  let session_date =
    wisp.get_query(req)
    |> list.key_find("date")
    |> common.try_replacing_error(date.from_iso_string, fn(_) {
      "Error parsing url params"
    })
    |> result.unwrap(date.today())
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
    |> list.sort(fn(session: common.GymSession, session2: common.GymSession) {
      session.date |> date.compare(session2.date)
    })
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
        date: session_date,
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
          session_date |> date.year |> int.to_string
          <> "/"
          <> session_date |> date.month_number |> int.to_string
          <> "/"
          <> session_date |> date.day |> int.to_string,
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
