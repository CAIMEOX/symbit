///|
/// Three-valued truth result used by the assumptions engine.
///
/// `Unknown` means the current rules cannot prove either truth or falsity from
/// the available information.
pub(all) enum Tri {
  True
  False
  Unknown
} derive(Eq, Debug)

///|
/// Convert a concrete boolean into a three-valued result.
pub fn tri_of_bool(value : Bool) -> Tri {
  if value {
    Tri::True
  } else {
    Tri::False
  }
}

///|
/// Convert a three-valued result back to `Bool?`.
///
/// `True` and `False` become `Some`, while `Unknown` becomes `None`.
pub fn tri_to_bool_option(value : Tri) -> Bool? {
  match value {
    Tri::True => Some(true)
    Tri::False => Some(false)
    Tri::Unknown => None
  }
}

///|
/// Negate a three-valued result.
pub fn tri_not(value : Tri) -> Tri {
  match value {
    Tri::True => Tri::False
    Tri::False => Tri::True
    Tri::Unknown => Tri::Unknown
  }
}

///|
/// Combine two three-valued results with logical conjunction.
pub fn tri_and(lhs : Tri, rhs : Tri) -> Tri {
  match (lhs, rhs) {
    (Tri::False, _) | (_, Tri::False) => Tri::False
    (Tri::True, Tri::True) => Tri::True
    _ => Tri::Unknown
  }
}

///|
/// Combine two three-valued results with logical disjunction.
pub fn tri_or(lhs : Tri, rhs : Tri) -> Tri {
  match (lhs, rhs) {
    (Tri::True, _) | (_, Tri::True) => Tri::True
    (Tri::False, Tri::False) => Tri::False
    _ => Tri::Unknown
  }
}

///|
/// Merge two pieces of knowledge about the same fact.
///
/// `Unknown` yields to a concrete answer. Conflicting concrete answers collapse
/// back to `Unknown` so callers can detect inconsistency separately.
pub fn tri_merge(current : Tri, incoming : Tri) -> Tri {
  match (current, incoming) {
    (Tri::Unknown, value) | (value, Tri::Unknown) => value
    (Tri::True, Tri::True) => Tri::True
    (Tri::False, Tri::False) => Tri::False
    _ => Tri::Unknown
  }
}

///|
/// Supported primitive predicates for direct expression tests.
///
/// These are the small built-in facts that [`ask_predicate`](#ask_predicate)
/// can evaluate without going through the full symbolic query language.
pub(all) enum Predicate {
  IsZero
  IsNonzero
  IsInteger
  IsRational
  IsReal
  IsPositive
  IsNonnegative
} derive(Eq, Debug)
