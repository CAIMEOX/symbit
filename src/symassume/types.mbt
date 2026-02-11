///|
pub(all) enum Tri {
  True
  False
  Unknown
} derive(Eq, Show)

///|
pub fn tri_of_bool(value : Bool) -> Tri {
  if value {
    Tri::True
  } else {
    Tri::False
  }
}

///|
pub fn tri_to_bool_option(value : Tri) -> Bool? {
  match value {
    Tri::True => Some(true)
    Tri::False => Some(false)
    Tri::Unknown => None
  }
}

///|
pub fn tri_not(value : Tri) -> Tri {
  match value {
    Tri::True => Tri::False
    Tri::False => Tri::True
    Tri::Unknown => Tri::Unknown
  }
}

///|
pub fn tri_and(lhs : Tri, rhs : Tri) -> Tri {
  match (lhs, rhs) {
    (Tri::False, _) | (_, Tri::False) => Tri::False
    (Tri::True, Tri::True) => Tri::True
    _ => Tri::Unknown
  }
}

///|
pub fn tri_or(lhs : Tri, rhs : Tri) -> Tri {
  match (lhs, rhs) {
    (Tri::True, _) | (_, Tri::True) => Tri::True
    (Tri::False, Tri::False) => Tri::False
    _ => Tri::Unknown
  }
}

///|
pub fn tri_merge(current : Tri, incoming : Tri) -> Tri {
  match (current, incoming) {
    (Tri::Unknown, value) | (value, Tri::Unknown) => value
    (Tri::True, Tri::True) => Tri::True
    (Tri::False, Tri::False) => Tri::False
    _ => Tri::Unknown
  }
}

///|
pub(all) enum Predicate {
  IsZero
  IsNonzero
  IsInteger
  IsRational
  IsReal
  IsPositive
  IsNonnegative
} derive(Eq, Show)
