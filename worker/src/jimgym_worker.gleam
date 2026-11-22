import common
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import lustre/attribute.{charset, class, content, href, name, rel}
import lustre/element
import lustre/element/html
import rada/date
import workout_history

pub fn render_workout(
  iso_date: String,
  payload: String,
) -> Result(String, Nil) {
  use workout_date <- result.try(
    date.from_iso_string(iso_date) |> result.replace_error(Nil),
  )
  let decoder = {
    use name <- decode.field("name", decode.optional(decode.string))
    use emoji <- decode.field("emoji", decode.optional(decode.string))
    use exercises <- decode.field(
      "exercises",
      decode.list(exercise_decoder(workout_date)),
    )
    decode.success(common.GymSession(
      workout_date,
      option.unwrap(name, "Workout"),
      common.group_records_into_exercises(exercises),
      option.unwrap(emoji, ""),
    ))
  }
  use session <- result.map(
    json.parse(payload, decoder) |> result.replace_error(Nil),
  )
  let title = session.session_name
  html.html([], [
    html.head([], [
      html.meta([charset("UTF-8")]),
      html.meta([
        name("viewport"),
        content("width=device-width, initial-scale=1.0"),
      ]),
      html.title([], title),
      html.link([rel("stylesheet"), href("/jimgym.css")]),
    ]),
    html.body([class("p-2")], [
      html.main([], [
        html.h1([class("text-4xl font-bold")], [
          html.text(session.emoji <> " " <> title),
        ]),
        html.p([], [html.text(iso_date)]),
        workout_history.view(session.exercises),
      ]),
    ]),
  ])
  |> element.to_document_string
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
