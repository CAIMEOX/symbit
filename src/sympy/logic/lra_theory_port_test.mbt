///|
fn satresult_to_bool_string(res : SatResult) -> String {
  match res {
    Single(None) => "False"
    _ => "True"
  }
}

///|
fn constraint_to_sympy_str(constraint : LinearConstraint) -> String {
  if constraint.op != Eq {
    return Show::to_string(constraint)
  }
  let raw = Show::to_string(constraint)
  let parts : Array[String] = Array::new()
  for part in raw.split(" == ") {
    parts.push(part.to_owned())
  }
  if parts.length() == 2 {
    return "Eq(\{parts[0]}, \{parts[1]})"
  }
  raw
}

///|
fn constraint_eq_parts(constraint : LinearConstraint) -> (String, String)? {
  if constraint.op != Eq {
    return None
  }
  let raw = Show::to_string(constraint)
  let parts : Array[String] = Array::new()
  for part in raw.split(" == ") {
    parts.push(part.to_owned())
  }
  if parts.length() == 2 {
    return Some((parts[0], parts[1]))
  }
  None
}

///|
fn expr_to_sympy_str(expr : BoolExpr) -> String {
  match expr {
    True => "True"
    False => "False"
    Symbol(name) => name
    LRA(constraint) => constraint_to_sympy_str(constraint)
    Not(inner) =>
      match inner {
        LRA(constraint) =>
          match constraint_eq_parts(constraint) {
            Some((lhs, rhs)) => "((\{lhs} < \{rhs}) | (\{lhs} > \{rhs}))"
            None => "~(\{expr_to_sympy_str(inner)})"
          }
        _ => "~(\{expr_to_sympy_str(inner)})"
      }
    And(args) => {
      if args.is_empty() {
        return "True"
      }
      let parts = args.map(arg => expr_to_sympy_str(arg))
      let wrapped = parts.map(p => "(\{p})")
      let joined = wrapped.join(" & ")
      "(\{joined})"
    }
    Or(args) => {
      if args.is_empty() {
        return "False"
      }
      let parts = args.map(arg => expr_to_sympy_str(arg))
      let wrapped = parts.map(p => "(\{p})")
      let joined = wrapped.join(" | ")
      "(\{joined})"
    }
    _ => to_string(expr)
  }
}

///|
fn oracle_lra_sat(expr : BoolExpr) -> String raise {
  let expr_str = expr_to_sympy_str(expr)
  let raw = inference_satisfiable_str(
    expr_str,
    algorithm="dpll2",
    use_lra_theory=true,
  )
  if raw == "False" {
    "False"
  } else {
    "True"
  }
}

///|
test "lra theory satisfiable parity" {
  let c1 = linear_constraint_from_ints([("x", 1)], 0, Ge)
  let c2 = linear_constraint_from_ints([("x", 1)], 1, Le)
  let expr1 = bool_and([LRA(c1), LRA(c2)])
  let ours1 = satresult_to_bool_string(satisfiable(expr1, use_lra_theory=true))
  let oracle1 = oracle_lra_sat(expr1)
  assert_eq(ours1, oracle1)
  let c3 = linear_constraint_from_ints([("x", 1)], 0, Ge)
  let c4 = linear_constraint_from_ints([("x", 1)], -1, Le)
  let expr2 = bool_and([LRA(c3), LRA(c4)])
  let ours2 = satresult_to_bool_string(satisfiable(expr2, use_lra_theory=true))
  let oracle2 = oracle_lra_sat(expr2)
  assert_eq(ours2, oracle2)
  let c5 = linear_constraint_from_ints([("x", 1), ("y", 1)], 1, Le)
  let c6 = linear_constraint_from_ints([("x", 1)], 1, Ge)
  let c7 = linear_constraint_from_ints([("y", 1)], 1, Ge)
  let expr3 = bool_and([LRA(c5), LRA(c6), LRA(c7)])
  let ours3 = satresult_to_bool_string(satisfiable(expr3, use_lra_theory=true))
  let oracle3 = oracle_lra_sat(expr3)
  assert_eq(ours3, oracle3)
  let c8 = linear_constraint_from_ints([("x", 1)], 0, Gt)
  let c9 = linear_constraint_from_ints([("x", 1)], 1, Lt)
  let expr4 = bool_and([LRA(c8), LRA(c9)])
  let ours4 = satresult_to_bool_string(satisfiable(expr4, use_lra_theory=true))
  let oracle4 = oracle_lra_sat(expr4)
  assert_eq(ours4, oracle4)
  let c10 = linear_constraint_from_ints([("x", 1)], 1, Eq)
  let c11 = linear_constraint_from_ints([("x", 1)], 2, Ge)
  let expr5 = bool_and([LRA(c10), LRA(c11)])
  let ours5 = satresult_to_bool_string(satisfiable(expr5, use_lra_theory=true))
  let oracle5 = oracle_lra_sat(expr5)
  assert_eq(ours5, oracle5)
}

///|
test "lra theory negated equality and or/not parity" {
  let eq0 = linear_constraint_from_ints([("x", 1)], 0, Eq)
  let ge1 = linear_constraint_from_ints([("x", 1)], 1, Ge)
  let expr1 = bool_and([bool_not(LRA(eq0)), LRA(ge1)])
  let ours1 = satresult_to_bool_string(satisfiable(expr1, use_lra_theory=true))
  let oracle1 = oracle_lra_sat(expr1)
  assert_eq(ours1, oracle1)
  let le0 = linear_constraint_from_ints([("x", 1)], 0, Le)
  let ge0 = linear_constraint_from_ints([("x", 1)], 0, Ge)
  let expr2 = bool_and([bool_not(LRA(eq0)), LRA(le0), LRA(ge0)])
  let ours2 = satresult_to_bool_string(satisfiable(expr2, use_lra_theory=true))
  let oracle2 = oracle_lra_sat(expr2)
  assert_eq(ours2, oracle2)
  let le_neg = linear_constraint_from_ints([("x", 1)], -1, Le)
  let ge_pos = linear_constraint_from_ints([("x", 1)], 1, Ge)
  let expr3 = bool_or([LRA(le_neg), LRA(ge_pos)])
  let ours3 = satresult_to_bool_string(satisfiable(expr3, use_lra_theory=true))
  let oracle3 = oracle_lra_sat(expr3)
  assert_eq(ours3, oracle3)
  let lt0 = linear_constraint_from_ints([("x", 1)], 0, Lt)
  let expr4 = bool_and([
    bool_or([bool_not(LRA(eq0)), LRA(lt0)]),
    LRA(le0),
    LRA(ge0),
  ])
  let ours4 = satresult_to_bool_string(satisfiable(expr4, use_lra_theory=true))
  let oracle4 = oracle_lra_sat(expr4)
  assert_eq(ours4, oracle4)
}
