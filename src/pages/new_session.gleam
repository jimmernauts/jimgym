import cache
import common
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import lustre/element.{type Element}
import pog
import rada/date
import supabase_client
import wisp.{type Request, type Response}

pub fn new_session(
  req: Request,
  actor: process.Subject(cache.Msg),
  db: pog.Connection,
) -> Response {
  echo "new session req"
  let template_name =
    wisp.get_query(req)
    |> list.key_find("template")
  let templates = cache.get_templates(actor)
  let find_template_in_cache = fn(template_name: String) -> Result(
    common.SessionTemplate,
    Nil,
  ) {
    list.find(templates, fn(template: common.SessionTemplate) {
      template.name == template_name
    })
  }
  let sessions = cache.get_sessions(actor)
  let get_last_session_matching_template = fn(template: common.SessionTemplate) -> Result(
    common.GymSession,
    Nil,
  ) {
    list.find(sessions, fn(session: common.GymSession) {
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
    supabase_client.DbError,
  ) {
    let new_session =
      common.GymSession(
        date: date.today(),
        session_name: matching_session.session_name,
        emoji: matching_session.emoji,
        exercises: matching_session.exercises,
      )
    supabase_client.upsert_session(db, new_session)
  }

  let return_response = fn(result: Result(a, b)) -> Response {
    cache.refresh_sessions(actor, db)
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
