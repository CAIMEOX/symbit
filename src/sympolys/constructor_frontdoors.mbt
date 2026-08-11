///|
/// Domain-construction front doors.
///
/// Current Limits:
/// - This is a typed MoonBit front door over Symbit's structural `Domain`
///   descriptors, not a Python object factory.
/// - Algebraic extension inference is conservative; pass `domain` explicitly
///   when a specific extension domain is required.

///|
/// Result of constructing a coefficient domain.
///
/// - Does: Stores the selected domain and converted elements.
/// - Input: Produced by `construct_domain`.
/// - Returns: A `ConstructDomainResult`.
/// - Limits: The element representation is still `Expr`, matching Symbit's
///   structural domain layer.
pub struct ConstructDomainResult {
  domain : Domain
  elements : Array[Expr]
}

///|
/// Construct a minimal domain for expressions.
///
/// - Does: Chooses a ground, polynomial-ring, or rational-function-field
///   domain for a list of expressions.
/// - Input: `Array[Expr]` plus optional explicit domain.
/// - Returns: `ConstructDomainResult`.
/// - Limits: Dict input and Python option objects are not modeled; algebraic
///   number-field construction remains explicit through domain front doors.
pub fn construct_domain(
  exprs : Array[Expr],
  domain? : Domain,
  composite? : Bool = true,
) -> ConstructDomainResult {
  let chosen = match domain {
    Some(d) => d
    None => infer_construct_domain(exprs, composite)
  }
  let elements : Array[Expr] = []
  for expr in exprs {
    elements.push(domain_from_sympy_expr(chosen, expr) catch { _ => expr })
  }
  { domain: chosen, elements }
}

///|
fn infer_construct_domain(exprs : Array[Expr], composite : Bool) -> Domain {
  let combined = if exprs.is_empty() { int(0) } else { @symcore.add(exprs) }
  let base = infer_domain(combined)
  let gens = infer_gens_union(exprs)
  if gens.is_empty() || !composite {
    base
  } else if exprs.any(expr => expr_has_negative_generator_power(expr, gens)) {
    RationalFunctionField(base, gens)
  } else {
    PolyRing(base, gens)
  }
}

///|
fn expr_has_negative_generator_power(expr : Expr, gens : Array[String]) -> Bool {
  match expr {
    Pow(Symbol(name), exp) => gens.contains(name) && expr_is_negative_int(exp)
    Add(args) | Mul(args) =>
      args.any(child => expr_has_negative_generator_power(child, gens))
    Pow(base, exp) =>
      expr_has_negative_generator_power(base, gens) ||
      expr_has_negative_generator_power(exp, gens)
    _ =>
      @symcore.args(expr).any(child => {
        expr_has_negative_generator_power(child, gens)
      })
  }
}

///|
fn expr_is_negative_int(expr : Expr) -> Bool {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) => den.compare(1N) == 0 && num.compare(0N) < 0
    None => false
  }
}
