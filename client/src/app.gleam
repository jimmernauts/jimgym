import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri.{type Uri, Uri}
import lustre
import lustre/attribute.{attribute, class, id}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  button, details, div, h3, section, summary, table, tbody, td, text, th, thead,
  tr,
}
import lustre/event.{on_click}
import modem
import rada/date

pub type Msg {
  StartNewSession(Option(SessionTemplate))
  UpdateSession(GymSession)
  EndActiveSession
  UpdateSessionTemplates(List(SessionTemplate))
  OnRouteChange(Route)
}

pub type Route {
  Home
  SessionPage
}

pub type Exercise {
  Exercise(name: String, sets: Int, reps: Int, weight: Float, rest: Int)
}

pub type SessionTemplate {
  SessionTemplate(name: String, emoji: String, exercises: List(Exercise))
}

pub type GymSession {
  GymSession(
    date: Int,
    // Rata die
    exercises: List(Exercise),
    emoji: String,
  )
}

pub type Model {
  Model(
    current_route: Route,
    current_session: Option(GymSession),
    session_template_picker: Bool,
    past_sessions: List(GymSession),
    session_templates: List(SessionTemplate),
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(
      current_route: Home,
      current_session: None,
      session_template_picker: False,
      past_sessions: [],
      session_templates: [
        SessionTemplate("Whole Body A", "💪", [
          Exercise("Sled Drag", 5, 10, 20.0, 60),
          Exercise("Sled Push", 5, 10, 20.0, 90),
          Exercise("Bench Press", 3, 10, 20.0, 90),
          Exercise("Rows", 3, 10, 20.0, 90),
        ]),
        SessionTemplate("Whole Body B", "🏋️", [
          Exercise("Sled Drag", 5, 10, 20.0, 60),
          Exercise("Deadlifts", 3, 10, 20.0, 90),
          Exercise("Pull-ups", 3, 10, 20.0, 90),
          Exercise("Shoulder Press", 3, 10, 12.5, 90),
        ]),
        SessionTemplate("Rehab", "🏃", [
          Exercise("Sled Drag", 5, 10, 20.0, 60),
          Exercise("Patrick Step", 3, 20, 0.0, 60),
        ]),
      ],
    ),
    modem.init(on_route_change),
  )
}

fn on_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    _ -> OnRouteChange(Home)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UpdateSession(new_session) -> {
      #(Model(..model, current_session: Some(new_session)), effect.none())
    }
    EndActiveSession -> {
      #(
        Model(..model, current_session: None, past_sessions: {
          case model.current_session {
            None -> model.past_sessions
            Some(session) -> list.append(model.past_sessions, [session])
          }
        }),
        effect.none(),
      )
    }
    StartNewSession(template) -> {
      #(
        Model(
          ..model,
          current_session: Some(case template {
            Some(SessionTemplate(_name, emoji, exercises)) -> {
              GymSession(date.today() |> date.to_rata_die, exercises, emoji)
            }
            None -> GymSession(date.today() |> date.to_rata_die, [], "")
          }),
        ),
        effect.none(),
      )
    }
    UpdateSessionTemplates(templates) -> {
      #(Model(..model, session_templates: templates), effect.none())
    }
    OnRouteChange(route) -> {
      #(Model(..model, current_route: route), effect.none())
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let page = case model.current_route {
    Home -> view_home(model)
    SessionPage -> view_session_page(model)
  }
  html.main(
    [
      class(
        "grid ml-2 mr-2 gap-2
    2xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_90%_[main-end]_3fr_[full-end]_1fr_[end]]
    xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
    lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
    md:grid-cols-[[start_full-start]_1fr_[main-start]_95%_[main-end]_1fr_[full-end_end]]
    grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]
    grid-rows-[[content]_95%_[footer]_1fr]
    font-industrial",
      ),
    ],
    [page],
  )
}

fn view_home(model: Model) -> Element(Msg) {
  html.section(
    [class("mt-4 gap-6 grid col-[main-start_/_main-end] grid-cols-6")],
    [
      html.h1([class("text-7xl font-bold col-span-6")], [text("💪🤸‍♂️🏋️")]),
      html.section([class("subgrid-cols gap-4 col-span-6")], [
        case model.current_session {
          None ->
            button(
              [
                class(
                  "font-code p-1 font-[400] text-3xl text-uchu-yin bg-uchu-light-gray border-uchu-yin border-2 rounded-md col-span-6",
                ),
                attribute.attribute("popovertarget", "session-template-picker"),
              ],
              [text("Start")],
            )
          Some(_) ->
            button(
              [
                class(
                  "font-code p-1 font-[400] text-3xl text-uchu-yin fill-diagonal-uchu-light-gray border-uchu-yin border-2 rounded-md col-span-6",
                ),
                on_click(OnRouteChange(SessionPage)),
              ],
              [text("Session in Progress")],
            )
        },
        button(
          [
            class(
              "font-code p-1 font-[400] text-3xl text-uchu-yin bg-uchu-light-gray border-uchu-yin border-2 rounded-md col-span-6",
            ),
          ],
          [text("Review")],
        ),
      ]),
      html.section(
        [
          class("mt-16 bg-white p-2 max-h-[80vh] w-full overflow-y-auto"),
          attribute("popover", ""),
          id("session-template-picker"),
        ],
        [
          div(
            [class("flex flex-col gap-4")],
            model.session_templates |> list.map(view_session_template_card),
          ),
        ],
      ),
    ],
  )
}

fn view_session_template_card(template: SessionTemplate) -> Element(Msg) {
  details(
    [class("bg-white border-2 border-uchu-yin rounded-md overflow-hidden")],
    [
      summary(
        [
          class(
            "p-3 bg-uchu-light-gray cursor-pointer flex justify-between items-center",
          ),
        ],
        [
          h3([class("font-bold text-3xl")], [
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
                tr([class("border-b border-gray-100")], [
                  td([class("py-1 text-center")], [
                    text(
                      int.to_string(exercise.sets)
                      <> "×"
                      <> int.to_string(exercise.reps),
                    ),
                  ]),
                  td([class("py-1")], [text(exercise.name)]),
                  td([class("py-1 text-center")], [
                    text(
                      case exercise.weight {
                        0.0 -> ""
                        weight -> {
                          // Check if it's effectively an integer
                          let int_part = float.truncate(weight)
                          let decimal_part = weight -. int.to_float(int_part)

                          case decimal_part <. 0.01 || decimal_part >. 0.99 {
                            True -> int.to_string(int_part)
                            False -> {
                              // Format with one decimal place
                              let decimal_str =
                                decimal_part *. 10.0
                                |> float.round
                                |> int.to_string

                              int.to_string(int_part) <> "." <> decimal_str
                            }
                          }
                        }
                      }
                      <> "kg",
                    ),
                  ]),
                  td([class("py-1 text-center")], [
                    text(int.to_string(exercise.rest) <> "s"),
                  ]),
                ])
              }),
          ),
        ]),
        button(
          [
            class(
              "mt-4 w-full p-2 bg-uchu-light-gray border border-uchu-yin rounded-md",
            ),
            on_click(StartNewSession(Some(template))),
          ],
          [text("Start Session")],
        ),
      ]),
    ],
  )
}

fn view_session_page(model: Model) -> Element(Msg) {
  html.section(
    [class("mt-4 gap-6 grid col-[main-start_/_main-end] grid-cols-6")],
    [
      html.h1([class("text-7xl font-bold col-span-6")], [
        text(case model.current_session {
          None -> ""
          Some(session) ->
            session.emoji
            <> " "
            <> session.date |> date.from_rata_die |> date.format("dd MMM yy")
        }),
      ]),
    ],
  )
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}
