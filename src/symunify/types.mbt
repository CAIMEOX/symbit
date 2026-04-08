///|
pub struct VariableKey[T] {
  arg : T
} derive(Eq, Hash)

///|
pub struct CondVariableKey[T] {
  arg : T
  id : Int
} derive(Eq, Hash)

///|
pub(all) enum MatchVar[T] {
  Variable(VariableKey[T])
  CondVariable(CondVariableKey[T])
} derive(Eq, Hash)

///|
pub(all) enum UnifyTerm[T, Op] {
  Atom(T)
  Compound(Op, Array[UnifyTerm[T, Op]])
  Sequence(Array[UnifyTerm[T, Op]])
  Variable(VariableKey[T])
  CondVariable(CondVariableKey[T], (UnifyTerm[T, Op]) -> Bool)
}

///|
pub type Substitution[T, Op] = Map[MatchVar[T], UnifyTerm[T, Op]]

///|
let cond_variable_id_ref : Ref[Int] = { val: 0 }

///|
fn next_cond_variable_id() -> Int {
  let next_id = cond_variable_id_ref.val
  cond_variable_id_ref.val = next_id + 1
  next_id
}

///|
pub fn[T] variable(arg : T) -> VariableKey[T] {
  { arg, }
}

///|
pub fn[T] cond_variable(arg : T) -> CondVariableKey[T] {
  { arg, id: next_cond_variable_id() }
}

///|
pub fn[T] VariableKey::arg(self : VariableKey[T]) -> T {
  self.arg
}

///|
pub fn[T] CondVariableKey::arg(self : CondVariableKey[T]) -> T {
  self.arg
}

///|
pub fn[T, Op] atom(value : T) -> UnifyTerm[T, Op] {
  UnifyTerm::Atom(value)
}

///|
pub fn[T, Op] compound(
  op : Op,
  args : Array[UnifyTerm[T, Op]],
) -> UnifyTerm[T, Op] {
  UnifyTerm::Compound(op, args.map(arg => arg))
}

///|
pub fn[T, Op] sequence(items : Array[UnifyTerm[T, Op]]) -> UnifyTerm[T, Op] {
  UnifyTerm::Sequence(items.map(item => item))
}

///|
pub fn[T, Op] variable_term(key : VariableKey[T]) -> UnifyTerm[T, Op] {
  UnifyTerm::Variable(key)
}

///|
pub fn[T, Op] cond_variable_term(
  key : CondVariableKey[T],
  valid : (UnifyTerm[T, Op]) -> Bool,
) -> UnifyTerm[T, Op] {
  UnifyTerm::CondVariable(key, valid)
}

///|
pub fn[T] match_var_arg(key : MatchVar[T]) -> T {
  match key {
    MatchVar::Variable(key0) => key0.arg()
    MatchVar::CondVariable(key0) => key0.arg()
  }
}

///|
fn[T, Op] term_match_var(term : UnifyTerm[T, Op]) -> MatchVar[T]? {
  match term {
    UnifyTerm::Variable(key) => Some(MatchVar::Variable(key))
    UnifyTerm::CondVariable(key, _) => Some(MatchVar::CondVariable(key))
    _ => None
  }
}

///|
fn[T, Op] term_cond_validator(
  term : UnifyTerm[T, Op],
) -> ((UnifyTerm[T, Op]) -> Bool)? {
  match term {
    UnifyTerm::CondVariable(_, valid) => Some(valid)
    _ => None
  }
}

///|
fn[T, Op] sequence_items(term : UnifyTerm[T, Op]) -> Array[UnifyTerm[T, Op]]? {
  match term {
    UnifyTerm::Sequence(items) => Some(items)
    _ => None
  }
}

///|
fn[T, Op] compound_parts(
  term : UnifyTerm[T, Op],
) -> (Op, Array[UnifyTerm[T, Op]])? {
  match term {
    UnifyTerm::Compound(op, args) => Some((op, args))
    _ => None
  }
}

///|
fn[T : Eq, Op : Eq] term_equal(
  lhs : UnifyTerm[T, Op],
  rhs : UnifyTerm[T, Op],
) -> Bool {
  match (lhs, rhs) {
    (UnifyTerm::Atom(a), UnifyTerm::Atom(b)) => a == b
    (UnifyTerm::Variable(a), UnifyTerm::Variable(b)) => a == b
    (UnifyTerm::CondVariable(a, _), UnifyTerm::CondVariable(b, _)) => a == b
    (UnifyTerm::Sequence(xs), UnifyTerm::Sequence(ys)) => terms_equal(xs, ys)
    (UnifyTerm::Compound(op_a, args_a), UnifyTerm::Compound(op_b, args_b)) =>
      op_a == op_b && terms_equal(args_a, args_b)
    _ => false
  }
}

///|
fn[T : Eq, Op : Eq] terms_equal(
  lhs : Array[UnifyTerm[T, Op]],
  rhs : Array[UnifyTerm[T, Op]],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if !term_equal(lhs[i], rhs[i]) {
      return false
    }
  }
  true
}

///|
fn[T : Eq + Hash, Op] substitution_assoc(
  subst : Substitution[T, Op],
  key : MatchVar[T],
  value : UnifyTerm[T, Op],
) -> Substitution[T, Op] {
  let out = subst.copy()
  out[key] = value
  out
}

///|
pub fn[T, Op] substitution_pairs(
  subst : Substitution[T, Op],
) -> Array[(MatchVar[T], UnifyTerm[T, Op])] {
  let out : Array[(MatchVar[T], UnifyTerm[T, Op])] = []
  for key, value in subst {
    out.push((key, value))
  }
  out
}
