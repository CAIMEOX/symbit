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
