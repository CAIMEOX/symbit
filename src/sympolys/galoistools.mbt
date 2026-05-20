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

///|
fn int_array_equal(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn int_array_contains(values : Array[Int], needle : Int) -> Bool {
  for value in values {
    if value == needle {
      return true
    }
  }
  false
}

///|
fn int_array_reverse(values : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for i in 0..<values.length() {
    out.push(values[values.length() - 1 - i])
  }
  out
}

///|
fn int_prime_factors_unique(n0 : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut n = if n0 < 0 { -n0 } else { n0 }
  let mut d = 2
  while d * d <= n {
    if n % d == 0 {
      out.push(d)
      while n % d == 0 {
        n = n / d
      }
    }
    if d == 2 {
      d = 3
    } else {
      d = d + 2
    }
  }
  if n > 1 {
    out.push(n)
  }
  out
}

///|
fn int_ceil_sqrt(n : Int) -> Int {
  if n <= 0 {
    return 0
  }
  let mut k = 0
  while k * k < n {
    k = k + 1
  }
  k
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
/// Expand a finite-field factorization.
///
/// - Does: Multiplies `(factor, exponent)` pairs in `GF(p)[x]`, including an
///   optional leading coefficient.
/// - Input: Dense factors with multiplicities, a prime modulus, and optional
///   `lc`.
/// - Returns: A dense polynomial over `GF(p)`.
/// - Limits: MoonBit uses an explicit `lc` optional argument instead of
///   accepting either a Python list or `(lc, factors)` tuple.
pub fn gf_expand(
  factors : Array[(Array[Int], Int)],
  p : Int,
  lc? : Int = 1,
) -> Array[Int] raise PolyError {
  let mut out = gf_trunc([lc], p)
  for entry in factors {
    let pow = gf_pow(entry.0, entry.1, p)
    out = gf_mul(out, pow, p)
  }
  out
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
/// Build the Frobenius monomial base modulo a polynomial.
///
/// - Does: Computes `x**(i*p) mod g` for `i = 0 .. deg(g)-1`.
/// - Input: A dense modulus polynomial and a prime modulus.
/// - Returns: An array of dense remainder polynomials.
/// - Limits: Raises through `gf_rem`/`gf_pow_mod` if the modulus is invalid.
pub fn gf_frobenius_monomial_base(
  g : Array[Int],
  p : Int,
) -> Array[Array[Int]] raise PolyError {
  let n = gf_degree(g)
  if n == 0 {
    return []
  }
  let base : Array[Array[Int]] = Array::make(n, [])
  base.set(0, [1])
  if p < n {
    for i in 1..<n {
      let mon = gf_lshift(base[i - 1], p)
      base.set(i, gf_rem(mon, g, p))
    }
  } else if n > 1 {
    base.set(1, gf_pow_mod([1, 0], p, g, p))
    for i in 2..<n {
      base.set(i, gf_rem(gf_mul(base[i - 1], base[1], p), g, p))
    }
  }
  base
}

///|
/// Apply the Frobenius map using a precomputed monomial base.
///
/// - Does: Computes `f**p mod g` from `x**(i*p) mod g` basis elements.
/// - Input: A dense polynomial, modulus polynomial, Frobenius base, and prime
///   modulus.
/// - Returns: A dense remainder polynomial.
/// - Limits: The base must come from `gf_frobenius_monomial_base(g, p)`.
pub fn gf_frobenius_map(
  f : Array[Int],
  g : Array[Int],
  b : Array[Array[Int]],
  p : Int,
) -> Array[Int] raise PolyError {
  let m = gf_degree(g)
  let ff = if gf_degree(f) >= m { gf_rem(f, g, p) } else { gf_trunc(f, p) }
  if ff.is_empty() {
    return []
  }
  let n = gf_degree(ff)
  let mut out = [ff[ff.length() - 1]]
  for i in 1..<=n {
    let v = gf_mul_ground(b[i], ff[n - i], p)
    out = gf_add(out, v, p)
  }
  out
}

///|
/// Compute a finite-field trace map in a quotient ring.
///
/// - Does: Returns `(a**t**n, a + a**t + ... + a**t**n) mod f` using
///   composition, matching SymPy's low-level helper.
/// - Input: Dense polynomials `a`, `b`, `c`, an iteration count `n`, modulus
///   `f`, and prime modulus.
/// - Returns: A pair of dense polynomials.
/// - Limits: Assumes `b` and `c` satisfy the same quotient-ring relation as in
///   SymPy's factorization routines.
pub fn gf_trace_map(
  a : Array[Int],
  b : Array[Int],
  c : Array[Int],
  n0 : Int,
  f : Array[Int],
  p : Int,
) -> (Array[Int], Array[Int]) raise PolyError {
  let mut u = gf_compose_mod(a, b, f, p)
  let mut v = b
  let mut n = n0
  let mut trace_sum = if n % 2 == 1 { gf_add(a, u, p) } else { a }
  let mut trace_power = if n % 2 == 1 { b } else { c }
  n = n / 2
  while n != 0 {
    u = gf_add(u, gf_compose_mod(u, v, f, p), p)
    v = gf_compose_mod(v, v, f, p)
    if n % 2 == 1 {
      trace_sum = gf_add(trace_sum, gf_compose_mod(u, trace_power, f, p), p)
      trace_power = gf_compose_mod(v, trace_power, f, p)
    }
    n = n / 2
  }
  (gf_compose_mod(a, trace_power, f, p), trace_sum)
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
/// Test whether a finite-field polynomial is irreducible using Ben-Or's test.
///
/// - Does: Runs the same low-degree/Frobenius branch structure as SymPy.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: `true` when the polynomial is irreducible over `GF(p)`.
/// - Limits: Assumes `p` is prime and coefficients use dense high-to-low form.
pub fn gf_irred_p_ben_or(f : Array[Int], p : Int) -> Bool raise PolyError {
  let n = gf_degree(f)
  if n <= 1 {
    return true
  }
  let ff = gf_monic(f, p)
  if n < 5 {
    let h_base = gf_pow_mod([1, 0], p, ff, p)
    let mut h = h_base
    for _ in 0..<(n / 2) {
      let g = gf_sub(h, [1, 0], p)
      if int_array_equal(gf_gcd(ff, g, p), [1]) {
        h = gf_compose_mod(h, h_base, ff, p)
      } else {
        return false
      }
    }
  } else {
    let b = gf_frobenius_monomial_base(ff, p)
    let h_base = gf_frobenius_map([1, 0], ff, b, p)
    let mut h = h_base
    for _ in 0..<(n / 2) {
      let g = gf_sub(h, [1, 0], p)
      if int_array_equal(gf_gcd(ff, g, p), [1]) {
        h = gf_frobenius_map(h, ff, b, p)
      } else {
        return false
      }
    }
  }
  true
}

///|
/// Test whether a finite-field polynomial is irreducible using Rabin's test.
///
/// - Does: Checks Frobenius iterates at the prime divisors of the degree and
///   verifies the final iterate returns `x`.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: `true` when the polynomial is irreducible over `GF(p)`.
/// - Limits: Uses a local trial-division factorization of the degree.
pub fn gf_irred_p_rabin(f : Array[Int], p : Int) -> Bool raise PolyError {
  let n = gf_degree(f)
  if n <= 1 {
    return true
  }
  let ff = gf_monic(f, p)
  let x = [1, 0]
  let prime_factors = int_prime_factors_unique(n)
  let indices : Array[Int] = []
  for d in prime_factors {
    indices.push(n / d)
  }
  let b = gf_frobenius_monomial_base(ff, p)
  let mut h = b[1]
  for i in 1..<n {
    if int_array_contains(indices, i) {
      let g = gf_sub(h, x, p)
      if !int_array_equal(gf_gcd(ff, g, p), [1]) {
        return false
      }
    }
    h = gf_frobenius_map(h, ff, b, p)
  }
  int_array_equal(h, x)
}

///|
/// Test finite-field irreducibility using SymPy's default Rabin path.
///
/// - Does: Dispatches to `gf_irred_p_rabin`.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: `true` for irreducible polynomials.
/// - Limits: Does not expose SymPy's runtime `GF_IRRED_METHOD` configuration.
pub fn gf_irreducible_p(f : Array[Int], p : Int) -> Bool raise PolyError {
  gf_irred_p_rabin(f, p)
}

///|
/// Generate a deterministic monic polynomial over `GF(p)`.
///
/// - Does: Produces a monic degree-`n` dense polynomial with pseudo-random
///   coefficients in `[0, p)`.
/// - Input: Degree, prime modulus, and optional deterministic seed.
/// - Returns: A dense monic polynomial.
/// - Limits: SymPy uses process-global randomness; this front door is
///   deterministic so tests and builds are reproducible.
pub fn gf_random(
  n : Int,
  p : Int,
  seed? : Int = 1,
) -> Array[Int] raise PolyError {
  if p <= 1 {
    raise PolyError::BadModulus
  }
  let out : Array[Int] = [1]
  let mut state = seed
  for _ in 0..<n {
    state = lcg_next(state, 2147483647)
    out.push(mod_pos(state, p))
  }
  out
}

///|
/// Generate a monic irreducible polynomial over `GF(p)`.
///
/// - Does: Tests deterministic `gf_random` candidates, then falls back to
///   exhaustive monic enumeration.
/// - Input: Degree, prime modulus, and optional seed.
/// - Returns: A monic irreducible dense polynomial.
/// - Limits: Exhaustive fallback is intended for modest low-level test inputs.
pub fn gf_irreducible(
  n : Int,
  p : Int,
  seed? : Int = 1,
) -> Array[Int] raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  let mut state = seed
  for _ in 0..<64 {
    let candidate = gf_random(n, p, seed=state)
    if gf_irreducible_p(candidate, p) {
      return candidate
    }
    state = state + 1
  }
  let total = int_pow(p, n)
  for code in 0..<total {
    let mut v = code
    let candidate : Array[Int] = [1]
    for _ in 0..<n {
      candidate.push(v % p)
      v = v / p
    }
    if gf_irreducible_p(candidate, p) {
      return candidate
    }
  }
  raise PolyError::BadModulus
}

///|
/// Test whether a finite-field polynomial is square-free.
///
/// - Does: Checks that the monic polynomial is coprime with its derivative.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: `true` for square-free polynomials.
/// - Limits: Assumes `p` is prime.
pub fn gf_sqf_p(f : Array[Int], p : Int) -> Bool raise PolyError {
  let ff = gf_monic(f, p)
  if ff.is_empty() {
    true
  } else {
    int_array_equal(gf_gcd(ff, gf_diff(ff, p), p), [1])
  }
}

///|
/// Compute the square-free decomposition over `GF(p)`.
///
/// - Does: Returns `(lc, [(factor, multiplicity), ...])` for monic
///   square-free factors, following SymPy's low-level algorithm.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: Leading coefficient and factor/multiplicity pairs.
/// - Limits: SymPy's unsupported `all=True` branch is not exposed.
pub fn gf_sqf_list(
  f : Array[Int],
  p : Int,
) -> (Int, Array[(Array[Int], Int)]) raise PolyError {
  let lc = gf_LC(f)
  let mut work = gf_monic(f, p)
  if gf_degree(work) < 1 {
    return (lc, [])
  }
  let mut n = 1
  let mut sqf = false
  let factors : Array[(Array[Int], Int)] = []
  while true {
    let deriv = gf_diff(work, p)
    if !deriv.is_empty() {
      let mut g = gf_gcd(work, deriv, p)
      let mut h = gf_quo(work, g, p)
      let mut i = 1
      while !int_array_equal(h, [1]) {
        let gcd_part = gf_gcd(g, h, p)
        let quotient_part = gf_quo(h, gcd_part, p)
        if gf_degree(quotient_part) > 0 {
          factors.push((quotient_part, i * n))
        }
        g = gf_quo(g, gcd_part, p)
        h = gcd_part
        i = i + 1
      }
      if int_array_equal(g, [1]) {
        sqf = true
      } else {
        work = g
      }
    }
    if !sqf {
      let d = gf_degree(work) / p
      let reduced : Array[Int] = []
      for i in 0..<=d {
        reduced.push(work[i * p])
      }
      work = gf_strip(reduced)
      n = n * p
    } else {
      break
    }
  }
  (lc, factors)
}

///|
/// Compute the square-free part over `GF(p)`.
///
/// - Does: Multiplies the factors returned by `gf_sqf_list`.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: A monic square-free dense polynomial.
/// - Limits: Same representation limits as `gf_sqf_list`.
pub fn gf_sqf_part(f : Array[Int], p : Int) -> Array[Int] raise PolyError {
  let (_, factors) = gf_sqf_list(f, p)
  let mut out = [1]
  for entry in factors {
    out = gf_mul(out, entry.0, p)
  }
  out
}

///|
/// Calculate Berlekamp's Q matrix.
///
/// - Does: Builds the Frobenius matrix used by Berlekamp factorization.
/// - Input: A dense polynomial and a prime modulus.
/// - Returns: Rows of the Q matrix as integer arrays.
/// - Limits: Intended for positive-degree dense polynomials.
pub fn gf_Qmatrix(f : Array[Int], p : Int) -> Array[Array[Int]] {
  let n = gf_degree(f)
  if n <= 0 {
    return [[1]]
  }
  let mut q = Array::make(n, 0)
  q.set(0, 1)
  let q_matrix : Array[Array[Int]] = Array::make(n, [])
  q_matrix.set(0, q.copy())
  for i in 1..<=((n - 1) * p) {
    let qq : Array[Int] = []
    let c = q[q.length() - 1]
    qq.push(mod_pos(-c * f[f.length() - 1], p))
    for j in 1..<n {
      qq.push(mod_pos(q[j - 1] - c * f[f.length() - j - 1], p))
    }
    if i % p == 0 {
      q_matrix.set(i / p, qq.copy())
    }
    q = qq
  }
  q_matrix
}

///|
/// Compute a basis of the kernel of Berlekamp's `Q - I`.
///
/// - Does: Performs the same column-reduction routine as SymPy's
///   `gf_Qbasis`.
/// - Input: A Q matrix and prime modulus.
/// - Returns: Basis vectors as integer arrays.
/// - Limits: Assumes a square matrix produced by `gf_Qmatrix`.
pub fn gf_Qbasis(
  q0 : Array[Array[Int]],
  p : Int,
) -> Array[Array[Int]] raise PolyError {
  let n = q0.length()
  let q_matrix : Array[Array[Int]] = []
  for row in q0 {
    q_matrix.push(row.copy())
  }
  for k in 0..<n {
    q_matrix[k].set(k, mod_pos(q_matrix[k][k] - 1, p))
  }
  for k in 0..<n {
    let mut pivot : Int? = None
    for i in k..<n {
      if q_matrix[k][i] != 0 {
        pivot = Some(i)
        break
      }
    }
    match pivot {
      None => ()
      Some(col) => {
        let inv = inv_mod(q_matrix[k][col], p)
        for j in 0..<n {
          q_matrix[j].set(col, mod_pos(q_matrix[j][col] * inv, p))
        }
        for j in 0..<n {
          let tmp = q_matrix[j][k]
          q_matrix[j].set(k, q_matrix[j][col])
          q_matrix[j].set(col, tmp)
        }
        for i in 0..<n {
          if i != k {
            let q = q_matrix[k][i]
            for j in 0..<n {
              q_matrix[j].set(
                i,
                mod_pos(q_matrix[j][i] - q_matrix[j][k] * q, p),
              )
            }
          }
        }
      }
    }
  }
  for i in 0..<n {
    for j in 0..<n {
      if i == j {
        q_matrix[i].set(j, mod_pos(1 - q_matrix[i][j], p))
      } else {
        q_matrix[i].set(j, mod_pos(-q_matrix[i][j], p))
      }
    }
  }
  let basis : Array[Array[Int]] = []
  for qv in q_matrix {
    let mut nonzero = false
    for coeff in qv {
      if coeff != 0 {
        nonzero = true
        break
      }
    }
    if nonzero {
      basis.push(qv)
    }
  }
  basis
}

///|
/// Factor a square-free polynomial over a small finite field.
///
/// - Does: Applies Berlekamp factorization to a square-free dense polynomial.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: Sorted monic irreducible factors.
/// - Limits: Intended for square-free input, as in SymPy's low-level helper.
pub fn gf_berlekamp(
  f : Array[Int],
  p : Int,
) -> Array[Array[Int]] raise PolyError {
  let q_matrix = gf_Qmatrix(f, p)
  let basis0 = gf_Qbasis(q_matrix, p)
  let basis : Array[Array[Int]] = []
  for v in basis0 {
    basis.push(gf_strip(int_array_reverse(v)))
  }
  let factors : Array[Array[Int]] = [f]
  for k in 1..<basis.length() {
    let snapshot = factors.copy()
    for original in snapshot {
      let mut current = original
      let mut s = 0
      while s < p {
        let g = gf_sub_ground(basis[k], s, p)
        let h = gf_gcd(current, g, p)
        if !int_array_equal(h, [1]) && !int_array_equal(h, current) {
          let mut found : Int? = None
          for idx in 0..<factors.length() {
            if int_array_equal(factors[idx], current) {
              found = Some(idx)
              break
            }
          }
          match found {
            Some(idx) => {
              ignore(factors.remove(idx))
              current = gf_quo(current, h, p)
              factors.push(current)
              factors.push(h)
            }
            None => ()
          }
        }
        if factors.length() == basis.length() {
          return _sort_factors(factors)
        }
        s = s + 1
      }
    }
  }
  _sort_factors(factors)
}

///|
fn gf_pow_pnm1d2(
  f0 : Array[Int],
  n : Int,
  g : Array[Int],
  b : Array[Array[Int]],
  p : Int,
) -> Array[Int] raise PolyError {
  let f = gf_rem(f0, g, p)
  let mut h = f
  let mut r = f
  for _ in 1..<n {
    h = gf_frobenius_map(h, g, b, p)
    r = gf_rem(gf_mul(r, h, p), g, p)
  }
  gf_pow_mod(r, (p - 1) / 2, g, p)
}

///|
fn gf_trace_map_sum_iter(
  f0 : Array[Int],
  n : Int,
  g : Array[Int],
  b : Array[Array[Int]],
  p : Int,
) -> Array[Int] raise PolyError {
  let f = gf_rem(f0, g, p)
  let mut h = f
  let mut r = f
  for _ in 1..<n {
    h = gf_frobenius_map(h, g, b, p)
    r = gf_rem(gf_add(r, h, p), g, p)
  }
  r
}

///|
fn gf_equal_degree_enumerate(
  f : Array[Int],
  n : Int,
  p : Int,
) -> Array[Array[Int]] raise PolyError {
  if gf_degree(f) <= n {
    return [f]
  }
  let mut remaining = f
  let factors : Array[Array[Int]] = []
  let total = int_pow(p, n)
  for code in 0..<total {
    if gf_degree(remaining) < n {
      break
    }
    let mut v = code
    let candidate : Array[Int] = [1]
    for _ in 0..<n {
      candidate.push(v % p)
      v = v / p
    }
    while gf_degree(remaining) >= n {
      let (q, r) = gf_div(remaining, candidate, p)
      if r.is_empty() {
        factors.push(candidate)
        remaining = q
      } else {
        break
      }
    }
  }
  if !remaining.is_empty() && !int_array_equal(remaining, [1]) {
    factors.push(remaining)
  }
  _sort_factors(factors)
}

///|
/// Distinct-degree factorization by the Cantor-Zassenhaus path.
///
/// - Does: Splits a monic square-free polynomial into factors whose
///   irreducible factors have distinct degrees.
/// - Input: A monic square-free dense polynomial and prime modulus.
/// - Returns: `(factor, degree)` pairs.
/// - Limits: Assumes square-free input, as in SymPy's low-level helper.
pub fn gf_ddf_zassenhaus(
  f0 : Array[Int],
  p : Int,
) -> Array[(Array[Int], Int)] raise PolyError {
  let mut i = 1
  let mut g = [1, 0]
  let mut f = f0
  let factors : Array[(Array[Int], Int)] = []
  let mut b = gf_frobenius_monomial_base(f, p)
  while 2 * i <= gf_degree(f) {
    g = gf_frobenius_map(g, f, b, p)
    let h = gf_gcd(f, gf_sub(g, [1, 0], p), p)
    if !int_array_equal(h, [1]) {
      factors.push((h, i))
      f = gf_quo(f, h, p)
      g = gf_rem(g, f, p)
      b = gf_frobenius_monomial_base(f, p)
    }
    i = i + 1
  }
  if !int_array_equal(f, [1]) {
    factors.push((f, gf_degree(f)))
  }
  factors
}

///|
/// Equal-degree factorization by the Cantor-Zassenhaus path.
///
/// - Does: Splits a monic square-free polynomial into irreducible factors of
///   degree `n`.
/// - Input: Dense polynomial, equal factor degree, and prime modulus.
/// - Returns: Sorted monic factors.
/// - Limits: Random choices are deterministic with exhaustive fallback.
pub fn gf_edf_zassenhaus(
  f : Array[Int],
  n : Int,
  p : Int,
) -> Array[Array[Int]] raise PolyError {
  let degree = gf_degree(f)
  if degree <= n {
    return [f]
  }
  let target = degree / n
  let mut factors : Array[Array[Int]] = [f]
  let frob_base = if p != 2 { gf_frobenius_monomial_base(f, p) } else { [] }
  let mut t = [1, 0]
  let mut seed = 1
  let mut attempts = 0
  while factors.length() < target && attempts < 64 {
    let g = if p == 2 {
      let mut h = t
      let mut r = t
      for _ in 0..<(n - 1) {
        r = gf_pow_mod(r, 2, f, p)
        h = gf_add(h, r, p)
      }
      t = gf_lshift(t, 2)
      gf_gcd(f, h, p)
    } else {
      let r = gf_random(2 * n - 1, p, seed~)
      seed = seed + 1
      let h = gf_pow_pnm1d2(r, n, f, frob_base, p)
      gf_gcd(f, gf_sub_ground(h, 1, p), p)
    }
    if !int_array_equal(g, [1]) && !int_array_equal(g, f) {
      let left = gf_edf_zassenhaus(g, n, p)
      let right = gf_edf_zassenhaus(gf_quo(f, g, p), n, p)
      let merged : Array[Array[Int]] = []
      for item in left {
        merged.push(item)
      }
      for item in right {
        merged.push(item)
      }
      factors = merged
    }
    attempts = attempts + 1
  }
  if factors.length() < target {
    return gf_equal_degree_enumerate(f, n, p)
  }
  _sort_factors(factors)
}

///|
/// Distinct-degree factorization by the Kaltofen-Shoup path.
///
/// - Does: Applies SymPy's Shoup DDF structure using Frobenius composition.
/// - Input: A monic square-free dense polynomial and prime modulus.
/// - Returns: `(factor, degree)` pairs.
/// - Limits: Intended for the same low-level inputs as SymPy's helper.
pub fn gf_ddf_shoup(
  f0 : Array[Int],
  p : Int,
) -> Array[(Array[Int], Int)] raise PolyError {
  let n = gf_degree(f0)
  if n <= 1 {
    return if n == 1 { [(f0, 1)] } else { [] }
  }
  let k = int_ceil_sqrt(n / 2)
  let b = gf_frobenius_monomial_base(f0, p)
  let h0 = gf_frobenius_map([1, 0], f0, b, p)
  let powers : Array[Array[Int]] = [[1, 0], h0]
  for _ in 0..<(k - 1) {
    powers.push([0])
  }
  for i in 2..<=k {
    powers.set(i, gf_frobenius_map(powers[i - 1], f0, b, p))
  }
  let h = powers[k]
  let u_values : Array[Array[Int]] = []
  for i in 0..<k {
    u_values.push(powers[i])
  }
  let v_values : Array[Array[Int]] = [h]
  for _ in 0..<(k - 1) {
    v_values.push([0])
  }
  for i in 1..<k {
    v_values.set(i, gf_compose_mod(v_values[i - 1], h, f0, p))
  }
  let factors : Array[(Array[Int], Int)] = []
  let mut f = f0
  for i in 0..<v_values.length() {
    let v = v_values[i]
    let mut block = [1]
    let mut j = k - 1
    for u in u_values {
      let diff = gf_sub(v, u, p)
      block = gf_rem(gf_mul(block, diff, p), f, p)
    }
    let mut g = gf_gcd(f, block, p)
    f = gf_quo(f, g, p)
    for idx in 0..<u_values.length() {
      let u = u_values[u_values.length() - 1 - idx]
      let diff = gf_sub(v, u, p)
      let factor = gf_gcd(g, diff, p)
      if !int_array_equal(factor, [1]) {
        factors.push((factor, k * (i + 1) - j))
      }
      g = gf_quo(g, factor, p)
      j = j - 1
    }
  }
  if !int_array_equal(f, [1]) {
    factors.push((f, gf_degree(f)))
  }
  factors
}

///|
/// Equal-degree factorization by the Gathen-Shoup path.
///
/// - Does: Uses the trace-map split from SymPy and falls back to the
///   Cantor-Zassenhaus EDF if the deterministic random choice is unlucky.
/// - Input: Dense polynomial, equal factor degree, and prime modulus.
/// - Returns: Sorted monic factors.
/// - Limits: Random choice is deterministic for reproducible tests.
pub fn gf_edf_shoup(
  f : Array[Int],
  n : Int,
  p : Int,
) -> Array[Array[Int]] raise PolyError {
  let degree = gf_degree(f)
  if degree <= 0 {
    return []
  }
  if degree <= n {
    return [f]
  }
  let x = [1, 0]
  let r = gf_random(degree - 1, p)
  let pieces : Array[Array[Int]] = []
  if p == 2 {
    let h = gf_pow_mod(x, p, f, p)
    let trace = gf_trace_map(r, h, x, n - 1, f, p).1
    let h1 = gf_gcd(f, trace, p)
    let h2 = gf_quo(f, h1, p)
    if int_array_equal(h1, [1]) || int_array_equal(h1, f) {
      return gf_edf_zassenhaus(f, n, p)
    }
    for item in gf_edf_shoup(h1, n, p) {
      pieces.push(item)
    }
    for item in gf_edf_shoup(h2, n, p) {
      pieces.push(item)
    }
  } else {
    let b = gf_frobenius_monomial_base(f, p)
    let trace = gf_trace_map_sum_iter(r, n, f, b, p)
    let h = gf_pow_mod(trace, (p - 1) / 2, f, p)
    let h1 = gf_gcd(f, h, p)
    let h2 = gf_gcd(f, gf_sub_ground(h, 1, p), p)
    let product = gf_mul(h1, h2, p)
    let h3 = gf_quo(f, product, p)
    let parts = [h1, h2, h3]
    let mut progress = false
    for part in parts {
      if gf_degree(part) > 0 && !int_array_equal(part, f) {
        progress = true
        for item in gf_edf_shoup(part, n, p) {
          pieces.push(item)
        }
      }
    }
    if !progress {
      return gf_edf_zassenhaus(f, n, p)
    }
  }
  _sort_factors(pieces)
}

///|
/// Factor a square-free polynomial over `GF(p)` using Zassenhaus.
///
/// - Does: Runs DDF followed by EDF and sorts the irreducible factors.
/// - Input: A monic square-free dense polynomial and prime modulus.
/// - Returns: Sorted monic irreducible factors.
/// - Limits: Same low-level assumptions as SymPy's helper.
pub fn gf_zassenhaus(
  f : Array[Int],
  p : Int,
) -> Array[Array[Int]] raise PolyError {
  let factors : Array[Array[Int]] = []
  for item in gf_ddf_zassenhaus(f, p) {
    for factor in gf_edf_zassenhaus(item.0, item.1, p) {
      factors.push(factor)
    }
  }
  _sort_factors(factors)
}

///|
/// Factor a square-free polynomial over `GF(p)` using Shoup.
///
/// - Does: Runs Shoup DDF/EDF and sorts the irreducible factors.
/// - Input: A monic square-free dense polynomial and prime modulus.
/// - Returns: Sorted monic irreducible factors.
/// - Limits: Deterministic random fallback keeps tests reproducible.
pub fn gf_shoup(f : Array[Int], p : Int) -> Array[Array[Int]] raise PolyError {
  let factors : Array[Array[Int]] = []
  for item in gf_ddf_shoup(f, p) {
    for factor in gf_edf_shoup(item.0, item.1, p) {
      factors.push(factor)
    }
  }
  _sort_factors(factors)
}

///|
/// Factor a square-free polynomial over `GF(p)`.
///
/// - Does: Returns `(lc, factors)` with monic irreducible factors.
/// - Input: Dense coefficients, prime modulus, and optional method name
///   `"berlekamp"`, `"zassenhaus"`, or `"shoup"`.
/// - Returns: Leading coefficient and sorted factor list.
/// - Limits: Unknown method names fall back to Zassenhaus.
pub fn gf_factor_sqf(
  f : Array[Int],
  p : Int,
  factor_method? : String = "",
) -> (Int, Array[Array[Int]]) raise PolyError {
  let lc = gf_LC(f)
  let monic = gf_monic(f, p)
  if gf_degree(monic) < 1 {
    return (lc, [])
  }
  let factors = match factor_method {
    "berlekamp" => gf_berlekamp(monic, p)
    "shoup" => gf_shoup(monic, p)
    _ => gf_zassenhaus(monic, p)
  }
  (lc, factors)
}

///|
/// Factor a finite-field polynomial, including repeated factors.
///
/// - Does: Runs square-free decomposition and factors each square-free part
///   into irreducibles.
/// - Input: Dense coefficients and a prime modulus.
/// - Returns: `(lc, [(factor, multiplicity), ...])`.
/// - Limits: Same dense `Int` representation and deterministic random limits
///   as the lower-level helpers.
pub fn gf_factor(
  f : Array[Int],
  p : Int,
) -> (Int, Array[(Array[Int], Int)]) raise PolyError {
  let lc = gf_LC(f)
  let monic = gf_monic(f, p)
  if gf_degree(monic) < 1 {
    return (lc, [])
  }
  let factors : Array[(Array[Int], Int)] = []
  let (_, sqf) = gf_sqf_list(monic, p)
  for item in sqf {
    let (_, irreducibles) = gf_factor_sqf(item.0, p)
    for factor in irreducibles {
      factors.push((factor, item.1))
    }
  }
  (lc, _sort_factors_multiple(factors))
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
