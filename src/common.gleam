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

pub const session_templates = [
  SessionTemplate(
    "Whole Body Full",
    "💪",
    [
      SetsExerciseTemplate("Bench Press", 3, 10, 35.0),
      SetsExerciseTemplate("Pull-ups", 3, 8, 14.0),
      SetsExerciseTemplate("Rows", 3, 10, 25.0),
      SetsExerciseTemplate("Shoulder Press", 3, 8, 18.0),
      SetsExerciseTemplate("ATG Squat", 3, 10, -1.0),
    ],
  ),
  SessionTemplate(
    "Rehab",
    "🧎",
    [
      SetsExerciseTemplate("Patrick Step", 3, 20, 0.0),
    ],
  ),
  SessionTemplate("Ride", "🚴", [TimedExerciseTemplate("Bike ride", 45)]),
  SessionTemplate(
    "Cardio",
    "🏃",
    [
      TimedExerciseTemplate("Backwards Treadmill", 20),
      TimedExerciseTemplate("Rowing", 10),
    ],
  ),
]

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

/// Applies a function to a successful result, or maps the error using a provided function.
///
/// This is useful when you want to transform a result but need to handle both
/// the success and error cases with different functions.
///
/// ## Examples
/// ```gleam
/// // Convert a string to an int, defaulting to 0 on error
/// "42"
/// |> int.parse
/// |> try_replacing_error(fn(x) { Ok(x) }, fn(_) { 0 })
/// // -> Ok(42)
///
/// "not a number"
/// |> int.parse
/// |> try_replacing_error(fn(x) { Ok(x) }, fn(_) { 0 })
/// // -> Error(0)
/// ```
///
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

///------LIST UTILS------------------------------------------------------------
/// Appends an item to the end of a list
///
pub fn list_append_one(list: List(a), item: a) -> List(a) {
  [[item], list] |> list.reverse |> list.flatten
}

/// Return the `n`th element of a list, or `None` if the list is too short.
pub fn list_at(list: List(a), n: Int) -> Option(a) {
  case list {
    [] -> None
    [x, ..] if n == 0 -> Some(x)
    [_x, ..xs] -> list_at(xs, n - 1)
  }
}

pub fn list_first_and_last(of list: List(a)) -> List(a) {
  let first = list |> list.first
  let last = list |> list.reverse |> list.first
  case first, last {
    Ok(first), Ok(last) -> [first, last]
    _, _ -> []
  }
}

pub fn list_keep_ok(results: List(Result(a, e))) -> List(a) {
  results
  |> list.map(fn(result) {
    case result {
      Ok(x) -> [x]
      Error(_) -> []
    }
  })
  |> list.flatten
}

pub fn float_to_intstring(input: Float) -> String {
  case input {
    0.0 -> ""
    input -> {
      // Check if it's effectively an integer
      let int_part = float.truncate(input)
      let decimal_part = input -. int.to_float(int_part)

      case decimal_part <. 0.01 || decimal_part >. 0.99 {
        True -> int.to_string(int_part)
        False -> {
          // Format with 1 decimal place if it's a true float
          let decimal_str =
            decimal_part *. 10.0
            |> float.round
            |> int.to_string

          int.to_string(int_part) <> "." <> decimal_str
        }
      }
    }
  }
}
