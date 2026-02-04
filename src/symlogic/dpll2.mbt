///|
/// DPLL2-style satisfiability (simplified, based on int repr).

///|
fn remove_int_local(xs : Array[Int], value : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for x in xs {
    if x != value {
      out.push(x)
    }
  }
  out
}

///|
fn lra_branch_satisfiable(
  base : Array[LinearConstraint],
  branches : Array[Array[LinearConstraint]],
  idx : Int,
) -> Bool {
  if idx >= branches.length() {
    return lra_satisfiable(base)
  }
  let choices = branches[idx]
  for choice in choices {
    let next = base.copy()
    next.push(choice)
    if lra_branch_satisfiable(next, branches, idx + 1) {
      return true
    }
  }
  false
}

///|
fn lra_model_satisfiable(
  model : Map[Int, Bool],
  symbol_names : Array[String],
  lra_map : Map[String, LinearConstraint],
) -> Bool {
  if lra_map.is_empty() {
    return true
  }
  let base : Array[LinearConstraint] = Array::new()
  let branches : Array[Array[LinearConstraint]] = Array::new()
  for key, val in model {
    let idx = key - 1
    if idx < 0 || idx >= symbol_names.length() {
      continue
    }
    let name = symbol_names[idx]
    match lra_map.get(name) {
      Some(constraint) => {
        if val {
          base.push(constraint)
        } else {
          branches.push(linear_constraint_negate(constraint))
        }
      }
      None => ()
    }
  }
  if branches.is_empty() {
    return lra_satisfiable(base)
  }
  lra_branch_satisfiable(base, branches, 0)
}

///|
fn dpll_int_repr_all_models(
  clauses : Array[Array[Int]],
  symbols : Array[Int],
  model : Map[Int, Bool],
) -> Array[Map[Int, Bool]] {
  let mut current_clauses = clauses
  let mut current_symbols = symbols
  let current_model = model
  let mut unit_res = find_unit_clause_int_repr(current_clauses, current_model)
  while true {
    match unit_res {
      (Some(p), Some(value)) => {
        current_model[p] = value
        current_symbols = remove_int_local(current_symbols, p)
        let lit = if value { p } else { -p }
        current_clauses = unit_propagate_int_repr(current_clauses, lit)
        unit_res = find_unit_clause_int_repr(current_clauses, current_model)
      }
      _ => break
    }
  }
  let mut pure_res = find_pure_symbol_int_repr(current_symbols, current_clauses)
  while true {
    match pure_res {
      (Some(p), Some(value)) => {
        current_model[p] = value
        current_symbols = remove_int_local(current_symbols, p)
        let lit = if value { p } else { -p }
        current_clauses = unit_propagate_int_repr(current_clauses, lit)
        pure_res = find_pure_symbol_int_repr(current_symbols, current_clauses)
      }
      _ => break
    }
  }
  let unknown : Array[Array[Int]] = Array::new()
  for clause in current_clauses {
    match pl_true_int_repr(clause, current_model) {
      Some(true) => ()
      Some(false) => return []
      None => unknown.push(clause)
    }
  }
  if unknown.is_empty() || current_symbols.is_empty() {
    return [current_model]
  }
  let p_sym = current_symbols[current_symbols.length() - 1]
  let rest = remove_int_local(current_symbols, p_sym)
  let model_true = current_model.copy()
  model_true[p_sym] = true
  let res = dpll_int_repr_all_models(
    unit_propagate_int_repr(unknown, p_sym),
    rest.copy(),
    model_true,
  )
  let model_false = current_model.copy()
  model_false[p_sym] = false
  let res_false = dpll_int_repr_all_models(
    unit_propagate_int_repr(unknown, -p_sym),
    rest,
    model_false,
  )
  for item in res_false {
    res.push(item)
  }
  res
}

///|
pub fn dpll2_satisfiable(
  expr : BoolExpr,
  use_lra_theory? : Bool = false,
) -> Map[String, Bool]? {
  match expr {
    BoolExpr::True => return Some(Map::new())
    BoolExpr::False => return None
    _ => ()
  }
  let cnf_expr = to_cnf(expr)
  let clauses = conjuncts(cnf_expr)
  for clause in clauses {
    if clause == BoolExpr::False {
      return None
    }
  }
  let symbols = symbols_in(expr)
  let symbol_names : Array[String] = Array::new()
  for s in symbols {
    let key = symbol_key(s)
    if key != "" {
      symbol_names.push(key)
    }
  }
  let lra_map : Map[String, LinearConstraint] = Map::new()
  for s in symbols {
    match s {
      BoolExpr::LRA(constraint) => {
        let key = linear_constraint_key(constraint)
        lra_map[key] = constraint
      }
      _ => ()
    }
  }
  let indices : Array[Int] = Array::new()
  for i in 0..<symbol_names.length() {
    indices.push(i + 1)
  }
  let clauses_int = to_int_repr(clauses, symbols)
  let models = dpll_int_repr_all_models(clauses_int, indices, Map::new())
  if models.is_empty() {
    return None
  }
  let use_lra = use_lra_theory && !lra_map.is_empty()
  for model in models {
    if use_lra && !lra_model_satisfiable(model, symbol_names, lra_map) {
      continue
    }
    let out : Map[String, Bool] = Map::new()
    for key, val in model {
      let idx = key - 1
      if idx >= 0 && idx < symbol_names.length() {
        out[symbol_names[idx]] = val
      }
    }
    return Some(out)
  }
  None
}

///|
pub fn dpll2_all_models(
  expr : BoolExpr,
  use_lra_theory? : Bool = false,
) -> Array[Map[String, Bool]?] {
  match expr {
    BoolExpr::True => return [Some(Map::new())]
    BoolExpr::False => return [None]
    _ => ()
  }
  let cnf_expr = to_cnf(expr)
  let clauses = conjuncts(cnf_expr)
  for clause in clauses {
    if clause == BoolExpr::False {
      return [None]
    }
  }
  let symbols = symbols_in(expr)
  let symbol_names : Array[String] = Array::new()
  for s in symbols {
    let key = symbol_key(s)
    if key != "" {
      symbol_names.push(key)
    }
  }
  let lra_map : Map[String, LinearConstraint] = Map::new()
  for s in symbols {
    match s {
      BoolExpr::LRA(constraint) => {
        let key = linear_constraint_key(constraint)
        lra_map[key] = constraint
      }
      _ => ()
    }
  }
  let indices : Array[Int] = Array::new()
  for i in 0..<symbol_names.length() {
    indices.push(i + 1)
  }
  let clauses_int = to_int_repr(clauses, symbols)
  let models = dpll_int_repr_all_models(clauses_int, indices, Map::new())
  if models.is_empty() {
    return [None]
  }
  let use_lra = use_lra_theory && !lra_map.is_empty()
  let out : Array[Map[String, Bool]?] = Array::new()
  for model in models {
    if use_lra && !lra_model_satisfiable(model, symbol_names, lra_map) {
      continue
    }
    let map : Map[String, Bool] = Map::new()
    for key, val in model {
      let idx = key - 1
      if idx >= 0 && idx < symbol_names.length() {
        map[symbol_names[idx]] = val
      }
    }
    out.push(Some(map))
  }
  if out.is_empty() {
    return [None]
  }
  out
}

///|
pub fn models_to_string(models : Array[Map[String, Bool]?]) -> String {
  if models.is_empty() {
    return "[]"
  }
  let parts : Array[String] = Array::new()
  for model in models {
    parts.push(model_to_string(model))
  }
  parts.sort()
  let joined = parts.join(", ")
  "[\{joined}]"
}
