///|
/// Dense univariate polynomial helpers over GF(p) with Int coefficients.
fn mod_pos(value : Int, p : Int) -> Int {
  let mut v = value % p
  if v < 0 {
    v = v + p
  }
  v
}

///|
fn inv_mod(a : Int, p : Int) -> Int raise PolyError {
  if p <= 1 {
    raise PolyError::BadModulus
  }
  let mut t0 = 0
  let mut t1 = 1
  let mut r0 = p
  let mut r1 = mod_pos(a, p)
  while r1 != 0 {
    let q = r0 / r1
    let r2 = r0 - q * r1
    r0 = r1
    r1 = r2
    let t2 = t0 - q * t1
    t0 = t1
    t1 = t2
  }
  if r0 != 1 {
    raise PolyError::DivisionByZero
  }
  mod_pos(t0, p)
}

///|
fn int_gcdex_local(a : Int, b : Int) -> (Int, Int, Int) {
  let mut old_r = a
  let mut r = b
  let mut old_s = 1
  let mut s = 0
  let mut old_t = 0
  let mut t = 1
  while r != 0 {
    let q = old_r / r
    let next_r = old_r - q * r
    old_r = r
    r = next_r
    let next_s = old_s - q * s
    old_s = s
    s = next_s
    let next_t = old_t - q * t
    old_t = t
    t = next_t
  }
  if old_r < 0 {
    (-old_s, -old_t, -old_r)
  } else {
    (old_s, old_t, old_r)
  }
}

/// Return the leading degree of ``f``.

///|
/// Public API `gf_degree`.
///
/// - Does: Provides the `gf_degree` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, using the package representation expected by
/// the signature.
/// - Returns: a `Int` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_degree(f : Array[Int]) -> Int {
  f.length() - 1
}

///|
/// Return the leading coefficient of ``f``.

///|
/// Public API `gf_LC`.
///
/// - Does: Provides the `gf_LC` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, using the package representation expected by
/// the signature.
/// - Returns: a `Int` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_LC(f : Array[Int]) -> Int {
  if f.is_empty() {
    0
  } else {
    f[0]
  }
}

///|
/// Return the trailing coefficient of ``f``.

///|
/// Public API `gf_TC`.
///
/// - Does: Provides the `gf_TC` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, using the package representation expected by
/// the signature.
/// - Returns: a `Int` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_TC(f : Array[Int]) -> Int {
  if f.is_empty() {
    0
  } else {
    f[f.length() - 1]
  }
}

///|
/// Remove leading zeros from ``f``.

///|
/// Public API `gf_strip`.
///
/// - Does: Provides the `gf_strip` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, using the package representation expected by
/// the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_strip(f : Array[Int]) -> Array[Int] {
  if f.is_empty() || f[0] != 0 {
    return f
  }
  let mut k = 0
  for coeff in f {
    if coeff != 0 {
      break
    }
    k = k + 1
  }
  if k >= f.length() {
    return Array::new()
  }
  let out : Array[Int] = Array::new()
  for i in k..<f.length() {
    out.push(f[i])
  }
  out
}

///|
/// Reduce all coefficients modulo ``p``.

///|
/// Public API `gf_trunc`.
///
/// - Does: Provides the `gf_trunc` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `p : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_trunc(f : Array[Int], p : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for c in f {
    out.push(mod_pos(c, p))
  }
  gf_strip(out)
}

///|
/// Coerce a residue to SymPy's symmetric integer representative.
///
/// - Does: Maps `a` from `[0, p)` into `[-p/2, p/2]`.
/// - Input: One integer residue and one positive modulus.
/// - Returns: An `Int`.
/// - Limits: Assumes `a` has already been reduced modulo `p`.
pub fn gf_int(a : Int, p : Int) -> Int {
  if a <= p / 2 {
    a
  } else {
    a - p
  }
}

///|
/// Normalize coefficients modulo `p`.
///
/// - Does: Reduces every coefficient and strips leading zeros.
/// - Input: Dense high-to-low coefficients and a prime modulus.
/// - Returns: A normalized dense polynomial.
/// - Limits: The explicit coefficient domain argument from SymPy is omitted.
pub fn gf_normal(f : Array[Int], p : Int) -> Array[Int] {
  gf_trunc(f, p)
}

///|
/// Create a finite-field polynomial from exponent coefficients.
///
/// - Does: Converts a map `{degree: coeff}` into dense high-to-low
///   coefficients modulo `p`.
/// - Input: A degree-to-coefficient map and a prime modulus.
/// - Returns: A normalized dense polynomial.
/// - Limits: Empty maps return the zero polynomial instead of raising from
///   Python's `max`.
pub fn gf_from_dict(f : Map[Int, Int], p : Int) -> Array[Int] {
  let mut max_degree = -1
  for degree, _ in f {
    if degree > max_degree {
      max_degree = degree
    }
  }
  if max_degree < 0 {
    return []
  }
  let out : Array[Int] = []
  for degree in 0..<=max_degree {
    let k = max_degree - degree
    let coeff = match f.get(k) {
      Some(value) => value
      None => 0
    }
    out.push(mod_pos(coeff, p))
  }
  gf_trunc(out, p)
}

///|
/// Convert a finite-field polynomial to exponent coefficients.
///
/// - Does: Converts dense high-to-low coefficients into `{degree: coeff}`.
/// - Input: Dense coefficients, a prime modulus, and optional symmetric output.
/// - Returns: A map containing only nonzero coefficients.
/// - Limits: The map is unordered; sort keys at presentation boundaries when
///   stable display is required.
pub fn gf_to_dict(
  f : Array[Int],
  p : Int,
  symmetric? : Bool = true,
) -> Map[Int, Int] {
  let out : Map[Int, Int] = {}
  let n = gf_degree(f)
  for k in 0..<=n {
    let raw = f[n - k]
    let value = if symmetric { gf_int(mod_pos(raw, p), p) } else { raw }
    if value != 0 {
      out[k] = value
    }
  }
  out
}

///|
/// Create a finite-field polynomial from integer dense coefficients.
///
/// - Does: Reduces `ZZ[x]` dense coefficients modulo `p`.
/// - Input: Dense high-to-low integer coefficients and a prime modulus.
/// - Returns: A normalized dense polynomial over `GF(p)`.
/// - Limits: Same as `gf_trunc`.
pub fn gf_from_int_poly(f : Array[Int], p : Int) -> Array[Int] {
  gf_trunc(f, p)
}

///|
/// Convert finite-field coefficients back to integers.
///
/// - Does: Uses symmetric representatives by default.
/// - Input: Dense high-to-low coefficients, a prime modulus, and optional
///   symmetric output.
/// - Returns: Dense integer coefficients.
/// - Limits: Does not strip or otherwise normalize the input shape.
pub fn gf_to_int_poly(
  f : Array[Int],
  p : Int,
  symmetric? : Bool = true,
) -> Array[Int] {
  if !symmetric {
    return f.copy()
  }
  f.map(c => gf_int(mod_pos(c, p), p))
}

///|
/// Negate a polynomial over `GF(p)`.
///
/// - Does: Maps each coefficient to its additive inverse modulo `p`.
/// - Input: Dense high-to-low coefficients and a prime modulus.
/// - Returns: Dense coefficients with the same shape.
/// - Limits: Mirrors SymPy's low-level helper and does not strip zeros.
pub fn gf_neg(f : Array[Int], p : Int) -> Array[Int] {
  f.map(c => mod_pos(-c, p))
}

///|
/// Add a ground element to a finite-field polynomial.
///
/// - Does: Computes `f + a`.
/// - Input: Dense coefficients, a ground coefficient, and a prime modulus.
/// - Returns: Dense coefficients.
/// - Limits: Mirrors SymPy's low-level shape behavior for constant and empty
///   polynomials.
pub fn gf_add_ground(f : Array[Int], a : Int, p : Int) -> Array[Int] {
  let coeff = if f.is_empty() {
    mod_pos(a, p)
  } else {
    mod_pos(f[f.length() - 1] + a, p)
  }
  if f.length() > 1 {
    let out : Array[Int] = []
    for i in 0..<(f.length() - 1) {
      out.push(f[i])
    }
    out.push(coeff)
    out
  } else if coeff == 0 {
    []
  } else {
    [coeff]
  }
}

///|
/// Subtract a ground element from a finite-field polynomial.
///
/// - Does: Computes `f - a`.
/// - Input: Dense coefficients, a ground coefficient, and a prime modulus.
/// - Returns: Dense coefficients.
/// - Limits: Mirrors `gf_add_ground`.
pub fn gf_sub_ground(f : Array[Int], a : Int, p : Int) -> Array[Int] {
  let coeff = if f.is_empty() {
    mod_pos(-a, p)
  } else {
    mod_pos(f[f.length() - 1] - a, p)
  }
  if f.length() > 1 {
    let out : Array[Int] = []
    for i in 0..<(f.length() - 1) {
      out.push(f[i])
    }
    out.push(coeff)
    out
  } else if coeff == 0 {
    []
  } else {
    [coeff]
  }
}

///|
/// Multiply a finite-field polynomial by a ground element.
///
/// - Does: Computes `f * a`.
/// - Input: Dense coefficients, a ground coefficient, and a prime modulus.
/// - Returns: Dense coefficients.
/// - Limits: Returns zero for zero scalar without preserving input length, as
///   SymPy does.
pub fn gf_mul_ground(f : Array[Int], a : Int, p : Int) -> Array[Int] {
  let coeff = mod_pos(a, p)
  if coeff == 0 {
    []
  } else {
    f.map(c => mod_pos(c * coeff, p))
  }
}

///|
/// Divide a finite-field polynomial by a ground element.
///
/// - Does: Computes `f / a` using the modular inverse of `a`.
/// - Input: Dense coefficients, a nonzero invertible ground coefficient, and a
///   prime modulus.
/// - Returns: Dense coefficients.
/// - Limits: Raises `PolyError::DivisionByZero` when `a` is not invertible
///   modulo `p`.
pub fn gf_quo_ground(
  f : Array[Int],
  a : Int,
  p : Int,
) -> Array[Int] raise PolyError {
  gf_mul_ground(f, inv_mod(a, p), p)
}

///|
/// Add polynomials in ``GF(p)[x]``.

///|
/// Public API `gf_add`.
///
/// - Does: Provides the `gf_add` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `g : Array[Int]`, `p : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_add(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] {
  if f.is_empty() {
    return gf_trunc(g, p)
  }
  if g.is_empty() {
    return gf_trunc(f, p)
  }
  let len = if f.length() > g.length() { f.length() } else { g.length() }
  let out : Array[Int] = Array::make(len, 0)
  for i in 0..<len {
    let fi = i - (len - f.length())
    let gi = i - (len - g.length())
    let a = if fi >= 0 { f[fi] } else { 0 }
    let b = if gi >= 0 { g[gi] } else { 0 }
    out.set(i, mod_pos(a + b, p))
  }
  gf_strip(out)
}

///|
/// Subtract polynomials in ``GF(p)[x]``.

///|
/// Public API `gf_sub`.
///
/// - Does: Provides the `gf_sub` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `g : Array[Int]`, `p : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_sub(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] {
  if f.is_empty() {
    let out : Array[Int] = Array::new()
    for c in g {
      out.push(mod_pos(-c, p))
    }
    return gf_strip(out)
  }
  if g.is_empty() {
    return gf_trunc(f, p)
  }
  let len = if f.length() > g.length() { f.length() } else { g.length() }
  let out : Array[Int] = Array::make(len, 0)
  for i in 0..<len {
    let fi = i - (len - f.length())
    let gi = i - (len - g.length())
    let a = if fi >= 0 { f[fi] } else { 0 }
    let b = if gi >= 0 { g[gi] } else { 0 }
    out.set(i, mod_pos(a - b, p))
  }
  gf_strip(out)
}

///|
/// Multiply polynomials in ``GF(p)[x]``.

///|
/// Public API `gf_mul`.
///
/// - Does: Provides the `gf_mul` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `g : Array[Int]`, `p : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn gf_mul(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] {
  if f.is_empty() || g.is_empty() {
    return Array::new()
  }
  let out_len = f.length() + g.length() - 1
  let out : Array[Int] = Array::make(out_len, 0)
  for i in 0..<f.length() {
    for j in 0..<g.length() {
      let idx = i + j
      out.set(idx, mod_pos(out[idx] + f[i] * g[j], p))
    }
  }
  gf_strip(out)
}

///|
/// Square a polynomial over `GF(p)`.
///
/// - Does: Computes `f * f`.
/// - Input: Dense high-to-low coefficients and a prime modulus.
/// - Returns: A normalized dense polynomial.
/// - Limits: Uses the same arithmetic path as `gf_mul`.
pub fn gf_sqr(f : Array[Int], p : Int) -> Array[Int] {
  gf_mul(f, f, p)
}

///|
/// Add a product to a polynomial over `GF(p)`.
///
/// - Does: Computes `f + g*h`.
/// - Input: Three dense polynomials and a prime modulus.
/// - Returns: A normalized dense polynomial.
/// - Limits: Same input representation as `gf_add` and `gf_mul`.
pub fn gf_add_mul(
  f : Array[Int],
  g : Array[Int],
  h : Array[Int],
  p : Int,
) -> Array[Int] {
  gf_add(f, gf_mul(g, h, p), p)
}

///|
/// Subtract a product from a polynomial over `GF(p)`.
///
/// - Does: Computes `f - g*h`.
/// - Input: Three dense polynomials and a prime modulus.
/// - Returns: A normalized dense polynomial.
/// - Limits: Same input representation as `gf_sub` and `gf_mul`.
pub fn gf_sub_mul(
  f : Array[Int],
  g : Array[Int],
  h : Array[Int],
  p : Int,
) -> Array[Int] {
  gf_sub(f, gf_mul(g, h, p), p)
}

///|
/// Compute LC and a monic polynomial in ``GF(p)[x]``.

///|
/// Public API `gf_monic`.
///
/// - Does: Provides the `gf_monic` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `p : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn gf_monic(f : Array[Int], p : Int) -> Array[Int] raise PolyError {
  if f.is_empty() {
    return f
  }
  let lc = mod_pos(f[0], p)
  if lc == 1 {
    return gf_trunc(f, p)
  }
  let inv = inv_mod(lc, p)
  let out : Array[Int] = Array::new()
  for c in f {
    out.push(mod_pos(c * inv, p))
  }
  gf_strip(out)
}

///|
/// Division with remainder in ``GF(p)[x]``.

///|
/// Public API `gf_div`.
///
/// - Does: Provides the `gf_div` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `g : Array[Int]`, `p : Int`, `) ->
/// (Array[Int]`, `Array[Int]`, using the package representation expected by the
/// signature.
/// - Returns: a `(Array[Int], Array[Int])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn gf_div(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> (Array[Int], Array[Int]) raise PolyError {
  let ff = gf_strip(f)
  let gg = gf_strip(g)
  if gg.is_empty() {
    raise PolyError::DivisionByZero
  }
  if ff.is_empty() {
    return (Array::new(), Array::new())
  }
  let df = ff.length() - 1
  let dg = gg.length() - 1
  if df < dg {
    return (Array::new(), ff)
  }
  let inv_lc = inv_mod(gg[0], p)
  let q_len = df - dg + 1
  let q : Array[Int] = Array::make(q_len, 0)
  let r = ff.copy()
  for i in 0..<q_len {
    let coeff = mod_pos(r[i] * inv_lc, p)
    q.set(i, coeff)
    if coeff != 0 {
      for j in 0..<=dg {
        let idx = i + j
        r.set(idx, mod_pos(r[idx] - coeff * gg[j], p))
      }
    }
  }
  let rem : Array[Int] = Array::new()
  for i in q_len..<r.length() {
    rem.push(r[i])
  }
  (gf_strip(q), gf_strip(rem))
}

///|
/// Compute exact quotient in ``GF(p)[x]``.

///|
/// Public API `gf_quo`.
///
/// - Does: Provides the `gf_quo` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `g : Array[Int]`, `p : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn gf_quo(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  let (q, _) = gf_div(f, g, p)
  q
}

///|
/// Compute an exact quotient in `GF(p)[x]`.
///
/// - Does: Divides `f` by `g` and requires zero remainder.
/// - Input: Two dense polynomials and a prime modulus.
/// - Returns: The quotient polynomial.
/// - Limits: Raises `PolyError::ExactQuotientFailed` if `g` does not divide
///   `f`.
pub fn gf_exquo(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  let (q, r) = gf_div(f, g, p)
  if r.is_empty() {
    q
  } else {
    raise PolyError::ExactQuotientFailed
  }
}

///|
/// Multiply a dense polynomial by `x**n`.
///
/// - Does: Appends `n` trailing zeros for nonzero input.
/// - Input: Dense coefficients and a nonnegative shift.
/// - Returns: Shifted dense coefficients.
/// - Limits: Negative shifts raise `PolyError::BadExponent`.
pub fn gf_lshift(f : Array[Int], n : Int) -> Array[Int] raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  if f.is_empty() {
    return []
  }
  let out = f.copy()
  for _ in 0..<n {
    out.push(0)
  }
  out
}

///|
/// Divide a dense polynomial by `x**n`.
///
/// - Does: Splits quotient and discarded trailing part.
/// - Input: Dense coefficients and a nonnegative shift.
/// - Returns: `(quotient, remainder_tail)`.
/// - Limits: Negative shifts raise `PolyError::BadExponent`.
pub fn gf_rshift(
  f : Array[Int],
  n : Int,
) -> (Array[Int], Array[Int]) raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  if n == 0 {
    return (f.copy(), [])
  }
  if n >= f.length() {
    return ([], f.copy())
  }
  let q : Array[Int] = []
  let r : Array[Int] = []
  for i in 0..<(f.length() - n) {
    q.push(f[i])
  }
  for i in (f.length() - n)..<f.length() {
    r.push(f[i])
  }
  (q, r)
}

///|
/// Raise a polynomial to a nonnegative power over `GF(p)`.
///
/// - Does: Uses repeated squaring in `GF(p)[x]`.
/// - Input: Dense coefficients, exponent, and prime modulus.
/// - Returns: A normalized dense polynomial.
/// - Limits: Negative exponents raise `PolyError::BadExponent`.
pub fn gf_pow(f : Array[Int], n : Int, p : Int) -> Array[Int] raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  if n == 0 {
    return [1]
  }
  if n == 1 {
    return gf_trunc(f, p)
  }
  let mut base = gf_trunc(f, p)
  let mut exp = n
  let mut acc = [1]
  while exp > 0 {
    if exp % 2 == 1 {
      acc = gf_mul(acc, base, p)
    }
    exp = exp / 2
    if exp > 0 {
      base = gf_sqr(base, p)
    }
  }
  acc
}

///|
/// Raise a polynomial modulo another polynomial over `GF(p)`.
///
/// - Does: Computes `f**n mod g` using repeated squaring.
/// - Input: Base polynomial, nonnegative exponent, modulus polynomial, and
///   prime modulus.
/// - Returns: A dense remainder polynomial.
/// - Limits: Negative exponents raise `PolyError::BadExponent`; zero modulus
///   follows `gf_rem` division errors.
pub fn gf_pow_mod(
  f : Array[Int],
  n : Int,
  g : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  if n == 0 {
    return [1]
  }
  if n == 1 {
    return gf_rem(f, g, p)
  }
  let mut base = gf_rem(gf_trunc(f, p), g, p)
  let mut exp = n
  let mut acc = [1]
  while exp > 0 {
    if exp % 2 == 1 {
      acc = gf_rem(gf_mul(acc, base, p), g, p)
    }
    exp = exp / 2
    if exp > 0 {
      base = gf_rem(gf_sqr(base, p), g, p)
    }
  }
  acc
}

///|
/// Compute polynomial remainder in ``GF(p)[x]``.

///|
/// Public API `gf_rem`.
///
/// - Does: Provides the `gf_rem` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `g : Array[Int]`, `p : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn gf_rem(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  let (_, r) = gf_div(f, g, p)
  r
}

///|
/// Differentiate a dense polynomial over `GF(p)`.
///
/// - Does: Computes the formal derivative modulo `p`.
/// - Input: Dense high-to-low coefficients and a prime modulus.
/// - Returns: A normalized dense derivative.
/// - Limits: Constants and zero polynomials return the zero polynomial.
pub fn gf_diff(f : Array[Int], p : Int) -> Array[Int] {
  let degree = gf_degree(f)
  if degree <= 0 {
    return []
  }
  let out : Array[Int] = []
  let mut power = degree
  for i in 0..<(f.length() - 1) {
    out.push(mod_pos(f[i] * power, p))
    power = power - 1
  }
  gf_strip(out)
}

///|
/// Evaluate a dense polynomial over `GF(p)`.
///
/// - Does: Uses Horner evaluation modulo `p`.
/// - Input: Dense coefficients, evaluation point, and prime modulus.
/// - Returns: The value in `[0, p)`.
/// - Limits: Coefficients are reduced modulo `p`.
pub fn gf_eval(f : Array[Int], a : Int, p : Int) -> Int {
  let point = mod_pos(a, p)
  let mut result = 0
  for coeff in f {
    result = mod_pos(result * point + coeff, p)
  }
  result
}

///|
/// Evaluate a dense polynomial at several points over `GF(p)`.
///
/// - Does: Applies `gf_eval` to each point.
/// - Input: Dense coefficients, evaluation points, and prime modulus.
/// - Returns: Values in `[0, p)`.
/// - Limits: Same as `gf_eval`.
pub fn gf_multi_eval(
  f : Array[Int],
  values : Array[Int],
  p : Int,
) -> Array[Int] {
  values.map(a => gf_eval(f, a, p))
}

///|
/// Compose two dense polynomials over `GF(p)`.
///
/// - Does: Computes `f(g)`.
/// - Input: Two dense polynomials and a prime modulus.
/// - Returns: A normalized dense polynomial.
/// - Limits: Same dense high-to-low representation as the other GF helpers.
pub fn gf_compose(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] {
  if g.length() <= 1 {
    return gf_strip([gf_eval(f, gf_LC(g), p)])
  }
  if f.is_empty() {
    return []
  }
  let mut out = [f[0]]
  for i in 1..<f.length() {
    out = gf_add_ground(gf_mul(out, g, p), f[i], p)
  }
  out
}

///|
/// Compose two dense polynomials modulo a third over `GF(p)`.
///
/// - Does: Computes `g(h) mod f`.
/// - Input: Outer polynomial, inner polynomial, modulus polynomial, and prime
///   modulus.
/// - Returns: A dense remainder polynomial.
/// - Limits: Zero modulus follows `gf_rem` division errors.
pub fn gf_compose_mod(
  g : Array[Int],
  h : Array[Int],
  f : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  if g.is_empty() {
    return []
  }
  let mut out = [g[0]]
  for i in 1..<g.length() {
    out = gf_mul(out, h, p)
    out = gf_add_ground(out, g[i], p)
    out = gf_rem(out, f, p)
  }
  out
}

///|
/// Evaluate a dense integer polynomial without modular reduction.
///
/// - Does: Uses Horner evaluation over integers.
/// - Input: Dense high-to-low coefficients and an integer point.
/// - Returns: The integer value.
/// - Limits: Uses MoonBit `Int`, so very large values can overflow.
pub fn gf_value(f : Array[Int], a : Int) -> Int {
  let mut result = 0
  for coeff in f {
    result = result * a + coeff
  }
  result
}

///|
/// Euclidean Algorithm in ``GF(p)[x]``.

///|
/// Public API `gf_gcd`.
///
/// - Does: Provides the `gf_gcd` operation for finite-field polynomial arithmetic.
/// - Input: parameters `f : Array[Int]`, `g : Array[Int]`, `p : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn gf_gcd(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  let mut a = gf_strip(f)
  let mut b = gf_strip(g)
  while !b.is_empty() {
    let (_, r) = gf_div(a, b, p)
    a = b
    b = r
  }
  gf_monic(a, p)
}

///|
/// Compute the polynomial LCM over `GF(p)`.
///
/// - Does: Computes a monic least common multiple.
/// - Input: Two dense polynomials and a prime modulus.
/// - Returns: A normalized monic dense polynomial.
/// - Limits: Zero input returns the zero polynomial.
pub fn gf_lcm(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  if f.is_empty() || g.is_empty() {
    return []
  }
  gf_monic(gf_quo(gf_mul(f, g, p), gf_gcd(f, g, p), p), p)
}

///|
/// Compute GCD and cofactors over `GF(p)`.
///
/// - Does: Returns `(h, cff, cfg)` such that `h = gcd(f,g)`,
///   `f = h*cff`, and `g = h*cfg`.
/// - Input: Two dense polynomials and a prime modulus.
/// - Returns: A triple of dense polynomials.
/// - Limits: Both zero inputs return three zero polynomials.
pub fn gf_cofactors(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> (Array[Int], Array[Int], Array[Int]) raise PolyError {
  if f.is_empty() && g.is_empty() {
    return ([], [], [])
  }
  let h = gf_gcd(f, g, p)
  (h, gf_quo(f, h, p), gf_quo(g, h, p))
}

///|
/// Extended Euclidean algorithm over `GF(p)`.
///
/// - Does: Finds `s`, `t`, and `h` with `s*f + t*g = h`.
/// - Input: Two dense polynomials and a prime modulus.
/// - Returns: `(s, t, h)` with monic `h`.
/// - Limits: Mirrors the low-level dense representation and raises when a
///   needed modular inverse does not exist.
pub fn gf_gcdex(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> (Array[Int], Array[Int], Array[Int]) raise PolyError {
  if f.is_empty() && g.is_empty() {
    return ([1], [], [])
  }
  let p0 = gf_LC(f)
  let mut r0 = gf_monic(f, p)
  let p1 = gf_LC(g)
  let mut r1 = gf_monic(g, p)
  if f.is_empty() {
    return ([], [inv_mod(p1, p)], r1)
  }
  if g.is_empty() {
    return ([inv_mod(p0, p)], [], r0)
  }
  let mut s0 = [inv_mod(p0, p)]
  let mut s1 : Array[Int] = []
  let mut t0 : Array[Int] = []
  let mut t1 = [inv_mod(p1, p)]
  while true {
    let (q, r) = gf_div(r0, r1, p)
    if r.is_empty() {
      break
    }
    let lc = gf_LC(r)
    let inv = inv_mod(lc, p)
    let new_r1 = gf_monic(r, p)
    r0 = r1
    r1 = new_r1
    let s = gf_sub_mul(s0, s1, q, p)
    let t = gf_sub_mul(t0, t1, q, p)
    let old_s1 = s1
    let old_t1 = t1
    s1 = gf_mul_ground(s, inv, p)
    s0 = old_s1
    t1 = gf_mul_ground(t, inv, p)
    t0 = old_t1
  }
  (s1, t1, r1)
}

///|
/// Chinese remainder for pairwise-coprime integer moduli.
///
/// - Does: Solves residues `u_i mod m_i`.
/// - Input: Residues and moduli arrays of matching length.
/// - Returns: The smallest nonnegative combined residue modulo the product.
/// - Limits: Assumes pairwise-coprime moduli, matching SymPy's low-level
///   no-validation helper.
pub fn gf_crt(u : Array[Int], m : Array[Int]) -> Int raise PolyError {
  let (p, e, s) = gf_crt1(m)
  gf_crt2(u, m, p, e, s)
}

///|
/// Precompute CRT data for fixed moduli.
///
/// - Does: Computes product, partial products, and inverses.
/// - Input: Pairwise-coprime moduli.
/// - Returns: `(p, E, S)` for `gf_crt2`.
/// - Limits: Assumes valid coprime positive moduli.
pub fn gf_crt1(m : Array[Int]) -> (Int, Array[Int], Array[Int]) raise PolyError {
  let mut p = 1
  for modulus in m {
    p = p * modulus
  }
  let e : Array[Int] = []
  let s : Array[Int] = []
  for modulus in m {
    let partial = p / modulus
    e.push(partial)
    s.push(inv_mod(mod_pos(partial, modulus), modulus))
  }
  (p, e, s)
}

///|
/// Finish CRT reconstruction from precomputed data.
///
/// - Does: Combines residues with the output of `gf_crt1`.
/// - Input: Residues, moduli, product, partial products, and inverses.
/// - Returns: The smallest nonnegative combined residue modulo `p`.
/// - Limits: Uses the overlapping prefix if arrays have different lengths.
pub fn gf_crt2(
  u : Array[Int],
  m : Array[Int],
  p : Int,
  e : Array[Int],
  s : Array[Int],
) -> Int {
  let mut acc = 0
  let count = u.length().min(m.length()).min(e.length()).min(s.length())
  for i in 0..<count {
    acc = acc + e[i] * mod_pos(u[i] * s[i], m[i])
  }
  mod_pos(acc, p)
}

///|
/// Solve a linear congruence.
///
/// - Does: Returns all distinct `x mod m` satisfying `a*x == b mod m`.
/// - Input: Integers `a`, `b`, and positive modulus `m`.
/// - Returns: An array of solutions in `[0, m)`.
/// - Limits: Raises `PolyError::BadModulus` for nonpositive `m`.
pub fn linear_congruence(
  a : Int,
  b : Int,
  m : Int,
) -> Array[Int] raise PolyError {
  if m <= 0 {
    raise PolyError::BadModulus
  }
  if mod_pos(a, m) == 0 {
    if mod_pos(b, m) == 0 {
      let out : Array[Int] = []
      for x in 0..<m {
        out.push(x)
      }
      return out
    }
    return []
  }
  let (r, _, g) = int_gcdex_local(a, m)
  if b % g != 0 {
    return []
  }
  let out : Array[Int] = []
  for t in 0..<g {
    out.push(mod_pos(r * (b / g) + t * (m / g), m))
  }
  out
}
