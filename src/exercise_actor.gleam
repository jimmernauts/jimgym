import gleam/otp/actor
import gleam/erlang/process.{type Subject}
import gleam/result
import common.{type GymSession}

// The state of our actor is a list of gym sessions
pub type State = List(GymSession)

// Messages that can be sent to the actor
pub type Msg {
  SetInitialSessions(sessions: List(GymSession))
  AddSession(session: GymSession)
  GetSessions(reply_to: process.Subject(List(GymSession)))
}

// Handle incoming messages
fn handle_message(msg: Msg, state: State) -> actor.Next(Msg, State) {
  case msg {
    SetInitialSessions(sessions) -> actor.continue(sessions)
    AddSession(session) -> {
      let new_state = [session, ..state]
      actor.continue(new_state)
    }
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
pub fn set_initial_sessions(
  actor_subject: process.Subject(Msg),
  sessions: List(GymSession),
) -> Nil {
  actor.send(actor_subject, SetInitialSessions(sessions))
}

// Add a new gym session
pub fn add_session(
  actor_subject: process.Subject(Msg),
  session: GymSession,
) -> Nil {
  actor.send(actor_subject, AddSession(session))
}

// Get all gym sessions
pub fn get_sessions(actor_subject: process.Subject(Msg)) -> List(GymSession) {
  process.try_call(actor_subject, fn(reply_channel) { GetSessions(reply_channel) }, 5000)
  |> result.unwrap(or: []) // Return an empty list in case of error or timeout
}
