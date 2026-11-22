import common
import gleam/float
import gleam/int
import gleam/list
import gleam/uri
import lustre/attribute.{class, href, name, type_, value}
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, div, form, h2, h3, input, label, option, section, select, table,
  tbody, td, text, tr,
}

pub fn setup_page(
  templates: List(common.SessionTemplate),
  editable: Bool,
) -> List(Element(a)) {
  [
    div(
      [
        class(
          "text-4xl font-slab font-bold col-[main-start_/_main-end] row-start-[header] flex items-center gap-8",
        ),
      ],
      [a([href("/")], [text("⚙️")]), h2([], [text("Setup Sessions")])],
    ),
    section(
      [
        class(
          "mt-2 col-[main-start_/_main-end] row-start-[content] overflow-y-auto",
        ),
      ],
      [
        div(
          [class("flex flex-col gap-4")],
          list.flatten([
            case editable {
              True -> list.map(templates, view_session_template_card)
              False -> list.map(templates, view_read_only_template)
            },
            case editable {
              True -> [view_add_template_form()]
              False -> [
                html.p([], [text("Template editing is not available yet.")]),
              ]
            },
          ]),
        ),
      ],
    ),
  ]
}

fn view_session_template_card(template: common.SessionTemplate) -> Element(a) {
  let encoded_name = template.name |> uri.percent_encode
  div(
    [
      class(
        "bg-white border-2 font-hand border-uchu-yin rounded-md overflow-hidden",
      ),
    ],
    [
      // Header with name/emoji and action buttons
      div(
        [
          class(
            "pt-2 pb-1 px-2 bg-uchu-light-gray flex justify-between items-center",
          ),
        ],
        [
          h3([class("font-slab font-bold text-3xl")], [
            text(template.emoji <> " " <> template.name),
          ]),
          div([class("flex gap-2")], [
            // Edit button - toggles edit form
            button(
              [
                type_("button"),
                class("text-xl cursor-pointer hover:bg-blue-100 p-1 rounded"),
                attribute.attribute("popovertarget", "edit-" <> encoded_name),
              ],
              [text("✏️")],
            ),
            // Delete button
            form(
              [
                attribute.method("post"),
                attribute.action("/setup/delete"),
                class("inline"),
              ],
              [
                input([
                  type_("hidden"),
                  name("template_name"),
                  value(template.name),
                ]),
                button(
                  [
                    type_("submit"),
                    class("text-xl cursor-pointer hover:bg-red-100 p-1 rounded"),
                    attribute.attribute(
                      "onclick",
                      "return confirm('Delete " <> template.name <> "?')",
                    ),
                  ],
                  [text("🗑️")],
                ),
              ],
            ),
          ]),
        ],
      ),
      // Edit popover form
      div(
        [
          attribute.id("edit-" <> encoded_name),
          attribute.attribute("popover", ""),
          class(
            "p-4 bg-white border-2 border-uchu-yin rounded-md shadow-lg max-w-md m-auto",
          ),
        ],
        [
          form([attribute.method("post"), attribute.action("/setup/update")], [
            input([
              type_("hidden"),
              name("old_name"),
              value(template.name),
            ]),
            h3([class("font-slab font-bold text-xl mb-3")], [
              text("Edit Template"),
            ]),
            div([class("flex gap-2 items-center mb-3")], [
              input([
                type_("text"),
                name("emoji"),
                value(template.emoji),
                class(
                  "w-16 p-2 border border-uchu-yin rounded text-center text-2xl",
                ),
                attribute.required(True),
              ]),
              input([
                type_("text"),
                name("new_name"),
                value(template.name),
                class("flex-1 p-2 border border-uchu-yin rounded"),
                attribute.required(True),
              ]),
            ]),
            button(
              [
                type_("submit"),
                class(
                  "w-full bg-uchu-light-gray border-2 border-uchu-yin rounded px-4 py-2 font-slab font-bold cursor-pointer",
                ),
              ],
              [text("Save")],
            ),
          ]),
        ],
      ),
      // Exercises list
      div([class("p-4 border-t border-uchu-yin")], [
        table([class("w-full text-sm")], [
          tbody(
            [],
            template.exercises
              |> list.map(fn(exercise) {
                view_exercise_row(template.name, exercise)
              }),
          ),
        ]),
        // Add exercise form
        view_add_exercise_form(template.name),
      ]),
    ],
  )
}

fn view_exercise_row(
  template_name: String,
  exercise: common.ExerciseTemplate,
) -> Element(a) {
  case exercise {
    common.SetsExerciseTemplate(name, sets, reps, weight) ->
      tr([class("border-b border-gray-100 group")], [
        td([class("py-1 text-center")], [
          text(int.to_string(sets) <> "×" <> int.to_string(reps)),
        ]),
        td([class("py-1")], [text(name)]),
        td([class("py-1 text-center")], [text(format_weight(weight))]),
        td([class("py-1 text-right")], [
          form(
            [
              attribute.method("post"),
              attribute.action("/setup/exercise/delete"),
              class("inline"),
            ],
            [
              input([
                type_("hidden"),
                attribute.name("template_name"),
                value(template_name),
              ]),
              input([
                type_("hidden"),
                attribute.name("exercise_name"),
                value(name),
              ]),
              button(
                [
                  type_("submit"),
                  class(
                    "text-sm cursor-pointer hover:bg-red-100 p-1 rounded opacity-50 group-hover:opacity-100",
                  ),
                ],
                [text("✕")],
              ),
            ],
          ),
        ]),
      ])
    common.TimedExerciseTemplate(name, duration) ->
      tr([class("border-b border-gray-100 group")], [
        td([class("py-1 text-center")], [
          text(int.to_string(duration) <> "m"),
        ]),
        td([class("py-1")], [text(name)]),
        td([class("py-1")], []),
        td([class("py-1 text-right")], [
          form(
            [
              attribute.method("post"),
              attribute.action("/setup/exercise/delete"),
              class("inline"),
            ],
            [
              input([
                type_("hidden"),
                attribute.name("template_name"),
                value(template_name),
              ]),
              input([
                type_("hidden"),
                attribute.name("exercise_name"),
                value(name),
              ]),
              button(
                [
                  type_("submit"),
                  class(
                    "text-sm cursor-pointer hover:bg-red-100 p-1 rounded opacity-50 group-hover:opacity-100",
                  ),
                ],
                [text("✕")],
              ),
            ],
          ),
        ]),
      ])
  }
}

fn view_add_exercise_form(template_name: String) -> Element(a) {
  let encoded_name = template_name |> uri.percent_encode
  div([class("mt-3 pt-3 border-t border-dashed border-gray-300")], [
    button(
      [
        type_("button"),
        class("text-sm text-gray-500 cursor-pointer hover:text-gray-700"),
        attribute.attribute("popovertarget", "add-ex-" <> encoded_name),
      ],
      [text("➕ Add exercise")],
    ),
    div(
      [
        attribute.id("add-ex-" <> encoded_name),
        attribute.attribute("popover", ""),
        class(
          "p-4 bg-white border-2 border-uchu-yin rounded-md shadow-lg m-auto",
        ),
      ],
      [
        form(
          [attribute.method("post"), attribute.action("/setup/exercise/add")],
          [
            input([type_("hidden"), name("template_name"), value(template_name)]),
            h3([class("font-slab font-bold text-lg mb-3")], [
              text("Add Exercise to " <> template_name),
            ]),
            div([class("flex flex-col gap-2")], [
              // Exercise type
              div([class("flex gap-2")], [
                label([class("w-20")], [text("Type:")]),
                select(
                  [
                    name("exercise_type"),
                    class("flex-1 p-2 border border-uchu-yin rounded"),
                  ],
                  [
                    option([value("sets")], "Sets"),
                    option([value("timed")], "Timed"),
                  ],
                ),
              ]),
              // Exercise name
              div([class("flex gap-2")], [
                label([class("w-20")], [text("Name:")]),
                input([
                  type_("text"),
                  name("exercise_name"),
                  attribute.placeholder("Exercise name"),
                  class("flex-1 p-2 border border-uchu-yin rounded"),
                  attribute.required(True),
                ]),
              ]),
              // Sets (for sets exercises)
              div([class("flex gap-2")], [
                label([class("w-20")], [text("Sets:")]),
                input([
                  type_("number"),
                  name("sets"),
                  value("3"),
                  class("flex-1 p-2 border border-uchu-yin rounded"),
                ]),
              ]),
              // Reps (for sets exercises)
              div([class("flex gap-2")], [
                label([class("w-20")], [text("Reps:")]),
                input([
                  type_("number"),
                  name("reps"),
                  value("10"),
                  class("flex-1 p-2 border border-uchu-yin rounded"),
                ]),
              ]),
              // Weight (for sets exercises)
              div([class("flex gap-2")], [
                label([class("w-20")], [text("Weight:")]),
                input([
                  type_("number"),
                  name("weight"),
                  attribute.step("0.5"),
                  attribute.placeholder("0"),
                  class("flex-1 p-2 border border-uchu-yin rounded"),
                ]),
              ]),
              // Duration (for timed exercises)
              div([class("flex gap-2")], [
                label([class("w-20")], [text("Duration:")]),
                input([
                  type_("number"),
                  name("duration"),
                  attribute.placeholder("minutes"),
                  class("flex-1 p-2 border border-uchu-yin rounded"),
                ]),
              ]),
              button(
                [
                  type_("submit"),
                  class(
                    "mt-2 bg-uchu-light-gray border-2 border-uchu-yin rounded px-4 py-2 font-slab font-bold cursor-pointer",
                  ),
                ],
                [text("Add Exercise")],
              ),
            ]),
          ],
        ),
      ],
    ),
  ])
}

fn view_add_template_form() -> Element(a) {
  div(
    [
      class(
        "bg-white border-2 border-dashed font-hand border-uchu-yin rounded-md overflow-hidden",
      ),
    ],
    [
      form(
        [
          attribute.method("post"),
          attribute.action("/setup/create"),
          class("p-4"),
        ],
        [
          h3([class("font-slab font-bold text-xl mb-3")], [
            text("➕ Add New Template"),
          ]),
          div([class("flex gap-2 items-center")], [
            input([
              type_("text"),
              name("emoji"),
              attribute.placeholder("💪"),
              class(
                "w-16 p-2 border border-uchu-yin rounded text-center text-2xl",
              ),
              attribute.required(True),
            ]),
            input([
              type_("text"),
              name("template_name"),
              attribute.placeholder("Template name"),
              class("flex-1 p-2 border border-uchu-yin rounded"),
              attribute.required(True),
            ]),
            button(
              [
                type_("submit"),
                class(
                  "bg-uchu-light-gray border-2 border-uchu-yin rounded px-4 py-2 font-slab font-bold cursor-pointer",
                ),
              ],
              [text("Add")],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn format_weight(weight: Float) -> String {
  case weight {
    0.0 -> ""
    w if w <. 0.0 -> ""
    weight -> {
      let int_part = float.truncate(weight)
      let decimal_part = weight -. int.to_float(int_part)

      case decimal_part <. 0.01 || decimal_part >. 0.99 {
        True -> int.to_string(int_part) <> "kg"
        False -> {
          let decimal_str =
            decimal_part *. 10.0
            |> float.round
            |> int.to_string

          int.to_string(int_part) <> "." <> decimal_str <> "kg"
        }
      }
    }
  }
}

fn view_read_only_template(template: common.SessionTemplate) -> Element(a) {
  section([class("border p-4")], [
    h3([class("font-bold")], [text(template.emoji <> " " <> template.name)]),
    html.ul(
      [],
      list.map(template.exercises, fn(exercise) {
        html.li([], [
          text(case exercise {
            common.SetsExerciseTemplate(name, sets, reps, weight) ->
              name
              <> " · "
              <> int.to_string(sets)
              <> "×"
              <> int.to_string(reps)
              <> " · "
              <> format_weight(weight)
              <> " kg"
            common.TimedExerciseTemplate(name, duration) ->
              name <> " · " <> int.to_string(duration) <> " min"
          }),
        ])
      }),
    ),
  ])
}
