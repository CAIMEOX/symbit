///|
pub(all) suberror RationalError {
  ZeroDenominator
}

///|
pub impl Show for RationalError with output(self, logger : &Logger) -> Unit {
  match self {
    RationalError::ZeroDenominator => logger.write_string("ZeroDenominator")
  }
}

///|
pub struct BigRational {
  num : BigInt
  den : BigInt
}

///|
pub fn gcd_bigint(a : BigInt, b : BigInt) -> BigInt {
  loop (abs_bigint(a), abs_bigint(b)) {
    (x, y) if x.is_zero() => y
    (x, y) if y.is_zero() => x
    (x, y) => continue (y, x.mod(y))
  }
}

///|
fn abs_bigint(x : BigInt) -> BigInt {
  if x.op_lt(BigInt::from_int(0)) {
    x.neg()
  } else {
    x
  }
}

///|
fn normalize(num : BigInt, den : BigInt) -> BigRational {
  let sign_flip = den.op_lt(BigInt::from_int(0))
  let mut n = if sign_flip { num.neg() } else { num }
  let mut d = if sign_flip { den.neg() } else { den }
  let g = gcd_bigint(n, d)
  if !g.is_zero() {
    n = n.div(g)
    d = d.div(g)
  }
  BigRational::{ num: n, den: d }
}

///|
pub fn BigRational::new(num : BigInt, den : BigInt) -> Self raise RationalError {
  if den.is_zero() {
    raise RationalError::ZeroDenominator
  }
  normalize(num, den)
}

///|
pub fn BigRational::from_int(n : Int) -> Self {
  normalize(BigInt::from_int(n), BigInt::from_int(1))
}

///|
pub fn BigRational::from_bigint(n : BigInt) -> Self {
  normalize(n, BigInt::from_int(1))
}

///|
pub fn BigRational::zero() -> Self {
  normalize(BigInt::from_int(0), BigInt::from_int(1))
}

///|
pub fn BigRational::one() -> Self {
  normalize(BigInt::from_int(1), BigInt::from_int(1))
}

///|
pub fn BigRational::add_r(
  self : BigRational,
  other : BigRational,
) -> BigRational {
  let num = self.num.mul(other.den).add(other.num.mul(self.den))
  let den = self.den.mul(other.den)
  normalize(num, den)
}

///|
pub fn BigRational::mul_r(
  self : BigRational,
  other : BigRational,
) -> BigRational {
  let num = self.num.mul(other.num)
  let den = self.den.mul(other.den)
  normalize(num, den)
}

///|
pub fn BigRational::neg_r(self : BigRational) -> BigRational {
  BigRational::{ num: self.num.neg(), den: self.den }
}

///|
pub fn BigRational::compare(self : BigRational, other : BigRational) -> Int {
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
pub fn BigRational::reciprocal(
  self : BigRational,
) -> BigRational raise RationalError {
  if self.is_zero() {
    raise RationalError::ZeroDenominator
  }
  normalize(self.den, self.num)
}

///|
pub fn BigRational::div_r(
  self : BigRational,
  other : BigRational,
) -> BigRational raise RationalError {
  self.mul_r(try! other.reciprocal())
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
pub impl Eq for BigRational with equal(self, other : BigRational) -> Bool {
  self.num.equal(other.num) && self.den.equal(other.den)
}

///|
pub impl Eq for BigRational with not_equal(self, other : BigRational) -> Bool {
  !self.equal(other)
}

///|
pub impl Hash for BigRational with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for BigRational with hash_combine(self, hasher : Hasher) -> Unit {
  self.num.hash_combine(hasher)
  self.den.hash_combine(hasher)
}

///|
pub impl Show for BigRational with output(self, logger : &Logger) -> Unit {
  logger.write_string(format_rational(self))
}

///|
pub impl Add for BigRational with add(self, other : BigRational) -> BigRational {
  self.add_r(other)
}

///|
pub impl Mul for BigRational with mul(self, other : BigRational) -> BigRational {
  self.mul_r(other)
}

///|
pub impl Neg for BigRational with neg(self) -> BigRational {
  self.neg_r()
}
