///|
/// Minimal elliptic curve support (finite fields).

///|
/// Public struct `EllipticCurve`.
///
/// - Does: Stores the coefficients and modulus for a short elliptic-curve model over integers modulo p.
/// - Input: Construct or reference it through the declared public type shape.
/// - Returns: `a struct value when constructed`.
/// - Limits: This declaration does not validate values by itself; validation is performed by the functions that consume it.
pub struct EllipticCurve {
  a1 : BigInt
  a2 : BigInt
  a3 : BigInt
  a4 : BigInt
  a6 : BigInt
  modulus : BigInt
}

///|
/// Public API `EllipticCurve::new`.
///
/// - Does: Constructs an elliptic curve from coefficients and an optional modulus.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `EllipticCurve`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn EllipticCurve::new(
  a4 : BigInt,
  a6 : BigInt,
  a1? : BigInt = bi(0),
  a2? : BigInt = bi(0),
  a3? : BigInt = bi(0),
  modulus? : BigInt = bi(0),
) -> EllipticCurve {
  { a1, a2, a3, a4, a6, modulus }
}

///|
/// Public API `EllipticCurve::characteristic`.
///
/// - Does: Returns the modulus/field characteristic stored on the curve.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn EllipticCurve::characteristic(self : EllipticCurve) -> BigInt {
  self.modulus
}

///|
/// Public API `EllipticCurve::discriminant`.
///
/// - Does: Computes the curve discriminant for the stored coefficients.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `EllipticCurve::contains`.
///
/// - Does: Tests whether a point satisfies the curve equation modulo the characteristic.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `EllipticCurve::points`.
///
/// - Does: Enumerates affine points on the curve over the finite modulus.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[(BigInt, BigInt)]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
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
/// Public API `EllipticCurve::points_x`.
///
/// - Does: Enumerates x-coordinates that appear among finite-field points on the curve.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[(BigInt, BigInt)]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
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
