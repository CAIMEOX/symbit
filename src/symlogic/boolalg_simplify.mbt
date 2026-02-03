///|
/// Higher-level simplification utilities for boolalg.

///|
pub fn simplify_logic(
  expr : BoolExpr,
  form? : String,
  deep? : Bool = true,
  force? : Bool = false,
  dontcare? : BoolExpr,
) -> BoolExpr {
  let _ = deep
  let form_str = match form {
    Some(v) => v
    None => ""
  }
  if form_str != "" && form_str != "cnf" && form_str != "dnf" {
    return expr
  }
  if is_literal(expr) && dontcare is None {
    return expr
  }
  let vars = symbols_in(expr)
  if dontcare is Some(dc) {
    let dc_vars = symbols_in(dc)
    for v in dc_vars {
      if !vars.contains(v) {
        vars.push(v)
      }
    }
    vars.sort_by(compare_bool)
  }
  if !force && vars.length() > 8 {
    return expr
  }
  let mut mins = true_terms(expr, vars)
  let mut dcs : Array[Array[Int]] = []
  if dontcare is Some(dc) {
    dcs = true_terms(dc, vars)
    let filtered : Array[Array[Int]] = Array::new()
    for term in mins {
      if !dcs.contains(term) {
        filtered.push(term)
      }
    }
    mins = filtered
  }
  let big =
    if vars.is_empty() {
      false
    } else {
      mins.length() >= (1 << (vars.length() - 1))
    }
  if form_str == "dnf" || (form_str == "" && big) {
    return _sop_form(vars, mins, dcs)
  }
  pos_form_bits(vars, mins, dcs)
}

///|
fn pos_form_bits(
  variables : Array[BoolExpr],
  minterms : Array[Array[Int]],
  dontcares : Array[Array[Int]],
) -> BoolExpr {
  let maxterms : Array[Array[Int]] = Array::new()
  let all = all_bit_vectors(variables.length())
  for t in all {
    if !minterms.contains(t) && !dontcares.contains(t) {
      maxterms.push(t)
    }
  }
  if maxterms.is_empty() {
    return BoolExpr::True
  }
  let new = _simplified_pairs(maxterms + dontcares)
  let essential = _rem_redundancy(new, maxterms)
  let args : Array[BoolExpr] = Array::new()
  for term in essential {
    args.push(_convert_to_varsPOS(term, variables))
  }
  bool_and(args)
}

///|
pub struct BoolMapResult {
  simplified : BoolExpr
  mapping : Map[String, BoolExpr]
} derive(Show)

///|
fn truth_table_equal(
  a : BoolExpr,
  b : BoolExpr,
  variables : Array[BoolExpr],
) -> Bool {
  let names = symbol_names_from_exprs(variables)
  let bits_list = all_bit_vectors(names.length())
  for bits in bits_list {
    let env = env_from_bits(names, bits)
    if bool_eval(a, env) != bool_eval(b, env) {
      return false
    }
  }
  true
}

///|
pub fn bool_map(bool1 : BoolExpr, bool2 : BoolExpr) -> BoolMapResult? {
  let a = simplify_logic(bool1)
  let b = simplify_logic(bool2)
  let vars_a = symbols_in(a)
  let vars_b = symbols_in(b)
  if vars_a.length() != vars_b.length() {
    return None
  }
  let names_a = symbol_names_from_exprs(vars_a)
  let names_b = symbol_names_from_exprs(vars_b)
  let perms = permutations_strings(names_b)
  for perm in perms {
    let mapping : Map[String, BoolExpr] = Map::new()
    for i in 0..<names_a.length() {
      mapping[names_a[i]] = BoolExpr::Symbol(perm[i])
    }
    let substituted = bool_subst(a, mapping)
    if truth_table_equal(substituted, b, vars_b) {
      return Some({ simplified: a, mapping })
    }
  }
  None
}

///|
pub fn simplify_univariate(expr : BoolExpr) -> BoolExpr {
  let vars = symbols_in(expr)
  if vars.length() != 1 {
    return expr
  }
  let name = match vars[0] {
    BoolExpr::Symbol(n) => n
    _ => return expr
  }
  let env0 : Map[String, Bool] = Map::new()
  env0[name] = false
  let env1 : Map[String, Bool] = Map::new()
  env1[name] = true
  let v0 = bool_eval(expr, env0)
  let v1 = bool_eval(expr, env1)
  if v0 && v1 {
    return BoolExpr::True
  }
  if !v0 && !v1 {
    return BoolExpr::False
  }
  if !v0 && v1 {
    return vars[0]
  }
  bool_not(vars[0])
}

///|
pub fn gateinputcount(expr : BoolExpr) -> Int {
  match expr {
    BoolExpr::True => 0
    BoolExpr::False => 0
    BoolExpr::Symbol(_) => 0
    BoolExpr::Not(inner) => 1 + gateinputcount(inner)
    BoolExpr::And(args)
    | BoolExpr::Or(args)
    | BoolExpr::Xor(args) => {
      let mut count = args.length()
      for arg in args {
        count += gateinputcount(arg)
      }
      count
    }
    BoolExpr::ITE(c, t, e) =>
      3 + gateinputcount(c) + gateinputcount(t) + gateinputcount(e)
    BoolExpr::Implies(_, _) | BoolExpr::Equivalent(_) =>
      gateinputcount(eliminate_implications(expr))
  }
}
