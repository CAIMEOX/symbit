///|
/// Symbolic root extraction for univariate polynomials.
///
/// Current Limits:
/// - Closed-form radicals are only exposed through degree `4`.
/// - Higher-degree irreducible factors fall back to symbolic `CRootOf`.

///|
/// Solve a linear univariate polynomial.
///
/// - Does: Returns the unique root of `a*x + b`.
/// - Input: One univariate degree-`1` `Poly`.
/// - Returns: `Array[Expr]` with one entry.
/// - Limits: Raises `PolyError::BadExponent` when the input degree is not `1`.
fn ensure_univar(poly : Poly) -> Unit raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
}

///|
fn coeff_expr(poly : Poly, exp : Int) -> Expr raise PolyError {
  let mono = monomial_one(1)
  mono.exps.set(0, exp)
  match poly.coeffs.get(mono) {
    Some(c) => field_elem_to_expr(c, poly.domain)
    None => int(0)
  }
}

///|
fn sqrt_bigint_if_square(value : BigInt) -> BigInt? {
  if value.op_lt(0N) {
    return None
  }
  let root = @symnum.isqrt(value) catch { _ => return None }
  if root.mul(root).compare(value) == 0 {
    Some(root)
  } else {
    None
  }
}

///|
fn sqrt_rational_expr(value : @symnum.BigRational) -> Expr? {
  if value.is_zero() {
    return Some(int(0))
  }
  let negative = value.compare(@symnum.BigRational::zero()) < 0
  let abs_value = if negative { value.neg_r() } else { value }
  let num_root = match sqrt_bigint_if_square(abs_value.numerator()) {
    Some(root) => root
    None => return None
  }
  let den_root = match sqrt_bigint_if_square(abs_value.denominator()) {
    Some(root) => root
    None => return None
  }
  let rat = @symnum.BigRational::new(num_root, den_root) catch {
    _ => return None
  }
  let base = Expr::Number(rat)
  if negative {
    let imag = @symcore.Expr::NumberSymbol(
      @symcore.NumberSymbolKind::ImaginaryUnit,
    )
    Some(@symcore.mul([base, imag]))
  } else {
    Some(base)
  }
}

///|
fn quadratic_sqrt(expr : Expr) -> Expr {
  match expr {
    Expr::Number(n) =>
      match sqrt_rational_expr(n) {
        Some(value) => value
        None => @symcore.function("sqrt", [expr])
      }
    _ => @symcore.function("sqrt", [expr])
  }
}

///|
/// Solve a linear univariate polynomial.
///
/// - Does: Returns the unique root of `a*x + b`.
/// - Input: One univariate degree-`1` `Poly`.
/// - Returns: `Array[Expr]` with one entry.
/// - Limits: Raises `PolyError::BadExponent` when the input degree is not `1`.
pub fn roots_linear(poly : Poly) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 1 {
    raise PolyError::BadExponent
  }
  let a = coeff_expr(poly, 1)
  let b = coeff_expr(poly, 0)
  let neg_b = @symcore.mul([int(-1), b])
  let denom = a
  let inv = @symcore.pow(denom, int(-1))
  let root = @symcore.mul([neg_b, inv])
  [root]
}

///|
/// Solve a quadratic univariate polynomial.
///
/// - Does: Applies the quadratic formula with exact symbolic square-root nodes.
/// - Input: One univariate degree-`2` `Poly`.
/// - Returns: `Array[Expr]` with two roots, including multiplicities implied by
///   the formula branch.
/// - Limits: Raises `PolyError::BadExponent` when the input degree is not `2`.
pub fn roots_quadratic(poly : Poly) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 2 {
    raise PolyError::BadExponent
  }
  let a = coeff_expr(poly, 2)
  let b = coeff_expr(poly, 1)
  let c = coeff_expr(poly, 0)
  if @symcore.is_zero(c) {
    let other = @symcore.mul([
      @symcore.mul([int(-1), b]),
      @symcore.pow(a, int(-1)),
    ])
    return [int(0), other]
  }
  if @symcore.is_zero(b) {
    let r = @symcore.mul([int(-1), c, @symcore.pow(a, int(-1))])
    let root = quadratic_sqrt(r)
    return [@symcore.mul([int(-1), root]), root]
  }
  let four = int(4)
  let two = int(2)
  let b2 = b ^ int(2)
  let ac4 = @symcore.mul([four, a, c])
  let disc = @symcore.add([b2, @symcore.mul([int(-1), ac4])])
  // SymPy reference: sympy/polys/polyroots.py::roots_quadratic.
  // Keep discriminant under symbolic square root (disc**(1/2)).
  let sqrt_disc = quadratic_sqrt(disc)
  let neg_b = @symcore.mul([int(-1), b])
  let inv = @symcore.pow(@symcore.mul([two, a]), int(-1))
  let r1 = @symcore.mul([
    @symcore.add([neg_b, @symcore.mul([int(-1), sqrt_disc])]),
    inv,
  ])
  let r2 = @symcore.mul([@symcore.add([neg_b, sqrt_disc]), inv])
  [r1, r2]
}

///|
fn append_roots(out : Array[Expr], roots : Array[Expr], mult : Int) -> Unit {
  for _ in 0..<mult {
    for r in roots {
      out.push(r)
    }
  }
}

///|
fn rootof_expr(poly : Poly, index : Int) -> Expr {
  @symcore.function("CRootOf", [poly.to_expr(), int(index)])
}

///|
/// Solve a cubic univariate polynomial.
///
/// - Does: Factors the polynomial and combines low-degree formulas with
///   `CRootOf` fallback for irreducible cubic factors.
/// - Input: One univariate degree-`3` `Poly`.
/// - Returns: `Array[Expr]`.
/// - Limits: Raises `PolyError::BadExponent` when the input degree is not `3`.
pub fn roots_cubic(poly : Poly) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 3 {
    raise PolyError::BadExponent
  }
  let (_, factors) = poly.factor_list()
  let roots : Array[Expr] = Array::new()
  for pair in factors {
    let (f, mult) = pair
    let fdeg = f.degree(0)
    if fdeg == 1 {
      append_roots(roots, roots_linear(f), mult)
    } else if fdeg == 2 {
      append_roots(roots, roots_quadratic(f), mult)
    } else {
      let ros : Array[Expr] = Array::new()
      for i in 0..<fdeg {
        ros.push(rootof_expr(f, i))
      }
      append_roots(roots, ros, mult)
    }
  }
  roots
}

///|
/// Solve a quartic univariate polynomial.
///
/// - Does: Factors the polynomial and combines low-degree formulas with
///   `CRootOf` fallback for irreducible quartic factors.
/// - Input: One univariate degree-`4` `Poly`.
/// - Returns: `Array[Expr]`.
/// - Limits: Raises `PolyError::BadExponent` when the input degree is not `4`.
pub fn roots_quartic(poly : Poly) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 4 {
    raise PolyError::BadExponent
  }
  let (_, factors) = poly.factor_list()
  let roots : Array[Expr] = Array::new()
  for pair in factors {
    let (f, mult) = pair
    let fdeg = f.degree(0)
    if fdeg == 1 {
      append_roots(roots, roots_linear(f), mult)
    } else if fdeg == 2 {
      append_roots(roots, roots_quadratic(f), mult)
    } else {
      let ros : Array[Expr] = Array::new()
      for i in 0..<fdeg {
        ros.push(rootof_expr(f, i))
      }
      append_roots(roots, ros, mult)
    }
  }
  roots
}

///|
fn roots_for_factor(
  poly : Poly,
  radicals : Bool,
) -> Array[Expr] raise PolyError {
  let deg = poly.degree(0)
  if deg <= 0 {
    return []
  }
  if deg == 1 {
    return roots_linear(poly)
  }
  if deg == 2 {
    return roots_quadratic(poly)
  }
  if radicals && deg == 3 {
    return roots_cubic(poly)
  }
  if radicals && deg == 4 {
    return roots_quartic(poly)
  }
  let roots : Array[Expr] = Array::new()
  for i in 0..<deg {
    roots.push(rootof_expr(poly, i))
  }
  roots
}

///|
/// Extract symbolic roots from a univariate polynomial.
///
/// - Does: Factors the polynomial, expands multiplicities, uses closed-form
///   formulas through degree `4` when enabled, and falls back to `CRootOf`
///   otherwise.
/// - Input: One univariate `Poly` and optional `radicals` toggle.
/// - Returns: `Array[Expr]`.
/// - Limits: Zero input returns `[]`, and higher-degree irreducible factors are
///   represented symbolically rather than numerically.
///
/// ```mbt check
/// test "sympolys roots returns the unique linear root" {
///   let x = @symcore.Expr::Symbol("x")
///   let poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(x - @symcore.int(1))
///   let rs = roots(poly)
///   inspect(rs.length(), content="1")
///   inspect(@symprint.pretty_string(rs[0]), content="1")
/// }
/// ```
pub fn roots(
  poly : Poly,
  radicals? : Bool = true,
) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  if poly.is_zero() {
    return []
  }
  let (_, factors) = poly.factor_list()
  let roots : Array[Expr] = Array::new()
  for pair in factors {
    let (f, mult) = pair
    let f_roots = roots_for_factor(f, radicals)
    append_roots(roots, f_roots, mult)
  }
  roots
}

///|
/// Return linear factors built from the symbolic roots of a polynomial.
///
/// - Does: Builds `x - r` for each ordered symbolic root `r`.
/// - Input: One univariate `Poly` and optional `radicals` toggle.
/// - Returns: `Array[Expr]` containing factor expressions.
/// - Limits: The current front door returns expressions only; it does not
///   expose Python's `filter` option or preserve `Poly` objects in the result.
pub fn root_factors(
  poly : Poly,
  radicals? : Bool = true,
) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  if poly.is_zero() {
    return [poly.to_expr()]
  }
  let x = Expr::Symbol(poly.gens[0])
  let factors : Array[Expr] = []
  let rs = roots(poly, radicals~)
  if rs.is_empty() {
    return [poly.to_expr()]
  }
  // SymPy reference: polyroots.root_factors orders zeros before building factors.
  rs.sort_by(@symcore.compare_expr)
  for root in rs {
    factors.push(x - root)
  }
  factors
}
