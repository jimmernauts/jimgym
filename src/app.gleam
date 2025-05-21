import cache
import common.{
  type Exercise, ExerciseRecord, GymSession, SessionTemplate, SetsExercise,
  SetsExerciseTemplate, TimedExercise, TimedExerciseTemplate,
}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/float
import gleam/http.{Get, Post}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/attribute.{
  attribute, charset, class, content, href, id, name, rel, type_,
}
import lustre/element.{type Element, to_document_string}
import lustre/element/html.{
  a, button, details, div, h1, h3, nav, section, summary, table, tbody, td, text,
  th, tr,
}
import mist
import pages/get_session.{get_session, get_session_mini}
import pages/list_sessions.{list_sessions}
import pages/new_session.{new_session}
import pages/update_session.{update_session}
import pog
import rada/date
import supabase_client
import wisp.{type Request, type Response}
import wisp/wisp_mist

// -- MAIN --
pub fn main() {
  let assert Ok(db) = supabase_client.connect_db()

  let actor = cache.start()
  supabase_client.get_all_sessions(db)
  |> echo
  |> result.unwrap([])
  |> cache.set_sessions(actor)

  session_templates
  |> cache.set_templates(actor)

  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request(_, actor, db), secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

pub fn handle_request(
  req: Request,
  actor: process.Subject(cache.Msg),
  db: pog.Connection,
) -> Response {
  let model = cache.get_sessions(actor)
  let assert Ok(priv) = wisp.priv_directory("app")
  use <- wisp.log_request(req)
  use <- wisp.serve_static(req, under: "/", from: priv <> "/static")
  case req.method, wisp.path_segments(req), wisp.get_query(req) {
    Get, [], _ -> view(home(req, model), [])
    Get, ["new"], _ -> new_session(req, actor, db)
    Get, [year, month], _ -> {
      let year = year |> int.parse |> result.unwrap(date.today() |> date.year)
      let month =
        month |> int.parse |> result.unwrap(date.today() |> date.month_number)

      view(
        list_sessions(
          req,
          model
            |> list.filter(fn(session) {
              session.date |> date.month_number == month
              && session.date |> date.year == year
            }),
          year,
          month,
        ),
        [],
      )
    }
    Get, [year, month, day], params -> {
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
          Ok(_) -> view_fragment(get_session_mini(req, session))
          Error(_) -> view(get_session(req, session), [save_session_button()])
        }
      })
      |> result.unwrap(wisp.not_found())
    }
    Post, [year, month, day], _ -> {
      let year = year |> int.parse |> result.unwrap(date.today() |> date.year)
      let month =
        month
        |> int.parse
        |> result.unwrap(date.today() |> date.month_number)
        |> date.number_to_month
      let day = day |> int.parse |> result.unwrap(date.today() |> date.day)
      update_session(req, date.from_calendar_date(year, month, day), actor, db)
    }
    _, _, _ -> wisp.not_found()
  }
}

fn save_session_button() -> Element(a) {
  html.button(
    [
      attribute.form("session-form"),
      attribute.formmethod("post"),
      class("self-center"),
    ],
    [text("💾")],
  )
}

const session_templates = [
  SessionTemplate(
    "Whole Body A",
    "💪",
    [
      SetsExerciseTemplate("Sled Drag", 5, 10, 20.0),
      SetsExerciseTemplate("Sled Push", 5, 10, 20.0),
      SetsExerciseTemplate("Bench Press", 3, 10, 20.0),
      SetsExerciseTemplate("Rows", 3, 10, 20.0),
    ],
  ),
  SessionTemplate(
    "Whole Body B",
    "🏋️",
    [
      SetsExerciseTemplate("Sled Drag", 5, 10, 20.0),
      SetsExerciseTemplate("Deadlifts", 3, 10, 20.0),
      SetsExerciseTemplate("Pull-ups", 3, 8, 14.0),
      SetsExerciseTemplate("Shoulder Press", 3, 8, 20.0),
    ],
  ),
  SessionTemplate(
    "Rehab",
    "🧎",
    [
      SetsExerciseTemplate("Sled Drag", 5, 10, 20.0),
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

//----VIEWS------------------------------------------------------------

pub fn view(body: List(Element(a)), nav_elements: List(Element(a))) -> Response {
  html.html([], [
    html.head([], [
      html.meta([
        charset("UTF-8"),
        name("viewport"),
        content("width=device-width, initial-scale=1.0"),
      ]),
      html.title([], "Jim's Gym Tracker"),
      html.link([rel("icon"), href("/favicon.svg"), type_("image/svg+xml")]),
      html.link([rel("stylesheet"), href("/app.css")]),
      html.script([attribute.src("/fixi.js")], ""),
    ]),
    html.body([], [
      html.main(
        [
          class(
            "h-dvh grid p-2 gap-2
    2xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_90%_[main-end]_3fr_[full-end]_1fr_[end]]
    xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
    lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
    md:grid-cols-[[start_full-start]_1fr_[main-start]_95%_[main-end]_1fr_[full-end_end]]
    grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]
    grid-rows-[[header]_1fr_[content]_8fr_[footer]_1fr]
    font-hand",
          ),
        ],
        body |> common.list_append_one(view_nav(nav_elements)),
      ),
    ]),
  ])
  |> element.to_document_string_tree
  |> wisp.html_response(200)
}

pub fn view_fragment(fragment: List(Element(a))) -> Response {
  case fragment {
    [a, ..rest] -> element.fragment(fragment)
    [a] -> a
    [] -> element.none()
  }
  |> element.to_string_tree
  |> wisp.html_response(200)
}

pub fn home(_req: Request, model: List(common.GymSession)) -> List(Element(a)) {
  let sessions = model
  [
    h1(
      [
        class(
          "text-7xl font-bold col-[main-start_/_main-end] row-start-[header]",
        ),
      ],
      [text("💪🤸‍♂️🏋️")],
    ),
    section(
      [
        class(
          "mt-4 font-slab flex flex-col gap-4  col-[main-start_/_main-end] row-start-[content]",
        ),
      ],
      [
        case list.find(sessions, fn(session) { session.date == date.today() }) {
          Error(_) ->
            button(
              [
                class(
                  "bg-uchu-light-gray border-2 border-uchu-yin rounded-md overflow-hidden col-span-6 p-3 cursor-pointer flex gap-2 justify-start items-center",
                ),
                attribute.attribute("popovertarget", "session-template-picker"),
              ],
              [
                h1([class("font-bold text-3xl")], [text("🟢 ")]),
                h1([class("font-bold text-3xl")], [text("Start new session")]),
              ],
            )
          Ok(_) ->
            a(
              [
                class(
                  "font-slab font-bold flex justify-start p-3 text-3xl text-uchu-yin fill-diagonal-uchu-light-gray border-uchu-yin border-2 rounded-md col-span-6 gap-2 items-center",
                ),
                attribute.href(
                  "/"
                  <> date.today() |> date.year |> int.to_string
                  <> "/"
                  <> date.today() |> date.month_number |> int.to_string
                  <> "/"
                  <> date.today() |> date.day |> int.to_string,
                ),
              ],
              [
                h1([class("font-bold text-3xl")], [text("⌛ ")]),
                h1([class("font-bold text-3xl")], [text("Session in progress")]),
              ],
            )
        },
        a(
          [
            class(
              "bg-uchu-light-gray border-2 border-uchu-yin rounded-md overflow-hidden col-span-6 p-3 cursor-pointer flex gap-2 justify-start items-center",
            ),
            attribute.href(
              "/"
              <> date.today() |> date.year |> int.to_string
              <> "/"
              <> date.today() |> date.month_number |> int.to_string,
            ),
          ],
          [
            h1([class("font-bold text-3xl")], [text("🕵️ ")]),
            h1([class("font-bold text-3xl")], [text("Review")]),
          ],
        ),
      ],
    ),
    section(
      [
        class(
          "mt-19 mb-16 font-slab bg-white p-2 row-start-2 h-full w-full overflow-y-auto",
        ),
        attribute("popover", ""),
        id("session-template-picker"),
      ],
      [
        div(
          [class("flex flex-col gap-4")],
          session_templates |> list.map(view_session_template_card),
        ),
      ],
    ),
  ]
}

//--VIEW HELPERS------------------------------------------------------------------

fn view_nav(children: List(Element(a))) -> Element(a) {
  nav(
    [
      class(
        "col-[main-start_/_main-end] row-start-[footer] text-2xl p-4 border-t-1 border-uchu-yin gap-6 flex justify-around flex-row",
      ),
    ],
    [a([attribute.href("/"), class("self-center")], [text("🏡")]), ..children],
  )
}

fn view_session_template_card(template: common.SessionTemplate) -> Element(a) {
  details(
    [
      class(
        "bg-white border-2 font-hand border-uchu-yin rounded-md overflow-hidden",
      ),
    ],
    [
      summary(
        [
          class(
            "p-3 bg-uchu-light-gray cursor-pointer flex justify-between items-center",
          ),
        ],
        [
          h3([class("font-slab font-bold text-3xl")], [
            text(template.emoji <> " " <> template.name),
          ]),
        ],
      ),
      div([class("p-4 border-t border-uchu-yin")], [
        table([class("w-full text-sm")], [
          tbody(
            [],
            template.exercises
              |> list.map(fn(exercise) {
                case exercise {
                  SetsExerciseTemplate(name, sets, reps, weight) ->
                    view_set_exercise_row(name, sets, reps, weight)
                  TimedExerciseTemplate(name, duration) ->
                    view_timed_exercise_row(name, duration)
                }
              }),
          ),
        ]),
        a(
          [
            class(
              "mt-4 w-full p-2 bg-uchu-light-gray font-bold font-slab border cursor-pointer border-uchu-yin rounded-md",
            ),
            attribute.href("/new?template=" <> template.name),
          ],
          [text("Start Session")],
        ),
      ]),
    ],
  )
}

fn view_timed_exercise_row(name: String, duration: Int) {
  tr([class("border-b border-gray-100")], [
    td([class("py-1 text-center")], [text(int.to_string(duration) <> "m")]),
    td([class("py-1")], [text(name)]),
  ])
}

fn view_set_exercise_row(name: String, sets: Int, reps: Int, weight: Float) {
  tr([class("border-b border-gray-100")], [
    td([class("py-1 text-center")], [
      text(int.to_string(sets) <> "×" <> int.to_string(reps)),
    ]),
    td([class("py-1")], [text(name)]),
    td([class("py-1 text-center")], [
      text(case weight {
        0.0 -> ""
        weight -> {
          // Check if it's effectively an integer
          let int_part = float.truncate(weight)
          let decimal_part = weight -. int.to_float(int_part)

          case decimal_part <. 0.01 || decimal_part >. 0.99 {
            True -> int.to_string(int_part) <> "kg"
            // Format with one decimal place
            False -> {
              let decimal_str =
                decimal_part *. 10.0
                |> float.round
                |> int.to_string

              int.to_string(int_part) <> "." <> decimal_str <> "kg"
            }
          }
        }
      }),
    ]),
  ])
}

//-----DB --------------------------------------------------------------------------

fn flatten_session(session: common.GymSession) -> List(common.ExerciseRecord) {
  dict.values(session.exercises)
  |> list.flatten
  |> list.map(fn(exercise) {
    case exercise {
      SetsExercise(name, reps, weight) ->
        ExerciseRecord(
          date: session.date,
          name: name,
          reps: Some(reps),
          weight: Some(weight),
          duration: None,
        )
      TimedExercise(name, duration) ->
        ExerciseRecord(
          date: session.date,
          name: name,
          reps: None,
          weight: None,
          duration: Some(duration),
        )
    }
  })
}
