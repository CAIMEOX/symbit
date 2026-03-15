///|
/// Finite-state automata used to accelerate word reduction.

///|
/// Role of a state in the reduction automaton.
pub enum StateType {
  Start
  Accept
  Dead
} derive(Eq)

///|
/// Identifier of an automaton state.
pub enum StateName {
  Start
  Word(FreeGroupElement)
} derive(Eq, Hash)

///|
/// One state of the rewriting-system automaton.
pub struct State {
  name : StateName
  transitions : Map[FreeGroupElement, StateName]
  mut state_type : StateType
  mut rh_rule : FreeGroupElement?
}

///|
/// Mutable automaton storing states and labelled transitions.
pub struct StateMachine {
  name : String
  automaton_alphabet : Array[FreeGroupElement]
  states : Array[State]
  state_index : Map[StateName, Int]
}

///|
/// Construct an empty state machine.
pub fn StateMachine::new(
  name : String,
  alphabet : Array[FreeGroupElement],
) -> StateMachine {
  let machine : StateMachine = {
    name,
    automaton_alphabet: alphabet,
    states: Array::new(),
    state_index: {},
  }
  machine.add_state(StateName::Start, StateType::Start)
  machine
}

///|
/// Return whether a state with the given name exists.
pub fn StateMachine::has_state(self : StateMachine, name : StateName) -> Bool {
  self.state_index.contains(name)
}

///|
/// Add a new state to the automaton.
pub fn StateMachine::add_state(
  self : StateMachine,
  name : StateName,
  state_type : StateType,
  rh_rule? : FreeGroupElement,
) -> Unit {
  if self.state_index.contains(name) {
    return
  }
  let idx = self.states.length()
  let state : State = { name, transitions: {}, state_type, rh_rule }
  self.states.push(state)
  self.state_index[name] = idx
}

///|
/// Look up a state by name.
pub fn StateMachine::get_state(self : StateMachine, name : StateName) -> State? {
  match self.state_index.get(name) {
    Some(idx) => Some(self.states[idx])
    None => None
  }
}

///|
/// Replace the stored data for an existing state.
pub fn StateMachine::update_state(self : StateMachine, state : State) -> Unit {
  match self.state_index.get(state.name) {
    Some(idx) => self.states[idx] = state
    None => ()
  }
}

///|
/// Return the list of state names currently stored.
pub fn StateMachine::state_names(self : StateMachine) -> Array[StateName] {
  let out : Array[StateName] = Array::new()
  for st in self.states {
    out.push(st.name)
  }
  out
}

///|
/// Change the state type of an existing state.
pub fn StateMachine::set_state_type(
  self : StateMachine,
  name : StateName,
  state_type : StateType,
) -> Unit {
  match self.state_index.get(name) {
    Some(idx) => {
      let st = self.states[idx]
      st.state_type = state_type
      self.states[idx] = st
    }
    None => ()
  }
}

///|
/// Attach the rewrite rule associated with a dead state.
pub fn StateMachine::set_dead_rule(
  self : StateMachine,
  name : StateName,
  rule : FreeGroupElement,
) -> Unit {
  match self.state_index.get(name) {
    Some(idx) => {
      let st = self.states[idx]
      st.state_type = StateType::Dead
      st.rh_rule = Some(rule)
      self.states[idx] = st
    }
    None => ()
  }
}

///|
/// Add or replace a labelled transition.
pub fn StateMachine::add_transition(
  self : StateMachine,
  from_name : StateName,
  letter : FreeGroupElement,
  to_name : StateName,
) -> Unit {
  match self.state_index.get(from_name) {
    Some(idx) => {
      let st = self.states[idx]
      st.transitions[letter] = to_name
      self.states[idx] = st
    }
    None => ()
  }
}

///|
/// Follow one labelled transition from a given state.
pub fn StateMachine::transition(
  self : StateMachine,
  from_name : StateName,
  letter : FreeGroupElement,
) -> StateName? {
  match self.state_index.get(from_name) {
    Some(idx) => {
      let st = self.states[idx]
      st.transitions.get(letter)
    }
    None => None
  }
}
