import common.{
  type Exercise, type GymSession, GymSession, SetsExercise, TimedExercise,
}
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import pages/update_session.{parse_formdata_to_session}
import rada/date
import startest.{describe, it}
import startest/expect
import wisp.{type FormData, FormData}

// Helper to create a consistent date for tests
fn test_date() -> date.Date {
  let default_date = case date.from_iso_string("0001-01-01") {
    Ok(d) -> d
    Error(_) ->
      panic as "Critical test setup: Failed to parse fallback min date '0001-01-01'"
  }

  date.from_iso_string("2024-01-01")
  |> result.unwrap(or: default_date)
  // "2024-01-01" should always parse for tests
}

// Helper to sort exercises within a GymSession for consistent comparison
fn sort_session_exercises(session: GymSession) -> GymSession {
  let sorted_exercise_map =
    session.exercises
    |> dict.map_values(fn(_, exercises) {
      exercises
      |> list.sort(fn(a, b) {
        case a, b {
          TimedExercise(name: na, duration: da),
            TimedExercise(name: nb, duration: db)
          -> {
            let name_cmp = string.compare(na, nb)
            case name_cmp {
              order.Eq -> int.compare(da, db)
              _ -> name_cmp
            }
          }
          SetsExercise(name: na, reps: ra, weight: wa),
            SetsExercise(name: nb, reps: rb, weight: wb)
          -> {
            let name_cmp = string.compare(na, nb)
            case name_cmp {
              order.Eq -> {
                let reps_cmp = int.compare(ra, rb)
                case reps_cmp {
                  order.Eq -> float.compare(wa, wb)
                  _ -> reps_cmp
                }
              }
              _ -> name_cmp
            }
          }
          TimedExercise(..), SetsExercise(..) -> order.Lt
          SetsExercise(..), TimedExercise(..) -> order.Gt
        }
      })
    })
  GymSession(..session, exercises: sorted_exercise_map)
}

// Custom assertion helper for GymSession equality
fn assert_gym_session_equal(
  actual: Result(GymSession, String),
  expected: Result(GymSession, String),
) {
  case actual, expected {
    Ok(act), Ok(exp) -> {
      let sorted_act = sort_session_exercises(act)
      let sorted_exp = sort_session_exercises(exp)

      sorted_act.date |> expect.to_equal(sorted_exp.date)
      sorted_act.session_name |> expect.to_equal(sorted_exp.session_name)
      sorted_act.emoji |> expect.to_equal(sorted_exp.emoji)
      // Compare exercise dictionaries
      // First check keys are the same
      dict.keys(sorted_act.exercises)
      |> list.sort(string.compare)
      |> expect.to_equal(
        dict.keys(sorted_exp.exercises) |> list.sort(string.compare),
      )

      // Then check exercise lists for each key
      dict.keys(sorted_act.exercises)
      |> list.each(fn(key) {
        let act_exs =
          dict.get(sorted_act.exercises, key) |> result.unwrap(or: [])
        let exp_exs =
          dict.get(sorted_exp.exercises, key) |> result.unwrap(or: [])
        act_exs |> expect.to_equal(exp_exs)
      })
    }
    Error(act_err), Error(exp_err) -> act_err |> expect.to_equal(exp_err)
    Ok(res), Error(err_exp) -> {
      let message_actual = "Got Ok(" <> string.inspect(res) <> ")"
      let message_expected = "Expected Error(" <> string.inspect(err_exp) <> ")"
      // This will fail and show both strings, indicating the mismatch
      message_actual |> expect.to_equal(message_expected)
    }
    Error(err_res), Ok(exp) -> {
      let message_actual = "Got Error(" <> string.inspect(err_res) <> ")"
      let message_expected = "Expected Ok(" <> string.inspect(exp) <> ")"
      // This will fail and show both strings, indicating the mismatch
      message_actual |> expect.to_equal(message_expected)
    }
  }
}

pub fn parse_formdata_to_session_tests() {
  let today = test_date()

  describe("Parse formdata", [
    describe("well-formed input", [
      it("returns a valid session with one timed exercise", fn() {
        let form_data = [
          #("session_name", "Morning Run"),
          #("session_emoji", "🏃"),
          #("exercise|name|1", "Run"),
          #("exercise|duration|1", "30"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Morning Run",
            emoji: "🏃",
            exercises: dict.from_list([
              #("Run", [TimedExercise(name: "Run", duration: 30)]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it(
        "returns a valid session with one sets-based exercise (integer weight)",
        fn() {
          let form_data = [
            #("session_name", "Strength Training"),
            #("session_emoji", "💪"),
            #("exercise|name|s1", "Squats"),
            #("exercise|reps|s1", "5"),
            #("exercise|weight|s1", "100"),
          ]
          let expected =
            Ok(GymSession(
              date: today,
              session_name: "Strength Training",
              emoji: "💪",
              exercises: dict.from_list([
                #("Squats", [
                  SetsExercise(name: "Squats", reps: 5, weight: 100.0),
                ]),
              ]),
            ))
          parse_formdata_to_session(
            today,
            FormData(values: form_data, files: []),
          )
          |> assert_gym_session_equal(expected)
        },
      ),
      it(
        "returns a valid session with one sets-based exercise (float weight)",
        fn() {
          let form_data = [
            #("session_name", "Strength Training Float"),
            #("session_emoji", "🏋️"),
            #("exercise|name|s1", "Bench Press"),
            #("exercise|reps|s1", "8"),
            #("exercise|weight|s1", "60.5"),
          ]
          let expected =
            Ok(GymSession(
              date: today,
              session_name: "Strength Training Float",
              emoji: "🏋️",
              exercises: dict.from_list([
                #("Bench Press", [
                  SetsExercise(name: "Bench Press", reps: 8, weight: 60.5),
                ]),
              ]),
            ))
          parse_formdata_to_session(
            today,
            FormData(values: form_data, files: []),
          )
          |> assert_gym_session_equal(expected)
        },
      ),
      it("returns a valid session with multiple different exercises", fn() {
        let form_data = [
          #("session_name", "Full Body Workout"),
          #("session_emoji", "🤸"),
          #("exercise|name|cardio1", "Cycling"),
          #("exercise|duration|cardio1", "25"),
          #("exercise|name|strength1", "Push-ups"),
          #("exercise|reps|strength1", "15"),
          #("exercise|weight|strength1", "0"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Full Body Workout",
            emoji: "🤸",
            exercises: dict.from_list([
              #("Cycling", [TimedExercise(name: "Cycling", duration: 25)]),
              #("Push-ups", [
                SetsExercise(name: "Push-ups", reps: 15, weight: 0.0),
              ]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it(
        "returns a valid session with multiple sets of the same exercise",
        fn() {
          let form_data = [
            #("session_name", "Leg Day"),
            #("session_emoji", "🦵"),
            #("exercise|name|set1", "Squats"),
            #("exercise|reps|set1", "10"),
            #("exercise|weight|set1", "80"),
            #("exercise|name|set2", "Squats"),
            #("exercise|reps|set2", "10"),
            #("exercise|weight|set2", "80.0"),
            #("exercise|name|set3", "Squats"),
            #("exercise|reps|set3", "8"),
            #("exercise|weight|set3", "80.5"),
          ]
          let expected =
            Ok(GymSession(
              date: today,
              session_name: "Leg Day",
              emoji: "🦵",
              exercises: dict.from_list([
                #("Squats", [
                  SetsExercise(name: "Squats", reps: 10, weight: 80.0),
                  SetsExercise(name: "Squats", reps: 10, weight: 80.0),
                  SetsExercise(name: "Squats", reps: 8, weight: 80.5),
                ]),
              ]),
            ))
          parse_formdata_to_session(
            today,
            FormData(values: form_data, files: []),
          )
          |> assert_gym_session_equal(expected)
        },
      ),
      it("returns a valid session with 'new_exercise' prefixed keys", fn() {
        let form_data = [
          #("session_name", "New Routine"),
          #("session_emoji", "✨"),
          #("new_exercise|name|n1", "Yoga"),
          #("new_exercise|duration|n1", "45"),
          #("new_exercise|name|n2", "Plank"),
          #("new_exercise|duration|n2", "1"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "New Routine",
            emoji: "✨",
            exercises: dict.from_list([
              #("Yoga", [TimedExercise(name: "Yoga", duration: 45)]),
              #("Plank", [TimedExercise(name: "Plank", duration: 1)]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("returns a valid session with no exercises", fn() {
        let form_data = [#("session_name", "Rest Day"), #("session_emoji", "😌")]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Rest Day",
            emoji: "😌",
            exercises: dict.new(),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("large number of exercises and sets (around 20 kvs)", fn() {
        let form_data = [
          #("session_name", "Big Workout Day"),
          #("session_emoji", "🎉"),
          #("exercise|name|sq1", "Squats"),
          #("exercise|reps|sq1", "10"),
          #("exercise|weight|sq1", "90"),
          #("exercise|name|sq2", "Squats"),
          #("exercise|reps|sq2", "10"),
          #("exercise|weight|sq2", "90.5"),
          #("exercise|name|sq3", "Squats"),
          #("exercise|reps|sq3", "8"),
          #("exercise|weight|sq3", "90.5"),
          #("exercise|name|run1", "Running"),
          #("exercise|duration|run1", "20"),
          #("exercise|name|pu1", "Pull-ups"),
          #("exercise|reps|pu1", "8"),
          #("exercise|weight|pu1", "0"),
          #("exercise|name|pu2", "Pull-ups"),
          #("exercise|reps|pu2", "6"),
          #("exercise|weight|pu2", "0"),
          #("new_exercise|name|plank1", "Plank"),
          #("new_exercise|duration|plank1", "2"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Big Workout Day",
            emoji: "🎉",
            exercises: dict.from_list([
              #("Squats", [
                SetsExercise(name: "Squats", reps: 10, weight: 90.0),
                SetsExercise(name: "Squats", reps: 10, weight: 90.5),
                SetsExercise(name: "Squats", reps: 8, weight: 90.5),
              ]),
              #("Running", [TimedExercise(name: "Running", duration: 20)]),
              #("Pull-ups", [
                SetsExercise(name: "Pull-ups", reps: 8, weight: 0.0),
                SetsExercise(name: "Pull-ups", reps: 6, weight: 0.0),
              ]),
              #("Plank", [TimedExercise(name: "Plank", duration: 2)]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
    ]),
    describe("malformed input", [
      it("errors on missing session_name", fn() {
        let form_data = [#("session_emoji", "🚀")]
        let expected = Error("Missing session name or emoji")
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("errors on missing session_emoji", fn() {
        let form_data = [#("session_name", "Incomplete Workout")]
        let expected = Error("Missing session name or emoji")
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("errors on empty form data", fn() {
        let form_data = []
        let expected = Error("Missing session name or emoji")
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops an exercise if name field is missing for an instance", fn() {
        let form_data = [
          #("session_name", "Test Missing Ex Name"),
          #("session_emoji", "🧪"),
          #("exercise|reps|1", "5"),
          #("exercise|weight|1", "60"),
          #("exercise|name|2", "Good Exercise"),
          #("exercise|duration|2", "10"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Test Missing Ex Name",
            emoji: "🧪",
            exercises: dict.from_list([
              #("Good Exercise", [
                TimedExercise(name: "Good Exercise", duration: 10),
              ]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops a timed exercise if duration is missing", fn() {
        let form_data = [
          #("session_name", "Test Missing Duration"),
          #("session_emoji", "⏳"),
          #("exercise|name|1", "Run"),
          #("exercise|name|2", "Walk"),
          #("exercise|duration|2", "15"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Test Missing Duration",
            emoji: "⏳",
            exercises: dict.from_list([
              #("Walk", [TimedExercise(name: "Walk", duration: 15)]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops a sets exercise if reps field is missing", fn() {
        let form_data = [
          #("session_name", "Test Missing Reps"),
          #("session_emoji", "📉"),
          #("exercise|name|s1", "Squats"),
          #("exercise|weight|s1", "50"),
          #("exercise|name|s2", "Lunges"),
          #("exercise|reps|s2", "10"),
          #("exercise|weight|s2", "20"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Test Missing Reps",
            emoji: "📉",
            exercises: dict.from_list([
              #("Lunges", [SetsExercise(name: "Lunges", reps: 10, weight: 20.0)]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops a sets exercise if weight field is missing", fn() {
        let form_data = [
          #("session_name", "Test Missing Weight"),
          #("session_emoji", "⚖️"),
          #("exercise|name|s1", "Deadlifts"),
          #("exercise|reps|s1", "5"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Test Missing Weight",
            emoji: "⚖️",
            exercises: dict.new(),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops an exercise if duration is not a number", fn() {
        let form_data = [
          #("session_name", "Test Invalid Duration"),
          #("session_emoji", "❌"),
          #("exercise|name|1", "Run"),
          #("exercise|duration|1", "abc"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Test Invalid Duration",
            emoji: "❌",
            exercises: dict.new(),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops an exercise if reps is not a number", fn() {
        let form_data = [
          #("session_name", "Test Invalid Reps"),
          #("session_emoji", "❌"),
          #("exercise|name|s1", "Curls"),
          #("exercise|reps|s1", "many"),
          #("exercise|weight|s1", "10"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Test Invalid Reps",
            emoji: "❌",
            exercises: dict.new(),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops an exercise if weight is not a number", fn() {
        let form_data = [
          #("session_name", "Test Invalid Weight"),
          #("session_emoji", "❌"),
          #("exercise|name|s1", "Rows"),
          #("exercise|reps|s1", "12"),
          #("exercise|weight|s1", "heavy"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Test Invalid Weight",
            emoji: "❌",
            exercises: dict.new(),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("drops an exercise if key is malformed (not enough parts)", fn() {
        let form_data = [
          #("session_name", "Malformed Keys"),
          #("session_emoji", "🔧"),
          #("exercise|name", "Bad Key Format"),
          #("exercise|duration", "10"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Malformed Keys",
            emoji: "🔧",
            exercises: dict.new(),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
      it("ignores extraneous form fields", fn() {
        let form_data = [
          #("session_name", "Clean Session"),
          #("session_emoji", "🧹"),
          #("exercise|name|1", "Jump Rope"),
          #("exercise|duration|1", "5"),
          #("csrf_token", "some_random_token"),
          #("another_field", "another_value"),
        ]
        let expected =
          Ok(GymSession(
            date: today,
            session_name: "Clean Session",
            emoji: "🧹",
            exercises: dict.from_list([
              #("Jump Rope", [TimedExercise(name: "Jump Rope", duration: 5)]),
            ]),
          ))
        parse_formdata_to_session(today, FormData(values: form_data, files: []))
        |> assert_gym_session_equal(expected)
      }),
    ]),
  ])
}
