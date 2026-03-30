///|
pub type FuzzyBool = Bool?

///|
pub fn torf(args : Array[FuzzyBool]) -> FuzzyBool {
  let mut saw_true = false
  let mut saw_false = false
  for arg in args {
    match arg {
      Some(true) => {
        if saw_false {
          return None
        }
        saw_true = true
      }
      Some(false) => {
        if saw_true {
          return None
        }
        saw_false = true
      }
      None => return None
    }
  }
  Some(saw_true)
}

///|
pub fn fuzzy_group(
  args : Array[FuzzyBool],
  quick_exit? : Bool = false,
) -> FuzzyBool {
  let mut saw_other = false
  for arg in args {
    match arg {
      Some(true) => ()
      None => return None
      Some(false) => {
        if quick_exit && saw_other {
          return None
        }
        saw_other = true
      }
    }
  }
  Some(!saw_other)
}

///|
pub fn fuzzy_bool(value : Bool?) -> FuzzyBool {
  value
}

///|
pub fn fuzzy_and(args : Array[FuzzyBool]) -> FuzzyBool {
  let mut out : FuzzyBool = Some(true)
  for arg in args {
    let current = fuzzy_bool(arg)
    match current {
      Some(false) => return Some(false)
      _ => if out == Some(true) { out = current }
    }
  }
  out
}

///|
pub fn fuzzy_not(value : FuzzyBool) -> FuzzyBool {
  match value {
    Some(v) => Some(!v)
    None => None
  }
}

///|
pub fn fuzzy_or(args : Array[FuzzyBool]) -> FuzzyBool {
  let mut out : FuzzyBool = Some(false)
  for arg in args {
    let current = fuzzy_bool(arg)
    match current {
      Some(true) => return Some(true)
      _ => if out == Some(false) { out = current }
    }
  }
  out
}

///|
pub fn fuzzy_xor(args : Array[FuzzyBool]) -> FuzzyBool {
  let mut count = 0
  for arg in args {
    match fuzzy_bool(arg) {
      Some(true) => count += 1
      Some(false) => ()
      None => return None
    }
  }
  Some(count % 2 == 1)
}

///|
pub fn fuzzy_nand(args : Array[FuzzyBool]) -> FuzzyBool {
  fuzzy_not(fuzzy_and(args))
}
