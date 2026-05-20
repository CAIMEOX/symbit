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
    raise PolyError::BadExponent
  }
  let x = Expr::Symbol(gen)
  let mut poly = Poly::from_expr((x ^ int(2)) - int(2), [gen], Domain::ZZ)
  let mut prime = 2
  for i in 2..<=n {
    prime = next_prime_int(prime)
    let z_name = "__sd_z\{i}"
    let z = Expr::Symbol(z_name)
    let old_expr = expr_replace_symbol(poly.to_expr(), gen, z_name)
    let f = Poly::from_expr(old_expr, [z_name, gen], Domain::QQ)
    let relation = ((x - z) ^ int(2)) - int(prime)
    let g = Poly::from_expr(relation, [z_name, gen], Domain::QQ)
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
    raise PolyError::BadExponent
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
  domain? : Domain = Domain::ZZ,
  seed? : Int = 1,
) -> Expr raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  let span = sup - inf + 1
  if span <= 0 || (inf == 0 && sup == 0) {
    raise PolyError::DomainMismatch
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
    raise PolyError::BadExponent
  }
  let x_values = match xs {
    Some(values) => {
      if values.length() < n {
        raise PolyError::DomainMismatch
      }
      values
    }
    None => default_symbol_array("x", n)
  }
  let y_values = match ys {
    Some(values) => {
      if values.length() < n {
        raise PolyError::DomainMismatch
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
  let f = Poly::from_expr((u + int(1)) * (u + int(2)), gens, Domain::ZZ)
  let g = Poly::from_expr(
    (v + int(1)) * (int(-3) * y1 * (y0 ^ int(2)) + (y1 ^ int(2)) - int(1)),
    gens,
    Domain::ZZ,
  )
  let h = Poly::one(gens, Domain::ZZ)
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
  let h = Poly::from_expr(h_expr, gens, Domain::ZZ)
  let f = Poly::from_expr(h_expr * f_expr, gens, Domain::ZZ)
  let g = Poly::from_expr(h_expr * g_expr, gens, Domain::ZZ)
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
  let h = Poly::from_expr(h_expr, gens, Domain::ZZ)
  let f = Poly::from_expr(h_expr * f_expr, gens, Domain::ZZ)
  let g = Poly::from_expr(h_expr * g_expr, gens, Domain::ZZ)
  (f, g, h)
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
    raise PolyError::BadExponent
  }
  let gens : Array[String] = []
  let exprs : Array[Expr] = []
  for i in 0..<=n {
    let name = "y_\{i}"
    gens.push(name)
    exprs.push(Expr::Symbol(name))
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
  Array::makei(n, i => Expr::Symbol("\{prefix}\{i}"))
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
