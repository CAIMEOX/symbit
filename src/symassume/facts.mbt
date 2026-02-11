///|
pub struct SymbolFacts {
  is_zero : Tri
  is_nonzero : Tri
  is_integer : Tri
  is_rational : Tri
  is_real : Tri
  is_positive : Tri
  is_nonnegative : Tri
} derive(Eq, Show)

///|
pub type AssumeEnv = Map[String, SymbolFacts]

///|
pub fn unknown_facts() -> SymbolFacts {
  SymbolFacts::{
    is_zero: Tri::Unknown,
    is_nonzero: Tri::Unknown,
    is_integer: Tri::Unknown,
    is_rational: Tri::Unknown,
    is_real: Tri::Unknown,
    is_positive: Tri::Unknown,
    is_nonnegative: Tri::Unknown,
  }
}

///|
pub fn symbol_facts(
  is_zero? : Tri = Tri::Unknown,
  is_nonzero? : Tri = Tri::Unknown,
  is_integer? : Tri = Tri::Unknown,
  is_rational? : Tri = Tri::Unknown,
  is_real? : Tri = Tri::Unknown,
  is_positive? : Tri = Tri::Unknown,
  is_nonnegative? : Tri = Tri::Unknown,
) -> SymbolFacts {
  normalize_facts(SymbolFacts::{
    is_zero,
    is_nonzero,
    is_integer,
    is_rational,
    is_real,
    is_positive,
    is_nonnegative,
  })
}

///|
pub fn empty_env() -> AssumeEnv {
  {}
}

///|
pub fn assume_env(entries : Array[(String, SymbolFacts)]) -> AssumeEnv {
  let env : AssumeEnv = {}
  for entry in entries {
    let (name, facts) = entry
    env[name] = normalize_facts(facts)
  }
  env
}

///|
pub fn env_set(env : AssumeEnv, name : String, facts : SymbolFacts) -> Unit {
  env[name] = normalize_facts(facts)
}

///|
pub fn env_get(env : AssumeEnv, name : String) -> SymbolFacts {
  match env.get(name) {
    Some(facts) => normalize_facts(facts)
    None => unknown_facts()
  }
}

///|
pub fn normalize_facts(facts : SymbolFacts) -> SymbolFacts {
  let mut is_zero = facts.is_zero
  let mut is_nonzero = facts.is_nonzero
  let mut is_integer = facts.is_integer
  let mut is_rational = facts.is_rational
  let mut is_real = facts.is_real
  let mut is_positive = facts.is_positive
  let mut is_nonnegative = facts.is_nonnegative

  for _ in 0..<8 {
    let mut changed = false

    let next_nonzero = if is_zero == Tri::True {
      tri_merge(is_nonzero, Tri::False)
    } else {
      is_nonzero
    }
    if next_nonzero != is_nonzero {
      is_nonzero = next_nonzero
      changed = true
    }

    let next_zero_from_nonzero = if is_nonzero == Tri::True {
      tri_merge(is_zero, Tri::False)
    } else {
      is_zero
    }
    if next_zero_from_nonzero != is_zero {
      is_zero = next_zero_from_nonzero
      changed = true
    }

    let next_nonnegative = if is_zero == Tri::True {
      tri_merge(is_nonnegative, Tri::True)
    } else {
      is_nonnegative
    }
    if next_nonnegative != is_nonnegative {
      is_nonnegative = next_nonnegative
      changed = true
    }

    let next_positive_from_zero = if is_zero == Tri::True {
      tri_merge(is_positive, Tri::False)
    } else {
      is_positive
    }
    if next_positive_from_zero != is_positive {
      is_positive = next_positive_from_zero
      changed = true
    }

    let next_real_from_zero = if is_zero == Tri::True {
      tri_merge(is_real, Tri::True)
    } else {
      is_real
    }
    if next_real_from_zero != is_real {
      is_real = next_real_from_zero
      changed = true
    }

    let next_integer_from_zero = if is_zero == Tri::True {
      tri_merge(is_integer, Tri::True)
    } else {
      is_integer
    }
    if next_integer_from_zero != is_integer {
      is_integer = next_integer_from_zero
      changed = true
    }

    let next_rational_from_integer = if is_integer == Tri::True {
      tri_merge(is_rational, Tri::True)
    } else if is_integer == Tri::False {
      tri_merge(is_rational, Tri::Unknown)
    } else {
      is_rational
    }
    if next_rational_from_integer != is_rational {
      is_rational = next_rational_from_integer
      changed = true
    }

    let next_real_from_rational = if is_rational == Tri::True {
      tri_merge(is_real, Tri::True)
    } else {
      is_real
    }
    if next_real_from_rational != is_real {
      is_real = next_real_from_rational
      changed = true
    }

    let next_rational_from_real = if is_real == Tri::False {
      tri_merge(is_rational, Tri::False)
    } else {
      is_rational
    }
    if next_rational_from_real != is_rational {
      is_rational = next_rational_from_real
      changed = true
    }

    let next_integer_from_rational = if is_rational == Tri::False {
      tri_merge(is_integer, Tri::False)
    } else {
      is_integer
    }
    if next_integer_from_rational != is_integer {
      is_integer = next_integer_from_rational
      changed = true
    }

    let next_nonnegative_from_positive = if is_positive == Tri::True {
      tri_merge(is_nonnegative, Tri::True)
    } else {
      is_nonnegative
    }
    if next_nonnegative_from_positive != is_nonnegative {
      is_nonnegative = next_nonnegative_from_positive
      changed = true
    }

    let next_real_from_nonnegative = if is_nonnegative == Tri::True {
      tri_merge(is_real, Tri::True)
    } else {
      is_real
    }
    if next_real_from_nonnegative != is_real {
      is_real = next_real_from_nonnegative
      changed = true
    }

    let next_nonzero_from_positive = if is_positive == Tri::True {
      tri_merge(is_nonzero, Tri::True)
    } else {
      is_nonzero
    }
    if next_nonzero_from_positive != is_nonzero {
      is_nonzero = next_nonzero_from_positive
      changed = true
    }

    let next_real_from_positive = if is_positive == Tri::True {
      tri_merge(is_real, Tri::True)
    } else {
      is_real
    }
    if next_real_from_positive != is_real {
      is_real = next_real_from_positive
      changed = true
    }

    let next_zero_from_positive = if is_positive == Tri::True {
      tri_merge(is_zero, Tri::False)
    } else {
      is_zero
    }
    if next_zero_from_positive != is_zero {
      is_zero = next_zero_from_positive
      changed = true
    }

    let next_positive_from_nonnegative_nonzero = if is_nonnegative == Tri::True &&
      is_nonzero == Tri::True {
      tri_merge(is_positive, Tri::True)
    } else {
      is_positive
    }
    if next_positive_from_nonnegative_nonzero != is_positive {
      is_positive = next_positive_from_nonnegative_nonzero
      changed = true
    }

    let next_positive_from_nonnegative_zero = if is_nonnegative == Tri::True &&
      is_zero == Tri::False {
      tri_merge(is_positive, Tri::True)
    } else {
      is_positive
    }
    if next_positive_from_nonnegative_zero != is_positive {
      is_positive = next_positive_from_nonnegative_zero
      changed = true
    }

    let next_positive_from_nonnegative_false = if is_nonnegative == Tri::False {
      tri_merge(is_positive, Tri::False)
    } else {
      is_positive
    }
    if next_positive_from_nonnegative_false != is_positive {
      is_positive = next_positive_from_nonnegative_false
      changed = true
    }

    if !changed {
      break
    }
  }

  SymbolFacts::{
    is_zero,
    is_nonzero,
    is_integer,
    is_rational,
    is_real,
    is_positive,
    is_nonnegative,
  }
}
