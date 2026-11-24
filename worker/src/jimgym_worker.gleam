import common
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string_tree
import lustre/attribute as attr
import lustre/element/html
import pages/get_session
import pages/list_sessions
import pages/setup
import rada/date
import workout_history
import workout_pages

pub fn render_page(
  page: String,
  year: Int,
  month: Int,
  action: String,
  payload: String,
) -> Result(String, Nil) {
  let decoder = {
    use sessions <- decode.field("sessions", decode.list(session_decoder()))
    use templates <- decode.field("templates", decode.list(template_decoder()))
    use order <- decode.field("order", decode.list(decode.string))
    decode.success(#(sessions, templates, order))
  }
  use model <- result.try(
    json.parse(payload, decoder) |> result.replace_error(Nil),
  )
  let #(sessions, templates, order) = model
  case page, sessions {
    "home", _ ->
      Ok(
        workout_pages.view(workout_pages.home(sessions, templates), [])
        |> string_tree.to_string,
      )
    "calendar", _ ->
      Ok(
        workout_pages.view(
          list_sessions.list_sessions(sessions, year, month, templates),
          [],
        )
        |> string_tree.to_string,
      )
    "setup", _ ->
      Ok(
        workout_pages.view(setup.setup_page(templates), [])
        |> string_tree.to_string,
      )
    "preview", [session] ->
      Ok(
        workout_pages.view_fragment(get_session.get_session_mini(session))
        |> string_tree.to_string,
      )
    "editor", [session] -> Ok(editor(session, action, order))
    "history", _ -> Ok(history(action, sessions))
    _, _ -> Error(Nil)
  }
}

pub fn new_workout(
  iso: String,
  action: String,
  payload: String,
) -> Result(String, Nil) {
  use workout_date <- result.try(
    date.from_iso_string(iso) |> result.replace_error(Nil),
  )
  use template <- result.map(
    json.parse(payload, template_decoder()) |> result.replace_error(Nil),
  )
  editor(
    common.GymSession(
      workout_date,
      template.name,
      common.exercises_from_template(template.exercises),
      template.emoji,
    ),
    action,
    list.map(template.exercises, fn(exercise) { exercise.name }) |> list.unique,
  )
}

fn editor(
  session: common.GymSession,
  action: String,
  order: List(String),
) -> String {
  workout_pages.view(get_session.grouped_session(session, action, order), [
    workout_pages.add_input_button(),
    workout_pages.save_session_button(),
  ])
  |> string_tree.to_string
}

pub fn choose_start(iso: String, payload: String) -> Result(String, Nil) {
  let decoder = {
    use family <- decode.field("family", template_decoder())
    let preview = {
      use label <- decode.field("label", decode.string)
      use session <- decode.field("session", session_decoder())
      decode.success(#(label, session))
    }
    use prior <- decode.field("prior", decode.list(preview))
    decode.success(#(family, prior))
  }
  use model <- result.map(
    json.parse(payload, decoder) |> result.replace_error(Nil),
  )
  let #(family, prior) = model
  let hidden = fn(key, value) {
    html.input([attr.type_("hidden"), attr.name(key), attr.value(value)])
  }
  let fields = [hidden("template", family.name), hidden("date", iso)]
  let form_attrs = [
    attr.action("/new"),
    attr.method("get"),
    attr.class("border p-2 space-y-2"),
  ]
  let submit = fn(label) {
    html.button([attr.type_("submit"), attr.class("border rounded px-2")], [
      html.text(label),
    ])
  }
  workout_pages.view(
    [
      html.h1(
        [
          attr.class(
            "row-start-[header] col-[main-start_/_main-end] text-3xl font-bold",
          ),
        ],
        [html.text(family.name)],
      ),
      html.section(
        [
          attr.class(
            "workout-start row-start-[content] col-[main-start_/_main-end]",
          ),
        ],
        [
          html.form(
            form_attrs,
            list.append(fields, [
              hidden("start", "pick"),
              html.h2([attr.class("font-bold")], [html.text("Pick activities")]),
              html.p([], [
                html.text("Select the activities you want, or start with none."),
              ]),
              html.fieldset(
                [],
                list.index_map(family.exercises, fn(exercise, index) {
                  html.label([attr.class("block")], [
                    html.input([
                      attr.type_("checkbox"),
                      attr.name("activity"),
                      attr.value(int.to_string(index)),
                    ]),
                    html.text(" " <> exercise.name),
                  ])
                }),
              ),
              submit("Start workout"),
            ]),
          ),
          html.h2([], [html.text("Clone a prior workout")]),
          ..case prior {
            [] -> [
              html.p([], [html.text("No earlier workouts in this family.")]),
            ]
            _ ->
              list.map(prior, fn(item) {
                let #(label, session) = item
                let day = date.to_iso_string(session.date)
                html.details([], [
                  html.summary([], [
                    html.time([attr.attribute("datetime", day)], [
                      html.text(label),
                    ]),
                  ]),
                  case dict.is_empty(session.exercises) {
                    True -> html.p([], [html.text("No exercises recorded.")])
                    False -> workout_history.view(session.exercises)
                  },
                  html.form(
                    form_attrs,
                    list.append(fields, [
                      hidden("clone", day),
                      submit("Clone workout"),
                    ]),
                  ),
                ])
              })
          }
        ],
      ),
    ],
    [],
  )
  |> string_tree.to_string
}

fn history(name: String, sessions: List(common.GymSession)) -> String {
  workout_pages.view(
    [
      html.h1(
        [
          attr.class(
            "row-start-[header] col-[main-start_/_main-end] text-3xl font-bold",
          ),
        ],
        [html.text(name <> " history")],
      ),
      html.section(
        [
          attr.class(
            "row-start-[content] col-[main-start_/_main-end] overflow-y-auto",
          ),
        ],
        [
          case sessions {
            [] ->
              html.p([], [
                html.text("No earlier sets recorded for this exercise."),
              ])
            _ ->
              html.ol(
                [],
                list.map(sessions, fn(session) {
                  let day = date.to_iso_string(session.date)
                  let path =
                    "/"
                    <> int.to_string(date.year(session.date))
                    <> "/"
                    <> int.to_string(date.month_number(session.date))
                    <> "/"
                    <> int.to_string(date.day(session.date))
                  let sets =
                    dict.get(session.exercises, name)
                    |> result.unwrap([])
                    |> list.reverse
                  html.li([attr.class("border-b py-2")], [
                    html.a([attr.href(path), attr.class("underline")], [
                      html.text(day <> " · " <> session.session_name),
                    ]),
                    html.p([], [html.text(workout_history.describe_sets(sets))]),
                  ])
                }),
              )
          },
        ],
      ),
    ],
    [],
  )
  |> string_tree.to_string
}

fn session_decoder() -> decode.Decoder(common.GymSession) {
  use iso <- decode.field("date", decode.string)
  case date.from_iso_string(iso) {
    Error(_) ->
      decode.failure(
        common.GymSession(
          date.from_rata_die(1),
          "",
          common.exercises_from_template([]),
          "",
        ),
        "ISO date",
      )
    Ok(workout_date) -> {
      use name <- decode.field("session_name", decode.optional(decode.string))
      use emoji <- decode.field("emoji", decode.optional(decode.string))
      use exercises <- decode.field(
        "exercises",
        decode.list(exercise_decoder(workout_date)),
      )
      decode.success(common.GymSession(
        workout_date,
        option.unwrap(name, "Workout"),
        common.group_records_into_exercises(exercises),
        option.unwrap(emoji, "💪"),
      ))
    }
  }
}

fn exercise_decoder(
  workout_date: date.Date,
) -> decode.Decoder(common.ExerciseRecord) {
  use name <- decode.field("name", decode.string)
  use reps <- decode.field("reps", decode.optional(decode.int))
  use weight <- decode.field("weight", decode.optional(decode.float))
  use duration <- decode.field("duration", decode.optional(decode.int))
  decode.success(common.ExerciseRecord(
    workout_date,
    name,
    reps,
    weight,
    duration,
  ))
}

fn template_decoder() -> decode.Decoder(common.SessionTemplate) {
  use name <- decode.field("name", decode.string)
  use emoji <- decode.field("emoji", decode.string)
  use exercises <- decode.field(
    "exercises",
    decode.list(template_exercise_decoder()),
  )
  decode.success(common.SessionTemplate(name, emoji, exercises))
}

fn template_exercise_decoder() -> decode.Decoder(common.ExerciseTemplate) {
  use name <- decode.field("name", decode.string)
  use kind <- decode.field("exercise_type", decode.string)
  case kind {
    "timed" -> {
      use duration <- decode.field("duration", decode.optional(decode.int))
      decode.success(common.TimedExerciseTemplate(
        name,
        option.unwrap(duration, 0),
      ))
    }
    _ -> {
      use sets <- decode.field("sets", decode.optional(decode.int))
      use reps <- decode.field("reps", decode.optional(decode.int))
      use weight <- decode.field("weight", decode.optional(decode.float))
      decode.success(common.SetsExerciseTemplate(
        name,
        option.unwrap(sets, 3),
        option.unwrap(reps, 10),
        option.unwrap(weight, 0.0),
      ))
    }
  }
}
