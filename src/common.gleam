import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import rada/date

pub type ExerciseTemplate {
  SetsExerciseTemplate(name: String, sets: Int, reps: Int, weight: Float)
  TimedExerciseTemplate(name: String, duration: Int)
}

pub type SessionTemplate {
  SessionTemplate(
    name: String,
    emoji: String,
    exercises: List(ExerciseTemplate),
  )
}

pub type Exercise {
  SetsExercise(name: String, reps: Int, weight: Float)
  TimedExercise(name: String, duration: Int)
}

pub type ExerciseRecord {
  ExerciseRecord(
    date: date.Date,
    name: String,
    reps: Option(Int),
    weight: Option(Float),
    duration: Option(Int),
  )
}

pub type GymSession {
  GymSession(
    date: date.Date,
    session_name: String,
    // Rata die
    exercises: Dict(String, List(Exercise)),
    emoji: String,
  )
}

/// Appends an item to the end of a list
///
pub fn list_append_one(list: List(a), item: a) -> List(a) {
  [[item], list] |> list.reverse |> list.flatten
}

/// Parses a string as a float, being tolerant of integer strings
/// 
pub fn float_parse_tolerant(string: String) -> Float {
  case string.contains(string, ".") {
    True -> string |> float.parse |> result.unwrap(0.0)
    False -> { string <> ".0" } |> float.parse |> result.unwrap(0.0)
  }
}

pub fn group_records_into_exercises(
  records: List(ExerciseRecord),
) -> Dict(String, List(Exercise)) {
  records
  |> list.map(fn(record) {
    case record.duration {
      None ->
        SetsExercise(
          record.name,
          option.unwrap(record.reps, 0),
          option.unwrap(record.weight, 0.0),
        )
      Some(duration) -> TimedExercise(record.name, duration)
    }
  })
  |> list.group(fn(exercise) { exercise.name })
}

pub fn flatten_errors(results: List(Result(a, b))) -> Result(Nil, List(b)) {
  let errors =
    list.fold(results, [], fn(acc, result) {
      case result {
        Ok(_) -> acc
        Error(e) -> [e, ..acc]
      }
    })
    // Reverse the list of errors to maintain the original order
    |> list.reverse

  case errors {
    [] -> Ok(Nil)
    _ -> Error(errors)
  }
}

pub fn format_time(seconds: Int) -> String {
  let minutes = seconds / 60
  let remaining_seconds = seconds % 60
  minutes |> int.to_string <> ":" <> remaining_seconds |> int.to_string
}

pub fn group_exercises_by_sets(exercises: List(Exercise)) {
  let uniques = exercises |> list.unique
  let counts =
    uniques
    |> list.map(fn(exercise) {
      #(exercises |> list.count(fn(e) { e == exercise }), exercise)
    })
  counts
}

// Helper function to get the name of an exercise
pub fn exercise_name(exercise: Exercise) -> String {
  case exercise {
    SetsExercise(name, _, _) -> name
    TimedExercise(name, _) -> name
  }
}

// Helper function to create exercises from a session template
pub fn exercises_from_template(
  template_exercises: List(ExerciseTemplate),
) -> dict.Dict(String, List(Exercise)) {
  let template_to_concrete = fn(template: ExerciseTemplate) -> List(Exercise) {
    case template {
      SetsExerciseTemplate(name, sets, reps, weight) ->
        list.repeat(SetsExercise(name, reps, weight), sets)
      TimedExerciseTemplate(name, duration) -> [TimedExercise(name, duration)]
    }
  }
  template_exercises
  |> list.map(template_to_concrete)
  |> list.flatten
  |> list.group(fn(exercise) { exercise.name })
}

pub fn try_replacing_error(
  result: Result(a, e),
  apply fun: fn(a) -> Result(b, f),
  replacing error_mapper: fn(e) -> f,
) -> Result(b, f) {
  case result {
    Ok(x) -> fun(x)
    Error(y) -> Error(error_mapper(y))
  }
}
