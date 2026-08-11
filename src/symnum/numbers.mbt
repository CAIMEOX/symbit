///|
/// Error raised when constructing or inverting a rational with zero denominator.
pub(all) suberror RationalError {
  ZeroDenominator
} derive(Debug)

///|
pub impl Show for RationalError with fn output(self, logger : &Logger) -> Unit {
  match self {
    RationalError::ZeroDenominator => logger.write_string("ZeroDenominator")
  }
}

///|
/// Canonical exact rational number `num/den` with gcd normalization.
pub struct BigRational {
  num : BigInt
  den : BigInt
} derive(Eq, Hash)

///|
/// Greatest common divisor for arbitrary-precision integers.
pub fn gcd_bigint(a : BigInt, b : BigInt) -> BigInt {
  let mut x = abs_bigint(a)
  let mut y = abs_bigint(b)
  if x.is_zero() {
    return y
  }
  if y.is_zero() {
    return x
  }
  if x.equal_int(1) || y.equal_int(1) {
    return BigInt::from_int(1)
  }
  while !x.is_zero() && !y.is_zero() {
    let next = x.mod(y)
    x = y
    y = next
  }
  if x.is_zero() {
    y
  } else {
    x
  }
}

///|
fn abs_bigint(x : BigInt) -> BigInt {
  if x < BigInt::from_int(0) {
    x.neg()
  } else {
    x
  }
}

///|
fn divide_bigint_if_needed(value : BigInt, divisor : BigInt) -> BigInt {
  if divisor.equal_int(1) {
    value
  } else {
    value.div(divisor)
  }
}

///|
fn normalize_rational(num : BigInt, den : BigInt) -> BigRational {
  if num.is_zero() {
    return BigRational::{ num: BigInt::from_int(0), den: BigInt::from_int(1) }
  }
  if den.equal_int(1) {
    return BigRational::{ num, den }
  }
  let sign_flip = den < BigInt::from_int(0)
  let mut n = if sign_flip { num.neg() } else { num }
  let mut d = if sign_flip { den.neg() } else { den }
  if d.equal_int(1) {
    return BigRational::{ num: n, den: d }
  }
  if n.equal_int(1) || n.equal_int(-1) {
    return BigRational::{ num: n, den: d }
  }
  let g = gcd_bigint(n, d)
  if !g.equal_int(1) {
    n = n.div(g)
    d = d.div(g)
  }
  BigRational::{ num: n, den: d }
}

///|
/// Construct a normalized rational and validate that `den != 0`.
pub fn BigRational::new(num : BigInt, den : BigInt) -> Self raise RationalError {
  if den.is_zero() {
    raise RationalError::ZeroDenominator
  }
  normalize_rational(num, den)
}

///|
/// Construct an exact rational from an `Int`.
pub fn BigRational::from_int(n : Int) -> Self {
  normalize_rational(BigInt::from_int(n), BigInt::from_int(1))
}

///|
/// Construct an exact rational from integer numerator and denominator.
pub fn BigRational::from_ints(num : Int, den : Int) -> Self raise RationalError {
  BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
}

///|
/// Construct an exact rational from a `BigInt`.
pub fn BigRational::from_bigint(n : BigInt) -> Self {
  normalize_rational(n, BigInt::from_int(1))
}

///|
pub fn BigRational::zero() -> Self {
  normalize_rational(BigInt::from_int(0), BigInt::from_int(1))
}

///|
pub fn BigRational::one() -> Self {
  normalize_rational(BigInt::from_int(1), BigInt::from_int(1))
}

///|
/// Add two exact rationals.
pub fn BigRational::add_r(
  self : BigRational,
  other : BigRational,
) -> BigRational {
  if self.num.is_zero() {
    return other
  }
  if other.num.is_zero() {
    return self
  }
  if self.den.equal_int(1) {
    if other.den.equal_int(1) {
      return BigRational::{
        num: self.num.add(other.num),
        den: BigInt::from_int(1),
      }
    }
    return BigRational::{
      num: self.num.mul(other.den).add(other.num),
      den: other.den,
    }
  }
  if other.den.equal_int(1) {
    return BigRational::{
      num: self.num.add(self.den.mul(other.num)),
      den: self.den,
    }
  }
  let num = self.num.mul(other.den).add(other.num.mul(self.den))
  let den = self.den.mul(other.den)
  normalize_rational(num, den)
}

///|
/// Subtract two exact rationals.
pub fn BigRational::sub_r(
  self : BigRational,
  other : BigRational,
) -> BigRational {
  if other.num.is_zero() {
    return self
  }
  if self.num.is_zero() {
    return other.neg_r()
  }
  if self.den.equal_int(1) {
    if other.den.equal_int(1) {
      return BigRational::{
        num: self.num.sub(other.num),
        den: BigInt::from_int(1),
      }
    }
    return BigRational::{
      num: self.num.mul(other.den).sub(other.num),
      den: other.den,
    }
  }
  if other.den.equal_int(1) {
    return BigRational::{
      num: self.num.sub(self.den.mul(other.num)),
      den: self.den,
    }
  }
  let num = self.num.mul(other.den).sub(other.num.mul(self.den))
  let den = self.den.mul(other.den)
  normalize_rational(num, den)
}

///|
/// Multiply two exact rationals.
pub fn BigRational::mul_r(
  self : BigRational,
  other : BigRational,
) -> BigRational {
  if self.num.is_zero() || other.num.is_zero() {
    return BigRational::zero()
  }
  if self.den.equal_int(1) {
    if other.den.equal_int(1) {
      return BigRational::{
        num: self.num.mul(other.num),
        den: BigInt::from_int(1),
      }
    }
    let g = gcd_bigint(self.num, other.den)
    return BigRational::{
      num: divide_bigint_if_needed(self.num, g).mul(other.num),
      den: divide_bigint_if_needed(other.den, g),
    }
  }
  if other.den.equal_int(1) {
    let g = gcd_bigint(other.num, self.den)
    return BigRational::{
      num: self.num.mul(divide_bigint_if_needed(other.num, g)),
      den: divide_bigint_if_needed(self.den, g),
    }
  }
  let g1 = gcd_bigint(self.num, other.den)
  let g2 = gcd_bigint(self.den, other.num)
  BigRational::{
    num: divide_bigint_if_needed(self.num, g1).mul(
      divide_bigint_if_needed(other.num, g2),
    ),
    den: divide_bigint_if_needed(self.den, g2).mul(
      divide_bigint_if_needed(other.den, g1),
    ),
  }
}

///|
/// Negate a rational.
pub fn BigRational::neg_r(self : BigRational) -> BigRational {
  BigRational::{ num: self.num.neg(), den: self.den }
}

///|
/// Three-way comparison: negative, zero, or positive.
pub fn BigRational::compare(self : BigRational, other : BigRational) -> Int {
  if self.den.equal_int(1) {
    if other.den.equal_int(1) {
      return self.num.compare(other.num)
    }
    return self.num.mul(other.den).compare(other.num)
  }
  if other.den.equal_int(1) {
    return self.num.compare(self.den.mul(other.num))
  }
  if self.den == other.den {
    return self.num.compare(other.num)
  }
  self.num.mul(other.den).compare(other.num.mul(self.den))
}

///|
pub fn BigRational::is_zero(self : BigRational) -> Bool {
  self.num.is_zero()
}

///|
pub fn BigRational::is_one(self : BigRational) -> Bool {
  self.num.equal_int(1) && self.den.equal_int(1)
}

///|
pub fn BigRational::is_integral(self : BigRational) -> Bool {
  self.den.equal_int(1)
}

///|
pub fn BigRational::numerator(self : BigRational) -> BigInt {
  self.num
}

///|
pub fn BigRational::denominator(self : BigRational) -> BigInt {
  self.den
}

///|
/// Return the multiplicative inverse.
pub fn BigRational::reciprocal(
  self : BigRational,
) -> BigRational raise RationalError {
  if self.is_zero() {
    raise RationalError::ZeroDenominator
  }
  normalize_rational(self.den, self.num)
}

///|
/// Divide by another rational (`self * other.reciprocal()`).
pub fn BigRational::div_r(
  self : BigRational,
  other : BigRational,
) -> BigRational raise RationalError {
  if other.is_zero() {
    raise RationalError::ZeroDenominator
  }
  if self.num.is_zero() {
    return BigRational::zero()
  }
  if other.den.equal_int(1) {
    let g = gcd_bigint(self.num, other.num)
    let num = divide_bigint_if_needed(self.num, g)
    let den = self.den.mul(divide_bigint_if_needed(other.num, g))
    return normalize_rational(num, den)
  }
  let g1 = gcd_bigint(self.num, other.num)
  let g2 = gcd_bigint(self.den, other.den)
  let num = divide_bigint_if_needed(self.num, g1).mul(
    divide_bigint_if_needed(other.den, g2),
  )
  let den = divide_bigint_if_needed(self.den, g2).mul(
    divide_bigint_if_needed(other.num, g1),
  )
  normalize_rational(num, den)
}

///|
fn format_rational(value : BigRational) -> String {
  if value.den.equal_int(1) {
    value.num.to_string()
  } else {
    "\{value.num.to_string()}/\{value.den.to_string()}"
  }
}

///|
/// Print as `n` or `n/d` in normalized form.
pub impl Show for BigRational with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(format_rational(self))
}

///|
pub impl Add for BigRational with fn add(self, other : BigRational) -> BigRational {
  self.add_r(other)
}

///|
pub impl Sub for BigRational with fn sub(self, other : BigRational) -> BigRational {
  self.sub_r(other)
}

///|
pub impl Mul for BigRational with fn mul(self, other : BigRational) -> BigRational {
  self.mul_r(other)
}

///|
pub impl Neg for BigRational with fn neg(self) -> BigRational {
  self.neg_r()
}
