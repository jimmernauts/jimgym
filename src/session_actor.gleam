import common.{type GymSession}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result
import pog
import supabase_client

// The state of our actor is a list of gym sessions
pub type State =
  List(GymSession)

// Messages that can be sent to the actor
pub type Msg {
  SetSessions(sessions: List(GymSession))
  GetSessions(reply_to: process.Subject(List(GymSession)))
}

// Handle incoming messages
fn handle_message(msg: Msg, state: State) -> actor.Next(Msg, State) {
  case msg {
    SetSessions(sessions) -> actor.continue(sessions)
    GetSessions(reply_channel) -> {
      process.send(reply_channel, state)
      actor.continue(state)
    }
  }
}

// Start the actor and return its subject (address)
pub fn start() -> process.Subject(Msg) {
  // actor.start takes initial_state and the loop function.
  // It returns Result(Subject(Msg), StartError).
  // We use `let assert Ok(...)` to panic if the actor fails to start.
  let assert Ok(actor_subject) = actor.start([], handle_message)
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
