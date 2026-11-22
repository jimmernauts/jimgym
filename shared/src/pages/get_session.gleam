import common
import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute.{attribute, class, href, id, name, type_}
import lustre/element.{type Element}
import lustre/element/html.{a, div, form, h1, section, text}
import rada/date
import workout_history

pub fn get_session(
  session: common.GymSession,
  action: String,
) -> List(Element(a)) {
  [
    h1(
      [
        class(
          "font-slab items-center text-4xl font-bold col-[main-start_/_main-end] row-start-[header] flex flex-row gap-2",
        ),
        attribute.style("min-width", "0"),
      ],
      [
        html.input([
          attribute.form("session-form"),
          class("text-4xl"),
          attribute.style("flex", "0 0 4rem"),
          attribute.style("width", "4rem"),
          id("session_emoji"),
          name("session_emoji"),
          type_("text"),
          attribute.value(session.emoji),
        ]),
        html.input([
          attribute.form("session-form"),
          class("text-4xl flex-1"),
          attribute.style("min-width", "0"),
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
          "row-start-[content] overflow-y-scroll gap-1 gap-y-3 grid col-[main-start_/_main-end] grid-cols-12 grid-rows-auto w-full text-sm",
        ),
        id("session-form"),
        attribute.action(action),
      ],
      session.exercises
        |> dict.to_list
        |> list.map(fn(group) { group.1 |> list.index_map(view_exercise_input) })
        |> list.flatten,
    ),
    exercise_input_template(),
  ]
}

//---VIEW HELPERS--------------------------------------------------

fn view_exercise_input(exercise: common.Exercise, index: Int) -> Element(a) {
  div(
    [
      class("text-xl col-span-full subgrid-cols gap-1 items-baseline"),
      id(
        "exercise_"
        <> exercise.name |> string.replace(" ", "_")
        <> "_"
        <> index |> int.to_string,
      ),
    ],
    case exercise {
      common.SetsExercise(name, reps, weight) -> [
        rep_input(name, reps, index),
        name_input(name, index),
        case weight {
          -1.0 ->
            html.input([
              type_("hidden"),
              attribute.name(name <> "|weight|" <> int.to_string(index)),
              attribute.value("-1"),
            ])
          _ -> weight_input(name, weight, index)
        },
        exercise_row_buttons(exercise, index),
      ]
      common.TimedExercise(name, duration) -> [
        div([class("col-span-3 flex justify-center gap-1")], [
          html.input([
            class("text-right"),
            type_("number"),
            attribute.name(
              exercise.name <> "|duration|" <> index |> int.to_string,
            ),
            attribute.value(duration |> int.to_string),
          ]),
          text("m"),
        ]),
        name_input(name, index),
        exercise_row_buttons(exercise, index),
      ]
    },
  )
}

fn rep_input(name: String, reps: Int, index: Int) {
  div([class("col-span-2 flex items-start justify-between gap-1")], [
    html.input([
      class("w-[2ch] text-right"),
      type_("number"),
      attribute.step("1"),
      attribute.value(reps |> int.to_string),
      attribute.name(name <> "|reps|" <> index |> int.to_string),
    ]),
    div([class("flex flex-col text-sm gap-1")], [
      html.button(
        [
          type_("button"),
          attribute(
            "fx-action",
            "increment-reps/" <> name <> "/" <> index |> int.to_string,
          ),
          attribute("fx-swap", "none"),
        ],
        [text("➕")],
      ),
      html.button(
        [
          type_("button"),
          attribute(
            "fx-action",
            "decrement-reps/" <> name <> "/" <> index |> int.to_string,
          ),
          attribute("fx-swap", "none"),
        ],
        [text("➖")],
      ),
    ]),
  ])
}

fn weight_input(name: String, weight: Float, index: Int) {
  div([class("col-span-3 flex justify-between gap-1")], [
    div([class("items-baseline flex text-sm")], [
      html.input([
        class("w-[3.5ch] text-right text-xl"),
        type_("number"),
        attribute.step("0.5"),
        attribute.value(weight |> common.float_to_intstring),
        attribute.name(name <> "|weight|" <> index |> int.to_string),
      ]),
      case weight {
        0.0 -> element.none()
        _ -> html.text("kg")
      },
    ]),
    div([class("flex flex-col text-sm gap-1")], [
      html.button(
        [
          type_("button"),
          attribute(
            "fx-action",
            "increment-weight/" <> name <> "/" <> index |> int.to_string,
          ),
          attribute("fx-swap", "none"),
        ],
        [text("➕")],
      ),
      html.button(
        [
          type_("button"),
          attribute(
            "fx-action",
            "decrement-weight/" <> name <> "/" <> index |> int.to_string,
          ),
          attribute("fx-swap", "none"),
        ],
        [text("➖")],
      ),
    ]),
  ])
}

fn name_input(name: String, index: Int) {
  html.input([
    class("col-start-4 col-span-5 text-left field-sizing-content"),
    type_("text"),
    attribute.value(name),
    attribute.name(name <> "|name|" <> index |> int.to_string),
  ])
}

fn exercise_row_buttons(exercise: common.Exercise, index: Int) {
  div([class("col-start-12 flex flex-col self-end text-sm gap-1")], [
    html.button(
      [
        type_("button"),
        attribute(
          "fx-action",
          "delete/" <> exercise.name <> "/" <> index |> int.to_string,
        ),
        attribute("fx-swap", "outerHTML"),
      ],
      [text("❌")],
    ),
    html.button(
      [
        type_("button"),
        attribute(
          "fx-action",
          "clone/" <> exercise.name <> "/" <> index |> int.to_string,
        ),
        attribute("fx-swap", "afterend"),
      ],
      [text("📚")],
    ),
  ])
}

//this is the default template we get when we insert a new exercise. 
//it uses an index of 99 which gets replaced by the fixi extension when it is swapped in.
fn exercise_input_template() -> Element(a) {
  element.fragment([
    html.template([id("/new-sets-exercise-input")], [
      view_exercise_input(common.SetsExercise("New Exercise", 0, 0.0), -99),
    ]),
    html.template([id("/new-timed-exercise-input")], [
      view_exercise_input(common.TimedExercise("New Exercise", 0), -99),
    ]),
  ])
}

pub fn get_session_mini(session: common.GymSession) -> List(Element(a)) {
  [
    section(
      [
        class(
          "row-start-8 row-span-1 col-span-7 subgrid-cols gap-1 overflow-y-scroll",
        ),
        id("mini_details"),
      ],
      [
        workout_history.view(session.exercises),
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
