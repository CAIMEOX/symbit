///|
/// SymPy-style monomial enumeration front doors.
///
/// Current Limits:
/// - MoonBit exposes separate total-degree and per-variable bounded entry
///   points because the source API accepts either an integer or a list in the
///   same argument slot.
/// - Non-commutative variable ordering is not modeled; all generated monomials
///   use the commutative expression constructors.

///|
/// Generate monomials with bounded total degree.
///
/// - Does: Enumerates products in `variables` whose total degree is between
///   `min_degree` and `max_degree`.
/// - Input: Variables as `Array[Expr]`, an integer maximum degree, and an
///   optional integer minimum degree.
/// - Returns: `Array[Expr]` containing the generated monomial expressions.
/// - Limits: Raises `PolyError::BadExponent` for negative degree bounds.
pub fn itermonomials(
  variables : Array[Expr],
  max_degree : Int,
  min_degree? : Int = 0,
) -> Array[Expr] raise PolyError {
  if max_degree < 0 || min_degree < 0 {
    raise BadExponent
  }
  if min_degree > max_degree {
    return []
  }
  if variables.is_empty() || max_degree == 0 {
    return [int(1)]
  }
  let out : Array[Expr] = []
  let exps = Array::make(variables.length(), 0)
  for total in min_degree..<=max_degree {
    itermonomials_fill_total(variables, exps, 0, total, out)
  }
  out
}

///|
/// Generate monomials with per-variable degree bounds.
///
/// - Does: Enumerates products where each variable exponent lies between the
///   corresponding minimum and maximum bound.
/// - Input: Variables, per-variable maximum degrees, and optional per-variable
///   minimum degrees.
/// - Returns: `Array[Expr]` containing the generated monomial expressions.
/// - Limits: Raises `PolyError::DomainMismatch` for length mismatch and
///   `PolyError::BadExponent` for invalid bounds.
pub fn itermonomials_bounded(
  variables : Array[Expr],
  max_degrees : Array[Int],
  min_degrees? : Array[Int],
) -> Array[Expr] raise PolyError {
  let n = variables.length()
  if max_degrees.length() != n {
    raise DomainMismatch
  }
  let mins = match min_degrees {
    Some(values) => {
      if values.length() != n {
        raise DomainMismatch
      }
      values
    }
    None => Array::make(n, 0)
  }
  for i in 0..<n {
    if mins[i] < 0 || max_degrees[i] < 0 || mins[i] > max_degrees[i] {
      raise BadExponent
    }
  }
  let out : Array[Expr] = []
  let exps = Array::make(n, 0)
  itermonomials_fill_bounds(variables, mins, max_degrees, exps, 0, out)
  out
}

///|
fn itermonomials_fill_total(
  variables : Array[Expr],
  exps : Array[Int],
  index : Int,
  remaining : Int,
  out : Array[Expr],
) -> Unit {
  if index == variables.length() - 1 {
    exps[index] = remaining
    out.push(monomial_expr_from_exps(variables, exps))
    return
  }
  for exp in 0..<=remaining {
    exps[index] = exp
    itermonomials_fill_total(variables, exps, index + 1, remaining - exp, out)
  }
}

///|
fn itermonomials_fill_bounds(
  variables : Array[Expr],
  mins : Array[Int],
  maxs : Array[Int],
  exps : Array[Int],
  index : Int,
  out : Array[Expr],
) -> Unit {
  if index == variables.length() {
    out.push(monomial_expr_from_exps(variables, exps))
    return
  }
  for exp in mins[index]..<=maxs[index] {
    exps[index] = exp
    itermonomials_fill_bounds(variables, mins, maxs, exps, index + 1, out)
  }
}

///|
fn monomial_expr_from_exps(variables : Array[Expr], exps : Array[Int]) -> Expr {
  let factors : Array[Expr] = []
  for i in 0..<variables.length() {
    let exp = exps[i]
    if exp == 0 {
      continue
    } else if exp == 1 {
      factors.push(variables[i])
    } else {
      factors.push(variables[i] ^ int(exp))
    }
  }
  if factors.is_empty() {
    int(1)
  } else {
    expr_mul_all(factors)
  }
}
