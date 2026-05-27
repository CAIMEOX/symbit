///|
/// Symbolic root extraction for univariate polynomials.
///
/// Current Limits:
/// - General closed-form radicals are exposed through degree `4`.
/// - `roots_quintic` covers the solvable irreducible binomial quintic path.
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
fn coeff_fe(poly : Poly, exp : Int) -> FieldElem raise PolyError {
  let mono = monomial_one(1)
  mono.exps.set(0, exp)
  match poly.coeffs.get(mono) {
    Some(c) => c
    None => fe_from_int(0, poly.domain)
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
fn polyroots_rational_expr(num : Int, den : Int) -> Expr raise PolyError {
  @symcore.rational_from_ints(num, den) catch {
    _ => raise PolyError::DivisionByZero
  }
}

///|
fn bigint_pow_int(base : BigInt, exp : Int) -> BigInt {
  let mut result = 1N
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result.mul(b)
    }
    e = e / 2
    if e > 0 {
      b = b.mul(b)
    }
  }
  result
}

///|
fn bigint_nth_root_exact(value : BigInt, n : Int) -> BigInt? {
  if n <= 0 || value.op_lt(0N) {
    return None
  }
  if value.compare(0N) == 0 {
    return Some(0N)
  }
  let high_bits = (value.bit_length() + n - 1) / n
  let mut low = 0N
  let mut high = 1N << high_bits
  while low.compare(high) <= 0 {
    let mid = (low + high).div(2N)
    let powered = bigint_pow_int(mid, n)
    let cmp = powered.compare(value)
    if cmp == 0 {
      return Some(mid)
    } else if cmp < 0 {
      low = mid + 1N
    } else {
      high = mid - 1N
    }
  }
  None
}

///|
fn positive_rational_nth_root_expr(
  value : @symnum.BigRational,
  n : Int,
) -> Expr raise PolyError {
  if value.is_zero() {
    return int(0)
  }
  let num_root = bigint_nth_root_exact(value.numerator(), n)
  let den_root = bigint_nth_root_exact(value.denominator(), n)
  match (num_root, den_root) {
    (Some(num), Some(den)) => Expr::Number(poly_rational_from_bigints(num, den))
    _ => @symcore.pow(Expr::Number(value), polyroots_rational_expr(1, n))
  }
}

///|
fn pi_expr() -> Expr {
  Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
}

///|
fn imag_expr() -> Expr {
  Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
}

///|
fn angle_expr(num : Int, den : Int) -> Expr raise PolyError {
  @symcore.mul([polyroots_rational_expr(num, den), pi_expr()])
}

///|
fn zeta_from_angle(
  num : Int,
  den : Int,
  conjugate : Bool,
) -> Expr raise PolyError {
  let theta = angle_expr(num, den)
  let real = @symcore.function("cos", [theta])
  let imag_part = @symcore.function("sin", [theta])
  let signed_imag = if conjugate {
    @symcore.mul([int(-1), imag_expr(), imag_part])
  } else {
    @symcore.mul([imag_expr(), imag_part])
  }
  @symcore.add([real, signed_imag])
}

///|
fn append_binomial_zetas(
  zetas : Array[Expr],
  n : Int,
  minus : Bool,
) -> Unit raise PolyError {
  let even = n % 2 == 0
  if even && !minus {
    zetas.push(int(-1))
    zetas.push(int(1))
    let mut k = n / 2 - 1
    while k > 0 {
      zetas.push(zeta_from_angle(2 * k, n, true))
      zetas.push(zeta_from_angle(2 * k, n, false))
      k = k - 1
    }
  } else if even && minus {
    let mut k = n / 2 - 1
    while k >= 0 {
      zetas.push(zeta_from_angle(2 * k + 1, n, true))
      zetas.push(zeta_from_angle(2 * k + 1, n, false))
      k = k - 1
    }
  } else if !even && !minus {
    zetas.push(int(1))
    let mut k = n / 2
    while k > 0 {
      zetas.push(zeta_from_angle(2 * k, n, true))
      zetas.push(zeta_from_angle(2 * k, n, false))
      k = k - 1
    }
  } else {
    zetas.push(int(-1))
    let mut k = n / 2 - 1
    while k >= 0 {
      zetas.push(zeta_from_angle(2 * k + 1, n, true))
      zetas.push(zeta_from_angle(2 * k + 1, n, false))
      k = k - 1
    }
  }
}

///|
fn polyroots_rational_abs(value : @symnum.BigRational) -> @symnum.BigRational {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    value.neg_r()
  } else {
    value
  }
}

///|
fn polyroots_bigint_abs(value : BigInt) -> BigInt {
  if value.op_lt(0N) {
    value.neg()
  } else {
    value
  }
}

///|
fn integer_coeff_abs(coeff : FieldElem) -> BigInt raise PolyError {
  let value = fe_expect_rational(coeff)
  if !value.is_integral() {
    raise PolyError::CoefficientNotInteger
  }
  polyroots_bigint_abs(value.numerator())
}

///|
fn gcd_bigint_values(values : Array[BigInt]) -> BigInt {
  let mut result = 0N
  for value in values {
    let current = polyroots_bigint_abs(value)
    if current.compare(0N) == 0 {
      continue
    }
    if result.compare(0N) == 0 {
      result = current
    } else {
      result = @symnum.gcd_bigint(result, current)
    }
  }
  result
}

///|
fn integer_basis(poly : Poly) -> Int? raise PolyError {
  ensure_univar(poly)
  let dense = to_dense(poly)
  let monoms : Array[Int] = Array::new()
  let coeffs : Array[BigInt] = Array::new()
  for offset in 0..<dense.length() {
    let exp = dense.length() - 1 - offset
    let coeff = dense[exp]
    if !fe_is_zero(coeff) {
      monoms.push(exp)
      coeffs.push(integer_coeff_abs(coeff))
    }
  }
  if coeffs.length() < 2 {
    return None
  }
  if coeffs[0].compare(coeffs[coeffs.length() - 1]) >= 0 {
    return None
  }
  let degree = monoms[0]
  let scaled_monoms : Array[Int] = Array::new()
  let scaled_coeffs : Array[BigInt] = Array::new()
  for i in 0..<(monoms.length() - 1) {
    let idx = monoms.length() - 1 - i
    scaled_monoms.push(degree - monoms[idx])
    scaled_coeffs.push(coeffs[idx])
  }
  if scaled_monoms.length() == 1 {
    match bigint_nth_root_exact(scaled_coeffs[0], scaled_monoms[0]) {
      Some(root) => return Some(root.to_int())
      None => return None
    }
  }
  let gcd = gcd_bigint_values(scaled_coeffs)
  if gcd.compare(1N) <= 0 {
    return None
  }
  let divisors = polyroots_divisors_int(gcd.to_int())
  if divisors.length() <= 1 {
    return None
  }
  let mut idx = divisors.length() - 1
  while idx >= 1 {
    let div = divisors[idx]
    let div_big = BigInt::from_int(div)
    let mut ok = true
    for i in 0..<scaled_monoms.length() {
      let power = bigint_pow_int(div_big, scaled_monoms[i])
      if power.compare(0N) == 0 || scaled_coeffs[i].mod(power).compare(0N) != 0 {
        ok = false
        break
      }
    }
    if ok {
      return Some(div)
    }
    if idx == 1 {
      break
    }
    idx = idx - 1
  }
  None
}

///|
fn preprocess_scale_by_basis(poly : Poly, basis : Int) -> Poly raise PolyError {
  let degree = poly.degree(0)
  let coeffs : Map[Monomial, FieldElem] = Map([])
  let base = BigInt::from_int(basis)
  for monom, coeff in poly.coeffs {
    let exp = monom.exps[0]
    let divisor = bigint_pow_int(base, degree - exp)
    let value = fe_expect_rational(coeff)
    let scaled = value.div_r(@symnum.BigRational::from_bigint(divisor)) catch {
      _ => raise PolyError::DivisionByZero
    }
    add_term(coeffs, monom, fe_from_rational(scaled, poly.domain), poly.domain)
  }
  Poly::{ coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
}

///|
/// Preprocess a polynomial before symbolic root solving.
///
/// - Does: Clears rational denominators, removes primitive integer content, and
///   applies SymPy's integer basis scaling for univariate integer polynomials.
/// - Input: One `Poly`.
/// - Returns: `(Expr, Poly)`, where the expression is the root rescaling
///   coefficient and the polynomial is the transformed input.
/// - Limits: Symbolic coefficient-domain stripping is not modeled yet; inputs
///   whose coefficients cannot be projected to exact rationals are returned
///   unchanged with coefficient `1`.
pub fn preprocess_roots(poly : Poly) -> (Expr, Poly) raise PolyError {
  let mut coeff = int(1)
  let cleared_result : Result[Poly, PolyError] = try? clear_denominators(poly)
  let cleared = match cleared_result {
    Ok(value) => value
    Err(PolyError::DomainMismatch) => return (coeff, poly)
    Err(PolyError::CoefficientNotInteger) => return (coeff, poly)
    Err(error) => raise error
  }
  let primitive_poly = cleared.primitive_part()
  if primitive_poly.gens.length() == 1 && primitive_poly.domain == Domain::ZZ {
    match integer_basis(primitive_poly) {
      Some(basis) => {
        coeff = @symcore.mul([coeff, int(basis)])
        return (coeff, preprocess_scale_by_basis(primitive_poly, basis))
      }
      None => ()
    }
  }
  (coeff, primitive_poly)
}

///|
/// Solve a binomial polynomial through roots of unity.
///
/// - Does: Mirrors SymPy's `roots_binomial` by using the leading and constant
///   coefficients as `a*x**n + b`, forming `x**n = -b/a`, and multiplying one
///   principal magnitude by the ordered `n`-th roots of unity.
/// - Input: One univariate `Poly`.
/// - Returns: `Array[Expr]` of length equal to the polynomial degree.
/// - Limits: The current front door handles exact rational coefficients. Like
///   SymPy's helper, non-binomial middle terms are not inspected.
pub fn roots_binomial(poly : Poly) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  let n = poly.degree(0)
  if n <= 0 {
    return []
  }
  let a = fe_expect_rational(coeff_fe(poly, n))
  let b = fe_expect_rational(coeff_fe(poly, 0))
  let base = b.neg_r().div_r(a) catch { _ => raise PolyError::DivisionByZero }
  if base.is_zero() {
    return Array::make(n, int(0))
  }
  let minus = base.compare(@symnum.BigRational::zero()) < 0
  let alpha = positive_rational_nth_root_expr(polyroots_rational_abs(base), n)
  let zetas : Array[Expr] = Array::new()
  append_binomial_zetas(zetas, n, minus)
  zetas.map(zeta => @symcore.mul([alpha, zeta]))
}

///|
fn polyroots_divisors_int(n : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for d in 1..<=n {
    if n % d == 0 {
      out.push(d)
    }
  }
  out
}

///|
fn inv_totient_estimate(m : Int) -> (Int, Int) {
  let primes : Array[Int] = Array::new()
  for d in polyroots_divisors_int(m) {
    let p = d + 1
    if is_prime_int(p) {
      primes.push(p)
    }
  }
  let mut a = 1
  let mut b = 1
  for p in primes {
    a = a * p
    b = b * (p - 1)
  }
  let lower = m
  let mut upper = (m * a + b - 1) / b
  let mut product = 2
  let mut p = 2
  let search_primes : Array[Int] = Array::new()
  while product <= upper {
    p = next_prime_int(p)
    search_primes.push(p)
    product = product * p
  }
  product = product / p
  b = 1
  if search_primes.length() > 0 {
    for i in 0..<(search_primes.length() - 1) {
      b = b * (search_primes[i] - 1)
    }
  }
  upper = (m * product + b - 1) / b
  (lower, upper)
}

///|
fn polyroots_poly_equal_qq(a : Poly, b : Poly) -> Bool raise PolyError {
  if !same_gens(a.gens, b.gens) {
    return false
  }
  lift_to_qq(a).sub(lift_to_qq(b)).is_zero()
}

///|
fn cyclotomic_index(poly : Poly) -> Int raise PolyError {
  ensure_univar(poly)
  let degree = poly.degree(0)
  if degree <= 0 {
    raise PolyError::BadExponent
  }
  let (lower, upper) = inv_totient_estimate(degree)
  for n in lower..<=upper {
    let candidate = cyclotomic_poly_domain(n, poly.gens[0])
    if polyroots_poly_equal_qq(poly, candidate) {
      return n
    }
  }
  raise PolyError::BadExponent
}

///|
fn cyclotomic_key_primary(k : Int, n : Int) -> Int {
  let h = n / 2
  if k <= h {
    k
  } else {
    fact_int_abs(k - n)
  }
}

///|
fn cyclotomic_key_secondary(k : Int, n : Int) -> Int {
  if k <= n / 2 {
    -1
  } else {
    1
  }
}

///|
/// Compute roots of a cyclotomic polynomial.
///
/// - Does: Recognizes the cyclotomic index and returns primitive roots of
///   unity in SymPy's ordering.
/// - Input: One univariate cyclotomic `Poly`.
/// - Returns: `Array[Expr]`.
/// - Limits: `factor=true` is not modeled yet; non-cyclotomic inputs raise
///   `PolyError::BadExponent`.
pub fn roots_cyclotomic(
  poly : Poly,
  factor? : Bool = false,
) -> Array[Expr] raise PolyError {
  if factor {
    raise PolyError::DomainMismatch
  }
  let n = cyclotomic_index(poly)
  let ks : Array[Int] = Array::new()
  for k in 1..<=n {
    if python_gcd(k, n) == 1 {
      ks.push(k)
    }
  }
  ks.sort_by((lhs, rhs) => {
    let primary = cyclotomic_key_primary(lhs, n) -
      cyclotomic_key_primary(rhs, n)
    if primary != 0 {
      primary
    } else {
      cyclotomic_key_secondary(lhs, n) - cyclotomic_key_secondary(rhs, n)
    }
  })
  let roots : Array[Expr] = Array::new()
  for i in 0..<ks.length() {
    let k = ks[ks.length() - 1 - i]
    roots.push(zeta_from_angle(2 * k, n, false))
  }
  roots
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
fn roots_quintic_coeff_rat(poly : Poly, exp : Int) -> @symnum.BigRational? {
  let coeff = coeff_fe(poly, exp) catch { _ => return None }
  let value = fe_expect_rational(coeff) catch { _ => return None }
  Some(value)
}

///|
fn roots_quintic_binomial_base(poly : Poly) -> @symnum.BigRational? {
  let lead = match roots_quintic_coeff_rat(poly, 5) {
    Some(value) => value
    None => return None
  }
  if lead.is_zero() {
    return None
  }
  for exp in 1..<5 {
    match roots_quintic_coeff_rat(poly, exp) {
      Some(value) => if !value.is_zero() { return None }
      None => return None
    }
  }
  let constant = match roots_quintic_coeff_rat(poly, 0) {
    Some(value) => value
    None => return None
  }
  let base = constant.neg_r().div_r(lead) catch { _ => return None }
  Some(base)
}

///|
fn roots_quintic_sqrt(expr : Expr) -> Expr {
  @symcore.function("sqrt", [expr])
}

///|
fn roots_quintic_imag_term(sign : Int, inner : Expr) -> Expr {
  if sign == 1 {
    @symcore.mul([imag_expr(), inner])
  } else {
    @symcore.mul([int(-1), imag_expr(), inner])
  }
}

///|
fn roots_quintic_binomial_roots(
  base : @symnum.BigRational,
) -> Array[Expr] raise PolyError {
  let fifth = polyroots_rational_expr(1, 5)
  let root = @symcore.pow(Expr::Number(base), fifth)
  let q1 = polyroots_rational_expr(1, 4)
  let qneg1 = polyroots_rational_expr(-1, 4)
  let q5_8 = polyroots_rational_expr(5, 8)
  let q1_8 = polyroots_rational_expr(1, 8)
  let sqrt5 = roots_quintic_sqrt(int(5))
  let small = roots_quintic_sqrt(
    @symcore.add([q5_8, @symcore.mul([int(-1), sqrt5, q1_8])]),
  )
  let large = roots_quintic_sqrt(
    @symcore.add([@symcore.mul([sqrt5, q1_8]), q5_8]),
  )
  let signed = if base.compare(@symnum.BigRational::zero()) < 0 {
    -1
  } else {
    1
  }
  let left_real = @symcore.add([@symcore.mul([int(-1), sqrt5, q1]), qneg1])
  let right_real = @symcore.add([qneg1, @symcore.mul([sqrt5, q1])])
  [
    root,
    @symcore.mul([
      root,
      @symcore.add([left_real, roots_quintic_imag_term(signed, small)]),
    ]),
    @symcore.mul([
      root,
      @symcore.add([right_real, roots_quintic_imag_term(0 - signed, large)]),
    ]),
    @symcore.mul([
      root,
      @symcore.add([right_real, roots_quintic_imag_term(signed, large)]),
    ]),
    @symcore.mul([
      root,
      @symcore.add([left_real, roots_quintic_imag_term(0 - signed, small)]),
    ]),
  ]
}

///|
/// Solve supported solvable quintic polynomials by radicals.
///
/// - Does: Mirrors SymPy's `roots_quintic` front-door contract: reducible or
///   unsupported quintics return `[]`, while supported solvable irreducible
///   quintics return exact radical roots.
/// - Input: One univariate degree-`5` `Poly` with rational coefficients.
/// - Returns: `Array[Expr]`.
/// - Limits: The current radical branch covers irreducible binomial quintics
///   `a*x**5 + b`; the full `PolyQuintic` resolvent algorithm is not yet
///   migrated.
pub fn roots_quintic(poly : Poly) -> Array[Expr] raise PolyError {
  ensure_univar(poly)
  if poly.degree(0) != 5 {
    raise PolyError::BadExponent
  }
  let (_, factors) = poly.factor_list()
  if factors.length() != 1 || factors[0].0.degree(0) != 5 || factors[0].1 != 1 {
    return []
  }
  match roots_quintic_binomial_base(poly) {
    Some(base) => roots_quintic_binomial_roots(base)
    None => []
  }
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
