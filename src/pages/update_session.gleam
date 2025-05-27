import cache
import common
import gleam/bool
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import pog
import rada/date
import sqlite_client
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
  let return_response = fn(result: Result(a, b)) -> Response {
    cache.refresh_sessions(actor, db)
    case result {
      Ok(_) -> wisp.redirect("/")
      Error(_) -> wisp.internal_server_error()
    }
  }
  use fd <- wisp.require_form(req)
  {
    parse_formdata_to_session(date, fd)
    |> common.try_replacing_error(
      fn(session) { sqlite_client.upsert_session(session) },
      fn(err) {
        echo err
        [sqlite_client.OtherError(err)]
      },
    )
    |> echo
    |> return_response
  }
}

pub fn parse_formdata_to_session(
  date: date.Date,
  fd: wisp.FormData,
) -> Result(common.GymSession, String) {
  let exercise_form_data =
    fd.values
    |> list.filter(fn(kv) {
      let a =
        kv.0
        |> string.contains("session_name")

      let b =
        kv.0
        |> string.contains("session_emoji")
      bool.nor(a, b)
    })
  let session_name =
    fd.values
    |> list.find(fn(kv) { kv.0 == "session_name" })
  let emoji =
    fd.values
    |> list.find(fn(kv) { kv.0 == "session_emoji" })
  let exercises = parse_exercises(exercise_form_data)
  case session_name, emoji {
    Ok(session_name), Ok(emoji) ->
      Ok(common.GymSession(
        date: date,
        emoji: emoji.1,
        exercises: exercises,
        session_name: session_name.1,
      ))
    _, _ -> Error("Missing session name or emoji")
  }
}

fn parse_exercises(
  values_list: List(#(String, String)),
) -> dict.Dict(String, List(common.Exercise)) {
  values_list
  |> list.group(fn(kv) {
    kv.0 |> string.split("|") |> common.list_first_and_last
  })
  |> dict.map_values(fn(_k, v) {
    v
    |> list.map(fn(kv) {
      #(
        kv.0 |> string.split("|") |> common.list_at(1) |> option.unwrap(""),
        kv.1,
      )
    })
  })
  |> dict.map_values(fn(_k, v) {
    v
    |> exercise_from_kv_list
  })
  |> dict.values
  |> common.list_keep_ok
  |> list.group(fn(ex) { ex.name })
}

fn exercise_from_kv_list(
  kv_list: List(#(String, String)),
) -> Result(common.Exercise, Nil) {
  let name = kv_list |> list.find(fn(kv) { kv.0 == "name" })
  let duration = kv_list |> list.find(fn(kv) { kv.0 == "duration" })
  let reps = kv_list |> list.find(fn(kv) { kv.0 == "reps" })
  let weight = kv_list |> list.find(fn(kv) { kv.0 == "weight" })
  case name, duration, reps, weight {
    Ok(name), _, Ok(reps), Ok(weight) ->
      Ok(common.SetsExercise(
        name.1,
        int.parse(reps.1) |> result.unwrap(0),
        common.float_parse_tolerant(weight.1),
      ))
    Ok(name), Ok(duration), _, _ ->
      Ok(common.TimedExercise(name.1, int.parse(duration.1) |> result.unwrap(0)))
    _, _, _, _ -> Error(Nil)
  }
}
