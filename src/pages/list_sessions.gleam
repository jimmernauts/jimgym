import common
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import lustre/attribute.{class, href, id}
import lustre/element.{type Element}
import lustre/element/html.{a, article, div, h1, h2, section, span, td, text, tr}
import rada/date
import wisp.{type Request}

pub fn list_sessions(
  _req: Request,
  model: List(common.GymSession),
  year: Int,
  month: Int,
) -> List(Element(a)) {
  [
    div(
      [
        class(
          "text-6xl font-bold col-[main-start_/_main-end] row-start-[header] flex gap-8",
        ),
      ],
      [
        a([href("/")], [text("💪🤸‍♂️🏋️")]),
        h2([], [
          text(
            month |> date.number_to_month |> month_to_label
            <> " "
            <> year |> int.to_string,
          ),
        ]),
      ],
    ),
    section(
      [
        class(
          "mt-2 col-[main-start_/_main-end] row-start-[content] grid-cols-7 grid gap-1 border-1 border-uchu-yin p-1",
        ),
      ],
      list.flatten([
        generate_calendar(month |> date.number_to_month, year, model)
        |> common.list_append_one(
          div([class("hidden"), id("mini_details")], []),
        )
        |> common.list_append_one(
          html.nav(
            [class("col-span-7 subgrid-cols row-span-1"), id("calendar_nav")],
            [
              a(
                [
                  class(
                    "col-span-1 col-start-1 self-center justify-self-center",
                  ),
                  href("/" <> prev_month(month, year)),
                ],
                [text("<")],
              ),
              a(
                [
                  class(
                    "col-span-1 col-start-7 self-center justify-self-center",
                  ),
                  href("/" <> next_month(month, year)),
                ],
                [text(">")],
              ),
            ],
          ),
        ),
      ]),
    ),
  ]
}

/// TODO: make it all fit in one list, sort out the styling issue with the nav arrows inside the calendar
// 
// 
// 
// 
// 
//         |> common.list_append_one(
//           ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
//             |> list.map(fn(day) {
//               article(
//                 [class("col-span-1 row-start-2 flex justify-center")],
//                 [text(day)],
//               )
//             }),
//           _,
//         )
//         |> list.append(
//           generate_calendar(month |> date.number_to_month, year, model)
//           |> common.list_append_one(
//             div([class("hidden"), id("mini_details")], []),
//           )
//           |> common.list_append_one(
//             html.nav(
//               [class("col-span-7 subgrid-cols row-span-1"), id("calendar_nav")],
//               [
//                 a(
//                   [
//                     class(
//                       "col-span-1 col-start-1 self-center justify-self-center",
//                     ),
//                     href("/" <> prev_month(month, year)),
//                   ],
//                   [text("<")],
//                 ),
//                 a(
//                   [
//                     class(
//                       "col-span-1 col-start-7 self-center justify-self-center",
//                     ),
//                     href("/" <> next_month(month, year)),
//                   ],
//                   [text(">")],
//                 ),
//               ],
//             ),
//           ),
//         ),
//     ),
//   ]
// }

pub fn view_exercise_history_group(
  exercises: List(common.Exercise),
) -> List(Element(a)) {
  common.group_exercises_by_sets(exercises)
  |> list.map(view_exercise_history)
}

pub fn view_exercise_history(sets: #(Int, common.Exercise)) -> Element(a) {
  case sets.1 {
    common.SetsExercise(name, reps, weight) ->
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
  emoji: String,
) -> Element(a) {
  article(
    {
      list.flatten([
        [
          class("col-span-1 grid grid-rows-2 justify-center"),
          {
            case starting_column {
              "" -> attribute.none()
              _ -> attribute.styles([#("grid-column-start", starting_column)])
            }
          },
        ],
        case emoji {
          "" -> []
          _ -> [
            attribute.style("cursor", "pointer"),
            attribute.attribute(
              "fx-action",
              "/"
                <> int.to_string(day |> date.year)
                <> "/"
                <> int.to_string(day |> date.month_number)
                <> "/"
                <> int.to_string(day |> date.day)
                <> "?mini",
            ),
            attribute.attribute("fx-swap", "outerHTML"),
            attribute.attribute("fx-target", "#mini_details"),
          ]
        },
      ])
    },
    [
      div([class("row-start-1 flex justify-center")], [
        text(day |> date.day |> int.to_string),
      ]),
      div([class("row-start-2 flex justify-center")], [
        case emoji {
          "" -> element.none()
          _ -> text(emoji)
        },
      ]),
    ],
  )
}

pub fn generate_days_in_month(month: date.Month, year: Int) -> List(date.Date) {
  let start = date.from_calendar_date(year, month, 1)
  let end = start |> date.add(1, date.Months)
  date.range(date.Day, 1, start, end)
}

pub fn next_month(month: Int, year: Int) -> String {
  case month {
    12 -> int.to_string(year + 1) <> "/1"
    _ -> int.to_string(year) <> "/" <> int.to_string(month + 1)
  }
}

pub fn prev_month(month: Int, year: Int) -> String {
  case month {
    1 -> int.to_string(year - 1) <> "/12"
    _ -> int.to_string(year) <> "/" <> int.to_string(month - 1)
  }
}

pub fn generate_calendar(
  month: date.Month,
  year: Int,
  sessions: List(common.GymSession),
) -> List(Element(a)) {
  list.flatten([
    ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
      |> list.map(fn(day) {
        article([class("col-span-1 row-start-1 flex justify-center")], [
          text(day),
        ])
      }),
    generate_calendar_tiles(month, year, sessions),
  ])
}

pub fn generate_calendar_tiles(
  month: date.Month,
  year: Int,
  sessions: List(common.GymSession),
) -> List(Element(a)) {
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
                  attribute.styles([
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
              list.find(sessions, fn(session) { session.date == first })
                |> result.map(fn(session) { session.emoji })
                |> result.unwrap(""),
            )
          },
        ],
        rest
          |> list.map(fn(day) {
            view_calendar_day(
              day,
              "",
              list.find(sessions, fn(session) { session.date == day })
                |> result.map(fn(session) { session.emoji })
                |> result.unwrap(""),
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
