///|
/// DPLL satisfiability (subset of sympy.logic.algorithms.dpll).

///|
fn abs_int(x : Int) -> Int {
  if x < 0 {
    -x
  } else {
    x
  }
}

///|
fn remove_int(xs : Array[Int], value : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for x in xs {
    if x != value {
      out.push(x)
    }
  }
  out
}

///|
fn contains_int(xs : Array[Int], value : Int) -> Bool {
  for x in xs {
    if x == value {
      return true
    }
  }
  false
}

///|
pub fn pl_true_int_repr(clause : Array[Int], model : Map[Int, Bool]) -> Bool? {
  let mut has_unknown = false
  for lit in clause {
    let lit_var = abs_int(lit)
    match model.get(lit_var) {
      Some(v) => if (lit > 0 && v) || (lit < 0 && !v) { return Some(true) }
      None => has_unknown = true
    }
  }
  if has_unknown {
    None
  } else {
    Some(false)
  }
}

///|
pub fn unit_propagate_int_repr(
  clauses : Array[Array[Int]],
  lit : Int,
) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  let neg = -lit
  for clause in clauses {
    if contains_int(clause, lit) {
      continue
    }
    if contains_int(clause, neg) {
      let filtered : Array[Int] = Array::new()
      for x in clause {
        if x != neg {
          filtered.push(x)
        }
      }
      out.push(filtered)
    } else {
      out.push(clause)
    }
  }
  out
}

///|
pub fn find_unit_clause_int_repr(
  clauses : Array[Array[Int]],
  model : Map[Int, Bool],
) -> (Int?, Bool?) {
  let bound : Map[Int, Bool] = Map::new()
  for key, _ in model {
    bound[key] = true
    bound[-key] = true
  }
  for clause in clauses {
    let unbound : Map[Int, Bool] = Map::new()
    for lit in clause {
      if !bound.contains(lit) {
        unbound[lit] = true
      }
    }
    if unbound.length() == 1 {
      for lit, _ in unbound {
        if lit < 0 {
          return (Some(-lit), Some(false))
        }
        return (Some(lit), Some(true))
      }
    }
  }
  (None, None)
}

///|
pub fn find_pure_symbol_int_repr(
  symbols : Array[Int],
  clauses : Array[Array[Int]],
) -> (Int?, Bool?) {
  let polarity : Map[Int, Int] = Map::new()
  for clause in clauses {
    for lit in clause {
      let lit_var = abs_int(lit)
      let mask = match polarity.get(lit_var) {
        Some(m) => m
        None => 0
      }
      let new_mask = if lit > 0 { mask | 1 } else { mask | 2 }
      polarity[lit_var] = new_mask
    }
  }
  for s in symbols {
    match polarity.get(s) {
      Some(1) => return (Some(s), Some(true))
      Some(2) => return (Some(s), Some(false))
      _ => ()
    }
  }
  (None, None)
}

///|
fn dpll_int_repr(
  clauses : Array[Array[Int]],
  symbols : Array[Int],
  model : Map[Int, Bool],
) -> Map[Int, Bool]? {
  let mut current_clauses = clauses
  let mut current_symbols = symbols
  let current_model = model
  let mut unit_res = find_unit_clause_int_repr(current_clauses, current_model)
  while true {
    match unit_res {
      (Some(p), Some(value)) => {
        current_model[p] = value
        current_symbols = remove_int(current_symbols, p)
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
        current_symbols = remove_int(current_symbols, p)
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
      Some(false) => return None
      None => unknown.push(clause)
    }
  }
  if unknown.is_empty() {
    return Some(current_model)
  }
  if current_symbols.is_empty() {
    return Some(current_model)
  }
  let p_sym = current_symbols[current_symbols.length() - 1]
  let rest = remove_int(current_symbols, p_sym)
  let model_true = current_model.copy()
  model_true[p_sym] = true
  match
    dpll_int_repr(
      unit_propagate_int_repr(unknown, p_sym),
      rest.copy(),
      model_true,
    ) {
    Some(res) => Some(res)
    None => {
      let model_false = current_model.copy()
      model_false[p_sym] = false
      dpll_int_repr(unit_propagate_int_repr(unknown, -p_sym), rest, model_false)
    }
  }
}

///|
fn contains_expr(xs : Array[BoolExpr], value : BoolExpr) -> Bool {
  for x in xs {
    if x == value {
      return true
    }
  }
  false
}

///|
pub fn unit_propagate(
  clauses : Array[BoolExpr],
  symbol : BoolExpr,
) -> Array[BoolExpr] {
  let out : Array[BoolExpr] = Array::new()
  let neg = bool_not(symbol)
  for clause in clauses {
    match clause {
      BoolExpr::Or(args) => {
        if contains_expr(args, symbol) {
          continue
        }
        if contains_expr(args, neg) {
          let filtered : Array[BoolExpr] = Array::new()
          for arg in args {
            if arg != neg {
              filtered.push(arg)
            }
          }
          out.push(bool_or(filtered))
        } else {
          out.push(clause)
        }
      }
      _ => out.push(clause)
    }
  }
  out
}

///|
pub fn find_unit_clause(
  clauses : Array[BoolExpr],
  model : Map[String, Bool],
) -> (BoolExpr?, Bool?) {
  for clause in clauses {
    let mut num_not_in_model = 0
    let mut p : BoolExpr? = None
    let mut value : Bool? = None
    for literal in disjuncts(clause) {
      let sym = literal_symbol(literal)
      let in_model = match sym {
        BoolExpr::Symbol(name) => model.contains(name)
        _ => false
      }
      if !in_model {
        num_not_in_model += 1
        p = Some(sym)
        value = Some(
          match literal {
            BoolExpr::Not(_) => false
            _ => true
          },
        )
      }
    }
    if num_not_in_model == 1 {
      return (p, value)
    }
  }
  (None, None)
}

///|
pub fn find_pure_symbol(
  symbols : Array[BoolExpr],
  clauses : Array[BoolExpr],
) -> (BoolExpr?, Bool?) {
  for sym in symbols {
    let mut found_pos = false
    let mut found_neg = false
    let neg = bool_not(sym)
    for clause in clauses {
      let lits = disjuncts(clause)
      if !found_pos && contains_expr(lits, sym) {
        found_pos = true
      }
      if !found_neg && contains_expr(lits, neg) {
        found_neg = true
      }
    }
    if found_pos != found_neg {
      return (Some(sym), Some(found_pos))
    }
  }
  (None, None)
}

///|
pub fn dpll(
  clauses : Array[BoolExpr],
  symbols : Array[BoolExpr],
  model : Map[String, Bool],
) -> Map[String, Bool]? {
  let symbol_names : Array[String] = Array::new()
  for s in symbols {
    let key = symbol_key(s)
    if key != "" {
      symbol_names.push(key)
    }
  }
  let indices : Array[Int] = Array::new()
  let model_int : Map[Int, Bool] = Map::new()
  for i in 0..<symbol_names.length() {
    let name = symbol_names[i]
    match model.get(name) {
      Some(v) => model_int[i + 1] = v
      None => indices.push(i + 1)
    }
  }
  let clauses_int = to_int_repr(clauses, symbols)
  let result = dpll_int_repr(clauses_int, indices, model_int)
  match result {
    None => None
    Some(int_model) => {
      let out : Map[String, Bool] = Map::new()
      for name, val in model {
        out[name] = val
      }
      for key, val in int_model {
        let idx = key - 1
        if idx >= 0 && idx < symbol_names.length() {
          out[symbol_names[idx]] = val
        }
      }
      Some(out)
    }
  }
}

///|
pub fn dpll_satisfiable(expr : BoolExpr) -> Map[String, Bool]? {
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
  let indices : Array[Int] = Array::new()
  for i in 0..<symbol_names.length() {
    indices.push(i + 1)
  }
  let clauses_int = to_int_repr(clauses, symbols)
  let result = dpll_int_repr(clauses_int, indices, Map::new())
  match result {
    None => None
    Some(model) => {
      let out : Map[String, Bool] = Map::new()
      for key, val in model {
        let idx = key - 1
        if idx >= 0 && idx < symbol_names.length() {
          out[symbol_names[idx]] = val
        }
      }
      Some(out)
    }
  }
}

///|
pub fn model_to_string(model : Map[String, Bool]?) -> String {
  match model {
    None => "False"
    Some(m) => {
      if m.is_empty() {
        return "{True: True}"
      }
      let keys : Array[String] = Array::new()
      for k, _ in m {
        keys.push(k)
      }
      keys.sort()
      let parts : Array[String] = Array::new()
      for k in keys {
        let v = if m[k] { "True" } else { "False" }
        parts.push("\{k}: \{v}")
      }
      let joined = parts.join(", ")
      "{\{joined}}"
    }
  }
}
