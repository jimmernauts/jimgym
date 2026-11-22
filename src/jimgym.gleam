import gleam/erlang/process
import gleam/float
import gleam/http.{Get, Post}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import mist
import pages/get_session.{get_session, get_session_mini}
import pages/list_sessions.{list_sessions}
import pages/new_session.{new_session}
import pages/setup
import pages/update_session.{update_session}
import rada/date
import sqlite_client
import wisp.{type Request, type Response}
import wisp/wisp_mist
import workout_pages.{add_input_button, save_session_button}

// -- MAIN --
pub fn main() {
  wisp.configure_logger()
  wisp.set_logger_level(wisp.DebugLevel)
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

pub fn handle_request(req: Request) -> Response {
  let model = sqlite_client.get_all_sessions()
  let assert Ok(priv) = wisp.priv_directory("jimgym")
  use <- wisp.log_request(req)
  use <- wisp.serve_static(req, under: "/", from: priv <> "/static")
  case model, req.method, wisp.path_segments(req), wisp.get_query(req) {
    Error(err), _, _, _ -> {
      echo err
      wisp.not_found()
    }
    Ok(model), Get, [], _ -> {
      let templates =
        sqlite_client.get_all_session_templates() |> result.unwrap([])
      workout_pages.view(workout_pages.home(model, templates), [])
      |> wisp.html_response(200)
    }
    Ok(_), Get, ["setup"], _ -> {
      case sqlite_client.get_all_session_templates() {
        Ok(templates) ->
          workout_pages.view(setup.setup_page(templates), [])
          |> wisp.html_response(200)
        Error(_) -> wisp.internal_server_error()
      }
    }
    Ok(_), Get, ["new"], _ -> new_session(req)
    Ok(_), Get, ["new", _], _ -> new_session(req)
    Ok(model), Get, [year, month], _ -> {
      let year = year |> int.parse |> result.unwrap(date.today() |> date.year)
      let month =
        month |> int.parse |> result.unwrap(date.today() |> date.month_number)

      workout_pages.view(
        list_sessions(
          model
            |> list.filter(fn(session) {
              session.date |> date.month_number == month
              && session.date |> date.year == year
            }),
          year,
          month,
          sqlite_client.get_all_session_templates() |> result.unwrap([]),
        ),
        [],
      )
      |> wisp.html_response(200)
    }
    Ok(model), Get, [year, month, day], params -> {
      let year = year |> int.parse |> result.unwrap(date.today() |> date.year)
      let month =
        month |> int.parse |> result.unwrap(date.today() |> date.month_number)
      let day = day |> int.parse |> result.unwrap(date.today() |> date.day)
      model
      |> list.find(fn(session) {
        date.from_calendar_date(year, month |> date.number_to_month, day)
        == session.date
      })
      |> result.map(fn(session) {
        case params |> list.key_find("mini") {
          Ok(_) ->
            workout_pages.view_fragment(get_session_mini(session))
            |> wisp.html_response(200)
          Error(_) ->
            workout_pages.view(get_session(session, ""), [
              add_input_button(),
              save_session_button(),
            ])
            |> wisp.html_response(200)
        }
      })
      |> result.unwrap(wisp.not_found())
    }
    // Setup POST routes - specific 3-segment routes MUST come before wildcard [year, month, day]
    Ok(_), Post, ["setup", "exercise", "add"], _ -> {
      use formdata <- wisp.require_form(req)
      let template_name =
        formdata.values
        |> list.key_find("template_name")
        |> result.unwrap("")
      let exercise_name =
        formdata.values
        |> list.key_find("exercise_name")
        |> result.unwrap("")
      let exercise_type =
        formdata.values
        |> list.key_find("exercise_type")
        |> result.unwrap("sets")
      let sets =
        formdata.values
        |> list.key_find("sets")
        |> result.try(int.parse)
        |> option.from_result
      let reps =
        formdata.values
        |> list.key_find("reps")
        |> result.try(int.parse)
        |> option.from_result
      let weight =
        formdata.values
        |> list.key_find("weight")
        |> result.try(float.parse)
        |> option.from_result
      let duration =
        formdata.values
        |> list.key_find("duration")
        |> result.try(int.parse)
        |> option.from_result
      case template_name, exercise_name {
        "", _ | _, "" -> wisp.bad_request()
        tmpl, ex -> {
          case
            sqlite_client.add_exercise_to_template(
              tmpl,
              ex,
              exercise_type,
              sets,
              reps,
              weight,
              duration,
            )
          {
            Ok(_) -> wisp.redirect("/setup")
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
    Ok(_), Post, ["setup", "exercise", "delete"], _ -> {
      use formdata <- wisp.require_form(req)
      let template_name =
        formdata.values
        |> list.key_find("template_name")
        |> result.unwrap("")
      let exercise_name =
        formdata.values
        |> list.key_find("exercise_name")
        |> result.unwrap("")
      case template_name, exercise_name {
        "", _ | _, "" -> wisp.bad_request()
        tmpl, ex -> {
          case sqlite_client.delete_exercise_from_template(tmpl, ex) {
            Ok(_) -> wisp.redirect("/setup")
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
    // Date-based POST route (wildcard - must come after specific routes)
    Ok(_), Post, [year, month, day], _ -> {
      let year = year |> int.parse |> result.unwrap(date.today() |> date.year)
      let month =
        month
        |> int.parse
        |> result.unwrap(date.today() |> date.month_number)
        |> date.number_to_month
      let day = day |> int.parse |> result.unwrap(date.today() |> date.day)
      update_session(req, date.from_calendar_date(year, month, day))
    }
    // Setup 2-segment POST routes
    Ok(_), Post, ["setup", "delete"], _ -> {
      use formdata <- wisp.require_form(req)
      let template_name =
        formdata.values
        |> list.key_find("template_name")
        |> result.unwrap("")
      case template_name {
        "" -> wisp.bad_request()
        name -> {
          case sqlite_client.delete_session_template(name) {
            Ok(_) -> wisp.redirect("/setup")
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
    Ok(_), Post, ["setup", "create"], _ -> {
      use formdata <- wisp.require_form(req)
      let template_name =
        formdata.values
        |> list.key_find("template_name")
        |> result.unwrap("")
      let emoji =
        formdata.values
        |> list.key_find("emoji")
        |> result.unwrap("💪")
      case template_name {
        "" -> wisp.bad_request()
        name -> {
          case sqlite_client.create_session_template(name, emoji) {
            Ok(_) -> wisp.redirect("/setup")
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
    Ok(_), Post, ["setup", "update"], _ -> {
      use formdata <- wisp.require_form(req)
      let old_name =
        formdata.values
        |> list.key_find("old_name")
        |> result.unwrap("")
      let new_name =
        formdata.values
        |> list.key_find("new_name")
        |> result.unwrap("")
      let emoji =
        formdata.values
        |> list.key_find("emoji")
        |> result.unwrap("💪")
      case old_name, new_name {
        "", _ | _, "" -> wisp.bad_request()
        old, new -> {
          case sqlite_client.update_session_template(old, new, emoji) {
            Ok(_) -> wisp.redirect("/setup")
            Error(_) -> wisp.internal_server_error()
          }
        }
      }
    }
    _, _, _, _ -> wisp.not_found()
  }
}
//----VIEWS------------------------------------------------------------
