///|
/// Linear real arithmetic (LRA) feasibility via Fourier–Motzkin elimination.

///|
pub(all) enum RelOp {
  Le
  Ge
  Lt
  Gt
  Eq
} derive(Eq)

///|
pub struct LinearConstraint {
  coeffs : Map[String, @symnum.BigRational]
  rhs : @symnum.BigRational
  op : RelOp
}

///|
pub struct LraConflictLit {
  key : String
  negated : Bool
} derive(Eq, Show)

///|
pub(all) struct LraAssumption {
  constraint : LinearConstraint
  key : String
  negated : Bool
}

///|
priv struct LinearExpr {
  coeffs : Map[String, @symnum.BigRational]
  constant : @symnum.BigRational
}

///|
priv struct Ineq {
  coeffs : Map[String, @symnum.BigRational]
  rhs : @symnum.BigRational
  strict : Bool
  origin : Array[LraConflictLit]
}

///|
priv enum LraCheck {
  Sat(Array[Ineq])
  Unsat(Array[LraConflictLit])
}

///|
fn br_zero() -> @symnum.BigRational {
  @symnum.BigRational::zero()
}

///|
fn br_one() -> @symnum.BigRational {
  @symnum.BigRational::one()
}

///|
fn br_neg(value : @symnum.BigRational) -> @symnum.BigRational {
  -value
}

///|
fn br_div(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational {
  try! a.div_r(b)
}

///|
fn add_coeff(
  coeffs : Map[String, @symnum.BigRational],
  name : String,
  value : @symnum.BigRational,
) -> Unit {
  if value.is_zero() {
    return
  }
  match coeffs.get(name) {
    Some(prev) => {
      let sum = prev + value
      if sum.is_zero() {
        coeffs.remove(name)
      } else {
        coeffs[name] = sum
      }
    }
    None => coeffs[name] = value
  }
}

///|
fn origin_key(lit : LraConflictLit) -> String {
  if lit.negated {
    "!\{lit.key}"
  } else {
    lit.key
  }
}

///|
fn origin_single(key : String, negated : Bool) -> Array[LraConflictLit] {
  [LraConflictLit::{ key, negated }]
}

///|
fn origin_union(
  a : Array[LraConflictLit],
  b : Array[LraConflictLit],
) -> Array[LraConflictLit] {
  let seen : Map[String, LraConflictLit] = Map::new()
  for lit in a {
    seen[origin_key(lit)] = lit
  }
  for lit in b {
    seen[origin_key(lit)] = lit
  }
  let out : Array[LraConflictLit] = Array::new()
  for _, lit in seen {
    out.push(lit)
  }
  out
}

///|
fn expr_from_rhs(rhs : @symnum.BigRational) -> LinearExpr {
  { coeffs: Map::new(), constant: rhs }
}

///|
fn expr_from_coeffs(
  coeffs : Map[String, @symnum.BigRational],
  constant : @symnum.BigRational,
) -> LinearExpr {
  { coeffs, constant }
}

///|
fn expr_sub(a : LinearExpr, b : LinearExpr) -> LinearExpr {
  let out : Map[String, @symnum.BigRational] = Map::new()
  for name, value in a.coeffs {
    add_coeff(out, name, value)
  }
  for name, value in b.coeffs {
    add_coeff(out, name, br_neg(value))
  }
  { coeffs: out, constant: a.constant + br_neg(b.constant) }
}

///|
fn expr_mul_scalar(a : LinearExpr, k : @symnum.BigRational) -> LinearExpr {
  if k.is_zero() {
    return { coeffs: Map::new(), constant: br_zero() }
  }
  let out : Map[String, @symnum.BigRational] = Map::new()
  for name, value in a.coeffs {
    add_coeff(out, name, value * k)
  }
  { coeffs: out, constant: a.constant * k }
}

///|
fn expr_div_scalar(a : LinearExpr, k : @symnum.BigRational) -> LinearExpr {
  expr_mul_scalar(a, br_div(br_one(), k))
}

///|
fn ineq_from_expr(
  expr : LinearExpr,
  strict : Bool,
  origin : Array[LraConflictLit],
) -> Ineq {
  Ineq::{ coeffs: expr.coeffs, rhs: br_neg(expr.constant), strict, origin }
}

///|
fn ineq_satisfied(rhs : @symnum.BigRational, strict : Bool) -> Bool {
  let cmp = rhs.compare(br_zero())
  if strict {
    cmp > 0
  } else {
    cmp >= 0
  }
}

///|
fn prune_ineqs(ineqs : Array[Ineq]) -> LraCheck {
  let out : Array[Ineq] = Array::new()
  for ineq in ineqs {
    if ineq.coeffs.is_empty() {
      if !ineq_satisfied(ineq.rhs, ineq.strict) {
        return LraCheck::Unsat(ineq.origin)
      }
      continue
    }
    out.push(ineq)
  }
  LraCheck::Sat(out)
}

///|
fn bound_from_ineq(
  ineq : Ineq,
  var_name : String,
  coeff : @symnum.BigRational,
) -> LinearExpr {
  let rest_coeffs : Map[String, @symnum.BigRational] = Map::new()
  for name, value in ineq.coeffs {
    if name != var_name {
      add_coeff(rest_coeffs, name, value)
    }
  }
  let rest = expr_from_coeffs(rest_coeffs, br_zero())
  let rhs_expr = expr_sub(expr_from_rhs(ineq.rhs), rest)
  expr_div_scalar(rhs_expr, coeff)
}

///|
fn eliminate_var(ineqs : Array[Ineq], var_name : String) -> LraCheck {
  let pos : Array[(Ineq, @symnum.BigRational)] = Array::new()
  let neg : Array[(Ineq, @symnum.BigRational)] = Array::new()
  let zero : Array[Ineq] = Array::new()
  for ineq in ineqs {
    match ineq.coeffs.get(var_name) {
      Some(c) => {
        let cmp = c.compare(br_zero())
        if cmp > 0 {
          pos.push((ineq, c))
        } else if cmp < 0 {
          neg.push((ineq, c))
        } else {
          zero.push(ineq)
        }
      }
      None => zero.push(ineq)
    }
  }
  if pos.is_empty() || neg.is_empty() {
    return prune_ineqs(zero)
  }
  let out : Array[Ineq] = Array::new()
  for ineq in zero {
    out.push(ineq)
  }
  for p in pos {
    let upper = bound_from_ineq(p.0, var_name, p.1)
    for n in neg {
      let lower = bound_from_ineq(n.0, var_name, n.1)
      let expr = expr_sub(lower, upper)
      let strict = p.0.strict || n.0.strict
      let origin = origin_union(p.0.origin, n.0.origin)
      out.push(ineq_from_expr(expr, strict, origin))
    }
  }
  prune_ineqs(out)
}

///|
fn normalize_coeffs(
  coeffs : Map[String, @symnum.BigRational],
) -> Map[String, @symnum.BigRational] {
  let out : Map[String, @symnum.BigRational] = Map::new()
  for name, value in coeffs {
    add_coeff(out, name, value)
  }
  out
}

///|
fn clone_coeffs(
  coeffs : Map[String, @symnum.BigRational],
) -> Map[String, @symnum.BigRational] {
  let out : Map[String, @symnum.BigRational] = Map::new()
  for name, value in coeffs {
    out[name] = value
  }
  out
}

///|
fn ineqs_from_constraint(
  constraint : LinearConstraint,
  origin : Array[LraConflictLit],
) -> Array[Ineq] {
  let coeffs = normalize_coeffs(constraint.coeffs)
  match constraint.op {
    RelOp::Le => [Ineq::{ coeffs, rhs: constraint.rhs, strict: false, origin }]
    RelOp::Lt => [Ineq::{ coeffs, rhs: constraint.rhs, strict: true, origin }]
    RelOp::Ge => {
      let neg_coeffs : Map[String, @symnum.BigRational] = Map::new()
      for name, value in coeffs {
        add_coeff(neg_coeffs, name, br_neg(value))
      }
      [
        Ineq::{
          coeffs: neg_coeffs,
          rhs: br_neg(constraint.rhs),
          strict: false,
          origin,
        },
      ]
    }
    RelOp::Gt => {
      let neg_coeffs : Map[String, @symnum.BigRational] = Map::new()
      for name, value in coeffs {
        add_coeff(neg_coeffs, name, br_neg(value))
      }
      [
        Ineq::{
          coeffs: neg_coeffs,
          rhs: br_neg(constraint.rhs),
          strict: true,
          origin,
        },
      ]
    }
    RelOp::Eq => {
      let neg_coeffs : Map[String, @symnum.BigRational] = Map::new()
      for name, value in coeffs {
        add_coeff(neg_coeffs, name, br_neg(value))
      }
      [
        Ineq::{ coeffs, rhs: constraint.rhs, strict: false, origin },
        Ineq::{
          coeffs: neg_coeffs,
          rhs: br_neg(constraint.rhs),
          strict: false,
          origin,
        },
      ]
    }
  }
}

///|
pub fn linear_constraint_from_ints(
  coeffs : Array[(String, Int)],
  rhs : Int,
  op : RelOp,
) -> LinearConstraint {
  let out : Map[String, @symnum.BigRational] = Map::new()
  for pair in coeffs {
    let name = pair.0
    let value = pair.1
    add_coeff(out, name, @symnum.BigRational::from_int(value))
  }
  { coeffs: out, rhs: @symnum.BigRational::from_int(rhs), op }
}

///|
pub fn linear_constraint_negate(
  constraint : LinearConstraint,
) -> Array[LinearConstraint] {
  match constraint.op {
    RelOp::Le =>
      [
        {
          coeffs: clone_coeffs(constraint.coeffs),
          rhs: constraint.rhs,
          op: RelOp::Gt,
        },
      ]
    RelOp::Lt =>
      [
        {
          coeffs: clone_coeffs(constraint.coeffs),
          rhs: constraint.rhs,
          op: RelOp::Ge,
        },
      ]
    RelOp::Ge =>
      [
        {
          coeffs: clone_coeffs(constraint.coeffs),
          rhs: constraint.rhs,
          op: RelOp::Lt,
        },
      ]
    RelOp::Gt =>
      [
        {
          coeffs: clone_coeffs(constraint.coeffs),
          rhs: constraint.rhs,
          op: RelOp::Le,
        },
      ]
    RelOp::Eq =>
      [
        {
          coeffs: clone_coeffs(constraint.coeffs),
          rhs: constraint.rhs,
          op: RelOp::Lt,
        },
        {
          coeffs: clone_coeffs(constraint.coeffs),
          rhs: constraint.rhs,
          op: RelOp::Gt,
        },
      ]
  }
}

///|
fn format_coeff(
  coeff : @symnum.BigRational,
  name : String,
  first : Bool,
) -> String {
  let zero = br_zero()
  let cmp = coeff.compare(zero)
  let mut sign = ""
  let mut abs_coeff = coeff
  if cmp < 0 {
    sign = if first { "-" } else { "- " }
    abs_coeff = br_neg(coeff)
  } else if !first {
    sign = "+ "
  }
  let coeff_str = abs_coeff.to_string()
  let term = if coeff_str == "1" { name } else { "\{coeff_str}*\{name}" }
  if sign == "" {
    term
  } else if sign == "+ " {
    "\{sign}\{term}"
  } else {
    "\{sign}\{term}"
  }
}

///|
fn linear_lhs_to_string(coeffs : Map[String, @symnum.BigRational]) -> String {
  if coeffs.is_empty() {
    return "0"
  }
  let names : Array[String] = Array::new()
  for name, _ in coeffs {
    names.push(name)
  }
  names.sort()
  let parts : Array[String] = Array::new()
  for i in 0..<names.length() {
    let name = names[i]
    let coeff = coeffs[name]
    let term = format_coeff(coeff, name, i == 0)
    parts.push(term)
  }
  parts.join(" ")
}

///|
pub fn linear_constraint_to_string(constraint : LinearConstraint) -> String {
  let lhs = linear_lhs_to_string(constraint.coeffs)
  let rhs = constraint.rhs.to_string()
  let op = match constraint.op {
    RelOp::Le => "<="
    RelOp::Ge => ">="
    RelOp::Lt => "<"
    RelOp::Gt => ">"
    RelOp::Eq => "=="
  }
  "\{lhs} \{op} \{rhs}"
}

///|
pub fn linear_constraint_key(constraint : LinearConstraint) -> String {
  linear_constraint_to_string(constraint)
}

///|
pub fn lra_check_with_conflict(
  assumptions : Array[LraAssumption],
) -> Array[LraConflictLit]? {
  let ineqs : Array[Ineq] = Array::new()
  for assumption in assumptions {
    let origin = origin_single(assumption.key, assumption.negated)
    for ineq in ineqs_from_constraint(assumption.constraint, origin) {
      ineqs.push(ineq)
    }
  }
  let mut current : Array[Ineq] = Array::new()
  match prune_ineqs(ineqs) {
    LraCheck::Unsat(conflict) => return Some(conflict)
    LraCheck::Sat(filtered) => current = filtered
  }
  let vars : Map[String, Bool] = Map::new()
  for ineq in current {
    for name, _ in ineq.coeffs {
      vars[name] = true
    }
  }
  let var_list : Array[String] = Array::new()
  for name, _ in vars {
    var_list.push(name)
  }
  var_list.sort()
  for name in var_list {
    match eliminate_var(current, name) {
      LraCheck::Unsat(conflict) => return Some(conflict)
      LraCheck::Sat(next) => current = next
    }
  }
  for ineq in current {
    if ineq.coeffs.is_empty() {
      if !ineq_satisfied(ineq.rhs, ineq.strict) {
        return Some(ineq.origin)
      }
    }
  }
  None
}

///|
pub fn lra_satisfiable(constraints : Array[LinearConstraint]) -> Bool {
  let assumptions : Array[LraAssumption] = Array::new()
  for constraint in constraints {
    assumptions.push(LraAssumption::{
      constraint,
      key: linear_constraint_key(constraint),
      negated: false,
    })
  }
  match lra_check_with_conflict(assumptions) {
    None => true
    Some(_) => false
  }
}
