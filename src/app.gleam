import common.{
  type Exercise, type ExerciseTemplate, ExerciseRecord, GymSession,
  SessionTemplate, SetsExercise, SetsExerciseTemplate, TimedExercise,
  TimedExerciseTemplate,
}
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import lustre
import lustre/attribute.{attribute, class, id, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, details, div, h1, h3, nav, section, summary, table, tbody, td, text,
  tr,
}
import lustre/event.{on_click}
import modem
import plinth/browser/audio
import plinth/javascript/global
import rada/date
import review

pub type Msg {
  StartNewSession(Option(common.SessionTemplate))
  RemoveSetFromCurrentSessionExercises(Int, String)
  UpdatedExerciseAtIndex(Int, common.Exercise)
  EndActiveSession
  SaveSession(common.GymSession)
  QueueRetrievePastSessions
  RetrievedPastSessions(List(common.GymSession))
  UpdateSessionTemplates(List(common.SessionTemplate))
  HandleRouteChange(Route)
  ShowTimer(Int)
  TimerTick
  TimerStarted(global.TimerID)
  PlayAlarm
  CancelAlarm
  Review(review.ReviewMsg)
  RequestWakeLock
  ReleaseWakeLock
  StoreWakeLock(WakeLockSentinel)
}

pub type Route {
  Home
  CurrentSessionPage
  ReviewPage(Option(date.Date))
}

pub type Model {
  Model(
    current_route: Route,
    sessions: List(common.GymSession),
    session_templates: List(common.SessionTemplate),
    timer: Int,
    timer_id: Option(global.TimerID),
    alarm_ringing: Bool,
    alarm_audio: Option(audio.Audio),
    review_model: review.ReviewModel,
    wake_lock: Option(WakeLockSentinel),
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let initial_route =
    modem.initial_uri()
    |> result.map(handle_route_change)
    |> result.map(fn(x) {
      case x {
        HandleRouteChange(route) -> route
        _ -> Home
      }
    })
    |> result.unwrap(Home)
  #(
    Model(
      current_route: initial_route,
      sessions: [],
      session_templates: [
        SessionTemplate("Whole Body A", "💪", [
          SetsExerciseTemplate("Sled Drag", 5, 10, 20.0, 90),
          SetsExerciseTemplate("Sled Push", 5, 10, 20.0, 90),
          SetsExerciseTemplate("Bench Press", 3, 10, 20.0, 90),
          SetsExerciseTemplate("Rows", 3, 10, 20.0, 90),
        ]),
        SessionTemplate("Whole Body B", "🏋️", [
          SetsExerciseTemplate("Sled Drag", 5, 10, 20.0, 60),
          SetsExerciseTemplate("Deadlifts", 3, 10, 20.0, 90),
          SetsExerciseTemplate("Pull-ups", 3, 8, 14.0, 90),
          SetsExerciseTemplate("Shoulder Press", 3, 8, 17.5, 90),
        ]),
        SessionTemplate("Rehab", "🏃", [
          SetsExerciseTemplate("Sled Drag", 5, 10, 20.0, 60),
          SetsExerciseTemplate("Patrick Step", 3, 20, 0.0, 60),
        ]),
        SessionTemplate("Cardio", "🏃", [
          TimedExerciseTemplate("Backwards Treadmill", 20),
          TimedExerciseTemplate("Rowing", 10),
        ]),
      ],
      timer: 0,
      timer_id: None,
      alarm_ringing: False,
      alarm_audio: None,
      wake_lock: None,
      review_model: review.ReviewModel(
        current_month: date.month(date.today()),
        session_dates: [],
        current_year: date.year(date.today()),
        selected_session: None,
      ),
    ),
    effect.batch([
      modem.init(handle_route_change),
      {
        use dispatch <- effect.from
        dispatch(QueueRetrievePastSessions)
      },
    ]),
  )
}

fn handle_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    [] -> HandleRouteChange(Home)
    ["session", "current"] -> HandleRouteChange(CurrentSessionPage)
    ["session", date] ->
      HandleRouteChange(
        ReviewPage(Some(
          date.from_iso_string(date) |> result.unwrap(date.today()),
        )),
      )
    ["review"] -> HandleRouteChange(ReviewPage(None))
    _ -> HandleRouteChange(Home)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  echo msg
  case msg {
    RemoveSetFromCurrentSessionExercises(index, name) -> {
      #(
        Model(
          ..model,
          sessions: case
            model.sessions
            |> list.find(fn(session) { session.date == date.today() })
          {
            Error(_) -> model.sessions
            Ok(session) -> {
              let new_exercises =
                dict.upsert(session.exercises, name, fn(exercises) {
                  case exercises {
                    Some(exercise_list) -> {
                      exercise_list
                      |> list.index_map(fn(exercise, i) { #(exercise, i) })
                      |> list.filter(fn(pair) { pair.1 != index })
                      |> list.map(fn(pair) { pair.0 })
                    }
                    None -> []
                  }
                })
              [
                common.GymSession(session.date, new_exercises, session.emoji),
                ..model.sessions
              ]
            }
          },
        ),
        effect.none(),
      )
    }
    UpdatedExerciseAtIndex(index, new_exercise) -> {
      #(
        Model(
          ..model,
          sessions: case
            model.sessions
            |> list.find(fn(session) { session.date == date.today() })
          {
            Error(_) -> model.sessions
            Ok(session) -> {
              let new_exercises =
                dict.upsert(session.exercises, new_exercise.name, fn(exercises) {
                  case exercises {
                    Some(exercise_list) -> {
                      exercise_list
                      |> list.index_map(fn(exercise, i) { #(exercise, i) })
                      |> list.filter_map(fn(pair) {
                        case pair.1 == index {
                          True -> Ok(#(new_exercise, index))
                          False -> Ok(pair)
                        }
                      })
                      |> list.map(fn(pair) { pair.0 })
                    }
                    None -> []
                  }
                })
              [
                common.GymSession(session.date, new_exercises, session.emoji),
                ..model.sessions
              ]
            }
          },
        ),
        effect.none(),
      )
    }
    EndActiveSession -> {
      #(
        model,
        effect.batch([
          modem.push("/", None, None),
          case
            model.sessions
            |> list.find(fn(session) { session.date == date.today() })
          {
            Error(_) -> effect.none()
            Ok(session) -> {
              use dispatch <- effect.from
              dispatch(SaveSession(session))
            }
          },
        ]),
      )
    }
    StartNewSession(template) -> {
      #(
        Model(..model, sessions: [
          case template {
            Some(common.SessionTemplate(_name, emoji, exercises)) -> {
              common.GymSession(
                date.today(),
                exercises
                  |> list.map(convert_template_to_sets)
                  |> dict.from_list,
                emoji,
              )
            }
            None -> GymSession(date.today(), dict.new(), "")
          },
          ..model.sessions
        ]),
        modem.replace("session/current", None, None),
      )
    }
    UpdateSessionTemplates(templates) -> {
      #(Model(..model, session_templates: templates), effect.none())
    }
    HandleRouteChange(route) -> {
      #(Model(..model, current_route: route), effect.none())
    }
    ShowTimer(seconds) -> {
      #(Model(..model, timer: seconds), {
        case model.timer_id {
          Some(timer_id) -> global.clear_interval(timer_id)
          None -> Nil
        }
        use dispatch <- effect.from
        let timer_id = global.set_interval(1000, fn() { dispatch(TimerTick) })
        dispatch(TimerStarted(timer_id))
      })
    }
    TimerStarted(timer_id) -> {
      #(Model(..model, timer_id: Some(timer_id)), effect.none())
    }
    TimerTick -> {
      case model.timer {
        i if -20 < i && i < 0 -> {
          #(Model(..model, timer: i - 1, alarm_ringing: True), effect.none())
        }
        i if i == 0 -> {
          #(Model(..model, timer: i - 1, alarm_ringing: True), {
            use dispatch <- effect.from
            dispatch(PlayAlarm)
          })
        }
        i if i > 0 -> {
          #(Model(..model, timer: i - 1), effect.none())
        }
        _ -> {
          #(Model(..model, timer: 0, alarm_ringing: False, timer_id: None), {
            model.timer_id |> option.map(global.clear_interval)
            effect.none()
          })
        }
      }
    }
    PlayAlarm -> {
      let alarm = audio.new("/hell-march-2.mp3")
      echo "playing alarm" <> string.inspect(alarm)
      #(Model(..model, alarm_audio: Some(alarm)), {
        alarm |> audio.play()
        effect.none()
      })
    }
    CancelAlarm -> {
      #(
        Model(
          ..model,
          alarm_ringing: False,
          timer: 0,
          timer_id: None,
          alarm_audio: None,
        ),
        {
          model.timer_id |> option.map(global.clear_interval)
          model.alarm_audio |> option.map(stop_audio)
          effect.none()
        },
      )
    }
    RequestWakeLock -> {
      #(model, {
        use dispatch <- effect.from
        request_wake_lock()
        |> promise.map(option.from_result)
        |> promise.tap(fn(x) {
          case x {
            Some(sentinel) -> dispatch(StoreWakeLock(sentinel))
            None -> Nil
          }
        })
        Nil
      })
    }
    ReleaseWakeLock -> {
      #(Model(..model, wake_lock: None), {
        model.wake_lock |> option.map(release_wake_lock)
        effect.none()
      })
    }
    StoreWakeLock(wake_lock) -> {
      #(Model(..model, wake_lock: Some(wake_lock)), effect.none())
    }
    SaveSession(session) -> {
      save_session(session)
      #(model, {
        use dispatch <- effect.from
        QueueRetrievePastSessions |> dispatch
      })
    }
    QueueRetrievePastSessions -> {
      #(model, {
        use dispatch <- effect.from
        retrieve_sessions()
        |> promise.map(result.unwrap(_, []))
        |> promise.tap(fn(x) { dispatch(RetrievedPastSessions(x)) })
        Nil
      })
    }
    RetrievedPastSessions(past_sessions) -> {
      #(
        Model(
          ..model,
          sessions: past_sessions,
          review_model: review.ReviewModel(
            date.month(date.today()),
            date.year(date.today()),
            past_sessions |> list.map(fn(session) { session.date }),
            None,
          ),
        ),
        effect.none(),
      )
    }
    Review(review.UserSelectedSessionDate(date)) -> {
      let selected_session =
        model.sessions
        |> list.find(fn(session) { session.date == date })
        |> option.from_result
      #(
        Model(
          ..model,
          review_model: review.ReviewModel(
            ..model.review_model,
            selected_session: selected_session,
          ),
        ),
        effect.none(),
      )
    }
    Review(review_msg) -> {
      let #(review_model, effect) =
        review.update(model.review_model, review_msg)
      #(Model(..model, review_model: review_model), effect.map(effect, Review))
    }
  }
}

//--PAGES------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  let page = case model.current_route {
    Home -> view_home(model)
    CurrentSessionPage -> view_current_session_page(model)
    ReviewPage(_) ->
      review.view_session_review(model.review_model)
      |> list.map(element.map(_, Review))
  }
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
      {
        case model.alarm_ringing {
          True -> on_click(CancelAlarm)
          _ -> attribute.none()
        }
      },
    ],
    page
      |> common.list_append_one(
        nav(
          [
            class(
              "col-[main-start_/_main-end] row-start-[footer] text-2xl p-4 border-t-1 border-uchu-yin gap-6 flex justify-around flex-row",
            ),
          ],
          [
            a([attribute.href("/"), class("self-center")], [text("🏡")]),
            {
              case model.timer_id, model.alarm_ringing {
                None, _ -> element.none()
                Some(_), False ->
                  button(
                    [
                      class("flex flex-row gap-4 justify-center items-center"),
                      type_("button"),
                      on_click(CancelAlarm),
                    ],
                    [
                      h1([class("text-3xl font-bold")], [
                        text(model.timer |> int.to_string),
                      ]),
                      html.span([class("text-lg")], [text(" ❌")]),
                    ],
                  )
                Some(_), True ->
                  button(
                    [
                      class("flex flex-row gap-4 justify-center items-center"),
                      type_("button"),
                      on_click(CancelAlarm),
                    ],
                    [
                      h1([class("text-3xl font-bold")], [
                        text("🔔 "),
                        text(model.timer |> int.to_string),
                      ]),
                      html.span([class("text-lg")], [text(" ❌")]),
                    ],
                  )
              }
            },
            {
              use <- bool.guard(
                model.current_route != CurrentSessionPage,
                element.none(),
              )
              button(
                [
                  class("self-center cursor-pointer"),
                  on_click(EndActiveSession),
                ],
                [text("🚩")],
              )
            },
            {
              case model.wake_lock {
                Some(_) ->
                  button([class("cursor-pointer"), on_click(ReleaseWakeLock)], [
                    text("🔒"),
                  ])
                None ->
                  button([class("cursor-pointer"), on_click(RequestWakeLock)], [
                    text("🔓"),
                  ])
              }
            },
          ],
        ),
      ),
  )
}

fn view_home(model: Model) -> List(Element(Msg)) {
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
        case
          list.find(model.sessions, fn(session) { session.date == date.today() })
        {
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
                h1([class("font-bold text-3xl")], [text("Start")]),
              ],
            )
          Ok(_) ->
            a(
              [
                class(
                  "font-slab font-bold flex justify-start p-3 text-3xl text-uchu-yin fill-diagonal-uchu-light-gray border-uchu-yin border-2 rounded-md col-span-6 gap-2 items-center",
                ),
                attribute.href("/session/current"),
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
            attribute.href("/review"),
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
          model.session_templates |> list.map(view_session_template_card),
        ),
      ],
    ),
  ]
}

fn view_current_session_page(model: Model) -> List(Element(Msg)) {
  case list.find(model.sessions, fn(session) { session.date == date.today() }) {
    Error(_) -> [
      h1(
        [
          class(
            "font-slab text-7xl font-bold col-[main-start_/_main-end] row-start-[header]",
          ),
        ],
        [text("No session today 😣")],
      ),
    ]
    Ok(session) -> [
      h1(
        [
          class(
            "font-slab text-7xl font-bold col-[main-start_/_main-end] row-start-[header]",
          ),
        ],
        [text(session.emoji <> " " <> session.date |> date.format("dd MMM yy"))],
      ),
      table(
        [
          class(
            "px-2 row-start-[content] overflow-y-scroll gap-6 grid col-[main-start_/_main-end] subgrid-cols w-full text-sm",
          ),
        ],
        [
          tbody(
            [class("grid grid-cols-6 col-[main-start_/_main-end]")],
            session.exercises
              |> dict.to_list
              |> list.map(fn(group) {
                group.1 |> list.index_map(view_exercise_input)
              })
              |> list.flatten,
          ),
        ],
      ),
    ]
  }
}

//--VIEW HELPERS------------------------------------------------------------------

fn view_session_template_card(template: common.SessionTemplate) -> Element(Msg) {
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
                  SetsExerciseTemplate(name, sets, reps, weight, rest) ->
                    view_set_exercise_row(name, sets, reps, weight, rest)
                  TimedExerciseTemplate(name, duration) ->
                    view_timed_exercise_row(name, duration)
                }
              }),
          ),
        ]),
        button(
          [
            class(
              "mt-4 w-full p-2 bg-uchu-light-gray font-bold font-slab border cursor-pointer border-uchu-yin rounded-md",
            ),
            on_click(StartNewSession(Some(template))),
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

fn view_set_exercise_row(
  name: String,
  sets: Int,
  reps: Int,
  weight: Float,
  rest: Int,
) {
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
            False -> {
              // Format with one decimal place
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
    td([class("py-1 text-center")], [text(int.to_string(rest) <> "s")]),
  ])
}

fn view_exercise_input(exercise: Exercise, index: Int) -> Element(Msg) {
  case exercise {
    SetsExercise(name, reps, weight, rest) ->
      tr([class("border-b border-gray-100 col-span-6 subgrid-cols gap-1")], [
        td(
          [
            class(
              "text-center col-start-1 col-span-1 items-center flex justify-center",
            ),
          ],
          [
            html.input([
              case reps |> int.to_string |> string.length < 2 {
                True -> attribute.style([#("padding-left", "1ch")])
                False -> attribute.none()
              },
              class("w-[2ch]"),
              type_("number"),
              attribute.step("1"),
              attribute.value(reps |> int.to_string),
              event.on_input(fn(input) {
                UpdatedExerciseAtIndex(
                  index,
                  common.SetsExercise(
                    ..exercise,
                    reps: input |> int.parse |> result.unwrap(0),
                  ),
                )
              }),
            ]),
          ],
        ),
        td(
          [
            class(
              "text-center col-start-2 items-center col-span-2 flex justify-start",
            ),
          ],
          [text(name)],
        ),
        td(
          [
            class(
              "text-center col-start-4 items-center col-span-1 flex justify-end",
            ),
          ],
          [
            html.input([
              class("w-[3.5ch]"),
              type_("number"),
              attribute.step("0.5"),
              event.on_input(fn(input) {
                echo input
                UpdatedExerciseAtIndex(
                  index,
                  common.SetsExercise(
                    ..exercise,
                    weight: input
                      |> common.float_parse_tolerant,
                  ),
                )
              }),
              attribute.value(weight |> float.to_string),
            ]),
            text("kg"),
          ],
        ),
        td(
          [
            class(
              "text-center col-start-5 items-center col-span-2 flex justify-evenly",
            ),
          ],
          [
            button([class(""), on_click(ShowTimer(rest))], [
              text(rest |> int.to_string <> "s ⌛"),
            ]),
            button(
              [
                class(""),
                on_click(RemoveSetFromCurrentSessionExercises(index, name)),
              ],
              [text("❎")],
            ),
          ],
        ),
      ])
    TimedExercise(name, duration) ->
      tr([class("border-b border-gray-100")], [
        td([class("py-1 text-center")], [
          html.input([
            class(""),
            type_("number"),
            attribute.value(duration |> int.to_string),
            event.on_input(fn(input) {
              UpdatedExerciseAtIndex(
                index,
                common.TimedExercise(
                  ..exercise,
                  duration: input |> int.parse |> result.unwrap(0),
                ),
              )
            }),
          ]),
          text("m"),
        ]),
        td([class("py-1")], [text(name)]),
        button([class(""), on_click(ShowTimer(duration * 60))], [
          text(format_time(duration * 60) <> "s ⌛"),
        ]),
        button(
          [
            class(""),
            on_click(RemoveSetFromCurrentSessionExercises(index, name)),
          ],
          [text("❎")],
        ),
      ])
  }
}

// ----- MAIN & UTILS -----------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

fn convert_template_to_sets(
  template: ExerciseTemplate,
) -> #(String, List(Exercise)) {
  #(template.name, case template {
    SetsExerciseTemplate(name, sets, reps, weight, rest) ->
      list.repeat(SetsExercise(name, reps, weight, rest), sets)
    TimedExerciseTemplate(name, duration) -> [TimedExercise(name, duration)]
  })
}

fn format_time(seconds: Int) -> String {
  let minutes = seconds / 60
  let remaining_seconds = seconds % 60
  minutes |> int.to_string <> ":" <> remaining_seconds |> int.to_string
}

//-----BROWSER ------------------------------------------------------------------------

@external(javascript, "./browser.ffi.mjs", "do_stop_audio")
pub fn stop_audio(audio: audio.Audio) -> Nil

pub type WakeLockSentinel

@external(javascript, "./browser.ffi.mjs", "requestWakeLock")
pub fn request_wake_lock() -> Promise(Result(WakeLockSentinel, String))

@external(javascript, "./browser.ffi.mjs", "releaseWakeLock")
pub fn release_wake_lock(sentinel: WakeLockSentinel) -> Nil

//-----DB --------------------------------------------------------------------------

fn flatten_session(session: common.GymSession) -> List(common.ExerciseRecord) {
  dict.values(session.exercises)
  |> list.flatten
  |> list.map(fn(exercise) {
    case exercise {
      SetsExercise(name, reps, weight, _rest) ->
        ExerciseRecord(
          date: session.date |> date.to_iso_string,
          name: name,
          reps: Some(reps),
          weight: Some(weight),
          duration: None,
        )
      TimedExercise(name, duration) ->
        ExerciseRecord(
          date: session.date |> date.to_iso_string,
          name: name,
          reps: None,
          weight: None,
          duration: Some(duration),
        )
    }
  })
}

fn group_records_into_sessions(
  records: List(common.ExerciseRecord),
) -> List(common.GymSession) {
  records
  |> list.group(fn(record) { record.date })
  |> dict.map_values(fn(date, inner_records) {
    GymSession(
      date: date
        |> date.from_iso_string
        |> result.unwrap(date.from_calendar_date(1970, date.Jan, 1)),
      exercises: inner_records
        |> list.map(fn(record) {
          case record.duration {
            None ->
              common.SetsExercise(
                record.name,
                option.unwrap(record.reps, 0),
                option.unwrap(record.weight, 0.0),
                rest: 0,
              )
            Some(duration) -> common.TimedExercise(record.name, duration)
          }
        })
        |> list.group(fn(exercise) { exercise.name }),
      emoji: "",
    )
  })
  |> dict.values
}

fn save_session(session: common.GymSession) -> Promise(Result(Nil, String)) {
  session |> flatten_session |> do_insert_exercise_records
}

@external(javascript, "./db.ffi.mjs", "do_insert_exercise_records")
pub fn do_insert_exercise_records(
  records: List(common.ExerciseRecord),
) -> Promise(Result(Nil, String))

fn retrieve_sessions() -> Promise(Result(List(common.GymSession), String)) {
  do_retrieve_exercise_records()
  |> promise.map(result.map(_, group_records_into_sessions))
}

@external(javascript, "./db.ffi.mjs", "do_retrieve_exercise_records")
pub fn do_retrieve_exercise_records() -> Promise(
  Result(List(common.ExerciseRecord), String),
)
