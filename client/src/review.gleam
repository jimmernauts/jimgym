import gleam/function
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute.{class, href, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, article, div, section, text}
import lustre/event.{on_click}
import rada/date

pub type ReviewMsg {
  ChangedMonth(#(date.Month, Int))
}

pub type ReviewModel {
  ReviewModel(
    current_month: date.Month,
    current_year: Int,
    session_dates: List(date.Date),
  )
}

pub fn update(
  model: ReviewModel,
  msg: ReviewMsg,
) -> #(ReviewModel, Effect(ReviewMsg)) {
  case msg {
    ChangedMonth(#(month, year)) -> {
      #(ReviewModel(..model, current_month: month, current_year: year), {
        effect.none()
      })
    }
  }
}

// ----- VIEW -----------------------------------------------------------------------

pub fn view_session_review(model: ReviewModel) -> Element(ReviewMsg) {
  section(
    [class("grid-cols-7 grid gap-1 border-1 border-uchu-yin p-1")],
    [
      [
        html.article([class("col-span-7 flex row-span-1 justify-center")], [
          html.p([], [
            text(
              model.current_month |> string.inspect
              <> " "
              <> model.current_year |> int.to_string,
            ),
          ]),
        ]),
      ],
      ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        |> list.map(fn(day) {
          html.article([class("col-span-1 row-start-2 flex justify-center")], [
            text(day),
          ])
        }),
      generate_calendar_tiles(
        model.current_month,
        model.current_year,
        model.session_dates,
      ),
      [
        html.nav([class("col-span-7 subgrid-cols row-span-1")], [
          html.button(
            [
              class("col-span-1 col-start-1"),
              type_("button"),
              on_click(
                ChangedMonth(prev_month(model.current_month, model.current_year)),
              ),
            ],
            [text("<")],
          ),
          html.button(
            [
              class("col-span-1 col-start-7"),
              type_("button"),
              on_click(
                ChangedMonth(next_month(model.current_month, model.current_year)),
              ),
            ],
            [text(">")],
          ),
        ]),
      ],
    ]
      |> list.flatten,
  )
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

pub fn view_calendar_day(
  day: date.Date,
  starting_column: String,
  has_session: Bool,
) -> Element(ReviewMsg) {
  article(
    [
      class("col-span-1 grid grid-rows-2 justify-center"),
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
  |> case has_session {
    True -> fn(inner) {
      a([href("/session/" <> day |> date.to_iso_string)], [inner])
    }
    False -> function.identity
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
