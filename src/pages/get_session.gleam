import common
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import lustre/attribute.{attribute, class, href, id, name, type_}
import lustre/element.{type Element}
import lustre/element/html.{
  a, div, form, h1, section, table, tbody, td, text, tr,
}
import rada/date
import wisp.{type Request}

pub fn get_session(
  _req: Request,
  session: common.GymSession,
) -> List(Element(a)) {
  [
    h1(
      [
        class(
          "font-slab items-center text-6xl font-bold col-[main-start_/_main-end] row-start-[header] flex flex-row gap-2",
        ),
      ],
      [
        html.input([
          attribute.form("session-form"),
          class("text-6xl"),
          id("session_emoji"),
          name("session_emoji"),
          type_("text"),
          attribute.value(session.emoji),
        ]),
        html.input([
          attribute.form("session-form"),
          class("text-6xl"),
          id("session_name"),
          name("session_name"),
          type_("text"),
          attribute.value(session.session_name),
        ]),
      ],
    ),
    form(
      [
        class(
          "px-2 row-start-[content] overflow-y-scroll gap-1 grid col-[main-start_/_main-end] grid-cols-6 grid-auto-rows w-full text-sm",
        ),
        id("session-form"),
      ],
      session.exercises
        |> dict.to_list
        |> list.map(fn(group) { group.1 |> list.index_map(view_exercise_input) })
        |> list.flatten
        |> common.list_append_one(exercise_input_template()),
    ),
  ]
}

//---VIEW HELPERS--------------------------------------------------

fn view_exercise_input(exercise: common.Exercise, index: Int) -> Element(a) {
  case exercise {
    common.SetsExercise(name, reps, weight) ->
      div(
        [
          class(
            "border-b border-gray-100 col-span-6 subgrid-cols gap-1 items-baseline",
          ),
        ],
        [
          html.input([
            class("w-[4ch] text-right col-start-1 col-span-1"),
            type_("number"),
            attribute.step("1"),
            attribute.value(reps |> int.to_string),
            attribute.name(exercise.name <> "|reps|" <> index |> int.to_string),
          ]),
          html.input([
            class("col-start-2 col-span-2 text-left flex justify-start"),
            type_("text"),
            attribute.value(name),
            attribute.name(exercise.name <> "|name|" <> index |> int.to_string),
          ]),
          html.input([
            class(
              "w-[3.5ch] col-start-4 text-left col-span-1 flex justify-start  ",
            ),
            type_("number"),
            attribute.step("0.5"),
            attribute.value(weight |> common.float_to_intstring),
            attribute.name(
              exercise.name <> "|weight|" <> index |> int.to_string,
            ),
          ]),
          text(" kg"),
          html.button(
            [
              class("col-start-6"),
              attribute("fx-action", "delete"),
              attribute("fx-swap", "outerHTML"),
            ],
            [text("❌")],
          ),
        ],
      )
    common.TimedExercise(name, duration) ->
      html.fieldset([class("border-b border-gray-100")], [
        div([class("py-1 text-center")], [
          html.input([
            class(""),
            type_("number"),
            attribute.name(
              exercise.name <> "|duration|" <> index |> int.to_string,
            ),
            attribute.value(duration |> int.to_string),
          ]),
          text("m"),
        ]),
        html.input([
          class("col-start-2 col-span-2 text-left flex justify-start"),
          type_("text"),
          attribute.value(name),
          attribute.name(exercise.name <> "|name|" <> index |> int.to_string),
        ]),
        html.button(
          [
            class("col-start-6"),
            attribute("fx-action", "delete"),
            attribute("fx-swap", "outerHTML"),
          ],
          [text("❌")],
        ),
      ])
  }
}

fn exercise_input_template() -> Element(a) {
  element.fragment([
    html.template([id("/new-sets-exercise-input")], [
      div(
        [
          class(
            "border-b border-gray-100 col-span-6 subgrid-cols gap-1 items-baseline",
          ),
        ],
        [
          html.input([
            class("w-[4ch] text-right col-start-1 col-span-1"),
            type_("number"),
            attribute.step("1"),
            attribute.name("new_exercise|reps|NN"),
          ]),
          html.input([
            class("col-start-2 col-span-2 text-left flex justify-start"),
            type_("text"),
            attribute.name("new_exercise|name|NN"),
          ]),
          html.input([
            class(
              "w-[3.5ch] col-start-4 text-left col-span-1 flex justify-start  ",
            ),
            type_("number"),
            attribute.step("0.5"),
            attribute.name("new_exercise|weight|NN"),
          ]),
          text(" kg"),
          html.button(
            [
              class("col-start-6"),
              attribute("fx-action", "delete"),
              attribute("fx-swap", "outerHTML"),
            ],
            [text("❌")],
          ),
        ],
      ),
    ]),
    html.template([id("/new-timed-exercise-input")], [
      div(
        [
          class(
            "border-b border-gray-100 col-span-6 subgrid-cols gap-1 items-baseline",
          ),
        ],
        [
          html.input([
            class("col-start-2 col-span-2 text-left flex justify-start"),
            type_("text"),
            attribute.name("new_exercise|name|NN"),
          ]),
          html.input([
            class(
              "w-[3.5ch] col-start-4 text-left col-span-1 flex justify-start  ",
            ),
            type_("number"),
            attribute.step("1"),
            attribute.name("new_exercise|duration|NN"),
          ]),
          text("m"),
          html.button(
            [
              class("col-start-6"),
              attribute("fx-action", "delete"),
              attribute("fx-swap", "outerHTML"),
            ],
            [text("❌")],
          ),
        ],
      ),
    ]),
  ])
}

pub fn get_session_mini(
  _req: Request,
  session: common.GymSession,
) -> List(Element(a)) {
  [
    section(
      [
        class(
          "row-start-8 row-span-1 col-span-7 subgrid-cols gap-1 overflow-y-scroll",
        ),
        id("mini_details"),
      ],
      [
        table([class("col-span-6 text-sm")], [
          tbody(
            [],
            session.exercises
              |> dict.values
              |> list.map(view_exercise_history_group)
              |> list.flatten,
          ),
        ]),
        a(
          [
            href(
              "/"
              <> int.to_string(session.date |> date.year)
              <> "/"
              <> int.to_string(session.date |> date.month_number)
              <> "/"
              <> int.to_string(session.date |> date.day),
            ),
            class("row-span-full col-7 flex-col justify-center items-center"),
          ],
          [text("🔎")],
        ),
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
