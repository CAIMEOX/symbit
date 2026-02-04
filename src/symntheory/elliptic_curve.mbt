///|
/// Minimal elliptic curve support (finite fields).

///|
pub struct EllipticCurve {
  a1 : BigInt
  a2 : BigInt
  a3 : BigInt
  a4 : BigInt
  a6 : BigInt
  modulus : BigInt
}

///|
pub fn EllipticCurve::new(
  a4 : BigInt,
  a6 : BigInt,
  a1? : BigInt = bi(0),
  a2? : BigInt = bi(0),
  a3? : BigInt = bi(0),
  modulus? : BigInt = bi(0),
) -> EllipticCurve {
  EllipticCurve::{ a1, a2, a3, a4, a6, modulus }
}

///|
pub fn EllipticCurve::characteristic(self : EllipticCurve) -> BigInt {
  self.modulus
}

///|
pub fn EllipticCurve::discriminant(self : EllipticCurve) -> BigInt {
  let b2 = self.a1 * self.a1 + bi(4) * self.a2
  let b4 = bi(2) * self.a4 + self.a1 * self.a3
  let b6 = self.a3 * self.a3 + bi(4) * self.a6
  let b8 = self.a1 * self.a1 * self.a6 +
    bi(4) * self.a2 * self.a6 -
    self.a1 * self.a3 * self.a4 +
    self.a2 * self.a3 * self.a3 -
    self.a4 * self.a4
  -b2 * b2 * b8 - bi(8) * b4 * b4 * b4 - bi(27) * b6 * b6 + bi(9) * b2 * b4 * b6
}

///|
pub fn EllipticCurve::contains(
  self : EllipticCurve,
  x : BigInt,
  y : BigInt,
) -> Bool {
  let left = y * y + self.a1 * x * y + self.a3 * y
  let right = x * x * x + self.a2 * x * x + self.a4 * x + self.a6
  if self.modulus <= bi(0) {
    left == right
  } else {
    mod_positive(left, self.modulus) == mod_positive(right, self.modulus)
  }
}

///|
pub fn EllipticCurve::points(
  self : EllipticCurve,
) -> Array[(BigInt, BigInt)] raise {
  if self.modulus <= bi(0) {
    fail("finite field modulus required")
  }
  let m = to_int_checked(self.modulus, 20)
  let out : Array[(BigInt, BigInt)] = Array::new()
  for xi in 0..<m {
    let x = bi(xi)
    for yi in 0..<m {
      let y = bi(yi)
      if self.contains(x, y) {
        out.push((x, y))
      }
    }
  }
  out
}

///|
pub fn EllipticCurve::points_x(
  self : EllipticCurve,
  x0 : BigInt,
) -> Array[(BigInt, BigInt)] raise {
  if self.modulus <= bi(0) {
    fail("finite field modulus required")
  }
  let m = to_int_checked(self.modulus, 20)
  let x = mod_positive(x0, self.modulus)
  let out : Array[(BigInt, BigInt)] = Array::new()
  for yi in 0..<m {
    let y = bi(yi)
    if self.contains(x, y) {
      out.push((x, y))
    }
  }
  out
}
