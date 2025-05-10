import gleam/dict.{type Dict}
import gleam/float
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import rada/date

pub type ExerciseTemplate {
  SetsExerciseTemplate(
    name: String,
    sets: Int,
    reps: Int,
    weight: Float,
    rest: Int,
  )
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
  SetsExercise(name: String, reps: Int, weight: Float, rest: Int)
  TimedExercise(name: String, duration: Int)
}

pub type ExerciseRecord {
  ExerciseRecord(
    date: String,
    name: String,
    reps: Option(Int),
    weight: Option(Float),
    duration: Option(Int),
  )
}

pub type GymSession {
  GymSession(
    date: date.Date,
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
