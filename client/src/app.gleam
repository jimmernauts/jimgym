import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri.{type Uri, Uri}
import lustre
import lustre/attribute.{class, placeholder, type_, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h2, h3, input, label, li, p, span, text, ul,
}
import lustre/event.{on_click, on_input, on_submit}
import modem
import rada/date

pub type Msg {
  StartNewSession(Option(SessionTemplate))
  UpdateSession(GymSession)
  EndActiveSession
  UpdateSessionTemplates(List(SessionTemplate))
  OnRouteChange(Route)
}

pub type Route {
  Home
}

pub type Exercise {
  Exercise(name: String, sets: Int, reps: Int, weight: Int)
}

pub type SessionTemplate {
  SessionTemplate(name: String, exercises: List(Exercise))
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
    session_templates: List(SessionTemplate),
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(
      current_route: Home,
      current_session: None,
      past_sessions: [],
      session_templates: [],
    ),
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
    UpdateSession(new_session) -> {
      #(Model(..model, current_session: Some(new_session)), effect.none())
    }
    EndActiveSession -> {
      #(
        Model(..model, current_session: None, past_sessions: {
          case model.current_session {
            None -> model.past_sessions
            Some(session) -> list.append(model.past_sessions, [session])
          }
        }),
        effect.none(),
      )
    }
    StartNewSession(template) -> {
      #(
        Model(
          ..model,
          current_session: Some(case template {
            Some(SessionTemplate(_name, exercises)) -> {
              GymSession(date.today() |> date.to_rata_die, exercises)
            }
            None -> GymSession(date.today() |> date.to_rata_die, [])
          }),
        ),
        effect.none(),
      )
    }
    UpdateSessionTemplates(templates) -> {
      #(Model(..model, session_templates: templates), effect.none())
    }
    OnRouteChange(route) -> {
      #(Model(..model, current_route: route), effect.none())
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let page = case model.current_route {
    Home -> view_home(model)
  }
  html.main(
    [
      class(
        "grid ml-2 mr-2 gap-2
    2xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_90%_[main-end]_3fr_[full-end]_1fr_[end]]
    xl:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
    lg:grid-cols-[[start]_1fr_[full-start]_3fr_[main-start]_95%_[main-end]_3fr_[full-end]_1fr_[end]]
    md:grid-cols-[[start_full-start]_1fr_[main-start]_95%_[main-end]_1fr_[full-end_end]]
    grid-cols-[[start_full-start_main-start]_100%_[main-end_full-end_end]]
    grid-rows-[[content]_95%_[footer]_1fr]
    font-rounded-sans",
      ),
    ],
    [page],
  )
}

fn view_home(model: Model) -> Element(Msg) {
  html.section([class("grid col-[main-start_/_main-end] grid-cols-6")], [
    html.h1([class("text-7xl font-bold col-span-6")], [text("💪🤸‍♂️🏋️")]),
    html.h2([class("text-4xl font-bold col-span-6")], [text("JimGym")]),
  ])
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}
