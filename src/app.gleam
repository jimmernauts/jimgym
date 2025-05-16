import common.{type Exercise, ExerciseRecord, GymSession, SetsExercise, TimedExercise}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/io
import lustre/attribute.{class, href, lang, name, rel, type_, value, method, action, step, for, id}
import lustre/element.{type Element, to_document_string}
import lustre/element/html
import mist
import rada/date
// import review // Commented out as review page is not part of this SSR refactor phase
import wisp.{type Request, type Response}
import wisp/wisp_mist
import gleam/http/client
import gleam/http
import exercise_actor
import supabase_client
import wisp/http_context

// Application context to hold shared resources like actor PID and HTTP client
pub type AppContext {
  AppContext(actor_subject: process.Subject(exercise_actor.Msg), http_client: client.Client)
}

// Client-side Model and Msg - Commented out for SSR refactor
// pub type Msg {
//   StartNewSession(Option(common.SessionTemplate))
//   RemoveSetFromCurrentSessionExercises(Int, String)
//   UpdatedExerciseAtIndex(Int, common.Exercise)
//   EndActiveSession
//   SaveSession(common.GymSession)
//   QueueRetrievePastSessions
//   RetrievedPastSessions(List(common.GymSession))
//   UpdateSessionTemplates(List(common.SessionTemplate))
//   HandleRouteChange(Route)
//   ShowTimer(Int)
//   TimerTick
//   TimerStarted(Int)
//   PlayAlarm
//   CancelAlarm
//   Review(review.ReviewMsg)
// }
// 
// pub type Route {
//   Home
//   CurrentSessionPage
//   ReviewPage(Option(date.Date))
// }
// 
// pub type Model {
//   Model(
//     current_route: Route,
//     sessions: List(common.GymSession),
//     session_templates: List(common.SessionTemplate),
//     review_model: review.ReviewModel,
//   )
// }
// 
// fn init(_flags) -> Model {
//   let initial_route = Home
//   Model(
//     current_route: initial_route,
//     sessions: [],
//     session_templates: [
//       // ... (session templates from original code) ...
//     ],
//     review_model: review.ReviewModel(
//       current_month: date.month(date.today()),
//       session_dates: [],
//       current_year: date.year(date.today()),
//       selected_session: None,
//     ),
//   )
// }

// -- SSR VIEW FUNCTIONS --

// Renders the main content for the home page, including sessions and an add form.
fn view_ssr_home(sessions: List(GymSession)) -> List(Element(Nil)) {
  let today_iso = date.to_iso_string(date.today())
  [
    html.h1([class("text-5xl font-bold my-6 text-center text-indigo-600")], [html.text("JimGym Tracker")]),
    html.section([class("mb-8 p-4 bg-white shadow-md rounded-lg")], [
      html.h2([class("text-2xl font-semibold mb-4 text-gray-700")], [html.text("Add New Exercise Record")]),
      html.form([action("/add-record"), method("POST"), class("space-y-4")], [
        html.div([class("flex flex-col")], [
          html.label([for("date"), class("mb-1 font-medium text-gray-600")], [html.text("Date:")]),
          html.input([
            type_("date"), id("date"), name("date"), value(today_iso),
            class("p-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"),
          ]),
        ]),
        html.div([class("flex flex-col")], [
          html.label([for("name"), class("mb-1 font-medium text-gray-600")], [html.text("Exercise Name:")]),
          html.input([
            type_("text"), id("name"), name("name"), attribute.required(True),
            class("p-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"),
          ]),
        ]),
        html.div([class("grid grid-cols-1 md:grid-cols-3 gap-4")], [
          html.div([class("flex flex-col")], [
            html.label([for("reps"), class("mb-1 font-medium text-gray-600")], [html.text("Reps (optional):")]),
            html.input([
              type_("number"), id("reps"), name("reps"), step(1),
              class("p-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"),
            ]),
          ]),
          html.div([class("flex flex-col")], [
            html.label([for("weight"), class("mb-1 font-medium text-gray-600")], [html.text("Weight (kg, optional):")]),
            html.input([
              type_("number"), id("weight"), name("weight"), step("0.01"),
              class("p-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"),
            ]),
          ]),
          html.div([class("flex flex-col")], [
            html.label([for("duration"), class("mb-1 font-medium text-gray-600")], [html.text("Duration (mins, optional):")]),
            html.input([
              type_("number"), id("duration"), name("duration"), step(1),
              class("p-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"),
            ]),
          ]),
        ]),
        html.button([
          type_("submit"), 
          class("w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded-md focus:outline-none focus:shadow-outline transition duration-150 ease-in-out")
        ], [html.text("Add Record")]),
      ]),
    ]),
    html.section([class("p-4 bg-white shadow-md rounded-lg")], [
      html.h2([class("text-2xl font-semibold mb-4 text-gray-700")], [html.text("Recorded Sessions")]),
      case sessions {
        [] -> html.p([class("text-gray-500")], [html.text("No sessions recorded yet.")])
        _ -> 
          html.ul([class("space-y-6")], 
            list.map(sessions, fn(session) {
              html.li([class("p-4 border border-gray-200 rounded-lg bg-gray-50")], [
                html.h3([class("text-xl font-semibold text-indigo-700 mb-2")], [
                  html.text(date.format(session.date, "%A, %B %d, %Y") <> " " <> session.emoji)
                ]),
                html.ul([class("list-disc list-inside pl-4 space-y-1")],
                  dict.to_list(session.exercises)
                  |> list.flat_map(fn(item) {
                    let exercise_name = item.0
                    let exercises_list = item.1
                    list.map(exercises_list, fn(ex) {
                      let details_text = case ex {
                        SetsExercise(_, reps, weight, _) -> " - " <> int.to_string(reps) <> " reps at " <> float.to_string(weight) <> "kg"
                        TimedExercise(_, duration) -> " - " <> int.to_string(duration) <> " minutes"
                      }
                      html.li([class("text-gray-600")], [html.text(exercise_name <> details_text)])
                    })
                  })
                )
              ])
            })
          )
      }
    ]),
  ]
}

// Renders the basic HTML page structure.
fn view_ssr_page(page_content: List(Element(Nil))) -> Response {
  let document = 
    html.html([
      lang("en"),
      class("bg-gray-100 text-gray-800 font-sans text-lg scroll-smooth"),
    ], [
      html.head([], [
        html.meta([html.charset("utf-8")]),
        html.title([], [html.text("JimGym - SSR")]),
        html.meta([name("viewport"), content("width=device-width, initial-scale=1")]),
        html.link([rel("stylesheet"), href("/static/app.css")]),
      ]),
      html.body([class("container mx-auto p-4")], page_content),

    ])

  // The `element.map` above with `todo` means we are not handling any messages from these elements.
  // For SSR, this is usually fine if there are no client-side interactions driven by Lustre messages.
  let rendered_html = 
    lustre.element.to_document_string(document)
    |> string.replace("<!DOCTYPE html>", "") // Lustre adds this, remove if not desired or if Mist adds it.

  wisp.html_response(rendered_html)
  |> wisp.prepend_header("cache-control", "no-store, max-age=0, must-revalidate")
}


// Server-side request handling
fn handle_request(ctx: AppContext, request: Request) -> Response {
  use req <- wisp.rescue_method_not_allowed(request)
  use req <- wisp.rescue_unsupported_media_type(req)
  use _ <- wisp.serve_static(req, under: "/static", from: "priv/static")

  let AppContext(actor_subject, http_client) = ctx

  case req.method, req.path {
    wisp.Get, "/" -> {
      let sessions = exercise_actor.get_sessions(actor_subject)
      // io.debug("Fetched sessions from actor: " <> string.inspect(sessions))
      view_ssr_page(view_ssr_home(sessions))
    }
    wisp.Post, "/add-record" -> {
      // io.debug("POST /add-record received")
      // Parse form data
      use form_data <- result.try(wisp.parse_body_form(req))
      // io.debug("Form data: " <> string.inspect(form_data))

      let date_str = dict.get(form_data, "date") |> result.unwrap_or("")
      let name_str = dict.get(form_data, "name") |> result.unwrap_or("")
      let reps_str = dict.get(form_data, "reps") |> result.unwrap_or("")
      let weight_str = dict.get(form_data, "weight") |> result.unwrap_or("")
      let duration_str = dict.get(form_data, "duration") |> result.unwrap_or("")

      // Validate and construct ExerciseRecord
      // Basic validation: name and date must be present
      case name_str == "" || date_str == "" {
        True -> wisp.bad_request_response("Name and Date are required.")
        False -> {
          let reps_opt = case string.is_empty(reps_str) { True -> None False -> int.parse(reps_str) |> result.to_option }
          let weight_opt = case string.is_empty(weight_str) { True -> None False -> float.parse(weight_str) |> result.to_option }
          let duration_opt = case string.is_empty(duration_str) { True -> None False -> int.parse(duration_str) |> result.to_option }

          let record = ExerciseRecord(
            date: date_str, 
            name: name_str, 
            reps: reps_opt, 
            weight: weight_opt, 
            duration: duration_opt
          )
          // io.debug("Constructed record: " <> string.inspect(record))

          case supabase_client.add_exercise_record(http_client, record) {
            Ok(_) -> {
              // io.debug("Record added to Supabase. Refreshing actor state.")
              // Refresh actor state by fetching all sessions again
              case supabase_client.fetch_all_gym_sessions(http_client) {
                Ok(all_sessions) -> exercise_actor.set_initial_sessions(actor_subject, all_sessions)
                Error(fetch_err) -> io.debug("Error fetching sessions after add: " <> string.inspect(fetch_err))
              }
              wisp.redirect_response("/", wisp.Found) // 302 Found
            }
            Error(add_err) -> {
              io.debug("Error adding record to Supabase: " <> string.inspect(add_err))
              // Consider showing an error page or message
              wisp.html_response("<html><body><h1>Error adding record.</h1><p>" <> string.inspect(add_err) <> "</p><a href='/'>Go back</a></body></html>")
              |> wisp.set_status(500)
            }
          }
        }
      }
    }
    _, _ -> wisp.not_found_response("Page not found.")
  }
}

// -- ROUTING -- // SSR does not use client-side routing in the same way.

// -- HTTP Requests & Local Storage -- These will be handled server-side or differently in SSR.

// -- MAIN --
pub fn main() {
  // Initialize Supabase client and ExerciseActor
  let assert Ok(http_client) = client.new()
  let actor_subject = exercise_actor.start() // exercise_actor.start() now returns Subject(Msg) and panics on error
  let app_context = AppContext(actor_subject: actor_subject, http_client: http_client)

  // Fetch initial data from Supabase and populate the actor
  case supabase_client.fetch_all_gym_sessions(http_client) { // Corrected to use http_client
    Ok(initial_sessions) -> {
      // io.debug("Fetched initial sessions: " <> string.inspect(initial_sessions))
      exercise_actor.set_initial_sessions(actor_pid, initial_sessions)
    }
    Error(err) -> {
      io.debug("Failed to fetch initial sessions: " <> string.inspect(err))
      // Proceed without initial data, or handle error as appropriate
    }
  }
  
  let service_handler = fn(req: Request, app_data: AppContext) -> Response {
    handle_request(app_data, req)
  }

  let get_app_data = fn(_wisp_context: wisp.WispContext) -> AppContext {
    app_context
  }

  let service = wisp_mist.service(service_handler, get_app_data)
  let assert Ok(_) = mist.serve_on_port(service, address: "0.0.0.0", port: 8080)
  process.sleep_forever()
}


// Helper function to create exercises from a session template
fn exercises_from_template(
  template: common.SessionTemplate,
) -> #(String, List(Exercise)) {
  #(template.name, case template {
    SetsExerciseTemplate(name, sets, reps, weight, rest) ->
      list.repeat(SetsExercise(name, reps, weight, rest), sets)
    TimedExerciseTemplate(name, duration) -> [TimedExercise(name, duration)]
  })
}

