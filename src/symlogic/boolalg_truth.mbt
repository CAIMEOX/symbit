///|
/// Truth tables and integer/term helpers for boolalg.

///|
pub(all) enum TruthTableRow {
  WithInput(Array[Int], Bool)
  Value(Bool)
} derive(Show, Eq)

///|
fn env_from_bits(
  names : Array[String],
  bits : Array[Int],
) -> Map[String, Bool] {
  let env : Map[String, Bool] = Map::new()
  for i in 0..<names.length() {
    env[names[i]] = bits[i] == 1
  }
  env
}

///|
pub fn truth_table(
  expr : BoolExpr,
  variables : Array[BoolExpr],
  input? : Bool = true,
) -> Array[TruthTableRow] {
  let names = symbol_names_from_exprs(variables)
  let bits_list = all_bit_vectors(names.length())
  let out : Array[TruthTableRow] = Array::new()
  for bits in bits_list {
    let env = env_from_bits(names, bits)
    let value = bool_eval(expr, env)
    if input {
      out.push(TruthTableRow::WithInput(bits, value))
    } else {
      out.push(TruthTableRow::Value(value))
    }
  }
  out
}

///|
fn true_terms(expr : BoolExpr, variables : Array[BoolExpr]) -> Array[Array[Int]] {
  let names = symbol_names_from_exprs(variables)
  let bits_list = all_bit_vectors(names.length())
  let out : Array[Array[Int]] = Array::new()
  for bits in bits_list {
    let env = env_from_bits(names, bits)
    if bool_eval(expr, env) {
      out.push(bits)
    }
  }
  out
}

///|
pub fn term_to_integer_bits(term : Array[Int]) -> Int {
  let mut value = 0
  for bit in term {
    value = (value << 1) + bit
  }
  value
}

///|
pub fn term_to_integer_str(term : String) -> Int {
  let mut value = 0
  for ch in term {
    let bit = if ch == '1' { 1 } else { 0 }
    value = (value << 1) + bit
  }
  value
}

///|
pub fn integer_to_term(value : Int, bits : Int) -> Array[Int] {
  ibin(value, bits)
}

///|
pub fn to_int_repr(
  clauses : Array[BoolExpr],
  symbols : Array[BoolExpr],
) -> Array[Array[Int]] {
  let names = symbol_names_from_exprs(symbols)
  let sym_map : Map[String, Int] = Map::new()
  for i in 0..<names.length() {
    sym_map[names[i]] = i + 1
  }
  let out : Array[Array[Int]] = Array::new()
  for clause in clauses {
    let parts = disjuncts(clause)
    let set : Map[Int, Bool] = Map::new()
    for part in parts {
      match part {
        BoolExpr::Symbol(name) =>
          match sym_map.get(name) {
            Some(idx) => set[idx] = true
            None => ()
          }
        BoolExpr::Not(inner) =>
          match inner {
            BoolExpr::Symbol(name) =>
              match sym_map.get(name) {
                Some(idx) => set[-idx] = true
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
    let clause_ints : Array[Int] = Array::new()
    for key, _ in set {
      clause_ints.push(key)
    }
    clause_ints.sort()
    out.push(clause_ints)
  }
  out
}

///|
pub(all) enum BitPattern {
  Index(Int)
  Bits(Array[Int])
}

///|
pub fn bool_minterm(pattern : BitPattern, variables : Array[BoolExpr]) -> BoolExpr {
  let bits =
    match pattern {
      BitPattern::Index(k) => ibin(k, variables.length())
      BitPattern::Bits(b) => b
    }
  _convert_to_varsSOP(bits, variables)
}

///|
pub fn bool_maxterm(pattern : BitPattern, variables : Array[BoolExpr]) -> BoolExpr {
  let bits =
    match pattern {
      BitPattern::Index(k) => ibin(k, variables.length())
      BitPattern::Bits(b) => b
    }
  _convert_to_varsPOS(bits, variables)
}

///|
pub fn bool_monomial(pattern : BitPattern, variables : Array[BoolExpr]) -> BoolExpr {
  let bits =
    match pattern {
      BitPattern::Index(k) => ibin(k, variables.length())
      BitPattern::Bits(b) => b
    }
  _convert_to_varsANF(bits, variables)
}
