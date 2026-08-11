///|
/// Add ``c*x**i`` to ``f`` in ``K[x]``.

///|
/// Public API `dup_add_term`.
///
/// - Does: Provides the `dup_add_term` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `k : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_add_term(
  f : Array[FieldElem],
  c : FieldElem,
  k : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if fe_is_zero(c) {
    return dup_normal(f)
  }
  let deg = f.length() - 1
  let zero = fe_from_int(0, domain)
  if deg < 0 {
    let out : Array[FieldElem] = Array::make(k + 1, zero)
    out.set(0, c)
    return dup_normal(out)
  }
  if k <= deg {
    let idx = deg - k
    let out = f.copy()
    out.set(idx, fe_add(out[idx], c))
    return dup_normal(out)
  }
  let shift = k - deg
  let out : Array[FieldElem] = Array::make(k + 1, zero)
  out.set(0, c)
  for i in 0..<f.length() {
    out.set(shift + i, f[i])
  }
  dup_normal(out)
}

///|
/// Subtract ``c*x**i`` from ``f`` in ``K[x]``.

///|
/// Public API `dup_sub_term`.
///
/// - Does: Provides the `dup_sub_term` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `k : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_sub_term(
  f : Array[FieldElem],
  c : FieldElem,
  k : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_add_term(f, fe_neg(c), k, domain)
}

///|
/// Multiply ``f`` by ``c*x**i`` in ``K[x]``.

///|
/// Public API `dup_mul_term`.
///
/// - Does: Provides the `dup_mul_term` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `k : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_mul_term(
  f : Array[FieldElem],
  c : FieldElem,
  k : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() || fe_is_zero(c) {
    return Array::new()
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(f.length() + k, zero)
  for i in 0..<f.length() {
    out.set(i, fe_mul(f[i], c))
  }
  dup_normal(out)
}

///|
/// Add an element of the ground domain to ``f``.

///|
/// Public API `dup_add_ground`.
///
/// - Does: Provides the `dup_add_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_add_ground(
  f : Array[FieldElem],
  c : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_add_term(f, c, 0, domain)
}

///|
/// Subtract an element of the ground domain from ``f``.

///|
/// Public API `dup_sub_ground`.
///
/// - Does: Provides the `dup_sub_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_sub_ground(
  f : Array[FieldElem],
  c : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_sub_term(f, c, 0, domain)
}

///|
/// Multiply ``f`` by a constant value in ``K[x]``.

///|
/// Public API `dup_mul_ground`.
///
/// - Does: Provides the `dup_mul_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `_domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_mul_ground(
  f : Array[FieldElem],
  c : FieldElem,
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() || fe_is_zero(c) {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::make(f.length(), f[0])
  for i in 0..<f.length() {
    out.set(i, fe_mul(f[i], c))
  }
  dup_normal(out)
}

///|
fn fe_quo_ground(
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(b) {
    raise DivisionByZero
  }
  match domain {
    ZZ => {
      let ar = fe_expect_rational(a)
      let br = fe_expect_rational(b)
      let num = ar.numerator().to_int()
      let den = br.numerator().to_int()
      let q = num / den
      fe_from_int(q, ZZ)
    }
    _ => fe_mul(a, fe_inv(b))
  }
}

///|
fn fe_exquo_ground(
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(b) {
    raise DivisionByZero
  }
  match domain {
    ZZ => {
      let ar = fe_expect_rational(a)
      let br = fe_expect_rational(b)
      let num = ar.numerator().to_int()
      let den = br.numerator().to_int()
      if num % den != 0 {
        raise ExactQuotientFailed
      }
      fe_from_int(num / den, ZZ)
    }
    _ => fe_mul(a, fe_inv(b))
  }
}

///|
/// Quotient by a constant in ``K[x]``.

///|
/// Public API `dup_quo_ground`.
///
/// - Does: Provides the `dup_quo_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_quo_ground(
  f : Array[FieldElem],
  c : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::make(f.length(), f[0])
  for i in 0..<f.length() {
    out.set(i, fe_quo_ground(f[i], c, domain))
  }
  dup_normal(out)
}

///|
/// Exact quotient by a constant in ``K[x]``.

///|
/// Public API `dup_exquo_ground`.
///
/// - Does: Provides the `dup_exquo_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `c : FieldElem`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_exquo_ground(
  f : Array[FieldElem],
  c : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::make(f.length(), f[0])
  for i in 0..<f.length() {
    out.set(i, fe_exquo_ground(f[i], c, domain))
  }
  dup_normal(out)
}

///|
/// Efficiently multiply ``f`` by ``x**n`` in ``K[x]``.

///|
/// Public API `dup_lshift`.
///
/// - Does: Provides the `dup_lshift` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `n : Int`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_lshift(
  f : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(f.length() + n, zero)
  for i in 0..<f.length() {
    out.set(i, f[i])
  }
  dup_normal(out)
}

///|
/// Efficiently divide ``f`` by ``x**n`` in ``K[x]``.

///|
/// Public API `dup_rshift`.
///
/// - Does: Provides the `dup_rshift` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `n : Int`, `_domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_rshift(
  f : Array[FieldElem],
  n : Int,
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  if n >= f.length() {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::new()
  for i in 0..<(f.length() - n) {
    out.push(f[i])
  }
  dup_normal(out)
}

///|
/// Negate a polynomial in ``K[x]``.

///|
/// Public API `dup_neg`.
///
/// - Does: Provides the `dup_neg` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `_domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_neg(
  f : Array[FieldElem],
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for c in f {
    out.push(fe_neg(c))
  }
  dup_normal(out)
}

///|
/// Make all coefficients positive in ``K[x]``.

///|
/// Public API `dup_abs`.
///
/// - Does: Provides the `dup_abs` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `_domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_abs(
  f : Array[FieldElem],
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for c in f {
    let r = fe_expect_rational(c)
    let sign = r.compare(@symnum.BigRational::zero())
    if sign < 0 {
      out.push(fe_neg(c))
    } else {
      out.push(c)
    }
  }
  dup_normal(out)
}

///|
/// Add dense polynomials in ``K[x]``.

///|
/// Public API `dup_add`.
///
/// - Does: Provides the `dup_add` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_add(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let n = f.length()
  let m = g.length()
  if n == 0 {
    return dup_normal(g)
  }
  if m == 0 {
    return dup_normal(f)
  }
  let max_len = if n > m { n } else { m }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(max_len, zero)
  for i in 0..<max_len {
    let fi = if i >= max_len - n { f[i - (max_len - n)] } else { zero }
    let gi = if i >= max_len - m { g[i - (max_len - m)] } else { zero }
    out.set(i, fe_add(fi, gi))
  }
  dup_normal(out)
}

///|
/// Subtract dense polynomials in ``K[x]``.

///|
/// Public API `dup_sub`.
///
/// - Does: Provides the `dup_sub` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_sub(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let n = f.length()
  let m = g.length()
  if m == 0 {
    return dup_normal(f)
  }
  if n == 0 {
    return dup_neg(g, domain)
  }
  let max_len = if n > m { n } else { m }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(max_len, zero)
  for i in 0..<max_len {
    let fi = if i >= max_len - n { f[i - (max_len - n)] } else { zero }
    let gi = if i >= max_len - m { g[i - (max_len - m)] } else { zero }
    out.set(i, fe_sub(fi, gi))
  }
  dup_normal(out)
}

///|
/// Multiply dense polynomials in ``K[x]``.

///|
/// Public API `dup_mul`.
///
/// - Does: Provides the `dup_mul` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_mul(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() || g.is_empty() {
    return Array::new()
  }
  let len = f.length() + g.length() - 1
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(len, zero)
  for i in 0..<f.length() {
    for j in 0..<g.length() {
      let idx = i + j
      let v = fe_add(out[idx], fe_mul(f[i], g[j]))
      out.set(idx, v)
    }
  }
  dup_normal(out)
}

///|
/// Square dense polynomials in ``K[x]``.

///|
/// Public API `dup_sqr`.
///
/// - Does: Provides the `dup_sqr` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_sqr(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_mul(f, f, domain)
}

///|
/// Raise ``f`` to the ``n``-th power in ``K[x]``.

///|
/// Public API `dup_pow`.
///
/// - Does: Provides the `dup_pow` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `n : Int`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_pow(
  f : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if n < 0 {
    raise BadExponent
  }
  if n == 0 {
    return [fe_from_int(1, domain)]
  }
  let mut result : Array[FieldElem] = [fe_from_int(1, domain)]
  let mut base = f
  let mut exp = n
  while exp > 0 {
    if exp % 2 == 1 {
      result = dup_mul(result, base, domain)
    }
    exp = exp / 2
    if exp > 0 {
      base = dup_mul(base, base, domain)
    }
  }
  result
}

///|
/// Multiply dense polynomials as truncated formal power series.
///
/// - Does: Computes `f*g mod x**n`, matching SymPy `dup_series_mul`.
/// - Input: Two dense univariate coefficient arrays, precision `n`, and a domain.
/// - Returns: A normalized dense coefficient array containing terms of degree `< n`.
/// - Limits: Uses the plain dense product kernel; SymPy's large-input Karatsuba
///   branch is an optimization detail, not a separate semantic front door.
pub fn dup_series_mul(
  f : Array[FieldElem],
  g : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() || g.is_empty() || n <= 0 {
    return []
  }
  dup_truncate(dup_mul(f, g, domain), n, domain)
}

///|
/// Square a dense polynomial as a truncated formal power series.
///
/// - Does: Computes `f**2 mod x**n`, matching SymPy `dup_series_sqr`.
/// - Input: One dense univariate coefficient array, precision `n`, and a domain.
/// - Returns: A normalized dense coefficient array containing terms of degree `< n`.
/// - Limits: Uses multiplication by itself for all sizes.
pub fn dup_series_sqr(
  f : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() || n <= 0 {
    return []
  }
  dup_series_mul(f, f, n, domain)
}

///|
/// Raise a dense polynomial as a truncated formal power series.
///
/// - Does: Computes `f**exp mod x**prec`, matching SymPy `dup_series_pow`.
/// - Input: One dense univariate coefficient array, a non-negative exponent,
///   precision, and a domain.
/// - Returns: A normalized dense coefficient array.
/// - Limits: Negative exponents raise `PolyError::BadExponent`.
pub fn dup_series_pow(
  f : Array[FieldElem],
  exp : Int,
  prec : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return []
  }
  if exp < 0 {
    raise BadExponent
  }
  if exp == 0 {
    return [fe_from_int(1, domain)]
  }
  if exp == 1 || (f.length() == 1 && fe_is_one(f[0])) {
    return dup_truncate(f, prec, domain)
  }
  dup_truncate(dup_pow(f, exp, domain), prec, domain)
}

///|
fn dmp_to_coeffs(f : DensePoly) -> Array[FieldElem] raise PolyError {
  match f {
    Coef(c) => dup_strip([c])
    Poly(items) => {
      if items.is_empty() {
        return Array::new()
      }
      let mut sample : FieldElem? = None
      for it in items {
        match it {
          Coef(c) => {
            sample = Some(c)
            break
          }
          Poly(_) => ()
        }
      }
      let zero = match sample {
        Some(c) => fe_sub(c, c)
        None =>
          if items.all(it => dmp_zero_p(it, 0)) {
            return Array::new()
          } else {
            raise NotUnivariate
          }
      }
      let coeffs : Array[FieldElem] = Array::new()
      for it in items {
        match it {
          Coef(c) => coeffs.push(c)
          Poly(_) =>
            if dmp_zero_p(it, 0) {
              coeffs.push(zero)
            } else {
              raise NotUnivariate
            }
        }
      }
      dup_strip(coeffs)
    }
  }
}

///|
fn dmp_from_coeffs(coeffs : Array[FieldElem]) -> DensePoly {
  if coeffs.is_empty() {
    Poly(Array::new())
  } else {
    let items : Array[DensePoly] = Array::make(coeffs.length(), Coef(coeffs[0]))
    for i in 0..<coeffs.length() {
      items.set(i, Coef(coeffs[i]))
    }
    Poly(items)
  }
}

///|
fn dmp_items(f : DensePoly) -> Array[DensePoly] {
  match f {
    Poly(items) => items
    Coef(c) => [Coef(c)]
  }
}

///|
/// Add ``c(x_2..x_u)*x_0**i`` to ``f`` in ``K[X]``.

///|
/// Public API `dmp_add_term`.
///
/// - Does: Provides the `dmp_add_term` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : DensePoly`, `k : Int`, `u : Int`, `domain
/// : Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_add_term(
  f : DensePoly,
  c : DensePoly,
  k : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let cc = match c {
      Coef(v) => v
      Poly(_) => fe_from_int(0, domain)
    }
    return dmp_from_coeffs(dup_add_term(fc, cc, k, domain))
  }
  if dmp_zero_p(c, u - 1) {
    return dmp_normal(f, u)
  }
  let items = dmp_items(f)
  let deg = items.length() - 1
  let zero = dmp_zero(u - 1)
  if deg < 0 {
    let out : Array[DensePoly] = Array::make(k + 1, zero)
    out.set(0, c)
    return dmp_strip(Poly(out))
  }
  if k <= deg {
    let idx = deg - k
    let out = items.copy()
    out.set(idx, dmp_add(out[idx], c, u - 1, domain))
    return dmp_strip(Poly(out))
  }
  let shift = k - deg
  let out : Array[DensePoly] = Array::make(k + 1, zero)
  out.set(0, c)
  for i in 0..<items.length() {
    out.set(shift + i, items[i])
  }
  dmp_strip(Poly(out))
}

///|
/// Subtract ``c(x_2..x_u)*x_0**i`` from ``f`` in ``K[X]``.

///|
/// Public API `dmp_sub_term`.
///
/// - Does: Provides the `dmp_sub_term` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : DensePoly`, `k : Int`, `u : Int`, `domain
/// : Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_sub_term(
  f : DensePoly,
  c : DensePoly,
  k : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_add_term(f, dmp_neg(c, u - 1, domain), k, u, domain)
}

///|
/// Multiply ``f`` by ``c(x_2..x_u)*x_0**i`` in ``K[X]``.

///|
/// Public API `dmp_mul_term`.
///
/// - Does: Provides the `dmp_mul_term` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : DensePoly`, `k : Int`, `u : Int`, `domain
/// : Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_mul_term(
  f : DensePoly,
  c : DensePoly,
  k : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let cc = match c {
      Coef(v) => v
      Poly(_) => fe_from_int(0, domain)
    }
    return dmp_from_coeffs(dup_mul_term(fc, cc, k, domain))
  }
  if dmp_zero_p(f, u) || dmp_zero_p(c, u - 1) {
    return dmp_zero(u)
  }
  let items = dmp_items(f)
  let zero = dmp_zero(u - 1)
  let out : Array[DensePoly] = Array::make(items.length() + k, zero)
  for i in 0..<items.length() {
    out.set(i, dmp_mul(items[i], c, u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Add an element of the ground domain to ``f``.

///|
/// Public API `dmp_add_ground`.
///
/// - Does: Provides the `dmp_add_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : FieldElem`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_add_ground(
  f : DensePoly,
  c : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_add_ground(fc, c, domain))
  }
  let ground = dmp_ground(c, u - 1)
  dmp_add_term(f, ground, 0, u, domain)
}

///|
/// Subtract an element of the ground domain from ``f``.

///|
/// Public API `dmp_sub_ground`.
///
/// - Does: Provides the `dmp_sub_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : FieldElem`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_sub_ground(
  f : DensePoly,
  c : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_sub_ground(fc, c, domain))
  }
  let ground = dmp_ground(c, u - 1)
  dmp_sub_term(f, ground, 0, u, domain)
}

///|
/// Multiply ``f`` by a constant value in ``K[X]``.

///|
/// Public API `dmp_mul_ground`.
///
/// - Does: Provides the `dmp_mul_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : FieldElem`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_mul_ground(
  f : DensePoly,
  c : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_mul_ground(fc, c, domain))
  }
  if dmp_zero_p(f, u) || fe_is_zero(c) {
    return dmp_zero(u)
  }
  let items = dmp_items(f)
  let out : Array[DensePoly] = Array::make(items.length(), dmp_zero(u - 1))
  for i in 0..<items.length() {
    out.set(i, dmp_mul_ground(items[i], c, u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Quotient by a constant in ``K[X]``.

///|
/// Public API `dmp_quo_ground`.
///
/// - Does: Provides the `dmp_quo_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : FieldElem`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_quo_ground(
  f : DensePoly,
  c : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_quo_ground(fc, c, domain))
  }
  let items = dmp_items(f)
  let out : Array[DensePoly] = Array::make(items.length(), dmp_zero(u - 1))
  for i in 0..<items.length() {
    out.set(i, dmp_quo_ground(items[i], c, u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Exact quotient by a constant in ``K[X]``.

///|
/// Public API `dmp_exquo_ground`.
///
/// - Does: Provides the `dmp_exquo_ground` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `c : FieldElem`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_exquo_ground(
  f : DensePoly,
  c : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_exquo_ground(fc, c, domain))
  }
  let items = dmp_items(f)
  let out : Array[DensePoly] = Array::make(items.length(), dmp_zero(u - 1))
  for i in 0..<items.length() {
    out.set(i, dmp_exquo_ground(items[i], c, u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Negate a polynomial in ``K[X]``.

///|
/// Public API `dmp_neg`.
///
/// - Does: Provides the `dmp_neg` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_neg(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_neg(fc, domain))
  }
  let items = dmp_items(f)
  let out : Array[DensePoly] = Array::make(items.length(), dmp_zero(u - 1))
  for i in 0..<items.length() {
    out.set(i, dmp_neg(items[i], u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Make all coefficients positive in ``K[X]``.

///|
/// Public API `dmp_abs`.
///
/// - Does: Provides the `dmp_abs` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_abs(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_abs(fc, domain))
  }
  let items = dmp_items(f)
  let out : Array[DensePoly] = Array::make(items.length(), dmp_zero(u - 1))
  for i in 0..<items.length() {
    out.set(i, dmp_abs(items[i], u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Add dense polynomials in ``K[X]``.

///|
/// Public API `dmp_add`.
///
/// - Does: Provides the `dmp_add` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_add(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let gc = dmp_to_coeffs(g)
    return dmp_from_coeffs(dup_add(fc, gc, domain))
  }
  if dmp_zero_p(f, u) {
    return dmp_strip(g)
  }
  if dmp_zero_p(g, u) {
    return dmp_strip(f)
  }
  let fi = dmp_items(f)
  let gi = dmp_items(g)
  let max_len = if fi.length() > gi.length() {
    fi.length()
  } else {
    gi.length()
  }
  let zero = dmp_zero(u - 1)
  let out : Array[DensePoly] = Array::make(max_len, zero)
  for i in 0..<max_len {
    let fi_idx = i - (max_len - fi.length())
    let gi_idx = i - (max_len - gi.length())
    let a = if fi_idx >= 0 { fi[fi_idx] } else { zero }
    let b = if gi_idx >= 0 { gi[gi_idx] } else { zero }
    out.set(i, dmp_add(a, b, u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Subtract dense polynomials in ``K[X]``.

///|
/// Public API `dmp_sub`.
///
/// - Does: Provides the `dmp_sub` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_sub(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let gc = dmp_to_coeffs(g)
    return dmp_from_coeffs(dup_sub(fc, gc, domain))
  }
  if dmp_zero_p(g, u) {
    return dmp_strip(f)
  }
  if dmp_zero_p(f, u) {
    return dmp_neg(g, u, domain)
  }
  let fi = dmp_items(f)
  let gi = dmp_items(g)
  let max_len = if fi.length() > gi.length() {
    fi.length()
  } else {
    gi.length()
  }
  let zero = dmp_zero(u - 1)
  let out : Array[DensePoly] = Array::make(max_len, zero)
  for i in 0..<max_len {
    let fi_idx = i - (max_len - fi.length())
    let gi_idx = i - (max_len - gi.length())
    let a = if fi_idx >= 0 { fi[fi_idx] } else { zero }
    let b = if gi_idx >= 0 { gi[gi_idx] } else { zero }
    out.set(i, dmp_sub(a, b, u - 1, domain))
  }
  dmp_strip(Poly(out))
}

///|
/// Multiply dense polynomials in ``K[X]``.

///|
/// Public API `dmp_mul`.
///
/// - Does: Provides the `dmp_mul` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_mul(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let gc = dmp_to_coeffs(g)
    return dmp_from_coeffs(dup_mul(fc, gc, domain))
  }
  if dmp_zero_p(f, u) || dmp_zero_p(g, u) {
    return dmp_zero(u)
  }
  let fi = dmp_items(f)
  let gi = dmp_items(g)
  let len = fi.length() + gi.length() - 1
  let zero = dmp_zero(u - 1)
  let out : Array[DensePoly] = Array::make(len, zero)
  for i in 0..<fi.length() {
    for j in 0..<gi.length() {
      let idx = i + j
      let term = dmp_mul(fi[i], gi[j], u - 1, domain)
      out.set(idx, dmp_add(out[idx], term, u - 1, domain))
    }
  }
  dmp_strip(Poly(out))
}

///|
/// Square dense polynomials in ``K[X]``.

///|
/// Public API `dmp_sqr`.
///
/// - Does: Provides the `dmp_sqr` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_sqr(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_mul(f, f, u, domain)
}

///|
/// Raise ``f`` to the ``n``-th power in ``K[X]``.

///|
/// Public API `dmp_pow`.
///
/// - Does: Provides the `dmp_pow` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `n : Int`, `u : Int`, `domain : Domain`, using
/// the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_pow(
  f : DensePoly,
  n : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if n < 0 {
    raise BadExponent
  }
  if n == 0 {
    return dmp_ground(fe_from_int(1, domain), u)
  }
  let mut result = dmp_ground(fe_from_int(1, domain), u)
  let mut base = f
  let mut exp = n
  while exp > 0 {
    if exp % 2 == 1 {
      result = dmp_mul(result, base, u, domain)
    }
    exp = exp / 2
    if exp > 0 {
      base = dmp_mul(base, base, u, domain)
    }
  }
  result
}

///|
fn domain_is_field(domain : Domain) -> Bool {
  match domain {
    ZZ => false
    QQ | CC | RR | QQ_I => true
    ZZ_I => false
    EX | EXRAW => true
    GF(_) | GFExt(_, _, _) => true
    Frac(_) => true
    PolyRing(_, _) => false
    RationalFunctionField(_, _) => true
    QuotientRing(_, _, _) => false
    PowerSeries(_, _, _) => false
    AlgExt(base, _, _) => domain_is_field(base)
  }
}

///|
fn fe_pow_local(base : FieldElem, exp : Int) -> FieldElem raise PolyError {
  if exp < 0 {
    return fe_inv(fe_pow_local(base, -exp))
  }
  let mut result = match base {
    QQ(_) => FieldElem::QQ(@symnum.BigRational::one())
    CC(_, _) => CC(@symnum.BigRational::one(), @symnum.BigRational::zero())
    GFp(p, _) => GFp(p, 1)
    GFExt(p, _, m) => GFExt(p, [1], m)
    AlgExt(base_d, _, minpoly, gen) =>
      AlgExt(base_d, [fe_from_int(1, base_d)], minpoly, gen)
  }
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = fe_mul(result, b)
    }
    e = e / 2
    if e > 0 {
      b = fe_mul(b, b)
    }
  }
  result
}

///|
fn fe_divides(
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> (Bool, FieldElem) raise PolyError {
  if fe_is_zero(b) {
    raise DivisionByZero
  }
  if domain_is_field(domain) {
    return (true, fe_mul(a, fe_inv(b)))
  }
  match domain {
    ZZ => {
      let ar = fe_expect_rational(a)
      let br = fe_expect_rational(b)
      if !ar.is_integral() || !br.is_integral() {
        return (false, fe_from_int(0, domain))
      }
      let num = ar.numerator()
      let den = br.numerator()
      if den.is_zero() {
        raise DivisionByZero
      }
      if !num.mod(den).is_zero() {
        return (false, fe_from_int(0, domain))
      }
      let q = num.div(den)
      let rat = @symnum.BigRational::from_bigint(q)
      (true, QQ(rat))
    }
    _ => (false, fe_from_int(0, domain))
  }
}

///|
/// Returns ``f + g*h`` where ``f, g, h`` are in ``K[x]``.

///|
/// Public API `dup_add_mul`.
///
/// - Does: Provides the `dup_add_mul` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `h :
/// Array[FieldElem]`, `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_add_mul(
  f : Array[FieldElem],
  g : Array[FieldElem],
  h : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_add(f, dup_mul(g, h, domain), domain)
}

///|
/// Returns ``f - g*h`` where ``f, g, h`` are in ``K[x]``.

///|
/// Public API `dup_sub_mul`.
///
/// - Does: Provides the `dup_sub_mul` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `h :
/// Array[FieldElem]`, `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_sub_mul(
  f : Array[FieldElem],
  g : Array[FieldElem],
  h : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_sub(f, dup_mul(g, h, domain), domain)
}

///|
/// Returns ``f + g*h`` where ``f, g, h`` are in ``K[X]``.

///|
/// Public API `dmp_add_mul`.
///
/// - Does: Provides the `dmp_add_mul` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `h : DensePoly`, `u : Int`,
/// `domain : Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_add_mul(
  f : DensePoly,
  g : DensePoly,
  h : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_add(f, dmp_mul(g, h, u, domain), u, domain)
}

///|
/// Returns ``f - g*h`` where ``f, g, h`` are in ``K[X]``.

///|
/// Public API `dmp_sub_mul`.
///
/// - Does: Provides the `dmp_sub_mul` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `h : DensePoly`, `u : Int`,
/// `domain : Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_sub_mul(
  f : DensePoly,
  g : DensePoly,
  h : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_sub(f, dmp_mul(g, h, u, domain), u, domain)
}

///|
/// Polynomial pseudo-division in ``K[x]``.

///|
/// Public API `dup_pdiv`.
///
/// - Does: Provides the `dup_pdiv` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, `) -> (Array[FieldElem]`, `Array[FieldElem]`, using the package
/// representation expected by the signature.
/// - Returns: a `(Array[FieldElem], Array[FieldElem])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_pdiv(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem]) raise PolyError {
  let df = dup_degree(f)
  let dg = dup_degree(g)
  if g.is_empty() {
    raise DivisionByZero
  }
  let mut q : Array[FieldElem] = Array::new()
  let mut r = f
  let mut dr = df
  if df < dg {
    return (q, r)
  }
  let mut n = df - dg + 1
  let lc_g = dup_LC(g)
  while true {
    let lc_r = dup_LC(r)
    let j = dr - dg
    n = n - 1
    let q_scaled = dup_mul_term(q, lc_g, 0, domain)
    q = dup_add_term(q_scaled, lc_r, j, domain)
    let r_scaled = dup_mul_term(r, lc_g, 0, domain)
    let g_scaled = dup_mul_term(g, lc_r, j, domain)
    r = dup_sub(r_scaled, g_scaled, domain)
    let prev_dr = dr
    dr = dup_degree(r)
    if dr < dg {
      break
    } else if !(dr < prev_dr) {
      raise PolynomialDivisionFailed
    }
  }
  let c = fe_pow_local(lc_g, n)
  q = dup_mul_term(q, c, 0, domain)
  r = dup_mul_term(r, c, 0, domain)
  (q, r)
}

///|
/// Polynomial pseudo-remainder in ``K[x]``.

///|
/// Public API `dup_prem`.
///
/// - Does: Provides the `dup_prem` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_prem(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_pdiv(f, g, domain).1
}

///|
/// Polynomial exact pseudo-quotient in ``K[X]``.

///|
/// Public API `dup_pquo`.
///
/// - Does: Provides the `dup_pquo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_pquo(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_pdiv(f, g, domain).0
}

///|
/// Polynomial pseudo-quotient in ``K[x]``.

///|
/// Public API `dup_pexquo`.
///
/// - Does: Provides the `dup_pexquo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_pexquo(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let (q, r) = dup_pdiv(f, g, domain)
  if r.is_empty() {
    q
  } else {
    raise ExactQuotientFailed
  }
}

///|
/// Polynomial pseudo-division in ``K[X]``.

///|
/// Public API `dmp_pdiv`.
///
/// - Does: Provides the `dmp_pdiv` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// `) -> (DensePoly` and 1 more parameter(s), using the package representation expected
/// by the signature.
/// - Returns: a `(DensePoly, DensePoly)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_pdiv(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (DensePoly, DensePoly) raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let gc = dmp_to_coeffs(g)
    let (q, r) = dup_pdiv(fc, gc, domain)
    return (dmp_from_coeffs(q), dmp_from_coeffs(r))
  }
  let df = dmp_degree(f, u)
  let dg = dmp_degree(g, u)
  if dg < 0 {
    raise DivisionByZero
  }
  let mut q = dmp_zero(u)
  let mut r = f
  let mut dr = df
  if df < dg {
    return (q, r)
  }
  let mut n = df - dg + 1
  let lc_g = dmp_LC(g)
  while true {
    let lc_r = dmp_LC(r)
    let j = dr - dg
    n = n - 1
    let q_scaled = dmp_mul_term(q, lc_g, 0, u, domain)
    q = dmp_add_term(q_scaled, lc_r, j, u, domain)
    let r_scaled = dmp_mul_term(r, lc_g, 0, u, domain)
    let g_scaled = dmp_mul_term(g, lc_r, j, u, domain)
    r = dmp_sub(r_scaled, g_scaled, u, domain)
    let prev_dr = dr
    dr = dmp_degree(r, u)
    if dr < dg {
      break
    } else if !(dr < prev_dr) {
      raise PolynomialDivisionFailed
    }
  }
  let c = dmp_pow(lc_g, n, u - 1, domain)
  q = dmp_mul_term(q, c, 0, u, domain)
  r = dmp_mul_term(r, c, 0, u, domain)
  (q, r)
}

///|
/// Polynomial pseudo-remainder in ``K[X]``.

///|
/// Public API `dmp_prem`.
///
/// - Does: Provides the `dmp_prem` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_prem(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_pdiv(f, g, u, domain).1
}

///|
/// Polynomial exact pseudo-quotient in ``K[X]``.

///|
/// Public API `dmp_pquo`.
///
/// - Does: Provides the `dmp_pquo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_pquo(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_pdiv(f, g, u, domain).0
}

///|
/// Polynomial pseudo-quotient in ``K[X]``.

///|
/// Public API `dmp_pexquo`.
///
/// - Does: Provides the `dmp_pexquo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_pexquo(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  let (q, r) = dmp_pdiv(f, g, u, domain)
  if dmp_zero_p(r, u) {
    q
  } else {
    raise ExactQuotientFailed
  }
}

///|
/// Univariate division with remainder over a ring.

///|
/// Public API `dup_rr_div`.
///
/// - Does: Provides the `dup_rr_div` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, `) -> (Array[FieldElem]`, `Array[FieldElem]`, using the package
/// representation expected by the signature.
/// - Returns: a `(Array[FieldElem], Array[FieldElem])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_rr_div(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem]) raise PolyError {
  let df = dup_degree(f)
  let dg = dup_degree(g)
  if g.is_empty() {
    raise DivisionByZero
  }
  let mut q : Array[FieldElem] = Array::new()
  let mut r = f
  let mut dr = df
  if df < dg {
    return (q, r)
  }
  let lc_g = dup_LC(g)
  while true {
    let lc_r = dup_LC(r)
    let (ok, c) = fe_divides(lc_r, lc_g, domain)
    if !ok {
      break
    }
    let j = dr - dg
    q = dup_add_term(q, c, j, domain)
    let h = dup_mul_term(g, c, j, domain)
    r = dup_sub(r, h, domain)
    let prev_dr = dr
    dr = dup_degree(r)
    if dr < dg {
      break
    } else if !(dr < prev_dr) {
      raise PolynomialDivisionFailed
    }
  }
  (q, r)
}

///|
/// Multivariate division with remainder over a ring.

///|
/// Public API `dmp_rr_div`.
///
/// - Does: Provides the `dmp_rr_div` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// `) -> (DensePoly` and 1 more parameter(s), using the package representation expected
/// by the signature.
/// - Returns: a `(DensePoly, DensePoly)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_rr_div(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (DensePoly, DensePoly) raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let gc = dmp_to_coeffs(g)
    let (q, r) = dup_rr_div(fc, gc, domain)
    return (dmp_from_coeffs(q), dmp_from_coeffs(r))
  }
  let df = dmp_degree(f, u)
  let dg = dmp_degree(g, u)
  if dg < 0 {
    raise DivisionByZero
  }
  let mut q = dmp_zero(u)
  let mut r = f
  let mut dr = df
  if df < dg {
    return (q, r)
  }
  let lc_g = dmp_LC(g)
  let v = u - 1
  while true {
    let lc_r = dmp_LC(r)
    let (c, rem) = dmp_rr_div(lc_r, lc_g, v, domain)
    if !dmp_zero_p(rem, v) {
      break
    }
    let j = dr - dg
    q = dmp_add_term(q, c, j, u, domain)
    let h = dmp_mul_term(g, c, j, u, domain)
    r = dmp_sub(r, h, u, domain)
    let prev_dr = dr
    dr = dmp_degree(r, u)
    if dr < dg {
      break
    } else if !(dr < prev_dr) {
      raise PolynomialDivisionFailed
    }
  }
  (q, r)
}

///|
/// Polynomial division with remainder over a field.

///|
/// Public API `dup_ff_div`.
///
/// - Does: Provides the `dup_ff_div` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, `) -> (Array[FieldElem]`, `Array[FieldElem]`, using the package
/// representation expected by the signature.
/// - Returns: a `(Array[FieldElem], Array[FieldElem])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_ff_div(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem]) raise PolyError {
  let df = dup_degree(f)
  let dg = dup_degree(g)
  if g.is_empty() {
    raise DivisionByZero
  }
  let mut q : Array[FieldElem] = Array::new()
  let mut r = f
  let mut dr = df
  if df < dg {
    return (q, r)
  }
  let lc_g = dup_LC(g)
  while true {
    let lc_r = dup_LC(r)
    let c = fe_mul(lc_r, fe_inv(lc_g))
    let j = dr - dg
    q = dup_add_term(q, c, j, domain)
    let h = dup_mul_term(g, c, j, domain)
    r = dup_sub(r, h, domain)
    let prev_dr = dr
    dr = dup_degree(r)
    if dr < dg {
      break
    } else if !(dr < prev_dr) {
      raise PolynomialDivisionFailed
    }
  }
  (q, r)
}

///|
/// Polynomial division with remainder over a field.

///|
/// Public API `dmp_ff_div`.
///
/// - Does: Provides the `dmp_ff_div` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// `) -> (DensePoly` and 1 more parameter(s), using the package representation expected
/// by the signature.
/// - Returns: a `(DensePoly, DensePoly)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_ff_div(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (DensePoly, DensePoly) raise PolyError {
  if u == 0 {
    let fc = dmp_to_coeffs(f)
    let gc = dmp_to_coeffs(g)
    let (q, r) = dup_ff_div(fc, gc, domain)
    return (dmp_from_coeffs(q), dmp_from_coeffs(r))
  }
  let df = dmp_degree(f, u)
  let dg = dmp_degree(g, u)
  if dg < 0 {
    raise DivisionByZero
  }
  let mut q = dmp_zero(u)
  let mut r = f
  let mut dr = df
  if df < dg {
    return (q, r)
  }
  let lc_g = dmp_LC(g)
  let v = u - 1
  while true {
    let lc_r = dmp_LC(r)
    let (c, rem) = dmp_ff_div(lc_r, lc_g, v, domain)
    if !dmp_zero_p(rem, v) {
      break
    }
    let j = dr - dg
    q = dmp_add_term(q, c, j, u, domain)
    let h = dmp_mul_term(g, c, j, u, domain)
    r = dmp_sub(r, h, u, domain)
    let prev_dr = dr
    dr = dmp_degree(r, u)
    if dr < dg {
      break
    } else if !(dr < prev_dr) {
      raise PolynomialDivisionFailed
    }
  }
  (q, r)
}

///|
/// Polynomial division with remainder in ``K[x]``.

///|
/// Public API `dup_div`.
///
/// - Does: Provides the `dup_div` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, `) -> (Array[FieldElem]`, `Array[FieldElem]`, using the package
/// representation expected by the signature.
/// - Returns: a `(Array[FieldElem], Array[FieldElem])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_div(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem]) raise PolyError {
  if domain_is_field(domain) {
    dup_ff_div(f, g, domain)
  } else {
    dup_rr_div(f, g, domain)
  }
}

///|
/// Returns polynomial remainder in ``K[x]``.

///|
/// Public API `dup_rem`.
///
/// - Does: Provides the `dup_rem` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_rem(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_div(f, g, domain).1
}

///|
/// Returns polynomial quotient in ``K[x]``.

///|
/// Public API `dup_quo`.
///
/// - Does: Provides the `dup_quo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_quo(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  dup_div(f, g, domain).0
}

///|
/// Returns exact polynomial quotient in ``K[x]``.

///|
/// Public API `dup_exquo`.
///
/// - Does: Provides the `dup_exquo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_exquo(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let (q, r) = dup_div(f, g, domain)
  if r.is_empty() {
    q
  } else {
    raise ExactQuotientFailed
  }
}

///|
/// Polynomial division with remainder in ``K[X]``.

///|
/// Public API `dmp_div`.
///
/// - Does: Provides the `dmp_div` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// `) -> (DensePoly` and 1 more parameter(s), using the package representation expected
/// by the signature.
/// - Returns: a `(DensePoly, DensePoly)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_div(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (DensePoly, DensePoly) raise PolyError {
  if domain_is_field(domain) {
    dmp_ff_div(f, g, u, domain)
  } else {
    dmp_rr_div(f, g, u, domain)
  }
}

///|
/// Returns polynomial remainder in ``K[X]``.

///|
/// Public API `dmp_rem`.
///
/// - Does: Provides the `dmp_rem` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_rem(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_div(f, g, u, domain).1
}

///|
/// Returns exact polynomial quotient in ``K[X]``.

///|
/// Public API `dmp_quo`.
///
/// - Does: Provides the `dmp_quo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_quo(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_div(f, g, u, domain).0
}

///|
/// Returns polynomial quotient in ``K[X]``.

///|
/// Public API `dmp_exquo`.
///
/// - Does: Provides the `dmp_exquo` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_exquo(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  let (q, r) = dmp_div(f, g, u, domain)
  if dmp_zero_p(r, u) {
    q
  } else {
    raise ExactQuotientFailed
  }
}

///|
fn fe_abs_rational(c : FieldElem) -> @symnum.BigRational raise PolyError {
  let r = fe_expect_rational(c)
  if r.compare(@symnum.BigRational::zero()) < 0 {
    r.neg_r()
  } else {
    r
  }
}

///|
/// Returns maximum norm of a polynomial in ``K[x]``.

///|
/// Public API `dup_max_norm`.
///
/// - Does: Provides the `dup_max_norm` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_max_norm(
  f : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  if f.is_empty() {
    return fe_from_int(0, domain)
  }
  let abs_vals = dup_abs(f, domain)
  let mut max_elem = abs_vals[0]
  let mut max_val = fe_abs_rational(max_elem)
  for i in 1..<abs_vals.length() {
    let v = fe_abs_rational(abs_vals[i])
    if v.compare(max_val) > 0 {
      max_val = v
      max_elem = abs_vals[i]
    }
  }
  max_elem
}

///|
/// Returns maximum norm of a polynomial in ``K[X]``.

///|
/// Public API `dmp_max_norm`.
///
/// - Does: Provides the `dmp_max_norm` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_max_norm(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  if u == 0 {
    let coeffs = dense_to_coeffs(f)
    return dup_max_norm(coeffs, domain)
  }
  match f {
    Coef(c) => dup_max_norm([c], domain)
    Poly(items) => {
      if items.is_empty() {
        return fe_from_int(0, domain)
      }
      let v = u - 1
      let mut max_elem = dmp_max_norm(items[0], v, domain)
      let mut max_val = fe_abs_rational(max_elem)
      for i in 1..<items.length() {
        let cur = dmp_max_norm(items[i], v, domain)
        let cur_val = fe_abs_rational(cur)
        if cur_val.compare(max_val) > 0 {
          max_val = cur_val
          max_elem = cur
        }
      }
      max_elem
    }
  }
}

///|
/// Returns l1 norm of a polynomial in ``K[x]``.

///|
/// Public API `dup_l1_norm`.
///
/// - Does: Provides the `dup_l1_norm` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_l1_norm(
  f : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  if f.is_empty() {
    return fe_from_int(0, domain)
  }
  let abs_vals = dup_abs(f, domain)
  let mut sum = fe_from_int(0, domain)
  for c in abs_vals {
    sum = fe_add(sum, c)
  }
  sum
}

///|
/// Returns l1 norm of a polynomial in ``K[X]``.

///|
/// Public API `dmp_l1_norm`.
///
/// - Does: Provides the `dmp_l1_norm` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_l1_norm(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  if u == 0 {
    let coeffs = dense_to_coeffs(f)
    return dup_l1_norm(coeffs, domain)
  }
  match f {
    Coef(c) => dup_l1_norm([c], domain)
    Poly(items) => {
      let v = u - 1
      let mut sum = fe_from_int(0, domain)
      for it in items {
        sum = fe_add(sum, dmp_l1_norm(it, v, domain))
      }
      sum
    }
  }
}

///|
/// Returns squared l2 norm of a polynomial in ``K[x]``.

///|
/// Public API `dup_l2_norm_squared`.
///
/// - Does: Provides the `dup_l2_norm_squared` operation for dense polynomial arithmetic.
/// - Input: parameters `f : Array[FieldElem]`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_l2_norm_squared(
  f : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let mut sum = fe_from_int(0, domain)
  for c in f {
    sum = fe_add(sum, fe_mul(c, c))
  }
  sum
}

///|
/// Returns squared l2 norm of a polynomial in ``K[X]``.

///|
/// Public API `dmp_l2_norm_squared`.
///
/// - Does: Provides the `dmp_l2_norm_squared` operation for dense polynomial arithmetic.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_l2_norm_squared(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  if u == 0 {
    let coeffs = dense_to_coeffs(f)
    return dup_l2_norm_squared(coeffs, domain)
  }
  match f {
    Coef(c) => dup_l2_norm_squared([c], domain)
    Poly(items) => {
      let v = u - 1
      let mut sum = fe_from_int(0, domain)
      for it in items {
        sum = fe_add(sum, dmp_l2_norm_squared(it, v, domain))
      }
      sum
    }
  }
}

///|
/// Multiply together several polynomials in ``K[x]``.

///|
/// Public API `dup_expand`.
///
/// - Does: Provides the `dup_expand` operation for dense polynomial arithmetic.
/// - Input: parameters `polys : Array[Array[FieldElem]]`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_expand(
  polys : Array[Array[FieldElem]],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if polys.is_empty() {
    return [fe_from_int(1, domain)]
  }
  let mut f = polys[0]
  for i in 1..<polys.length() {
    f = dup_mul(f, polys[i], domain)
  }
  f
}

///|
/// Multiply together several polynomials in ``K[X]``.

///|
/// Public API `dmp_expand`.
///
/// - Does: Provides the `dmp_expand` operation for dense polynomial arithmetic.
/// - Input: parameters `polys : Array[DensePoly]`, `u : Int`, `domain : Domain`, using
/// the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_expand(
  polys : Array[DensePoly],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if polys.is_empty() {
    return dmp_one(u, domain)
  }
  let mut f = polys[0]
  for i in 1..<polys.length() {
    f = dmp_mul(f, polys[i], u, domain)
  }
  f
}
