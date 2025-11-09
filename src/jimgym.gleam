import common.{SetsExerciseTemplate, TimedExerciseTemplate, session_templates}
import gleam/erlang/process
import gleam/float
import gleam/http.{Get, Post}
import gleam/int
import gleam/list
import gleam/result
import lustre/attribute.{
  attribute, charset, class, content, href, id, name, rel, style, styles, type_,
}
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, details, div, h1, h3, nav, section, summary, table, tbody, td, text,
  tr,
}
import mist
import pages/get_session.{get_session, get_session_mini}
import pages/list_sessions.{list_sessions}
import pages/new_session.{new_session}
import pages/update_session.{update_session}
import rada/date
import sqlite_client
import wisp.{type Request, type Response}
import wisp/wisp_mist

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
    Ok(model), Get, [], _ -> view(home(req, model), [])
    Ok(_), Get, ["new"], _ -> new_session(req)
    Ok(_), Get, ["new", _], _ -> new_session(req)
    Ok(model), Get, [year, month], _ -> {
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
          Ok(_) -> view_fragment(get_session_mini(req, session))
          Error(_) ->
            view(get_session(req, session), [
              add_input_button(),
              save_session_button(),
            ])
        }
      })
      |> result.unwrap(wisp.not_found())
    }
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
    _, _, _, _ -> wisp.not_found()
  }
}

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
      html.link([rel("stylesheet"), href("/jimgym.css")]),
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
    grid-rows-[[header]_8%_[content]_82%_[footer]_8%]
    font-hand",
          ),
        ],
        body |> common.list_append_one(view_nav(nav_elements)),
      ),
      html.script([attribute.src("/fixi.js")], ""),
      html.script([attribute.src("/ext-fixi.js")], ""),
    ]),
  ])
  |> element.to_document_string_tree
  |> wisp.html_response(200)
}

pub fn home(_req: Request, model: List(common.GymSession)) -> List(Element(a)) {
  let sessions = model
  [
    h1(
      [
        class(
          "text-5xl flex items-center font-bold col-[main-start_/_main-end] row-start-[header]",
        ),
      ],
      [text("💪🤸‍♂️🏋️")],
    ),
    section(
      [
        class(
          "mt-2 font-slab flex flex-col gap-4  col-[main-start_/_main-end] row-start-[content]",
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

fn add_input_button() -> Element(a) {
  element.fragment([
    html.button(
      [
        class("self-center"),
        attribute.popovertarget("add-input-picker"),
        style("anchor-name", "--add-input-picker"),
      ],
      [text("➕")],
    ),
    html.aside(
      [
        id("add-input-picker"),
        attribute.popover("auto"),
        class("rounded border border-uchu-yin bg-white p-2 absolute"),
        styles([
          #("inset", "auto"),
          #("position-anchor", "--add-input-picker"),
          #("position-area", "top"),
        ]),
      ],
      [
        html.button(
          [
            attribute("fx-action", "/new-sets-exercise-input"),
            attribute("fx-target", "#session-form"),
            attribute("fx-swap", "beforeend"),
          ],
          [text("🔢")],
        ),
        html.button(
          [
            attribute("fx-action", "/new-timed-exercise-input"),
            attribute("fx-target", "#session-form"),
            attribute("fx-swap", "beforeend"),
          ],
          [text("⏱️")],
        ),
      ],
    ),
  ])
}

pub fn view_fragment(fragment: List(Element(a))) -> Response {
  case list.length(fragment) {
    0 -> element.none()
    1 -> fragment |> list.first |> result.unwrap(element.none())
    _ -> element.fragment(fragment)
  }
  |> element.to_string_tree
  |> wisp.html_response(200)
}

fn view_nav(children: List(Element(a))) -> Element(a) {
  nav(
    [
      class(
        "col-[main-start_/_main-end] row-start-[footer] text-2xl p-4 border-t border-uchu-yin gap-6 flex justify-around flex-row",
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
            "pt-2 pb-1 px-2 bg-uchu-light-gray cursor-pointer flex justify-between items-center",
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
              "mt-4 block p-2 text-center bg-uchu-light-gray font-bold font-slab border-2 cursor-pointer border-uchu-yin rounded-md",
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
