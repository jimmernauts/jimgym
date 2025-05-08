import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option}
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
  [item, ..list] |> list.reverse
}
