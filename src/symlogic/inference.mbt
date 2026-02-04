///|
/// Propositional inference helpers (subset of sympy.logic.inference).

///|
pub enum SatResult {
  Single(Map[String, Bool]?)
  All(Array[Map[String, Bool]?])
}

///|
pub fn satresult_to_string(res : SatResult) -> String {
  match res {
    SatResult::Single(model) => model_to_string(model)
    SatResult::All(models) => models_to_string(models)
  }
}

///|
pub fn literal_symbol(literal : BoolExpr) -> BoolExpr {
  match literal {
    BoolExpr::True => BoolExpr::True
    BoolExpr::False => BoolExpr::False
    BoolExpr::Symbol(_) => literal
    BoolExpr::LRA(_) => literal
    BoolExpr::Not(inner) => literal_symbol(inner)
    _ => literal
  }
}

///|
fn pl_true_eval(expr : BoolExpr, model : Map[String, Bool?]) -> Bool? {
  match expr {
    BoolExpr::True => Some(true)
    BoolExpr::False => Some(false)
    BoolExpr::Symbol(name) =>
      match model.get(name) {
        Some(v) => v
        None => None
      }
    BoolExpr::LRA(constraint) =>
      match model.get(linear_constraint_key(constraint)) {
        Some(v) => v
        None => None
      }
    BoolExpr::Not(inner) =>
      match pl_true_eval(inner, model) {
        Some(v) => Some(!v)
        None => None
      }
    BoolExpr::And(args) => {
      let mut has_unknown = false
      for arg in args {
        match pl_true_eval(arg, model) {
          Some(true) => ()
          Some(false) => return Some(false)
          None => has_unknown = true
        }
      }
      if has_unknown { None } else { Some(true) }
    }
    BoolExpr::Or(args) => {
      let mut has_unknown = false
      for arg in args {
        match pl_true_eval(arg, model) {
          Some(true) => return Some(true)
          Some(false) => ()
          None => has_unknown = true
        }
      }
      if has_unknown { None } else { Some(false) }
    }
    BoolExpr::Xor(args) => {
      let mut count = 0
      for arg in args {
        match pl_true_eval(arg, model) {
          Some(true) => count += 1
          Some(false) => ()
          None => return None
        }
      }
      Some(count % 2 == 1)
    }
    BoolExpr::Implies(a, b) =>
      match pl_true_eval(a, model) {
        Some(false) => Some(true)
        Some(true) => pl_true_eval(b, model)
        None =>
          match pl_true_eval(b, model) {
            Some(true) => Some(true)
            Some(false) => None
            None => None
          }
      }
    BoolExpr::Equivalent(args) => {
      if args.is_empty() {
        return Some(true)
      }
      let mut first_val : Bool? = None
      let mut has_unknown = false
      for arg in args {
        match pl_true_eval(arg, model) {
          Some(v) =>
            match first_val {
              Some(prev) => if prev != v { return Some(false) }
              None => first_val = Some(v)
            }
          None => has_unknown = true
        }
      }
      match first_val {
        Some(_) => if has_unknown { None } else { Some(true) }
        None => None
      }
    }
    BoolExpr::ITE(c, t, e) =>
      match pl_true_eval(c, model) {
        Some(true) => pl_true_eval(t, model)
        Some(false) => pl_true_eval(e, model)
        None =>
          match (pl_true_eval(t, model), pl_true_eval(e, model)) {
            (Some(tv), Some(ev)) => if tv == ev { Some(tv) } else { None }
            _ => None
          }
      }
  }
}

///|
pub fn pl_true(
  expr : BoolExpr,
  model? : Map[String, Bool?] = {},
  deep? : Bool = false,
) -> Bool? {
  let result = pl_true_eval(expr, model)
  if !deep {
    return result
  }
  match result {
    Some(_) => result
    None => {
      if valid(expr) {
        return Some(true)
      }
      match satisfiable(expr) {
        SatResult::Single(None) => Some(false)
        _ => None
      }
    }
  }
}

///|
pub fn satisfiable(
  expr : BoolExpr,
  algorithm? : String = "",
  all_models? : Bool = false,
  minimal? : Bool = false,
  use_lra_theory? : Bool = false,
) -> SatResult {
  let _ = minimal
  let mut algo = algorithm
  if use_lra_theory {
    algo = "dpll2"
  }
  if algo == "" || algo == "pycosat" || algo == "minisat22" || algo == "z3" {
    algo = "dpll2"
  }
  if all_models {
    let models = dpll2_all_models(expr, use_lra_theory=use_lra_theory)
    return SatResult::All(models)
  }
  let model =
    if algo == "dpll" {
      dpll_satisfiable(expr)
    } else {
      dpll2_satisfiable(expr, use_lra_theory=use_lra_theory)
    }
  SatResult::Single(model)
}

///|
pub fn valid(expr : BoolExpr) -> Bool {
  match satisfiable(bool_not(expr)) {
    SatResult::Single(None) => true
    _ => false
  }
}

///|
pub fn entails(expr : BoolExpr, formula_set? : Array[BoolExpr] = []) -> Bool {
  let formulas = formula_set.copy()
  formulas.push(bool_not(expr))
  let combined = bool_and(formulas)
  match satisfiable(combined) {
    SatResult::Single(None) => true
    _ => false
  }
}

///|
pub struct PropKB {
  clauses : Map[BoolExpr, Bool]
}

///|
pub fn PropKB::new() -> PropKB {
  { clauses: Map::new() }
}

///|
pub fn PropKB::tell(self : PropKB, sentence : BoolExpr) -> Unit {
  let cnf = to_cnf(sentence)
  for clause in conjuncts(cnf) {
    self.clauses[clause] = true
  }
}

///|
pub fn PropKB::ask(self : PropKB, query : BoolExpr) -> Bool {
  let clauses = self.clauses()
  entails(query, formula_set=clauses)
}

///|
pub fn PropKB::retract(self : PropKB, sentence : BoolExpr) -> Unit {
  let cnf = to_cnf(sentence)
  for clause in conjuncts(cnf) {
    self.clauses.remove(clause)
  }
}

///|
pub fn PropKB::clauses(self : PropKB) -> Array[BoolExpr] {
  let out : Array[BoolExpr] = Array::new()
  for clause, _ in self.clauses {
    out.push(clause)
  }
  out.sort_by(compare_bool)
  out
}
