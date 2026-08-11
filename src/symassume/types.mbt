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
pub impl Show for Tri with fn to_string(self) {
  match self {
    True => "True"
    False => "False"
    Unknown => "Unknown"
  }
}

///|
pub impl Show for Tri with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
/// Convert a concrete boolean into a three-valued result.
pub fn tri_of_bool(value : Bool) -> Tri {
  if value {
    True
  } else {
    False
  }
}

///|
/// Convert a three-valued result back to `Bool?`.
///
/// `True` and `False` become `Some`, while `Unknown` becomes `None`.
pub fn tri_to_bool_option(value : Tri) -> Bool? {
  match value {
    True => Some(true)
    False => Some(false)
    Unknown => None
  }
}

///|
/// Negate a three-valued result.
pub fn tri_not(value : Tri) -> Tri {
  match value {
    True => False
    False => True
    Unknown => Unknown
  }
}

///|
/// Combine two three-valued results with logical conjunction.
pub fn tri_and(lhs : Tri, rhs : Tri) -> Tri {
  match (lhs, rhs) {
    (False, _) | (_, False) => False
    (True, True) => True
    _ => Unknown
  }
}

///|
/// Combine two three-valued results with logical disjunction.
pub fn tri_or(lhs : Tri, rhs : Tri) -> Tri {
  match (lhs, rhs) {
    (True, _) | (_, True) => True
    (False, False) => False
    _ => Unknown
  }
}

///|
/// Merge two pieces of knowledge about the same fact.
///
/// `Unknown` yields to a concrete answer. Conflicting concrete answers collapse
/// back to `Unknown` so callers can detect inconsistency separately.
pub fn tri_merge(current : Tri, incoming : Tri) -> Tri {
  match (current, incoming) {
    (Unknown, value) | (value, Unknown) => value
    (True, True) => True
    (False, False) => False
    _ => Unknown
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
