///|
/// Finite state machine utilities for rewriting systems.

///|
pub enum StateType {
  Start
  Accept
  Dead
} derive(Eq)

///|
pub enum StateName {
  Start
  Word(FreeGroupElement)
} derive(Eq)

///|
pub impl Hash for StateName with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for StateName with hash_combine(self, hasher : Hasher) -> Unit {
  match self {
    StateName::Start => hasher.combine_int(0)
    StateName::Word(w) => {
      hasher.combine_int(1)
      w.hash_combine(hasher)
    }
  }
}

///|
pub struct State {
  name : StateName
  transitions : Map[FreeGroupElement, StateName]
  mut state_type : StateType
  mut rh_rule : FreeGroupElement?
}

///|
pub struct StateMachine {
  name : String
  automaton_alphabet : Array[FreeGroupElement]
  states : Array[State]
  state_index : Map[StateName, Int]
}

///|
pub fn StateMachine::new(name : String, alphabet : Array[FreeGroupElement]) -> StateMachine {
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
pub fn StateMachine::has_state(self : StateMachine, name : StateName) -> Bool {
  self.state_index.contains(name)
}

///|
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
  let state : State = {
    name,
    transitions: {},
    state_type,
    rh_rule,
  }
  self.states.push(state)
  self.state_index[name] = idx
}

///|
pub fn StateMachine::get_state(self : StateMachine, name : StateName) -> State? {
  match self.state_index.get(name) {
    Some(idx) => Some(self.states[idx])
    None => None
  }
}

///|
pub fn StateMachine::update_state(self : StateMachine, state : State) -> Unit {
  match self.state_index.get(state.name) {
    Some(idx) => self.states[idx] = state
    None => ()
  }
}

///|
pub fn StateMachine::state_names(self : StateMachine) -> Array[StateName] {
  let out : Array[StateName] = Array::new()
  for st in self.states {
    out.push(st.name)
  }
  out
}

///|
pub fn StateMachine::set_state_type(self : StateMachine, name : StateName, state_type : StateType) -> Unit {
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
