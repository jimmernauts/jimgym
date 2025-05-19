import common.{type GymSession}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result
import pog
import supabase_client

// The state of our actor is a list of gym sessions and templates
pub type State {
  State(sessions: List(GymSession), templates: List(common.SessionTemplate))
}

// Messages that can be sent to the actor
pub type Msg {
  SetSessions(sessions: List(GymSession))
  GetSessions(reply_to: process.Subject(List(GymSession)))
  SetTemplates(templates: List(common.SessionTemplate))
  GetTemplates(reply_to: process.Subject(List(common.SessionTemplate)))
}

// Handle incoming messages
fn handle_message(msg: Msg, state: State) -> actor.Next(Msg, State) {
  case msg {
    SetSessions(sessions) -> actor.continue(State(sessions, state.templates))
    GetSessions(reply_channel) -> {
      process.send(reply_channel, state.sessions)
      actor.continue(state)
    }
    SetTemplates(templates) -> actor.continue(State(state.sessions, templates))
    GetTemplates(reply_channel) -> {
      process.send(reply_channel, state.templates)
      actor.continue(state)
    }
  }
}

// Start the actor and return its subject (address)
pub fn start() -> process.Subject(Msg) {
  // actor.start takes initial_state and the loop function.
  // It returns Result(Subject(Msg), StartError).
  // We use `let assert Ok(...)` to panic if the actor fails to start.
  let assert Ok(actor_subject) = actor.start(State([], []), handle_message)
  actor_subject
}

// --- Client functions to interact with the actor ---

// Set the initial list of gym sessions (e.g., loaded from a database)
pub fn set_sessions(
  sessions: List(GymSession),
  actor_subject: process.Subject(Msg),
) -> Nil {
  actor.send(actor_subject, SetSessions(sessions))
}

// Get all gym sessions
pub fn get_sessions(actor_subject: process.Subject(Msg)) -> List(GymSession) {
  process.try_call(
    actor_subject,
    fn(reply_channel) { GetSessions(reply_channel) },
    5000,
  )
  |> result.unwrap(or: [])
  // Return an empty list in case of error or timeout
}

pub fn refresh_sessions(
  actor_subject: process.Subject(Msg),
  db: pog.Connection,
) -> Nil {
  supabase_client.get_all_sessions(db)
  |> result.unwrap([])
  |> set_sessions(actor_subject)
}

pub fn set_templates(
  templates: List(common.SessionTemplate),
  actor_subject: process.Subject(Msg),
) -> Nil {
  actor.send(actor_subject, SetTemplates(templates))
}

pub fn get_templates(
  actor_subject: process.Subject(Msg),
) -> List(common.SessionTemplate) {
  process.try_call(
    actor_subject,
    fn(reply_channel) { GetTemplates(reply_channel) },
    5000,
  )
  |> result.unwrap(or: [])
}
