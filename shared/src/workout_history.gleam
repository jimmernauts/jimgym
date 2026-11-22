import common
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import lustre/attribute.{class, colspan}
import lustre/element.{type Element}
import lustre/element/html.{table, tbody, td, text, tr}

pub fn view(exercises: dict.Dict(String, List(common.Exercise))) -> Element(a) {
  table([class("col-span-6 text-sm")], [
    tbody(
      [],
      exercises |> dict.values |> list.flat_map(view_exercise_history_group),
    ),
  ])
}

fn view_exercise_history_group(
  exercises: List(common.Exercise),
) -> List(Element(a)) {
  common.group_exercises_by_sets(exercises)
  |> list.map(view_exercise_history)
}

fn view_exercise_history(sets: #(Int, common.Exercise)) -> Element(a) {
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
      tr([], [
        td([colspan(3)], [
          text(
            int.to_string(sets.0)
            <> " sets "
            <> name
            <> " "
            <> int.to_string(duration)
            <> "m",
          ),
        ]),
      ])
  }
}
