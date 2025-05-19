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
  echo req
  let template_name =
    wisp.get_query(req)
    |> list.key_find("template")
    |> result.unwrap("No template")

  let emoji =
    wisp.get_query(req)
    |> list.key_find("emoji")
    |> result.unwrap("⁉️")

  let res =
    supabase_client.insert_session(
      db,
      common.GymSession(
        date: date.today(),
        session_name: template_name,
        emoji: emoji,
        exercises: dict.new(),
      ),
    )

  case res {
    Ok(_) -> {
      cache.refresh_sessions(actor, db)
      wisp.redirect(
        date.today() |> date.year |> int.to_string
        <> "/"
        <> date.today() |> date.month_number |> int.to_string
        <> "/"
        <> date.today() |> date.day |> int.to_string,
      )
    }
    Error(_) -> wisp.internal_server_error()
  }
}
