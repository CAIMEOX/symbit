///|
/// Truncated univariate power-series compatibility layer.
///
/// Current Limits:
/// - this file models truncated one-variable series only.
/// - transcendental and inverse operations follow the current exact domain
///   model and stay conservative outside characteristic-zero field inputs.

///|
/// Truncated power-series ring `K[[x]]/(x^prec)`.
///
/// - Does: Describes the coefficient domain, generator name, and truncation
///   precision for a univariate series ring.
/// - Input: Constructed from a `Domain`, generator `String`, and positive
///   precision.
/// - Returns: A `SeriesRing`.
/// - Limits: Precision must be positive and the ring is always univariate.
pub struct SeriesRing {
  domain : Domain
  sym : String
  precision : Int
} derive(Eq)

///|
/// Element in a truncated univariate power-series ring.
///
/// - Does: Stores a truncated series together with its parent ring.
/// - Input: A `SeriesRing` and coefficients in ascending degree order.
/// - Returns: A `SeriesElem`.
/// - Limits: Coefficients beyond the ring precision are discarded by the public
///   constructors.
pub struct SeriesElem {
  ring : SeriesRing
  coeffs : Array[FieldElem]
}

///|
/// Build a truncated univariate power-series ring.
///
/// - Does: Creates the public ring descriptor used by the series compatibility
///   API.
/// - Input: A coefficient `Domain`, generator `String`, and positive precision.
/// - Returns: A `SeriesRing`.
/// - Limits: Raises `PolyError::BadExponent` when `precision <= 0`.
pub fn power_series_ring(
  domain : Domain,
  sym : String,
  precision : Int,
) -> SeriesRing raise PolyError {
  if precision <= 0 {
    raise PolyError::BadExponent
  }
  SeriesRing::{ domain, sym, precision }
}

///|
fn normalize_series_coeffs(
  ring : SeriesRing,
  coeffs : Array[FieldElem],
) -> Array[FieldElem] {
  let mut end = coeffs.length()
  if end > ring.precision {
    end = ring.precision
  }
  while end > 0 && fe_is_zero(coeffs[end - 1]) {
    end = end - 1
  }
  let out : Array[FieldElem] = Array::new()
  for i in 0..<end {
    out.push(coeffs[i])
  }
  out
}

///|
fn series_coeffs_equal(lhs : Array[FieldElem], rhs : Array[FieldElem]) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if lhs[i].to_string() != rhs[i].to_string() {
      return false
    }
  }
  true
}

///|
fn series_shift_right(coeffs : Array[FieldElem], k : Int) -> Array[FieldElem] {
  if k <= 0 {
    return coeffs.copy()
  }
  if k >= coeffs.length() {
    return []
  }
  let out : Array[FieldElem] = Array::new()
  for i in k..<coeffs.length() {
    out.push(coeffs[i])
  }
  out
}

///|
fn series_shift_left(
  coeffs : Array[FieldElem],
  k : Int,
  precision : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if k <= 0 {
    return coeffs.copy()
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::new()
  let mut i = 0
  while i < k && i < precision {
    out.push(zero)
    i = i + 1
  }
  let mut j = 0
  while i + j < precision && j < coeffs.length() {
    out.push(coeffs[j])
    j = j + 1
  }
  out
}

///|
fn fe_series_exact_div(
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(b) {
    raise PolyError::DivisionByZero
  }
  if domain_is_field_pred(domain) {
    return fe_mul(a, fe_inv(b))
  }
  match domain {
    Domain::ZZ => {
      let ar = fe_expect_rational(a)
      let br = fe_expect_rational(b)
      if !ar.is_integral() || !br.is_integral() {
        raise PolyError::DomainMismatch
      }
      let num = ar.numerator()
      let den = br.numerator()
      if den.is_zero() {
        raise PolyError::DivisionByZero
      }
      if !num.mod(den).is_zero() {
        raise PolyError::DomainMismatch
      }
      fe_from_rational(@symnum.BigRational::from_bigint(num.div(den)), domain)
    }
    _ => raise PolyError::DomainMismatch
  }
}

///|
fn series_require_zero_constant(
  s : SeriesElem,
  op : String,
) -> Unit raise PolyError {
  if !domain_is_field_pred(s.ring.domain) {
    raise PolyError::DomainNotField
  }
  if !fe_is_zero(s.coeff(0)) {
    raise PolyError::BadGenerator(op)
  }
}

///|
fn series_factorial(n : Int) -> @symnum.BigRational {
  let mut acc = BigInt::from_int(1)
  for i in 2..<=n {
    acc = acc.mul(BigInt::from_int(i))
  }
  @symnum.BigRational::from_bigint(acc)
}

///|
fn series_inv_factorial_with_sign(
  n : Int,
  negate : Bool,
  domain : Domain,
) -> FieldElem raise PolyError {
  let mut q = poly_rational_div(@symnum.BigRational::one(), series_factorial(n))
  if negate {
    q = q.neg_r()
  }
  fe_from_rational(q, domain)
}

///|
fn series_bigint_square_root_nonnegative(value : BigInt) -> BigInt? {
  if value.op_lt(BigInt::from_int(0)) {
    return None
  }
  if value.is_zero() {
    return Some(BigInt::from_int(0))
  }
  let one = BigInt::from_int(1)
  let two = BigInt::from_int(2)
  let mut lo = BigInt::from_int(0)
  let mut hi = value.add(one)
  while lo.add(one).op_lt(hi) {
    let mid = lo.add(hi).div(two)
    let sq = mid.mul(mid)
    if sq.equal(value) {
      return Some(mid)
    }
    if sq.op_lt(value) {
      lo = mid
    } else {
      hi = mid
    }
  }
  None
}

///|
fn series_rational_square_root(
  value : @symnum.BigRational,
) -> @symnum.BigRational raise PolyError {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    raise PolyError::BadExponent
  }
  match
    (
      series_bigint_square_root_nonnegative(value.numerator()),
      series_bigint_square_root_nonnegative(value.denominator()),
    ) {
    (Some(num), Some(den)) =>
      @symnum.BigRational::new(num, den) catch {
        _ => raise PolyError::BadExponent
      }
    _ => raise PolyError::BadExponent
  }
}

///|
fn series_bigint_pow_nonnegative(base : BigInt, exp : Int) -> BigInt {
  let mut out = BigInt::from_int(1)
  for _ in 0..<exp {
    out = out.mul(base)
  }
  out
}

///|
fn series_bigint_nth_root_exact(value : BigInt, n : Int) -> BigInt? {
  if n <= 0 {
    return None
  }
  let zero = BigInt::from_int(0)
  let one = BigInt::from_int(1)
  let two = BigInt::from_int(2)
  let negative = value.op_lt(zero)
  if negative && n % 2 == 0 {
    return None
  }
  let target = if negative { value.neg() } else { value }
  if target.is_zero() {
    return Some(zero)
  }
  let mut lo = zero
  let mut hi = target.add(one)
  while lo.add(one).op_lt(hi) {
    let mid = lo.add(hi).div(two)
    let pow = series_bigint_pow_nonnegative(mid, n)
    if pow.equal(target) {
      return Some(if negative { mid.neg() } else { mid })
    }
    if pow.op_lt(target) {
      lo = mid
    } else {
      hi = mid
    }
  }
  None
}

///|
fn series_rational_nth_root(
  value : @symnum.BigRational,
  n : Int,
) -> @symnum.BigRational raise PolyError {
  match
    (
      series_bigint_nth_root_exact(value.numerator(), n),
      series_bigint_nth_root_exact(value.denominator(), n),
    ) {
    (Some(num), Some(den)) =>
      @symnum.BigRational::new(num, den) catch {
        _ => raise PolyError::BadExponent
      }
    _ => raise PolyError::BadExponent
  }
}

///|
fn series_binomial_rational(
  alpha : @symnum.BigRational,
  k : Int,
) -> @symnum.BigRational raise PolyError {
  let mut out = @symnum.BigRational::one()
  for i in 0..<k {
    let factor = alpha.sub_r(@symnum.BigRational::from_int(i))
    out = out.mul_r(factor)
    out = poly_rational_div(out, @symnum.BigRational::from_int(i + 1))
  }
  out
}

///|
/// Return the zero element of the ring.
///
/// - Does: Builds the additive identity in this series ring.
/// - Input: A `SeriesRing`.
/// - Returns: A `SeriesElem`.
/// - Limits: The result uses the ring precision and domain unchanged.
pub fn SeriesRing::zero(self : SeriesRing) -> SeriesElem {
  SeriesElem::{ ring: self, coeffs: [] }
}

///|
/// Return the multiplicative identity of the ring.
///
/// - Does: Builds the constant series `1`.
/// - Input: A `SeriesRing`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` only if the ground `1` cannot be represented in
///   the ring domain.
pub fn SeriesRing::one(self : SeriesRing) -> SeriesElem raise PolyError {
  SeriesElem::{ ring: self, coeffs: [fe_from_int(1, self.domain)] }
}

///|
/// Return the distinguished generator of the ring.
///
/// - Does: Builds the series `x` for this truncated ring.
/// - Input: A `SeriesRing`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` only if the ground coefficients cannot be
///   created in the ring domain.
pub fn SeriesRing::gen(self : SeriesRing) -> SeriesElem raise PolyError {
  let zero = fe_from_int(0, self.domain)
  let one = fe_from_int(1, self.domain)
  self.from_coeffs([zero, one])
}

///|
/// Build a series from coefficient data.
///
/// - Does: Normalizes and truncates an explicit coefficient array.
/// - Input: A `SeriesRing` and `Array[FieldElem]` in ascending degree order.
/// - Returns: A `SeriesElem`.
/// - Limits: Coefficients past the ring precision are dropped and trailing zeros
///   are removed.
pub fn SeriesRing::from_coeffs(
  self : SeriesRing,
  coeffs : Array[FieldElem],
) -> SeriesElem {
  SeriesElem::{ ring: self, coeffs: normalize_series_coeffs(self, coeffs) }
}

///|
/// Build a series from integer coefficients.
///
/// - Does: Lifts integer literals into the ring domain and normalizes the
///   resulting series.
/// - Input: A `SeriesRing` and `Array[Int]`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the ring domain cannot represent the input
///   integers.
pub fn SeriesRing::from_int_coeffs(
  self : SeriesRing,
  coeffs : Array[Int],
) -> SeriesElem raise PolyError {
  let lifted : Array[FieldElem] = Array::new()
  for c in coeffs {
    lifted.push(fe_from_int(c, self.domain))
  }
  self.from_coeffs(lifted)
}

///|
/// Convert a compatible univariate polynomial into a truncated series.
///
/// - Does: Reinterprets polynomial coefficients as series coefficients in the
///   same generator and domain.
/// - Input: A `SeriesRing` and a univariate `Poly`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::DomainMismatch` when the polynomial generator or
///   domain does not match the ring.
pub fn SeriesRing::from_poly(
  self : SeriesRing,
  poly : Poly,
) -> SeriesElem raise PolyError {
  if poly.gens.length() != 1 ||
    poly.gens[0] != self.sym ||
    poly.domain.not_equal(self.domain) {
    raise PolyError::DomainMismatch
  }
  let degree = poly.degree(0)
  let coeffs = to_dense(poly, degree~)
  self.from_coeffs(coeffs)
}

///|
/// Read a coefficient by degree.
///
/// - Does: Returns the coefficient of `x^n`, supplying zero when the stored
///   representation is shorter.
/// - Input: A `SeriesElem` and non-negative degree `Int`.
/// - Returns: A `FieldElem`.
/// - Limits: Raises `PolyError::BadExponent` when `n` is outside the ring
///   precision.
pub fn SeriesElem::coeff(
  self : SeriesElem,
  n : Int,
) -> FieldElem raise PolyError {
  if n < 0 || n >= self.ring.precision {
    raise PolyError::BadExponent
  }
  if n < self.coeffs.length() {
    self.coeffs[n]
  } else {
    fe_from_int(0, self.ring.domain)
  }
}

///|
/// Return the stored coefficient list.
///
/// - Does: Exposes the normalized truncated coefficients in ascending degree
///   order.
/// - Input: A `SeriesElem`.
/// - Returns: `Array[FieldElem]`.
/// - Limits: The array reflects the stored truncation, not an infinite series.
pub fn SeriesElem::to_list(self : SeriesElem) -> Array[FieldElem] {
  self.coeffs.copy()
}

///|
/// Compare two series by ring and stored coefficients.
///
/// - Does: Checks whether two series have the same parent ring and equal
///   normalized truncated coefficients.
/// - Input: Two `SeriesElem` values.
/// - Returns: A `Bool`.
/// - Limits: This compares the stored truncated representation only.
pub fn SeriesElem::equal_repr(self : SeriesElem, other : SeriesElem) -> Bool {
  self.ring == other.ring &&
  series_coeffs_equal(
    normalize_series_coeffs(self.ring, self.coeffs),
    normalize_series_coeffs(other.ring, other.coeffs),
  )
}

///|
/// Apply unary plus.
///
/// - Does: Returns the same series after coefficient normalization.
/// - Input: A `SeriesElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: This never changes the parent ring.
pub fn SeriesElem::positive(self : SeriesElem) -> SeriesElem {
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, self.coeffs),
  }
}

///|
/// Add two truncated series.
///
/// - Does: Computes coefficientwise addition inside a shared ring.
/// - Input: Two `SeriesElem` values from the same `SeriesRing`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::DomainMismatch` when the rings differ.
pub fn SeriesElem::add(
  self : SeriesElem,
  other : SeriesElem,
) -> SeriesElem raise PolyError {
  if self.ring != other.ring {
    raise PolyError::DomainMismatch
  }
  let n = if self.coeffs.length() > other.coeffs.length() {
    self.coeffs.length()
  } else {
    other.coeffs.length()
  }
  let coeffs : Array[FieldElem] = Array::new()
  for i in 0..<n {
    let a = if i < self.coeffs.length() {
      self.coeffs[i]
    } else {
      fe_from_int(0, self.ring.domain)
    }
    let b = if i < other.coeffs.length() {
      other.coeffs[i]
    } else {
      fe_from_int(0, self.ring.domain)
    }
    coeffs.push(fe_add(a, b))
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Negate a truncated series.
///
/// - Does: Negates every stored coefficient.
/// - Input: A `SeriesElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: This keeps the same parent ring and truncation.
pub fn SeriesElem::neg(self : SeriesElem) -> SeriesElem {
  SeriesElem::{ ring: self.ring, coeffs: self.coeffs.map(c => fe_neg(c)) }
}

///|
/// Subtract one truncated series from another.
///
/// - Does: Computes `self - other` inside a shared ring.
/// - Input: Two `SeriesElem` values from the same `SeriesRing`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::DomainMismatch` when the rings differ.
pub fn SeriesElem::sub(
  self : SeriesElem,
  other : SeriesElem,
) -> SeriesElem raise PolyError {
  self.add(other.neg())
}

///|
/// Add a scalar to the constant coefficient.
///
/// - Does: Updates the degree-zero term by adding a ground-domain scalar.
/// - Input: A `SeriesElem` and `FieldElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: The scalar must already belong to the ring domain.
pub fn SeriesElem::add_ground(
  self : SeriesElem,
  scalar : FieldElem,
) -> SeriesElem raise PolyError {
  let coeffs = self.coeffs.copy()
  if coeffs.is_empty() {
    coeffs.push(scalar)
  } else {
    coeffs.set(0, fe_add(coeffs[0], scalar))
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Subtract a scalar from the constant coefficient.
///
/// - Does: Updates the degree-zero term by subtracting a ground-domain scalar.
/// - Input: A `SeriesElem` and `FieldElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: The scalar must already belong to the ring domain.
pub fn SeriesElem::sub_ground(
  self : SeriesElem,
  scalar : FieldElem,
) -> SeriesElem raise PolyError {
  self.add_ground(fe_neg(scalar))
}

///|
/// Subtract a series from a scalar.
///
/// - Does: Computes `scalar - self`.
/// - Input: A `SeriesElem` and `FieldElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: The scalar must already belong to the ring domain.
pub fn SeriesElem::rsub_ground(
  self : SeriesElem,
  scalar : FieldElem,
) -> SeriesElem raise PolyError {
  self.neg().add_ground(scalar)
}

///|
/// Multiply a series by a scalar.
///
/// - Does: Multiplies every stored coefficient by a ground-domain scalar.
/// - Input: A `SeriesElem` and `FieldElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: The scalar must already belong to the ring domain.
pub fn SeriesElem::mul_ground(
  self : SeriesElem,
  scalar : FieldElem,
) -> SeriesElem raise PolyError {
  if fe_is_zero(scalar) {
    return self.ring.zero()
  }
  let coeffs : Array[FieldElem] = Array::new()
  for c in self.coeffs {
    coeffs.push(fe_mul(c, scalar))
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Multiply two truncated series.
///
/// - Does: Computes the truncated Cauchy product in a shared ring.
/// - Input: Two `SeriesElem` values from the same `SeriesRing`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::DomainMismatch` when the rings differ.
pub fn SeriesElem::mul(
  self : SeriesElem,
  other : SeriesElem,
) -> SeriesElem raise PolyError {
  if self.ring != other.ring {
    raise PolyError::DomainMismatch
  }
  let n = self.ring.precision
  let zero = fe_from_int(0, self.ring.domain)
  let coeffs : Array[FieldElem] = Array::make(n, zero)
  for i in 0..<self.coeffs.length() {
    for j in 0..<other.coeffs.length() {
      let k = i + j
      if k >= n {
        continue
      }
      let term = fe_mul(self.coeffs[i], other.coeffs[j])
      coeffs.set(k, fe_add(coeffs[k], term))
    }
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Square a truncated series.
///
/// - Does: Computes `self * self`.
/// - Input: A `SeriesElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: The result is truncated to the ring precision.
pub fn SeriesElem::square(self : SeriesElem) -> SeriesElem raise PolyError {
  self.mul(self)
}

///|
/// Raise a series to a non-negative integer power.
///
/// - Does: Computes `self^exp` by repeated squaring in the truncated ring.
/// - Input: A `SeriesElem` and non-negative `Int`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::BadExponent` for negative exponents.
pub fn SeriesElem::pow_int(
  self : SeriesElem,
  exp : Int,
) -> SeriesElem raise PolyError {
  if exp < 0 {
    raise PolyError::BadExponent
  }
  if exp == 0 {
    return self.ring.one()
  }
  let mut result = self.ring.one()
  let mut base = self
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result.mul(base)
    }
    e = e / 2
    if e > 0 {
      base = base.square()
    }
  }
  result
}

///|
/// Truncate a series to a lower precision bound.
///
/// - Does: Keeps coefficients below `n` and drops the rest.
/// - Input: A `SeriesElem` and cutoff `Int`.
/// - Returns: A `SeriesElem`.
/// - Limits: Negative cutoffs yield the zero series.
pub fn SeriesElem::truncate(self : SeriesElem, n : Int) -> SeriesElem {
  let limit = if n < 0 {
    0
  } else if n < self.ring.precision {
    n
  } else {
    self.ring.precision
  }
  let coeffs : Array[FieldElem] = Array::new()
  let end = if self.coeffs.length() < limit {
    self.coeffs.length()
  } else {
    limit
  }
  for i in 0..<end {
    coeffs.push(self.coeffs[i])
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Differentiate a truncated series.
///
/// - Does: Computes the formal derivative term by term.
/// - Input: A `SeriesElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: Terms past the ring precision remain truncated.
pub fn SeriesElem::diff(self : SeriesElem) -> SeriesElem raise PolyError {
  if self.coeffs.length() <= 1 {
    return self.ring.zero()
  }
  let coeffs : Array[FieldElem] = Array::new()
  for i in 1..<self.coeffs.length() {
    coeffs.push(fe_mul(fe_from_int(i, self.ring.domain), self.coeffs[i]))
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Integrate a truncated series term by term.
///
/// - Does: Computes a formal antiderivative with zero constant term.
/// - Input: A `SeriesElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::DomainNotField` when exact division by
///   positive integers is unavailable in the ring domain.
pub fn SeriesElem::integrate(self : SeriesElem) -> SeriesElem raise PolyError {
  if !domain_is_field_pred(self.ring.domain) {
    raise PolyError::DomainNotField
  }
  let coeffs : Array[FieldElem] = [fe_from_int(0, self.ring.domain)]
  for i in 0..<self.coeffs.length() {
    let den = fe_from_int(i + 1, self.ring.domain)
    coeffs.push(fe_mul(self.coeffs[i], fe_inv(den)))
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Return the order of vanishing.
///
/// - Does: Finds the smallest exponent with non-zero coefficient.
/// - Input: A `SeriesElem`.
/// - Returns: `Some(Int)` for a non-zero series, or `None` for the zero series.
/// - Limits: This reflects the stored truncated representation.
pub fn SeriesElem::valuation(self : SeriesElem) -> Int? {
  for i in 0..<self.coeffs.length() {
    if !fe_is_zero(self.coeffs[i]) {
      return Some(i)
    }
  }
  None
}

///|
/// Invert a truncated series.
///
/// - Does: Computes the multiplicative inverse in the truncated series ring.
/// - Input: A `SeriesElem` with non-zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` for zero series, non-units, or domains without
///   the needed exact division semantics.
pub fn SeriesElem::inverse(self : SeriesElem) -> SeriesElem raise PolyError {
  if self.coeffs.is_empty() {
    raise PolyError::DivisionByZero
  }
  match self.valuation() {
    Some(v) => if v != 0 { raise PolyError::BadExponent }
    None => raise PolyError::DivisionByZero
  }
  let n = self.ring.precision
  let zero = fe_from_int(0, self.ring.domain)
  let one = fe_from_int(1, self.ring.domain)
  let coeffs : Array[FieldElem] = Array::make(n, zero)
  let a0 = self.coeffs[0]
  coeffs.set(0, fe_series_exact_div(one, a0, self.ring.domain))
  for k in 1..<n {
    let mut acc = zero
    let upper = if k < self.coeffs.length() {
      k
    } else {
      self.coeffs.length() - 1
    }
    for i in 1..<=upper {
      let term = fe_mul(self.coeffs[i], coeffs[k - i])
      acc = fe_add(acc, term)
    }
    coeffs.set(k, fe_series_exact_div(fe_neg(acc), a0, self.ring.domain))
  }
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Divide one truncated series by another.
///
/// - Does: Computes the quotient when the division stays inside the truncated
///   ring.
/// - Input: Two `SeriesElem` values from the same ring.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` for mismatched rings, zero divisors, or
///   quotients that would require unsupported negative valuation.
pub fn SeriesElem::divide(
  self : SeriesElem,
  other : SeriesElem,
) -> SeriesElem raise PolyError {
  if self.ring != other.ring {
    raise PolyError::DomainMismatch
  }
  if other.coeffs.is_empty() {
    raise PolyError::DivisionByZero
  }
  if self.coeffs.is_empty() {
    return self.ring.zero()
  }
  let n = self.ring.precision
  let zero = fe_from_int(0, self.ring.domain)
  let v_num = match self.valuation() {
    Some(v) => v
    None => return self.ring.zero()
  }
  let v_den = match other.valuation() {
    Some(v) => v
    None => raise PolyError::DivisionByZero
  }
  if v_num < v_den {
    raise PolyError::BadExponent
  }
  let shift = v_num - v_den
  let num = series_shift_right(self.coeffs, v_num)
  let den = series_shift_right(other.coeffs, v_den)
  if den.is_empty() {
    raise PolyError::DivisionByZero
  }
  let q_len = if shift >= n { 0 } else { n - shift }
  let q_coeffs : Array[FieldElem] = Array::make(q_len, zero)
  let d0 = den[0]
  for k in 0..<q_len {
    let mut acc = if k < num.length() { num[k] } else { zero }
    let upper = if k < den.length() { k } else { den.length() - 1 }
    for i in 1..<=upper {
      let term = fe_mul(den[i], q_coeffs[k - i])
      acc = fe_sub(acc, term)
    }
    q_coeffs.set(k, fe_series_exact_div(acc, d0, self.ring.domain))
  }
  let coeffs = series_shift_left(
    q_coeffs,
    shift,
    self.ring.precision,
    self.ring.domain,
  )
  SeriesElem::{
    ring: self.ring,
    coeffs: normalize_series_coeffs(self.ring, coeffs),
  }
}

///|
/// Compose two truncated series.
///
/// - Does: Computes `self(other)` by Horner-style evaluation.
/// - Input: Two `SeriesElem` values from the same ring.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::BadExponent` unless `other(0) = 0`.
pub fn SeriesElem::compose(
  self : SeriesElem,
  other : SeriesElem,
) -> SeriesElem raise PolyError {
  if self.ring != other.ring {
    raise PolyError::DomainMismatch
  }
  if !fe_is_zero(other.coeff(0)) {
    raise PolyError::BadExponent
  }
  let mut out = self.ring.zero()
  let mut i = self.coeffs.length()
  while i > 0 {
    i = i - 1
    out = out.mul(other).add_ground(self.coeffs[i])
  }
  out
}

///|
fn series_compose_truncated(
  p : SeriesElem,
  q : SeriesElem,
) -> SeriesElem raise PolyError {
  if p.ring != q.ring {
    raise PolyError::DomainMismatch
  }
  let mut out = p.ring.zero()
  let mut i = p.coeffs.length()
  while i > 0 {
    i = i - 1
    out = out.mul(q).add_ground(p.coeffs[i])
  }
  out
}

///|
/// Compute the exponential of a series.
///
/// - Does: Expands `exp(self)` in the truncated ring.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::exp(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "exp")
  let mut out = self.ring.one()
  let mut term = self.ring.one()
  for k in 1..<self.ring.precision {
    term = term.mul(self).mul_ground(fe_inv(fe_from_int(k, self.ring.domain)))
    out = out.add(term)
  }
  out
}

///|
/// Compute `exp(self) - 1`.
///
/// - Does: Reuses the exponential front door and subtracts the constant `1`.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Shares the same preconditions as `SeriesElem::exp`.
pub fn SeriesElem::expm1(self : SeriesElem) -> SeriesElem raise PolyError {
  self.exp().sub_ground(fe_from_int(1, self.ring.domain))
}

///|
/// Compute the logarithm of a unit series.
///
/// - Does: Expands `log(self)` for a series whose constant term is `1`.
/// - Input: A `SeriesElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError::BadExponent` unless the constant term is `1`.
pub fn SeriesElem::log(self : SeriesElem) -> SeriesElem raise PolyError {
  let one = fe_from_int(1, self.ring.domain)
  if self.coeffs.is_empty() || !fe_is_zero(fe_sub(self.coeffs[0], one)) {
    raise PolyError::BadExponent
  }
  self.sub_ground(one).log1p()
}

///|
/// Compute `log(1 + self)`.
///
/// - Does: Expands the logarithm around zero using the truncated series model.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::log1p(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "log1p")
  let mut out = self.ring.zero()
  let mut term = self
  for k in 1..<self.ring.precision {
    let sign = if k % 2 == 1 { 1 } else { -1 }
    let coeff = fe_series_exact_div(
      fe_from_int(sign, self.ring.domain),
      fe_from_int(k, self.ring.domain),
      self.ring.domain,
    )
    out = out.add(term.mul_ground(coeff))
    term = term.mul(self)
  }
  out
}

///|
/// Compute a truncated square root.
///
/// - Does: Expands a square root in the current truncated ring.
/// - Input: A `SeriesElem`.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` for odd valuation, unsupported constant terms,
///   or domains without the required exact field semantics.
pub fn SeriesElem::sqrt(self : SeriesElem) -> SeriesElem raise PolyError {
  if !domain_is_field_pred(self.ring.domain) {
    raise PolyError::DomainNotField
  }
  match self.valuation() {
    None => self.ring.zero()
    Some(v) => {
      if v % 2 != 0 {
        raise PolyError::BadExponent
      }
      let shift = v / 2
      let core = SeriesElem::{
        ring: self.ring,
        coeffs: normalize_series_coeffs(
          self.ring,
          series_shift_right(self.coeffs, v),
        ),
      }
      if core.coeffs.is_empty() {
        return self.ring.zero()
      }
      let root0 = series_rational_square_root(
        fe_expect_rational(core.coeffs[0]),
      )
      let n = self.ring.precision - shift
      let zero = fe_from_int(0, self.ring.domain)
      let coeffs : Array[FieldElem] = Array::make(n, zero)
      coeffs.set(0, fe_from_rational(root0, self.ring.domain))
      let two = fe_from_int(2, self.ring.domain)
      for k in 1..<n {
        let mut acc = if k < core.coeffs.length() {
          core.coeffs[k]
        } else {
          zero
        }
        for i in 1..<k {
          acc = fe_sub(acc, fe_mul(coeffs[i], coeffs[k - i]))
        }
        let denom = fe_mul(two, coeffs[0])
        coeffs.set(k, fe_series_exact_div(acc, denom, self.ring.domain))
      }
      let shifted = series_shift_left(
        coeffs,
        shift,
        self.ring.precision,
        self.ring.domain,
      )
      SeriesElem::{
        ring: self.ring,
        coeffs: normalize_series_coeffs(self.ring, shifted),
      }
    }
  }
}

///|
/// Compute the sine of a series.
///
/// - Does: Expands `sin(self)` in the truncated ring.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::sin(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "sin")
  let mut out = self.ring.zero()
  let mut k = 0
  while 2 * k + 1 < self.ring.precision * 2 {
    let exp = 2 * k + 1
    let term = self
      .pow_int(exp)
      .mul_ground(
        series_inv_factorial_with_sign(exp, k % 2 == 1, self.ring.domain),
      )
    out = out.add(term)
    k = k + 1
  }
  out
}

///|
/// Compute the hyperbolic sine of a series.
///
/// - Does: Expands `sinh(self)` in the truncated ring.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::sinh(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "sinh")
  let mut out = self.ring.zero()
  let mut k = 0
  while 2 * k + 1 < self.ring.precision * 2 {
    let exp = 2 * k + 1
    let term = self
      .pow_int(exp)
      .mul_ground(series_inv_factorial_with_sign(exp, false, self.ring.domain))
    out = out.add(term)
    k = k + 1
  }
  out
}

///|
/// Compute the cosine of a series.
///
/// - Does: Expands `cos(self)` in the truncated ring.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::cos(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "cos")
  let mut out = self.ring.one()
  let mut k = 1
  while 2 * k < self.ring.precision * 2 {
    let exp = 2 * k
    let term = self
      .pow_int(exp)
      .mul_ground(
        series_inv_factorial_with_sign(exp, k % 2 == 1, self.ring.domain),
      )
    out = out.add(term)
    k = k + 1
  }
  out
}

///|
/// Compute the hyperbolic cosine of a series.
///
/// - Does: Expands `cosh(self)` in the truncated ring.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::cosh(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "cosh")
  let mut out = self.ring.one()
  let mut k = 1
  while 2 * k < self.ring.precision * 2 {
    let exp = 2 * k
    let term = self
      .pow_int(exp)
      .mul_ground(series_inv_factorial_with_sign(exp, false, self.ring.domain))
    out = out.add(term)
    k = k + 1
  }
  out
}

///|
/// Compute the tangent of a series.
///
/// - Does: Expands `tan(self)` through `sin/cos` in the truncated ring.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Shares the same domain and constant-term requirements as
///   `SeriesElem::sin` and `SeriesElem::cos`.
pub fn SeriesElem::tan(self : SeriesElem) -> SeriesElem raise PolyError {
  self.sin().divide(self.cos())
}

///|
/// Compute the hyperbolic tangent of a series.
///
/// - Does: Expands `tanh(self)` through `sinh/cosh` in the truncated ring.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Shares the same domain and constant-term requirements as
///   `SeriesElem::sinh` and `SeriesElem::cosh`.
pub fn SeriesElem::tanh(self : SeriesElem) -> SeriesElem raise PolyError {
  self.sinh().divide(self.cosh())
}

///|
/// Compute the arctangent of a series.
///
/// - Does: Expands `atan(self)` through the differential equation front door.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::atan(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "atan")
  let one = fe_from_int(1, self.ring.domain)
  self.diff().divide(self.square().add_ground(one)).integrate()
}

///|
/// Compute the hyperbolic arctangent of a series.
///
/// - Does: Expands `atanh(self)` through the differential equation front door.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::atanh(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "atanh")
  let one = fe_from_int(1, self.ring.domain)
  self.diff().divide(self.square().neg().add_ground(one)).integrate()
}

///|
/// Compute the arcsine of a series.
///
/// - Does: Expands `asin(self)` through the differential equation front door.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::asin(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "asin")
  let one = fe_from_int(1, self.ring.domain)
  self.diff().divide(self.square().neg().add_ground(one).sqrt()).integrate()
}

///|
/// Compute the hyperbolic arcsine of a series.
///
/// - Does: Expands `asinh(self)` through the differential equation front door.
/// - Input: A `SeriesElem` with zero constant term.
/// - Returns: A `SeriesElem`.
/// - Limits: Raises `PolyError` when the constant term is not zero.
pub fn SeriesElem::asinh(self : SeriesElem) -> SeriesElem raise PolyError {
  series_require_zero_constant(self, "asinh")
  let one = fe_from_int(1, self.ring.domain)
  self.diff().divide(self.square().add_ground(one).sqrt()).integrate()
}

///|
/// Convert a truncated series back to an expression.
///
/// - Does: Rebuilds the finite truncated polynomial expression represented by
///   the stored coefficients.
/// - Input: A `SeriesElem`.
/// - Returns: An `Expr`.
/// - Limits: Terms past the ring precision are not represented.
pub fn SeriesElem::to_expr(self : SeriesElem) -> Expr {
  let x = Expr::Symbol(self.ring.sym)
  let terms : Array[Expr] = Array::new()
  for i in 0..<self.coeffs.length() {
    let c = self.coeffs[i]
    if fe_is_zero(c) {
      continue
    }
    let coeff_expr = fe_to_expr_const(c)
    let term = if i == 0 {
      coeff_expr
    } else if i == 1 {
      coeff_expr * x
    } else {
      coeff_expr * (x ^ int(i))
    }
    terms.push(term)
  }
  if terms.is_empty() {
    int(0)
  } else {
    @symcore.add(terms)
  }
}

///|
fn series_precision_or_default(s : SeriesElem, prec : Int) -> Int {
  if prec < 0 {
    s.ring.precision
  } else {
    prec
  }
}

///|
fn series_at_precision(
  s : SeriesElem,
  prec : Int,
) -> SeriesElem raise PolyError {
  if prec <= 0 {
    raise PolyError::BadExponent
  }
  if prec == s.ring.precision {
    return s
  }
  let ring = SeriesRing::{
    domain: s.ring.domain,
    sym: s.ring.sym,
    precision: prec,
  }
  ring.from_coeffs(s.coeffs)
}

///|
fn series_pair_at_precision(
  a : SeriesElem,
  b : SeriesElem,
  prec : Int,
) -> (SeriesElem, SeriesElem) raise PolyError {
  if a.ring.domain.not_equal(b.ring.domain) || a.ring.sym != b.ring.sym {
    raise PolyError::DomainMismatch
  }
  let ring = SeriesRing::{
    domain: a.ring.domain,
    sym: a.ring.sym,
    precision: prec,
  }
  (ring.from_coeffs(a.coeffs), ring.from_coeffs(b.coeffs))
}

///|
/// Truncate a power series.
///
/// - Does: Mirrors SymPy `rs_trunc` for the univariate `SeriesElem` model.
/// - Input: A series and precision bound.
/// - Returns: A `SeriesElem` with terms below the bound.
/// - Limits: Only the package's univariate truncated series representation is
///   supported.
pub fn rs_trunc(p : SeriesElem, prec : Int) -> SeriesElem {
  p.truncate(prec)
}

///|
/// Multiply two truncated power series.
///
/// - Does: Mirrors SymPy `rs_mul` through the univariate series product.
/// - Input: Two compatible `SeriesElem` values and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Multivariate sparse-ring truncation is not modeled by this front
///   door.
pub fn rs_mul(
  p : SeriesElem,
  q : SeriesElem,
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  let n = series_precision_or_default(p, prec)
  let (a, b) = series_pair_at_precision(p, q, n)
  a.mul(b)
}

///|
/// Square a truncated power series.
///
/// - Does: Mirrors SymPy `rs_square` by multiplying the series by itself.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Uses the univariate truncated model.
pub fn rs_square(
  p : SeriesElem,
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  let n = series_precision_or_default(p, prec)
  series_at_precision(p, n).square()
}

///|
/// Raise a truncated power series to an integer power.
///
/// - Does: Mirrors SymPy `rs_pow` for integer exponents.
/// - Input: A `SeriesElem`, exponent, and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Negative exponents require a unit series; rational exponents use
///   `rs_nth_root` separately.
pub fn rs_pow(
  p : SeriesElem,
  n : Int,
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  let m = series_precision_or_default(p, prec)
  let base = series_at_precision(p, m)
  if n >= 0 {
    base.pow_int(n)
  } else {
    base.pow_int(-n).inverse()
  }
}

///|
/// Differentiate a truncated power series.
///
/// - Does: Mirrors SymPy `rs_diff` for the univariate generator.
/// - Input: A `SeriesElem`.
/// - Returns: Its formal derivative.
/// - Limits: There is no separate variable argument because `SeriesElem` is
///   univariate.
pub fn rs_diff(p : SeriesElem) -> SeriesElem raise PolyError {
  p.diff()
}

///|
/// Integrate a truncated power series.
///
/// - Does: Mirrors SymPy `rs_integrate` for the univariate generator.
/// - Input: A `SeriesElem`.
/// - Returns: A zero-constant antiderivative.
/// - Limits: Requires a domain where exact division by positive integers is
///   available.
pub fn rs_integrate(p : SeriesElem) -> SeriesElem raise PolyError {
  p.integrate()
}

///|
/// Invert a truncated power series.
///
/// - Does: Mirrors SymPy `rs_series_inversion` for unit series.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: Multiplicative inverse in the truncated ring.
/// - Limits: Laurent outputs with negative powers are not represented.
pub fn rs_series_inversion(
  p : SeriesElem,
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).inverse()
}

///|
/// Test whether a series uses Puiseux exponents.
///
/// - Does: Mirrors SymPy `rs_is_puiseux` for the package's regular
///   univariate representation.
/// - Input: A `SeriesElem`.
/// - Returns: `false`, because `SeriesElem` stores only non-negative integer
///   exponents.
/// - Limits: Negative and fractional powers are not representable in this
///   series model.
pub fn rs_is_puiseux(_p : SeriesElem) -> Bool {
  false
}

///|
/// Find the smallest exponent present in a series.
///
/// - Does: Mirrors SymPy `rs_min_pow` on an already-expanded univariate
///   `SeriesElem`.
/// - Input: A `SeriesElem`.
/// - Returns: The minimum non-zero exponent.
/// - Limits: Raises `PolyError::BadExponent` for the zero series, whose minimum
///   exponent is undefined.
pub fn rs_min_pow(p : SeriesElem) -> Int raise PolyError {
  match p.valuation() {
    Some(v) => v
    None => raise PolyError::BadExponent
  }
}

///|
fn series_elem_positive_nth_root(
  p : SeriesElem,
  n : Int,
) -> SeriesElem raise PolyError {
  if !domain_is_field_pred(p.ring.domain) {
    raise PolyError::DomainNotField
  }
  match p.valuation() {
    None => p.ring.zero()
    Some(v) => {
      if v % n != 0 {
        raise PolyError::BadExponent
      }
      let shift = v / n
      let inner_prec = p.ring.precision - shift
      if inner_prec <= 0 {
        return p.ring.zero()
      }
      let inner_ring = SeriesRing::{
        domain: p.ring.domain,
        sym: p.ring.sym,
        precision: inner_prec,
      }
      let core = inner_ring.from_coeffs(series_shift_right(p.coeffs, v))
      let c0 = core.coeff(0)
      let root0_rat = series_rational_nth_root(fe_expect_rational(c0), n)
      let root0 = fe_from_rational(root0_rat, p.ring.domain)
      let normalized_coeffs : Array[FieldElem] = []
      for coeff in core.coeffs {
        normalized_coeffs.push(fe_series_exact_div(coeff, c0, p.ring.domain))
      }
      let normalized = inner_ring.from_coeffs(normalized_coeffs)
      let delta = normalized.sub(inner_ring.one())
      let alpha = poly_rational_from_ints(1, n)
      let mut power = inner_ring.one()
      let mut out = inner_ring.zero()
      for k in 0..<inner_prec {
        if k > 0 {
          power = power.mul(delta)
        }
        let coeff = fe_from_rational(
          series_binomial_rational(alpha, k),
          p.ring.domain,
        )
        out = out.add(power.mul_ground(coeff))
      }
      out = out.mul_ground(root0)
      let shifted = series_shift_left(
        out.coeffs,
        shift,
        p.ring.precision,
        p.ring.domain,
      )
      SeriesElem::{
        ring: p.ring,
        coeffs: normalize_series_coeffs(p.ring, shifted),
      }
    }
  }
}

///|
/// Compute an integer nth root of a truncated series.
///
/// - Does: Mirrors SymPy `rs_nth_root` for regular univariate power series.
/// - Input: A `SeriesElem`, an integer root order, and optional precision.
/// - Returns: A `SeriesElem` satisfying the requested root expansion modulo the
///   stored precision.
/// - Limits: Fractional/Puiseux exponents and Laurent outputs are not
///   represented; constants must have exact rational nth roots in the current
///   domain.
pub fn rs_nth_root(
  p : SeriesElem,
  n : Int,
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  let q = series_at_precision(p, series_precision_or_default(p, prec))
  if n == 0 {
    match q.valuation() {
      None => raise PolyError::BadExponent
      Some(_) => q.ring.one()
    }
  } else if n == 1 {
    q
  } else if n < 0 {
    series_elem_positive_nth_root(q, -n).inverse()
  } else {
    series_elem_positive_nth_root(q, n)
  }
}

///|
/// Compute `exp(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_exp` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected instead of extending the
///   coefficient ring.
pub fn rs_exp(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).exp()
}

///|
/// Compute `log(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_log` on unit univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Requires constant term `1`.
pub fn rs_log(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).log()
}

///|
/// Compute `sin(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_sin` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_sin(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).sin()
}

///|
/// Compute `cos(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_cos` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_cos(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).cos()
}

///|
/// Compute both cosine and sine of a truncated series.
///
/// - Does: Mirrors SymPy `rs_cos_sin` by returning `(cos(p), sin(p))`.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A pair of `SeriesElem` values.
/// - Limits: Shares `rs_cos`/`rs_sin` preconditions.
pub fn rs_cos_sin(
  p : SeriesElem,
  prec? : Int = -1,
) -> (SeriesElem, SeriesElem) raise PolyError {
  let q = series_at_precision(p, series_precision_or_default(p, prec))
  (q.cos(), q.sin())
}

///|
/// Compute `tan(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_tan` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Shares the exact-division requirements of the series quotient.
pub fn rs_tan(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).tan()
}

///|
/// Compute `cot(p)` as a truncated series when it stays regular.
///
/// - Does: Mirrors SymPy `rs_cot` for regular quotients `cos(p)/sin(p)`.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Laurent terms such as `x**(-1)` are not represented and raise
///   `PolyError`.
pub fn rs_cot(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  let q = series_at_precision(p, series_precision_or_default(p, prec))
  q.cos().divide(q.sin())
}

///|
/// Compute `sinh(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_sinh` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_sinh(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).sinh()
}

///|
/// Compute `cosh(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_cosh` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_cosh(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).cosh()
}

///|
/// Compute both hyperbolic cosine and sine of a truncated series.
///
/// - Does: Mirrors SymPy `rs_cosh_sinh` by returning `(cosh(p), sinh(p))`.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A pair of `SeriesElem` values.
/// - Limits: Shares `rs_cosh`/`rs_sinh` preconditions.
pub fn rs_cosh_sinh(
  p : SeriesElem,
  prec? : Int = -1,
) -> (SeriesElem, SeriesElem) raise PolyError {
  let q = series_at_precision(p, series_precision_or_default(p, prec))
  (q.cosh(), q.sinh())
}

///|
/// Compute `tanh(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_tanh` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Shares the exact-division requirements of the series quotient.
pub fn rs_tanh(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).tanh()
}

///|
/// Compute `atan(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_atan` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_atan(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).atan()
}

///|
/// Compute `atanh(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_atanh` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_atanh(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).atanh()
}

///|
/// Compute `asin(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_asin` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_asin(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).asin()
}

///|
/// Compute `asinh(p)` as a truncated series.
///
/// - Does: Mirrors SymPy `rs_asinh` on zero-constant univariate input.
/// - Input: A `SeriesElem` and optional precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Non-zero constant terms are rejected.
pub fn rs_asinh(p : SeriesElem, prec? : Int = -1) -> SeriesElem raise PolyError {
  series_at_precision(p, series_precision_or_default(p, prec)).asinh()
}

///|
/// Sum a coefficient list against powers of a series.
///
/// - Does: Mirrors SymPy `rs_series_from_list` as `sum(c[i] * p**i)`.
/// - Input: A `SeriesElem`, coefficients in ascending power order, and optional
///   precision.
/// - Returns: A `SeriesElem`.
/// - Limits: Coefficients must already be representable in the series domain.
pub fn rs_series_from_list(
  p : SeriesElem,
  coeffs : Array[FieldElem],
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  let q = series_at_precision(p, series_precision_or_default(p, prec))
  let mut power = q.ring.one()
  let mut out = q.ring.zero()
  for i in 0..<coeffs.length() {
    if i > 0 {
      power = power.mul(q)
    }
    out = out.add(power.mul_ground(coeffs[i]))
  }
  out
}

///|
/// Substitute the generator by another truncated series.
///
/// - Does: Mirrors SymPy `rs_subs` for the package's univariate series model by
///   evaluating `p(replacement)` and truncating to `prec`.
/// - Input: Two compatible `SeriesElem` values and optional precision.
/// - Returns: The substituted `SeriesElem`.
/// - Limits: Only the single-generator substitution `{x: replacement}` is
///   modeled; simultaneous multivariate substitutions are outside this
///   representation.
pub fn rs_subs(
  p : SeriesElem,
  replacement : SeriesElem,
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  let n = series_precision_or_default(p, prec)
  let (pp, qq) = series_pair_at_precision(p, replacement, n)
  series_compose_truncated(pp, qq)
}

///|
fn series_invert_monoms(
  p : SeriesElem,
  precision : Int,
) -> SeriesElem raise PolyError {
  if p.coeffs.is_empty() {
    raise PolyError::DivisionByZero
  }
  let degree = p.coeffs.length() - 1
  let ring = SeriesRing::{ domain: p.ring.domain, sym: p.ring.sym, precision }
  let coeffs : Array[FieldElem] = Array::new()
  for i in 0..<precision {
    let src = degree - i
    coeffs.push(
      if src >= 0 && src < p.coeffs.length() {
        p.coeffs[src]
      } else {
        fe_from_int(0, p.ring.domain)
      },
    )
  }
  ring.from_coeffs(coeffs)
}

///|
/// Compute truncated Newton sums for a univariate polynomial series.
///
/// - Does: Mirrors SymPy `rs_newton`: reverse monomials, invert the reversed
///   polynomial as a series, multiply by its derivative, and shift back.
/// - Input: A finite univariate `SeriesElem` and precision `prec`.
/// - Returns: A `SeriesElem` containing Newton sums up to degree `prec`.
/// - Limits: Uses the package's univariate truncated representation; the zero
///   polynomial raises `PolyError::DivisionByZero`.
pub fn rs_newton(
  p : SeriesElem,
  prec? : Int = -1,
) -> SeriesElem raise PolyError {
  if p.coeffs.is_empty() {
    raise PolyError::DivisionByZero
  }
  let n = if prec < 0 { p.ring.precision - 1 } else { prec }
  if n < 0 {
    raise PolyError::BadExponent
  }
  let degree = p.coeffs.length() - 1
  let out_ring = SeriesRing::{
    domain: p.ring.domain,
    sym: p.ring.sym,
    precision: n + 1,
  }
  if n == 0 {
    return out_ring.from_coeffs([fe_from_int(degree, p.ring.domain)])
  }
  let p1 = series_invert_monoms(p, n)
  let p2 = p1.inverse()
  let p3 = p1.diff().mul(p2)
  let shifted = SeriesElem::{
    ring: out_ring,
    coeffs: normalize_series_coeffs(
      out_ring,
      series_shift_left(p3.coeffs, 1, n + 1, p.ring.domain),
    ),
  }
  shifted.neg().add_ground(fe_from_int(degree, p.ring.domain))
}

///|
/// Multiply a series by a power of the generator.
///
/// - Does: Mirrors SymPy `mul_xin` for the univariate series generator.
/// - Input: A `SeriesElem` and integer shift.
/// - Returns: A shifted `SeriesElem`.
/// - Limits: Negative shifts discard terms that would become negative powers.
pub fn mul_xin(p : SeriesElem, n : Int) -> SeriesElem raise PolyError {
  let coeffs = if n >= 0 {
    series_shift_left(p.coeffs, n, p.ring.precision, p.ring.domain)
  } else {
    series_shift_right(p.coeffs, -n)
  }
  SeriesElem::{ ring: p.ring, coeffs: normalize_series_coeffs(p.ring, coeffs) }
}

///|
/// Scale exponents of a univariate series.
///
/// - Does: Mirrors SymPy `pow_xin` by mapping `x**i` to `x**(i*n)`.
/// - Input: A `SeriesElem` and non-negative integer exponent scale.
/// - Returns: A `SeriesElem`.
/// - Limits: Fractional and negative exponent scales are outside the current
///   univariate representation.
pub fn pow_xin(p : SeriesElem, n : Int) -> SeriesElem raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  let zero = fe_from_int(0, p.ring.domain)
  let coeffs : Array[FieldElem] = Array::make(p.ring.precision, zero)
  for i in 0..<p.coeffs.length() {
    let j = i * n
    if j >= p.ring.precision {
      continue
    }
    coeffs.set(j, fe_add(coeffs[j], p.coeffs[i]))
  }
  SeriesElem::{ ring: p.ring, coeffs: normalize_series_coeffs(p.ring, coeffs) }
}

///|
/// Apply the exponential Hadamard transform.
///
/// - Does: Mirrors SymPy `rs_hadamard_exp` by dividing or multiplying the
///   coefficient of `x**i` by `i!`.
/// - Input: A `SeriesElem` and `inverse` flag.
/// - Returns: A `SeriesElem`.
/// - Limits: Requires an exact field domain for factorial division.
pub fn rs_hadamard_exp(
  p : SeriesElem,
  inverse? : Bool = false,
) -> SeriesElem raise PolyError {
  if !domain_is_field_pred(p.ring.domain) {
    raise PolyError::DomainNotField
  }
  let coeffs : Array[FieldElem] = []
  for i in 0..<p.coeffs.length() {
    let fact = fe_from_rational(series_factorial(i), p.ring.domain)
    coeffs.push(
      if inverse {
        fe_mul(p.coeffs[i], fact)
      } else {
        fe_series_exact_div(p.coeffs[i], fact, p.ring.domain)
      },
    )
  }
  SeriesElem::{ ring: p.ring, coeffs: normalize_series_coeffs(p.ring, coeffs) }
}
