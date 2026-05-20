///|
/// Rational-expression front doors from `sympy.polys.rationaltools`.
///
/// Current Limits:
/// - This is a structural symbolic implementation: it combines rational
///   additive terms without running a full polynomial minimization pass.
/// - Container and function traversal is intentionally narrower than Python's
///   dynamic object model.

///|
priv struct TogetherFactor {
  key : String
  base : Expr
  exp : Int
}

///|
/// One typed partial-fraction term.
///
/// - Does: Stores a numerator over a denominator power.
/// - Input: Produced by `apart_list` or constructed directly.
/// - Returns: An item consumed by `assemble_partfrac_list`.
/// - Limits: This is a MoonBit typed representation, not SymPy's Python tuple
///   with `Lambda` objects.
pub struct ApartTerm {
  numerator : Expr
  denominator : Expr
  exponent : Int
}

///|
/// Structured partial-fraction decomposition.
///
/// - Does: Stores a common multiplier, polynomial part, and proper fraction
///   terms.
/// - Input: Produced by `apart_list`.
/// - Returns: A value accepted by `assemble_partfrac_list`.
/// - Limits: See `ApartTerm`.
pub struct ApartList {
  common : Expr
  polynomial : Expr
  terms : Array[ApartTerm]
}

///|
fn together_expr_is_one(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_one()
    _ => false
  }
}

///|
fn together_expr_is_zero(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn together_int_exp(expr : Expr) -> Int? {
  match expr_coeff_rational_value(expr) {
    Some(value) if value.is_integral() => Some(value.numerator().to_int())
    _ => None
  }
}

///|
fn together_pow_int(base : Expr, exp : Int) -> Expr {
  if exp == 0 {
    int(1)
  } else if exp == 1 {
    base
  } else {
    @symcore.pow(base, int(exp))
  }
}

///|
fn together_mul_exprs(args : Array[Expr]) -> Expr {
  let live = args.filter(item => !together_expr_is_one(item))
  if live.is_empty() {
    int(1)
  } else if live.length() == 1 {
    live[0]
  } else {
    @symcore.mul(live)
  }
}

///|
fn together_add_exprs(args : Array[Expr]) -> Expr {
  let live = args.filter(item => !together_expr_is_zero(item))
  if live.is_empty() {
    int(0)
  } else if live.length() == 1 {
    live[0]
  } else {
    @symcore.add(live)
  }
}

///|
fn together_factor_key(base : Expr) -> String {
  @symprint.pretty_string(base)
}

///|
fn together_push_factor(
  factors : Array[TogetherFactor],
  base : Expr,
  exp : Int,
) -> Unit {
  if exp == 0 || together_expr_is_one(base) {
    return
  }
  let key = together_factor_key(base)
  for i in 0..<factors.length() {
    if factors[i].key == key {
      factors[i] = TogetherFactor::{
        key,
        base: factors[i].base,
        exp: factors[i].exp + exp,
      }
      return
    }
  }
  factors.push(TogetherFactor::{ key, base, exp })
}

///|
fn together_den_factors(expr : Expr) -> Array[TogetherFactor] {
  let factors : Array[TogetherFactor] = []
  fn collect(node : Expr) -> Unit {
    match node {
      Expr::Mul(args) =>
        for arg in args {
          collect(arg)
        }
      Expr::Pow(base, exp) =>
        match together_int_exp(exp) {
          Some(k) if k > 0 => together_push_factor(factors, base, k)
          _ => together_push_factor(factors, node, 1)
        }
      _ => together_push_factor(factors, node, 1)
    }
  }
  if !together_expr_is_one(expr) {
    collect(expr)
  }
  factors
}

///|
fn together_factor_exp(factors : Array[TogetherFactor], key : String) -> Int {
  for item in factors {
    if item.key == key {
      return item.exp
    }
  }
  0
}

///|
fn together_lcm_denominators(dens : Array[Expr]) -> Array[TogetherFactor] {
  let common : Array[TogetherFactor] = []
  for den in dens {
    for factor in together_den_factors(den) {
      let mut found = false
      for i in 0..<common.length() {
        if common[i].key == factor.key {
          found = true
          if factor.exp > common[i].exp {
            common[i] = TogetherFactor::{
              key: common[i].key,
              base: common[i].base,
              exp: factor.exp,
            }
          }
          break
        }
      }
      if !found {
        common.push(factor)
      }
    }
  }
  common
}

///|
fn together_factors_to_expr(factors : Array[TogetherFactor]) -> Expr {
  let pieces : Array[Expr] = []
  for factor in factors {
    if factor.exp > 0 {
      pieces.push(together_pow_int(factor.base, factor.exp))
    }
  }
  together_mul_exprs(pieces)
}

///|
fn together_den_quotient(common : Array[TogetherFactor], den : Expr) -> Expr {
  let den_factors = together_den_factors(den)
  let pieces : Array[Expr] = []
  for factor in common {
    let remaining = factor.exp - together_factor_exp(den_factors, factor.key)
    if remaining > 0 {
      pieces.push(together_pow_int(factor.base, remaining))
    }
  }
  together_mul_exprs(pieces)
}

///|
fn together_make_fraction(num : Expr, den : Expr) -> Expr {
  if together_expr_is_one(den) {
    num
  } else if together_expr_is_zero(num) {
    int(0)
  } else {
    match den {
      Expr::Number(n) =>
        match
          (
            try? n.reciprocal() :
            Result[@symnum.BigRational, @symnum.RationalError]) {
          Ok(inv) => @symcore.mul([num, Expr::Number(inv)])
          Err(_) => @symcore.mul([num, @symcore.pow(den, int(-1))])
        }
      _ => @symcore.mul([num, @symcore.pow(den, int(-1))])
    }
  }
}

///|
fn together_split_fraction(expr : Expr) -> (Expr, Expr) {
  match expr {
    Expr::Number(n) => {
      let num = @symnum.BigRational::from_bigint(n.numerator())
      let den = @symnum.BigRational::from_bigint(n.denominator())
      (Expr::Number(num), Expr::Number(den))
    }
    Expr::Mul(args) => {
      let nums : Array[Expr] = []
      let dens : Array[Expr] = []
      for arg in args {
        let (num, den) = together_split_fraction(arg)
        nums.push(num)
        dens.push(den)
      }
      (together_mul_exprs(nums), together_mul_exprs(dens))
    }
    Expr::Pow(base, exp) =>
      match together_int_exp(exp) {
        Some(k) if k > 0 => {
          let (num, den) = together_split_fraction(base)
          (together_pow_int(num, k), together_pow_int(den, k))
        }
        Some(k) if k < 0 => {
          let (num, den) = together_split_fraction(base)
          (together_pow_int(den, -k), together_pow_int(num, -k))
        }
        _ => (expr, int(1))
      }
    _ => (expr, int(1))
  }
}

///|
fn together_add_terms(args : Array[Expr], fraction : Bool) -> Expr {
  if !fraction {
    return together_add_exprs(args)
  }
  let nums : Array[Expr] = []
  let dens : Array[Expr] = []
  for arg in args {
    let (num, den) = together_split_fraction(arg)
    nums.push(num)
    dens.push(den)
  }
  let common_factors = together_lcm_denominators(dens)
  let common_den = together_factors_to_expr(common_factors)
  let terms : Array[Expr] = []
  for i in 0..<nums.length() {
    terms.push(
      together_mul_exprs([
        nums[i],
        together_den_quotient(common_factors, dens[i]),
      ]),
    )
  }
  together_make_fraction(together_add_exprs(terms), common_den)
}

///|
fn together_inner(expr : Expr, deep : Bool, fraction : Bool) -> Expr {
  match expr {
    Expr::Add(args) => {
      let transformed = args.map(arg => together_inner(arg, deep, fraction))
      together_add_terms(transformed, fraction)
    }
    Expr::Mul(args) =>
      together_mul_exprs(args.map(arg => together_inner(arg, deep, fraction)))
    Expr::Pow(base, exp) => {
      let new_base = together_inner(base, deep, fraction)
      let new_exp = if deep { together_inner(exp, deep, fraction) } else { exp }
      @symcore.pow(new_base, new_exp)
    }
    Expr::Apply(head, args) =>
      if deep {
        match
          @symcore.apply(
            head,
            args.map(arg => together_inner(arg, deep, fraction)),
          ) {
          Some(value) => value
          None => expr
        }
      } else {
        expr
      }
    Expr::Tuple(items) =>
      Expr::Tuple(items.map(item => together_inner(item, deep, fraction)))
    Expr::Relational(op, lhs, rhs) =>
      Expr::Relational(
        op,
        together_inner(lhs, deep, fraction),
        together_inner(rhs, deep, fraction),
      )
    Expr::Derivative(body, vars) =>
      Expr::Derivative(
        together_inner(body, deep, fraction),
        vars.map(item => together_inner(item, deep, fraction)),
      )
    Expr::Subs(body, variable, value) =>
      Expr::Subs(
        together_inner(body, deep, fraction),
        together_inner(variable, deep, fraction),
        together_inner(value, deep, fraction),
      )
    Expr::Lambda(vars, body) =>
      Expr::Lambda(vars, together_inner(body, deep, fraction))
    _ => expr
  }
}

///|
/// Combine rational subexpressions over common denominators.
///
/// - Does: Denests additive rational terms such as `1/x + 1/y` into a single
///   rational expression.
/// - Input: One `Expr`, plus optional `deep` traversal and `fraction` controls.
/// - Returns: A transformed `Expr`.
/// - Limits: The result is structurally combined but not fully minimized; use
///   polynomial `cancel` front doors when explicit numerator/denominator
///   reduction is required.
pub fn together(
  expr : Expr,
  deep? : Bool = false,
  fraction? : Bool = true,
) -> Expr {
  together_inner(expr, deep, fraction)
}

///|
fn apart_subst_gen(expr : Expr, gen : String, value : Expr) -> Expr {
  let env : Map[String, Expr] = {}
  env[gen] = value
  @symcore.subst(expr, env)
}

///|
fn apart_eval_poly(poly : Poly, value : Expr) -> Expr raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let degree = poly.degree(0)
  let mut acc = int(0)
  for i in 0..<=degree {
    acc = together_add_exprs([
      together_mul_exprs([acc, value]),
      coeff_expr(poly, degree - i),
    ])
  }
  acc
}

///|
fn apart_infer_gen(expr : Expr, gen : String) -> String raise PolyError {
  if gen != "" {
    return gen
  }
  match infer_gens(expr) {
    [name, ..] => name
    [] => raise PolyError::BadGenerator("")
  }
}

///|
fn apart_linear_distinct(
  expr : Expr,
  gen : String,
  full : Bool,
) -> Expr raise PolyError {
  if full {
    return expr
  }
  let combined = together(expr)
  let (num_expr, den_expr) = together_split_fraction(combined)
  if together_expr_is_one(den_expr) {
    return combined
  }
  let den_poly = Poly::from_expr(den_expr, [gen], Domain::QQ)
  let (content, factors) = factor_list(den_poly)
  if factors.is_empty() {
    return combined
  }
  for item in factors {
    if item.1 != 1 || item.0.degree(0) != 1 {
      return combined
    }
  }

  let (poly_part, rem_expr) = match
    (try? Poly::from_expr(num_expr, [gen], Domain::QQ) : Result[Poly, PolyError]) {
    Ok(num_poly) => {
      let (q, r) = div(num_poly, den_poly)
      (q.to_expr(), r.to_expr())
    }
    Err(_) =>
      if @symcore.has(num_expr, Expr::Symbol(gen)) {
        return combined
      } else {
        (int(0), num_expr)
      }
  }

  let terms : Array[Expr] = []
  if !together_expr_is_zero(poly_part) {
    terms.push(poly_part)
  }
  for i in 0..<factors.length() {
    let factor = factors[i].0
    let roots = roots_linear(factor)
    if roots.length() != 1 {
      return combined
    }
    let root = roots[0]
    let mut denom_at_root = Expr::Number(content)
    for j in 0..<factors.length() {
      if i != j {
        denom_at_root = together_mul_exprs([
          denom_at_root,
          apart_eval_poly(factors[j].0, root),
        ])
      }
    }
    let numerator_at_root = apart_subst_gen(rem_expr, gen, root)
    let residue = together_make_fraction(numerator_at_root, denom_at_root)
    terms.push(together_make_fraction(residue, factor.to_expr()))
  }
  together_add_exprs(terms)
}

///|
/// Compute a partial fraction decomposition for simple rational functions.
///
/// - Does: Splits a univariate rational expression over distinct linear
///   denominator factors.
/// - Input: One `Expr`, optional main generator name, and optional `full`.
/// - Returns: A decomposed `Expr`, or the original combined expression when the
///   local front door cannot safely decompose it.
/// - Limits: Repeated factors and Bronstein full decomposition are not yet
///   implemented; irreducible nonlinear factors are left unchanged.
pub fn apart(
  expr : Expr,
  gen? : String = "",
  full? : Bool = false,
) -> Expr raise PolyError {
  let main_gen = apart_infer_gen(expr, gen)
  apart_linear_distinct(expr, main_gen, full)
}

///|
/// Return a structured partial-fraction decomposition.
///
/// - Does: Decomposes with `apart`, then separates polynomial and proper
///   rational terms.
/// - Input: One `Expr`, optional main generator name, and optional `full`.
/// - Returns: `ApartList`.
/// - Limits: Uses the same decomposition coverage as `apart`; the structure is
///   typed for MoonBit rather than matching Python's dynamic tuple exactly.
pub fn apart_list(
  expr : Expr,
  gen? : String = "",
  full? : Bool = false,
) -> ApartList raise PolyError {
  let decomposed = apart(expr, gen~, full~)
  let pieces = match decomposed {
    Expr::Add(args) => args
    _ => [decomposed]
  }
  let polynomial_terms : Array[Expr] = []
  let proper_terms : Array[ApartTerm] = []
  for piece in pieces {
    let (num, den) = together_split_fraction(piece)
    if together_expr_is_one(den) {
      polynomial_terms.push(num)
    } else {
      proper_terms.push(ApartTerm::{
        numerator: num,
        denominator: den,
        exponent: 1,
      })
    }
  }
  ApartList::{
    common: int(1),
    polynomial: together_add_exprs(polynomial_terms),
    terms: proper_terms,
  }
}

///|
/// Assemble a structured partial-fraction decomposition.
///
/// - Does: Rebuilds an expression from `ApartList`.
/// - Input: One `ApartList`.
/// - Returns: An `Expr` equivalent to the represented decomposition.
/// - Limits: Only the typed `ApartList` representation is accepted.
pub fn assemble_partfrac_list(decomposition : ApartList) -> Expr {
  let terms : Array[Expr] = [decomposition.polynomial]
  for term in decomposition.terms {
    terms.push(
      together_make_fraction(
        term.numerator,
        together_pow_int(term.denominator, term.exponent),
      ),
    )
  }
  together_mul_exprs([decomposition.common, together_add_exprs(terms)])
}
