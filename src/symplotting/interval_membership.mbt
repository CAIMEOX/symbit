///|
priv struct IntervalMembership {
  truth : Bool?
  validity : Bool?
}

///|
fn interval_membership(truth : Bool?, validity : Bool?) -> IntervalMembership {
  IntervalMembership::{ truth, validity }
}

///|
fn plot_fuzzy_and(values : Array[Bool?]) -> Bool? {
  let mut saw_none = false
  for value in values {
    match value {
      Some(false) => return Some(false)
      Some(true) => ()
      None => saw_none = true
    }
  }
  if saw_none {
    None
  } else {
    Some(true)
  }
}

///|
fn plot_fuzzy_or(values : Array[Bool?]) -> Bool? {
  let mut saw_none = false
  for value in values {
    match value {
      Some(true) => return Some(true)
      Some(false) => ()
      None => saw_none = true
    }
  }
  if saw_none {
    None
  } else {
    Some(false)
  }
}

///|
fn plot_fuzzy_not(value : Bool?) -> Bool? {
  match value {
    Some(v) => Some(!v)
    None => None
  }
}

///|
fn plot_fuzzy_xor(values : Array[Bool?]) -> Bool? {
  let mut parity = false
  for value in values {
    match value {
      Some(v) => parity = parity != v
      None => return None
    }
  }
  Some(parity)
}

///|
fn interval_membership_and(
  lhs : IntervalMembership,
  rhs : IntervalMembership,
) -> IntervalMembership {
  interval_membership(
    plot_fuzzy_and([lhs.truth, rhs.truth]),
    plot_fuzzy_and([lhs.validity, rhs.validity]),
  )
}

///|
fn interval_membership_or(
  lhs : IntervalMembership,
  rhs : IntervalMembership,
) -> IntervalMembership {
  interval_membership(
    plot_fuzzy_or([lhs.truth, rhs.truth]),
    plot_fuzzy_or([lhs.validity, rhs.validity]),
  )
}

///|
fn interval_membership_not(value : IntervalMembership) -> IntervalMembership {
  interval_membership(plot_fuzzy_not(value.truth), value.validity)
}

///|
fn interval_membership_xor(
  lhs : IntervalMembership,
  rhs : IntervalMembership,
) -> IntervalMembership {
  interval_membership(
    plot_fuzzy_xor([lhs.truth, rhs.truth]),
    plot_fuzzy_and([lhs.validity, rhs.validity]),
  )
}
