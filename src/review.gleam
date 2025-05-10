import common.{type GymSession}
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/attribute.{class, href, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  a, article, div, h1, section, table, tbody, td, text, tr,
}
import lustre/event.{on_click}
import rada/date

pub type ReviewMsg {
  UserChangedMonth(#(date.Month, Int))
  UserSelectedSessionDate(date.Date)
}

pub type ReviewModel {
  ReviewModel(
    current_month: date.Month,
    current_year: Int,
    session_dates: List(date.Date),
    selected_session: Option(GymSession),
  )
}

pub fn update(
  model: ReviewModel,
  msg: ReviewMsg,
) -> #(ReviewModel, Effect(ReviewMsg)) {
  case msg {
    UserChangedMonth(#(month, year)) -> {
      #(
        ReviewModel(
          ..model,
          current_month: month,
          current_year: year,
          selected_session: None,
        ),
        { effect.none() },
      )
    }
    // UserSelectedSessionDate is handled in layer above
    _ -> #(model, effect.none())
  }
}

// ----- VIEW -----------------------------------------------------------------------

pub fn view_session_review(model: ReviewModel) -> List(Element(ReviewMsg)) {
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
          "col-[main-start_/_main-end] row-start-[content] grid-cols-7 grid gap-1 border-1 border-uchu-yin p-1",
        ),
      ],
      html.article([class("col-span-7 flex row-span-1 justify-center")], [
        html.p([], [
          text(
            model.current_month |> month_to_label
            <> " "
            <> model.current_year |> int.to_string,
          ),
        ]),
      ])
        |> common.list_append_one(
          ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            |> list.map(fn(day) {
              html.article(
                [class("col-span-1 row-start-2 flex justify-center")],
                [text(day)],
              )
            }),
          _,
        )
        |> list.append(
          generate_calendar_tiles(
            model.current_month,
            model.current_year,
            model.session_dates,
          )
          |> common.list_append_one(view_session_history(model))
          |> common.list_append_one(
            html.nav([class("col-span-7 subgrid-cols row-span-1")], [
              html.button(
                [
                  class("col-span-1 col-start-1"),
                  type_("button"),
                  on_click(
                    UserChangedMonth(prev_month(
                      model.current_month,
                      model.current_year,
                    )),
                  ),
                ],
                [text("<")],
              ),
              html.button(
                [
                  class("col-span-1 col-start-7"),
                  type_("button"),
                  on_click(
                    UserChangedMonth(next_month(
                      model.current_month,
                      model.current_year,
                    )),
                  ),
                ],
                [text(">")],
              ),
            ]),
          ),
        ),
    ),
  ]
}

pub fn view_session_history(model: ReviewModel) -> Element(ReviewMsg) {
  case model.selected_session {
    None -> element.none()
    Some(session) ->
      section(
        [class("mt-4 row-start-8 row-span-1 col-span-7 overflow-y-scroll")],
        [
          table([class("w-full text-sm")], [
            tbody(
              [],
              session.exercises
                |> dict.values
                |> list.map(view_exercise_history_group)
                |> list.flatten,
            ),
          ]),
        ],
      )
  }
}

pub fn view_exercise_history_group(
  exercises: List(common.Exercise),
) -> List(Element(ReviewMsg)) {
  group_exercises_by_sets(exercises)
  |> list.map(view_exercise_history)
}

pub fn view_exercise_history(
  sets: #(Int, common.Exercise),
) -> Element(ReviewMsg) {
  case sets.1 {
    common.SetsExercise(name, reps, weight, _rest) ->
      tr([class("border-b border-gray-100")], [
        td([class("py-1 text-center")], [
          text(int.to_string(sets.0) <> "×" <> int.to_string(reps)),
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
      ])
    common.TimedExercise(name, duration) ->
      div([class("col-span-6")], [
        text(sets.0 |> int.to_string <> " sets "),
        text(name),
        text(duration |> int.to_string <> "m"),
      ])
  }
}

pub fn view_calendar_day(
  day: date.Date,
  starting_column: String,
  has_session: Bool,
) -> Element(ReviewMsg) {
  article(
    [
      class("col-span-1 grid grid-rows-2 justify-center"),
      case has_session {
        True -> event.on_click(UserSelectedSessionDate(day))
        False -> attribute.none()
      },
      {
        case starting_column {
          "" -> attribute.none()
          _ -> attribute.style([#("grid-column-start", starting_column)])
        }
      },
    ],
    [
      div([class("row-start-1 flex justify-center")], [
        text(day |> date.day |> int.to_string),
      ]),
      div([class("row-start-2 flex justify-center")], [
        case has_session {
          True -> text("💪")
          False -> text(" ")
        },
      ]),
    ],
  )
}

pub fn group_exercises_by_sets(exercises: List(common.Exercise)) {
  let uniques = exercises |> list.unique
  let counts =
    uniques
    |> list.map(fn(exercise) {
      #(exercises |> list.count(fn(e) { e == exercise }), exercise)
    })
  counts
}

pub fn generate_days_in_month(month: date.Month, year: Int) -> List(date.Date) {
  let start = date.from_calendar_date(year, month, 1) |> echo
  let end = start |> date.add(1, date.Months) |> echo
  date.range(date.Day, 1, start, end)
}

pub fn next_month(month: date.Month, year: Int) -> #(date.Month, Int) {
  case month {
    date.Dec -> #(date.Jan, year + 1)
    _ -> #(date.month_to_number(month) + 1 |> date.number_to_month, year)
  }
}

pub fn prev_month(month: date.Month, year: Int) -> #(date.Month, Int) {
  case month {
    date.Jan -> #(date.Dec, year - 1)
    _ -> #(date.month_to_number(month) - 1 |> date.number_to_month, year)
  }
}

pub fn generate_calendar_tiles(
  month: date.Month,
  year: Int,
  sessions: List(date.Date),
) -> List(Element(ReviewMsg)) {
  let days = generate_days_in_month(month, year)
  case days {
    [] -> []
    [first, ..rest] -> {
      let number = first |> date.weekday_number

      list.flatten([
        [
          case number {
            1 -> element.none()
            _ ->
              html.article(
                [
                  attribute.style([
                    #(
                      "grid-column",
                      "span "
                        <> number - 1 |> int.to_string
                        <> " / span "
                        <> number - 1 |> int.to_string,
                    ),
                  ]),
                ],
                [],
              )
          },
        ],
        [
          {
            first
            |> view_calendar_day(
              "col-start-" <> number |> int.to_string <> " row-start-3",
              list.find(sessions, fn(session) { session == first })
                |> result.is_ok,
            )
          },
        ],
        rest
          |> list.map(fn(day) {
            view_calendar_day(
              day,
              "",
              list.find(sessions, fn(session) { session == day })
                |> result.is_ok,
            )
          }),
      ])
    }
  }
}

pub fn month_to_label(month: date.Month) -> String {
  case month {
    date.Jan -> "Jan"
    date.Feb -> "Feb"
    date.Mar -> "Mar"
    date.Apr -> "Apr"
    date.May -> "May"
    date.Jun -> "Jun"
    date.Jul -> "Jul"
    date.Aug -> "Aug"
    date.Sep -> "Sep"
    date.Oct -> "Oct"
    date.Nov -> "Nov"
    date.Dec -> "Dec"
  }
}
