import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri.{type Uri, Uri}
import lustre
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, text}
import lustre/event.{on_click}
import modem
import rada/date

pub type Msg {
  AddExercise(Exercise)
  RemoveExercise(Exercise)
  StartNewSession
  OnRouteChange(Route)
}

pub type Route {
  Home
}

pub type Exercise {
  Exercise(name: String, sets: Int, reps: Int, weight: Float)
}

pub type GymSession {
  GymSession(
    date: Int,
    // Rata die
    exercises: List(Exercise),
  )
}

pub type Model {
  Model(
    current_route: Route,
    current_session: Option(GymSession),
    past_sessions: List(GymSession),
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(current_route: Home, current_session: None, past_sessions: []),
    modem.init(on_route_change),
  )
}

fn on_route_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    _ -> OnRouteChange(Home)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    AddExercise(exercise) -> {
      #(
        case model.current_session {
          None -> model
          Some(session) -> {
            let updated_session =
              GymSession(..session, exercises: [exercise, ..session.exercises])
            Model(..model, current_session: Some(updated_session))
          }
        },
        effect.none(),
      )
    }

    RemoveExercise(exercise) -> {
      #(
        case model.current_session {
          None -> model
          Some(session) -> {
            let updated_exercises =
              session.exercises
              |> list.filter(fn(e) { e != exercise })
            Model(
              ..model,
              current_session: Some(
                GymSession(..session, exercises: updated_exercises),
              ),
            )
          }
        },
        effect.none(),
      )
    }

    StartNewSession -> {
      let new_session =
        GymSession(date: date.today() |> date.to_rata_die, exercises: [])
      #(
        case model.current_session {
          None ->
            Model(
              ..model,
              current_session: Some(new_session),
              past_sessions: model.past_sessions,
            )
          Some(current) ->
            Model(..model, current_session: Some(new_session), past_sessions: [
              current,
              ..model.past_sessions
            ])
        },
        effect.none(),
      )
    }
    OnRouteChange(route) -> {
      #(Model(..model, current_route: route), effect.none())
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  div([class("app")], [
    // TODO: Add exercise form
    // TODO: Current session view
    // TODO: Past sessions view
    button([on_click(StartNewSession)], [text("Start New Session")]),
  ])
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}
