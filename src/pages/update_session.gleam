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

pub fn update_session(
  req: Request,
  date: date.Date,
  actor: process.Subject(cache.Msg),
  db: pog.Connection,
) -> Response {
  // pretty similar to new_session

  // get form data from req object

  // parse it into the shape needed by the DB

  // refresh the cache

  // redirect to the get session page for this session
  echo "new session req"
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
  use fd <- wisp.require_form(req)
  {
    parse_formdata_to_session(fd)
    |> common.try_replacing_error(
      fn(session) { supabase_client.upsert_session(db, session) },
      fn(err) { supabase_client.OtherError(err) },
    )
    |> return_response
  }
}

pub fn parse_formdata_to_session(
  fd: wisp.FormData,
) -> Result(common.GymSession, String) {
  echo fd
  Error("not implemented")
}
