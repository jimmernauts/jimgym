import common
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute.{class, scope}
import lustre/element.{type Element}
import lustre/element/html.{table, tbody, td, text, th, tr}

pub fn view(exercises: dict.Dict(String, List(common.Exercise))) -> Element(a) {
  table([class("col-span-6 text-sm")], [
    tbody(
      [],
      dict.to_list(exercises)
        |> list.map(fn(group) {
          let #(name, sets) = group
          tr([class("border-b border-gray-100")], [
            th([scope("row"), class("py-1 text-left")], [text(name)]),
            // list.group builds each group in reverse record order.
            td([class("py-1")], [text(describe_sets(list.reverse(sets)))]),
          ])
        }),
    ),
  ])
}

pub fn describe_sets(sets: List(common.Exercise)) -> String {
  case sets {
    [common.SetsExercise(_, _, weight), ..] -> {
      case
        list.all(sets, fn(set) {
          case set {
            common.SetsExercise(_, _, other) -> weight == other
            _ -> False
          }
        })
      {
        True -> {
          let reps =
            list.filter_map(sets, fn(set) {
              case set {
                common.SetsExercise(_, reps, _) -> Ok(int.to_string(reps))
                _ -> Error(Nil)
              }
            })
          string.join(reps, ", ") <> " reps" <> weight_suffix(weight)
        }
        False -> list.map(sets, describe_set) |> string.join("; ")
      }
    }
    [common.TimedExercise(..), ..] ->
      list.map(sets, describe_set) |> string.join("; ")
    [] -> ""
  }
}

fn describe_set(set: common.Exercise) -> String {
  case set {
    common.SetsExercise(_, reps, weight) ->
      int.to_string(reps) <> " reps" <> weight_suffix(weight)
    common.TimedExercise(_, duration) -> int.to_string(duration) <> " min"
  }
}

fn weight_suffix(weight: Float) -> String {
  case weight {
    -1.0 -> " (bodyweight)"
    0.0 -> ""
    _ -> {
      let label = float.to_string(weight)
      let label = case string.ends_with(label, ".0") {
        True -> string.drop_end(label, 2)
        False -> label
      }
      " @ " <> label <> " kg"
    }
  }
}
