import common
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute.{class, id, name, style, type_}
import lustre/element.{type Element}
import lustre/element/html.{div, form, h1, section, table, tbody, td, text, tr}
import rada/date
import wisp.{type Request, type Response}

pub fn get_session(req: Request, session: common.GymSession) -> List(Element(a)) {
  [
    h1(
      [
        class(
          "font-slab text-7xl font-bold col-[main-start_/_main-end] row-start-[header] flex flex-row gap-2",
        ),
      ],
      [
        html.input([
          attribute.form("session-form"),
          id("session-emoji"),
          type_("text"),
          attribute.value(session.emoji),
        ]),
        html.input([
          attribute.form("session-form"),
          id("session-name"),
          type_("text"),
          attribute.value(session.session_name),
        ]),
      ],
    ),
    form(
      [
        class(
          "px-2 row-start-[content] overflow-y-scroll gap-1 grid col-[main-start_/_main-end] grid-cols-6 w-full text-sm",
        ),
        id("session-form"),
      ],
      session.exercises
        |> dict.to_list
        |> list.map(fn(group) { group.1 |> list.index_map(view_exercise_input) })
        |> list.flatten,
    ),
  ]
}

//---VIEW HELPERS--------------------------------------------------

fn view_exercise_input(exercise: common.Exercise, index: Int) -> Element(a) {
  case exercise {
    common.SetsExercise(name, reps, weight) ->
      div([class("border-b border-gray-100 col-span-6 subgrid-cols gap-1")], [
        html.input([
          class("w-[4ch] text-right col-start-1 col-span-1"),
          type_("number"),
          attribute.step("1"),
          attribute.value(reps |> int.to_string),
          attribute.name(exercise.name <> "-reps-" <> index |> int.to_string),
        ]),
        html.input([
          class(
            "col-start-2 col-span-2 text-center items-center flex justify-start",
          ),
          type_("text"),
          attribute.value(name),
          attribute.name(exercise.name <> "-name-" <> index |> int.to_string),
        ]),
        html.input([
          class(
            "w-[3.5ch] text-center col-start-4 items-center col-span-1 flex justify-end",
          ),
          type_("number"),
          attribute.step("0.5"),
          attribute.value(weight |> float.to_string),
          attribute.name(exercise.name <> "-weight-" <> index |> int.to_string),
        ]),
        text(" kg"),
      ])
    common.TimedExercise(name, duration) ->
      html.fieldset([class("border-b border-gray-100")], [
        div([class("py-1 text-center")], [
          html.input([
            class(""),
            type_("number"),
            attribute.name(
              exercise.name <> "-duration-" <> index |> int.to_string,
            ),
            attribute.value(duration |> int.to_string),
          ]),
          text("m"),
        ]),
        div([class("py-1")], [text(name)]),
      ])
  }
}

pub fn get_session_mini(
  req: Request,
  session: common.GymSession,
) -> List(Element(a)) {
  [
    section(
      [
        class("mt-4 row-start-8 row-span-1 col-span-7 overflow-y-scroll"),
        id("mini_details"),
      ],
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
    ),
  ]
}

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
