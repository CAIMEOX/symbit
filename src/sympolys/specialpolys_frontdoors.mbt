///|
/// Special polynomial front doors ported from `sympy.polys.specialpolys`.
///
/// Current Limits:
/// - These front doors return expression values, matching the default symbolic
///   source behavior. Use `poly_from_expr` when a `Poly` value is needed.
/// - `random_poly` uses an explicit deterministic seed. This avoids hidden
///   process-global RNG state while preserving the coefficient-range contract.

///|
/// Generate a cyclotomic polynomial.
///
/// - Does: Builds the `n`-th cyclotomic polynomial in the selected generator.
/// - Input: Positive integer `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` for non-positive `n`.
pub fn cyclotomic_poly(n : Int, gen? : String = "x") -> Expr raise PolyError {
  cyclotomic_poly_domain(n, gen).to_expr()
}

///|
/// Generate a Swinnerton-Dyer polynomial.
///
/// - Does: Builds the minimal polynomial of the sum of the first `n` square
///   roots of primes.
/// - Input: Positive integer `n` and optional generator name.
/// - Returns: An exact expression.
/// - Limits: Resultant-based construction grows exponentially in degree.
pub fn swinnerton_dyer_poly(
  n : Int,
  gen? : String = "x",
) -> Expr raise PolyError {
  if n <= 0 {
    raise BadExponent
  }
  let x = Expr::Symbol(gen)
  let mut poly = Poly::from_expr((x ^ int(2)) - int(2), [gen], ZZ)
  let mut prime = 2
  for i in 2..<=n {
    prime = next_prime_int(prime)
    let z_name = "__sd_z\{i}"
    let z = Expr::Symbol(z_name)
    let old_expr = expr_replace_symbol(poly.to_expr(), gen, z_name)
    let f = Poly::from_expr(old_expr, [z_name, gen], QQ)
    let relation = ((x - z) ^ int(2)) - int(prime)
    let g = Poly::from_expr(relation, [z_name, gen], QQ)
    let res = resultant_elim_poly(f, g, 0)
    poly = try_round_to_int(res) catch { _ => res }
  }
  poly.to_expr()
}

///|
/// Generate an elementary symmetric polynomial.
///
/// - Does: Sums all products of `n` distinct generators.
/// - Input: An order `n` and a non-empty generator array.
/// - Returns: An exact expression.
/// - Limits: Raises `PolyError::BadExponent` when `n` is outside
///   `0..=gens.length()`.
pub fn symmetric_poly(n : Int, gens : Array[Expr]) -> Expr raise PolyError {
  if gens.is_empty() || n < 0 || n > gens.length() {
    raise BadExponent
  }
  if n == 0 {
    return int(1)
  }
  let terms : Array[Expr] = []
  let chosen : Array[Expr] = []
  symmetric_poly_fill(gens, n, 0, chosen, terms)
  expr_add_all(terms)
}

///|
/// Generate a deterministic pseudo-random polynomial.
///
/// - Does: Builds a degree-`n` univariate polynomial with coefficients in
///   `[inf, sup]` and a nonzero leading coefficient.
/// - Input: Generator name, degree, coefficient bounds, optional domain, and
///   explicit seed.
/// - Returns: An exact expression, matching SymPy's default non-`polys` mode.
/// - Limits: Python's process-global random state and `polys=True` dynamic
///   return type are not modeled; use `poly_from_expr` for a `Poly`.
pub fn random_poly(
  gen : String,
  n : Int,
  inf : Int,
  sup : Int,
  domain? : Domain = ZZ,
  seed? : Int = 1,
) -> Expr raise PolyError {
  if n < 0 {
    raise BadExponent
  }
  let span = sup - inf + 1
  if span <= 0 || (inf == 0 && sup == 0) {
    raise DomainMismatch
  }
  let coeffs : Array[FieldElem] = []
  let mut state = seed
  for i in 0..<=n {
    let mut value = 0
    let mut found = false
    while !found {
      state = lcg_next(state, 2147483647)
      value = inf + state % span
      found = i != n || value != 0
    }
    coeffs.push(fe_from_int(value, domain))
  }
  from_dense(coeffs, [gen], domain).to_expr()
}

///|
/// Construct a formal Lagrange interpolation polynomial.
///
/// - Does: Builds `sum_i y_i * prod_{j != i}(x - x_j)/(x_i - x_j)`.
/// - Input: Number of points, interpolation variable, and optional `x_i`/`y_i`
///   value arrays.
/// - Returns: An exact expression.
/// - Limits: Optional value arrays must contain at least `n` entries; duplicate
///   x-values are not detected before symbolic construction.
pub fn interpolating_poly(
  n : Int,
  x : Expr,
  xs? : Array[Expr],
  ys? : Array[Expr],
) -> Expr raise PolyError {
  if n < 0 {
    raise BadExponent
  }
  let x_values = match xs {
    Some(values) => {
      if values.length() < n {
        raise DomainMismatch
      }
      values
    }
    None => default_symbol_array("x", n)
  }
  let y_values = match ys {
    Some(values) => {
      if values.length() < n {
        raise DomainMismatch
      }
      values
    }
    None => default_symbol_array("y", n)
  }
  let terms : Array[Expr] = []
  for i in 0..<n {
    let numer_factors : Array[Expr] = []
    let denom_factors : Array[Expr] = []
    for j in 0..<n {
      if i == j {
        continue
      }
      numer_factors.push(x - x_values[j])
      denom_factors.push(x_values[i] - x_values[j])
    }
    let numer = if numer_factors.is_empty() {
      int(1)
    } else {
      expr_mul_all(numer_factors)
    }
    let denom = if denom_factors.is_empty() {
      int(1)
    } else {
      expr_mul_all(denom_factors)
    }
    terms.push(y_values[i] * numer * (denom ^ int(-1)))
  }
  if terms.is_empty() {
    int(0)
  } else {
    expr_add_all(terms)
  }
}

///|
/// Fateman GCD benchmark family F1.
///
/// - Does: Builds the trivial-GCD Fateman benchmark triple `(F, G, H)`.
/// - Input: Variable count marker `n`.
/// - Returns: Three `Poly` values over `ZZ` in generators `y_0..y_n`.
/// - Limits: Requires `n >= 1`.
pub fn fateman_poly_F_1(n : Int) -> (Poly, Poly, Poly) raise PolyError {
  let (gens, y) = fateman_generators(n)
  let y0 = y[0]
  let y1 = y[1]
  let u = y0 + expr_add_all(fateman_tail(y))
  let sq_terms : Array[Expr] = []
  for i in 1..<y.length() {
    sq_terms.push(y[i] ^ int(2))
  }
  let v = (y0 ^ int(2)) + expr_add_all(sq_terms)
  let f = Poly::from_expr((u + int(1)) * (u + int(2)), gens, ZZ)
  let g = Poly::from_expr(
    (v + int(1)) * (int(-3) * y1 * (y0 ^ int(2)) + (y1 ^ int(2)) - int(1)),
    gens,
    ZZ,
  )
  let h = Poly::one(gens, ZZ)
  (f, g, h)
}

///|
/// Fateman GCD benchmark family F2.
///
/// - Does: Builds the linearly dense quartic Fateman benchmark triple.
/// - Input: Variable count marker `n`.
/// - Returns: Three `Poly` values over `ZZ` in generators `y_0..y_n`.
/// - Limits: Requires `n >= 1`.
pub fn fateman_poly_F_2(n : Int) -> (Poly, Poly, Poly) raise PolyError {
  let (gens, y) = fateman_generators(n)
  let y0 = y[0]
  let u = expr_add_all(fateman_tail(y))
  let h_expr = (y0 + u + int(1)) ^ int(2)
  let f_expr = (y0 - u - int(2)) ^ int(2)
  let g_expr = (y0 + u + int(2)) ^ int(2)
  let h = Poly::from_expr(h_expr, gens, ZZ)
  let f = Poly::from_expr(h_expr * f_expr, gens, ZZ)
  let g = Poly::from_expr(h_expr * g_expr, gens, ZZ)
  (f, g, h)
}

///|
/// Fateman GCD benchmark family F3.
///
/// - Does: Builds the sparse high-degree Fateman benchmark triple.
/// - Input: Variable count marker `n`.
/// - Returns: Three `Poly` values over `ZZ` in generators `y_0..y_n`.
/// - Limits: Requires `n >= 1`; expression expansion grows quickly.
pub fn fateman_poly_F_3(n : Int) -> (Poly, Poly, Poly) raise PolyError {
  let (gens, y) = fateman_generators(n)
  let y0 = y[0]
  let exp = n + 1
  let terms : Array[Expr] = []
  for i in 1..<y.length() {
    terms.push(y[i] ^ int(exp))
  }
  let u = expr_add_all(terms)
  let y0p = y0 ^ int(exp)
  let h_expr = (y0p + u + int(1)) ^ int(2)
  let f_expr = (y0p - u - int(2)) ^ int(2)
  let g_expr = (y0p + u + int(2)) ^ int(2)
  let h = Poly::from_expr(h_expr, gens, ZZ)
  let f = Poly::from_expr(h_expr * f_expr, gens, ZZ)
  let g = Poly::from_expr(h_expr * g_expr, gens, ZZ)
  (f, g, h)
}

///|
fn specialpoly_convert_coeff(
  coeff : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  fe_from_rational(fe_expect_rational(coeff), domain)
}

///|
fn specialpoly_to_dmp(
  poly : Poly,
  domain : Domain,
) -> DensePoly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map([])
  for monom, coeff in poly.coeffs {
    coeffs[monom] = specialpoly_convert_coeff(coeff, domain)
  }
  dmp_from_dict(coeffs, poly.gens.length() - 1, domain)
}

///|
fn specialpoly_dmp_tuple(
  triple : (Poly, Poly, Poly),
  domain : Domain,
) -> (DensePoly, DensePoly, DensePoly) raise PolyError {
  (
    specialpoly_to_dmp(triple.0, domain),
    specialpoly_to_dmp(triple.1, domain),
    specialpoly_to_dmp(triple.2, domain),
  )
}

///|
/// Fateman GCD benchmark family F1 in recursive dense representation.
///
/// - Does: Builds the same trivial-GCD Fateman benchmark as
///   `fateman_poly_F_1`, returned as `DensePoly` values.
/// - Input: Variable count marker `n` and a coefficient domain.
/// - Returns: Three recursive dense polynomials.
/// - Limits: Requires `n >= 1`; coefficients must be rationally convertible to
///   the requested domain.
pub fn dmp_fateman_poly_F_1(
  n : Int,
  domain : Domain,
) -> (DensePoly, DensePoly, DensePoly) raise PolyError {
  specialpoly_dmp_tuple(fateman_poly_F_1(n), domain)
}

///|
/// Fateman GCD benchmark family F2 in recursive dense representation.
///
/// - Does: Builds the linearly dense quartic Fateman benchmark as `DensePoly`
///   values.
/// - Input: Variable count marker `n` and a coefficient domain.
/// - Returns: Three recursive dense polynomials.
/// - Limits: Requires `n >= 1`; coefficients must be rationally convertible to
///   the requested domain.
pub fn dmp_fateman_poly_F_2(
  n : Int,
  domain : Domain,
) -> (DensePoly, DensePoly, DensePoly) raise PolyError {
  specialpoly_dmp_tuple(fateman_poly_F_2(n), domain)
}

///|
/// Fateman GCD benchmark family F3 in recursive dense representation.
///
/// - Does: Builds the sparse high-degree Fateman benchmark as `DensePoly`
///   values.
/// - Input: Variable count marker `n` and a coefficient domain.
/// - Returns: Three recursive dense polynomials.
/// - Limits: Requires `n >= 1`; expression expansion grows quickly.
pub fn dmp_fateman_poly_F_3(
  n : Int,
  domain : Domain,
) -> (DensePoly, DensePoly, DensePoly) raise PolyError {
  specialpoly_dmp_tuple(fateman_poly_F_3(n), domain)
}

///|
fn special_poly_from_terms(
  gens : Array[String],
  terms : Array[(Int, Array[Int])],
) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map([])
  for term in terms {
    let (coeff, exps) = term
    if exps.length() != gens.length() {
      raise DomainMismatch
    }
    if coeff != 0 {
      coeffs[{ exps, }] = fe_from_int(coeff, ZZ)
    }
  }
  { coeffs, gens, domain: ZZ, order: Lex }
}

///|
fn special_f_0() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z"], [
    (1, [2, 1, 2]),
    (2, [2, 1, 1]),
    (3, [2, 1, 0]),
    (2, [2, 0, 0]),
    (3, [1, 0, 0]),
    (4, [0, 2, 2]),
    (5, [0, 2, 1]),
    (6, [0, 2, 0]),
    (1, [0, 1, 2]),
    (2, [0, 1, 1]),
    (1, [0, 1, 0]),
    (1, [0, 0, 0]),
  ])
}

///|
fn special_f_1() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z"], [
    (1, [3, 1, 1]),
    (1, [2, 2, 2]),
    (1, [2, 2, 0]),
    (20, [2, 1, 1]),
    (30, [2, 1, 0]),
    (1, [2, 0, 2]),
    (10, [2, 0, 1]),
    (1, [1, 3, 1]),
    (30, [1, 2, 1]),
    (20, [1, 2, 0]),
    (1, [1, 1, 3]),
    (10, [1, 1, 2]),
    (1, [1, 1, 1]),
    (610, [1, 1, 0]),
    (20, [1, 0, 2]),
    (230, [1, 0, 1]),
    (300, [1, 0, 0]),
    (1, [0, 2, 2]),
    (10, [0, 2, 1]),
    (30, [0, 1, 2]),
    (320, [0, 1, 1]),
    (200, [0, 1, 0]),
    (600, [0, 0, 1]),
    (6000, [0, 0, 0]),
  ])
}

///|
fn special_f_2() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z"], [
    (1, [5, 3, 0]),
    (1, [5, 2, 1]),
    (1, [5, 1, 2]),
    (1, [5, 0, 3]),
    (1, [3, 2, 0]),
    (1, [3, 1, 1]),
    (90, [3, 1, 0]),
    (90, [3, 0, 1]),
    (1, [2, 2, 1]),
    (-11, [2, 2, 0]),
    (1, [2, 0, 3]),
    (-11, [2, 0, 2]),
    (1, [0, 1, 1]),
    (-11, [0, 1, 0]),
    (90, [0, 0, 1]),
    (-990, [0, 0, 0]),
  ])
}

///|
fn special_f_3() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z"], [
    (1, [5, 2, 0]),
    (1, [4, 0, 4]),
    (1, [4, 0, 0]),
    (1, [3, 3, 1]),
    (1, [3, 0, 1]),
    (1, [2, 4, 0]),
    (1, [2, 3, 3]),
    (1, [2, 1, 5]),
    (1, [2, 1, 1]),
    (1, [1, 2, 4]),
    (1, [1, 2, 0]),
    (1, [1, 1, 7]),
    (1, [1, 1, 3]),
    (1, [1, 1, 2]),
    (1, [0, 2, 1]),
    (1, [0, 1, 4]),
  ])
}

///|
fn special_f_4() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z"], [
    (-1, [9, 8, 1]),
    (-1, [8, 5, 3]),
    (-1, [7, 12, 2]),
    (-5, [7, 8, 0]),
    (-1, [6, 9, 4]),
    (1, [6, 7, 3]),
    (3, [6, 7, 1]),
    (-5, [6, 5, 2]),
    (-1, [6, 4, 3]),
    (1, [5, 4, 5]),
    (3, [5, 4, 3]),
    (-1, [5, 1, 5]),
    (1, [4, 11, 4]),
    (3, [4, 11, 2]),
    (-1, [4, 8, 4]),
    (5, [4, 7, 2]),
    (15, [4, 7, 0]),
    (-5, [4, 4, 2]),
    (1, [3, 8, 6]),
    (3, [3, 8, 4]),
    (-1, [3, 5, 6]),
    (5, [3, 4, 4]),
    (15, [3, 4, 2]),
    (1, [3, 3, 5]),
    (3, [3, 3, 3]),
    (-5, [3, 1, 4]),
    (1, [2, 0, 7]),
    (3, [2, 0, 5]),
    (1, [1, 7, 6]),
    (3, [1, 7, 4]),
    (5, [1, 3, 4]),
    (15, [1, 3, 2]),
    (1, [0, 4, 8]),
    (3, [0, 4, 6]),
    (5, [0, 0, 6]),
    (15, [0, 0, 4]),
  ])
}

///|
fn special_f_5() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z"], [
    (-1, [3, 0, 0]),
    (-3, [2, 1, 0]),
    (3, [2, 0, 1]),
    (-3, [1, 2, 0]),
    (6, [1, 1, 1]),
    (-3, [1, 0, 2]),
    (-1, [0, 3, 0]),
    (3, [0, 2, 1]),
    (-3, [0, 1, 2]),
    (1, [0, 0, 3]),
  ])
}

///|
fn special_f_6() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z", "t"], [
    (2115, [4, 1, 0, 0]),
    (45, [3, 0, 3, 2]),
    (-45, [3, 0, 0, 2]),
    (-423, [1, 4, 0, 0]),
    (-47, [1, 3, 0, 0]),
    (141, [1, 1, 3, 0]),
    (94, [1, 1, 1, 1]),
    (-9, [0, 3, 3, 2]),
    (9, [0, 3, 0, 2]),
    (-1, [0, 2, 3, 2]),
    (1, [0, 2, 0, 2]),
    (3, [0, 0, 6, 2]),
    (2, [0, 0, 4, 3]),
    (-3, [0, 0, 3, 2]),
    (-2, [0, 0, 1, 3]),
  ])
}

///|
fn special_w_1() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y", "z"], [
    (4, [6, 4, 2]),
    (4, [6, 3, 3]),
    (-4, [6, 2, 4]),
    (-4, [6, 1, 5]),
    (1, [5, 4, 3]),
    (12, [5, 3, 1]),
    (-1, [5, 2, 5]),
    (12, [5, 2, 2]),
    (-12, [5, 1, 3]),
    (-12, [5, 0, 4]),
    (8, [4, 4, 0]),
    (6, [4, 3, 2]),
    (8, [4, 3, 1]),
    (-4, [4, 2, 4]),
    (4, [4, 2, 3]),
    (-8, [4, 2, 2]),
    (-4, [4, 1, 5]),
    (-2, [4, 1, 4]),
    (-8, [4, 1, 3]),
    (2, [3, 4, 1]),
    (1, [3, 3, 3]),
    (-1, [3, 2, 5]),
    (-2, [3, 2, 3]),
    (9, [3, 2, 1]),
    (-12, [3, 1, 3]),
    (12, [3, 1, 2]),
    (-12, [3, 0, 4]),
    (3, [3, 0, 3]),
    (6, [2, 3, 0]),
    (-6, [2, 2, 2]),
    (8, [2, 2, 1]),
    (-2, [2, 1, 4]),
    (-8, [2, 1, 3]),
    (2, [2, 1, 2]),
    (2, [1, 3, 1]),
    (-2, [1, 2, 3]),
    (-3, [1, 1, 1]),
    (3, [1, 0, 3]),
    (-2, [0, 2, 0]),
    (2, [0, 1, 2]),
  ])
}

///|
fn special_w_2() -> Poly raise PolyError {
  special_poly_from_terms(["x", "y"], [
    (24, [8, 3]),
    (48, [8, 2]),
    (24, [7, 5]),
    (-72, [7, 2]),
    (25, [6, 4]),
    (2, [6, 3]),
    (4, [6, 1]),
    (8, [6, 0]),
    (1, [5, 6]),
    (1, [5, 3]),
    (-12, [5, 0]),
    (1, [4, 5]),
    (-1, [4, 4]),
    (-2, [4, 3]),
    (292, [4, 2]),
    (-1, [3, 6]),
    (3, [3, 3]),
    (-1, [2, 5]),
    (12, [2, 3]),
    (48, [2, 0]),
    (-12, [0, 3]),
  ])
}

///|
/// Return Wang's seven benchmark `f` polynomials.
///
/// - Does: Builds the benchmark tuple from Wang's polynomial GCD examples.
/// - Input: No arguments.
/// - Returns: Seven `Poly` values over `ZZ`.
/// - Limits: Returns Symbit `Poly` values rather than SymPy ring elements.
pub fn f_polys() -> Array[Poly] raise PolyError {
  [
    special_f_0(),
    special_f_1(),
    special_f_2(),
    special_f_3(),
    special_f_4(),
    special_f_5(),
    special_f_6(),
  ]
}

///|
/// Return Wang's two benchmark `w` polynomials.
///
/// - Does: Builds the benchmark tuple from Wang's polynomial GCD examples.
/// - Input: No arguments.
/// - Returns: Two `Poly` values over `ZZ`.
/// - Limits: Returns Symbit `Poly` values rather than SymPy ring elements.
pub fn w_polys() -> Array[Poly] raise PolyError {
  [special_w_1(), special_w_2()]
}

///|
fn symmetric_poly_fill(
  gens : Array[Expr],
  target : Int,
  start : Int,
  chosen : Array[Expr],
  terms : Array[Expr],
) -> Unit {
  if chosen.length() == target {
    terms.push(expr_mul_all(chosen))
    return
  }
  let need = target - chosen.length()
  let last = gens.length() - need
  for i in start..<=last {
    chosen.push(gens[i])
    symmetric_poly_fill(gens, target, i + 1, chosen, terms)
    let _ = chosen.pop()
  }
}

///|
fn fateman_generators(n : Int) -> (Array[String], Array[Expr]) raise PolyError {
  if n < 1 {
    raise BadExponent
  }
  let gens : Array[String] = []
  let exprs : Array[Expr] = []
  for i in 0..<=n {
    let name = "y_\{i}"
    gens.push(name)
    exprs.push(Symbol(name))
  }
  (gens, exprs)
}

///|
fn fateman_tail(y : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for i in 1..<y.length() {
    out.push(y[i])
  }
  out
}

///|
fn default_symbol_array(prefix : String, n : Int) -> Array[Expr] {
  Array::makei(n, i => Symbol("\{prefix}\{i}"))
}

///|
fn next_prime_int(n : Int) -> Int {
  let mut candidate = n + 1
  while !is_prime_int(candidate) {
    candidate += 1
  }
  candidate
}

///|
fn is_prime_int(n : Int) -> Bool {
  if n < 2 {
    return false
  }
  if n == 2 {
    return true
  }
  if n % 2 == 0 {
    return false
  }
  let mut d = 3
  while d * d <= n {
    if n % d == 0 {
      return false
    }
    d += 2
  }
  true
}
