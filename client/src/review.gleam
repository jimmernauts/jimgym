import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute.{class, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, section, text}
import lustre/event.{on_click}
import rada/date

pub type ReviewMsg {
  ChangedMonth(#(date.Month, Int))
  RetrievedPastSessionDates(List(date.Date))
}

pub type ReviewModel {
  ReviewModel(
    current_month: date.Month,
    current_year: Int,
    past_session_dates: List(date.Date),
  )
}

pub fn update(
  model: ReviewModel,
  msg: ReviewMsg,
) -> #(ReviewModel, Effect(ReviewMsg)) {
  case msg {
    ChangedMonth(#(month, year)) -> {
      #(ReviewModel(..model, current_month: month, current_year: year), {
        // 
        // retrieve_days_with_past_sessions(month, year)
        // |> promise.map(result.unwrap(_, []))
        // |> promise.tap(RetrievedPastSessionDates)
        // effect.none()
        effect.none()
      })
    }
    RetrievedPastSessionDates(dates) -> {
      #(ReviewModel(..model, past_session_dates: dates), effect.none())
    }
  }
}

// ----- VIEW -----------------------------------------------------------------------

pub fn view_session_review(model: ReviewModel) -> Element(ReviewMsg) {
  section([class("col-span-6 grid-cols-7 gap-1 border-1 border-uchu-yin p-1")], [
    html.article([class("col-span-7 row-span-1")], [
      text(
        model.current_month |> string.inspect
        <> " "
        <> model.current_year |> int.to_string,
      ),
    ]),
    generate_days_in_month(model.current_month, model.current_year)
      |> list.map(view_calendar_day)
      |> element.fragment,
    html.nav([class("col-span-7 row-span-1")], [
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
  ])
}

pub fn generate_days_in_month(month: date.Month, year: Int) -> List(date.Date) {
  let start = date.from_calendar_date(year, month, 1)
  let end = start |> date.ceiling(date.Month)
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

pub fn view_calendar_day(day: date.Date) -> Element(ReviewMsg) {
  html.article([class("col-span-1 row-span-1")], [
    text(day |> date.day |> int.to_string),
  ])
}
// ----- DB -----------------------------------------------------------------------
// 
// pub fn retrieve_days_with_past_sessions(
//   month: date.Month,
//   year: Int,
// ) -> Promise(Result(List(date.Date), String)) {
//   do_retrieve_days_with_past_sessions(month, year)
// }
// 
// @external(javascript, "./db.ffi.mjs", "do_retrieve_days_with_past_sessions")
// pub fn do_retrieve_days_with_past_sessions(
//   month: date.Month,
//   year: Int,
// ) -> Promise(Result(List(date.Date), String))
