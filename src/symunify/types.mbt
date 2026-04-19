///|
/// Generic term and substitution types for unification.
///
/// Current Limits:
/// - The core term language is intentionally small: atoms, compounds,
///   sequences, and match variables.
/// - Conditional variables validate candidate terms but do not explain rejected
///   matches.

///|
/// Key identifying an unconstrained match variable.
///
/// - Does: Stores the payload used to identify one unification variable.
/// - Input: A payload value of type `T`.
/// - Returns: A `VariableKey[T]`.
/// - Limits: Equality and hashing follow the payload type.
pub struct VariableKey[T] {
  arg : T
} derive(Eq, Hash)

///|
/// Key identifying a match variable with an attached validation rule.
///
/// The internal `id` keeps two conditional variables with the same printable
/// payload distinct.
///
/// - Does: Stores a payload and unique identity for a conditional variable.
/// - Input: A payload value of type `T`.
/// - Returns: A `CondVariableKey[T]`.
/// - Limits: The unique identity is process-local.
pub struct CondVariableKey[T] {
  arg : T
  id : Int
} derive(Eq, Hash)

///|
/// Variable kinds that may appear in a unification substitution.
///
/// - Does: Tags a substitution key as unconstrained or conditional.
/// - Input: A variable key or conditional variable key.
/// - Returns: A `MatchVar[T]` key.
/// - Limits: Does not store the conditional predicate itself.
pub(all) enum MatchVar[T] {
  Variable(VariableKey[T])
  CondVariable(CondVariableKey[T])
} derive(Eq, Hash)

///|
/// Term language used by the generic unification engine.
///
/// `Atom` stores indivisible values, `Compound` stores an operator plus child
/// terms, `Sequence` stores a positional collection, and the variable cases mark
/// holes that may be substituted during matching.
///
/// - Does: Represents a value in the generic unification term language.
/// - Input: Atoms, operator applications, sequences, or variable keys.
/// - Returns: A `UnifyTerm[T, Op]`.
/// - Limits: Semantic meaning of atoms and operators is supplied by callers.
pub(all) enum UnifyTerm[T, Op] {
  Atom(T)
  Compound(Op, Array[UnifyTerm[T, Op]])
  Sequence(Array[UnifyTerm[T, Op]])
  Variable(VariableKey[T])
  CondVariable(CondVariableKey[T], (UnifyTerm[T, Op]) -> Bool)
}

///|
/// Mapping from match variables to the terms they were bound to.
///
/// - Does: Aliases the substitution map used by the unifier.
/// - Input: `MatchVar` keys and `UnifyTerm` values.
/// - Returns: A map from variables to matched terms.
/// - Limits: The map itself does not enforce occurs checks.
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
/// Build an unconstrained variable key.
///
/// - Does: Wraps a payload as a plain variable key.
/// - Input: One payload value.
/// - Returns: A `VariableKey[T]`.
/// - Limits: Does not create a term until passed to `variable_term`.
pub fn[T] variable(arg : T) -> VariableKey[T] {
  { arg, }
}

///|
/// Build a fresh conditional variable key.
///
/// - Does: Wraps a payload with a fresh conditional-variable identity.
/// - Input: One payload value.
/// - Returns: A `CondVariableKey[T]`.
/// - Limits: The validation predicate is attached later by
///   `cond_variable_term`.
pub fn[T] cond_variable(arg : T) -> CondVariableKey[T] {
  { arg, id: next_cond_variable_id() }
}

///|
/// Recover the payload stored inside a variable key.
///
/// - Does: Extracts the payload from a `VariableKey`.
/// - Input: One variable key.
/// - Returns: The stored payload.
/// - Limits: Does not expose any additional identity.
pub fn[T] VariableKey::arg(self : VariableKey[T]) -> T {
  self.arg
}

///|
/// Recover the payload stored inside a conditional variable key.
///
/// - Does: Extracts the payload from a `CondVariableKey`.
/// - Input: One conditional variable key.
/// - Returns: The stored payload.
/// - Limits: Does not expose the internal unique id.
pub fn[T] CondVariableKey::arg(self : CondVariableKey[T]) -> T {
  self.arg
}

///|
/// Wrap a plain value as an atomic unification term.
///
/// - Does: Builds an atom term.
/// - Input: One payload value.
/// - Returns: `UnifyTerm::Atom(value)`.
/// - Limits: The atom is matched by caller-provided equality.
pub fn[T, Op] atom(value : T) -> UnifyTerm[T, Op] {
  UnifyTerm::Atom(value)
}

///|
/// Build a compound unification term.
///
/// - Does: Builds an operator application term.
/// - Input: An operator value and argument terms.
/// - Returns: `UnifyTerm::Compound(op, args)`.
/// - Limits: Associativity and commutativity are not encoded in the term itself.
pub fn[T, Op] compound(
  op : Op,
  args : Array[UnifyTerm[T, Op]],
) -> UnifyTerm[T, Op] {
  UnifyTerm::Compound(op, args.map(arg => arg))
}

///|
/// Build a sequence term.
///
/// - Does: Builds a positional sequence term.
/// - Input: An array of terms.
/// - Returns: `UnifyTerm::Sequence(items)`.
/// - Limits: Sequence semantics are positional and not associative.
pub fn[T, Op] sequence(items : Array[UnifyTerm[T, Op]]) -> UnifyTerm[T, Op] {
  UnifyTerm::Sequence(items.map(item => item))
}

///|
/// Wrap a variable key as a variable term.
///
/// - Does: Builds a plain variable term.
/// - Input: One `VariableKey`.
/// - Returns: `UnifyTerm::Variable(key)`.
/// - Limits: The term accepts any candidate that passes the occurs check.
pub fn[T, Op] variable_term(key : VariableKey[T]) -> UnifyTerm[T, Op] {
  UnifyTerm::Variable(key)
}

///|
/// Wrap a conditional variable key as a guarded variable term.
///
/// `valid` is called before binding the variable to a candidate term.
///
/// - Does: Builds a variable term guarded by a predicate.
/// - Input: A conditional variable key and candidate validator.
/// - Returns: `UnifyTerm::CondVariable(key, valid)`.
/// - Limits: Rejected matches are silently omitted.
pub fn[T, Op] cond_variable_term(
  key : CondVariableKey[T],
  valid : (UnifyTerm[T, Op]) -> Bool,
) -> UnifyTerm[T, Op] {
  UnifyTerm::CondVariable(key, valid)
}

///|
/// Recover the payload stored inside any match-variable variant.
///
/// - Does: Extracts the payload from a substitution key.
/// - Input: One `MatchVar`.
/// - Returns: The payload stored in the underlying key.
/// - Limits: Conditional-variable identity is not returned.
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
/// Convert a substitution map into a plain array of pairs.
///
/// This is convenient when callers want a stable iterable snapshot instead of
/// traversing the map directly.
///
/// - Does: Converts a substitution map to an array of key/value pairs.
/// - Input: One substitution map.
/// - Returns: An array of `(MatchVar, UnifyTerm)` pairs.
/// - Limits: Pair order follows map iteration order and is not sorted.
pub fn[T, Op] substitution_pairs(
  subst : Substitution[T, Op],
) -> Array[(MatchVar[T], UnifyTerm[T, Op])] {
  let out : Array[(MatchVar[T], UnifyTerm[T, Op])] = []
  for key, value in subst {
    out.push((key, value))
  }
  out
}
