import common
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute.{class, style, type_}
import lustre/element.{type Element}
import lustre/element/html.{h1, table, tbody, td, text, tr}
import rada/date
import wisp.{type Request, type Response}

pub fn get_session(req: Request, session: common.GymSession) -> List(Element(a)) {
  [
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

//---VIEW HELPERS--------------------------------------------------

fn view_exercise_input(exercise: common.Exercise, index: Int) -> Element(a) {
  case exercise {
    common.SetsExercise(name, reps, weight, rest) ->
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
                True -> style("padding-left", "1ch")
                False -> attribute.none()
              },
              class("w-[2ch]"),
              type_("number"),
              attribute.step("1"),
              attribute.value(reps |> int.to_string),
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
          [text(rest |> int.to_string <> "s ⌛")],
        ),
      ])
    common.TimedExercise(name, duration) ->
      tr([class("border-b border-gray-100")], [
        td([class("py-1 text-center")], [
          html.input([
            class(""),
            type_("number"),
            attribute.value(duration |> int.to_string),
          ]),
          text("m"),
        ]),
        td([class("py-1")], [
          text(name),
          text(common.format_time(duration * 60) <> "s ⌛"),
        ]),
      ])
  }
}
