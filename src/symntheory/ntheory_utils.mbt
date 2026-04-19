///|
/// Shared helpers for ntheory.

///|
/// Public API `bi`.
///
/// - Does: Converts an Int into BigInt.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn bi(n : Int) -> BigInt {
  @bigint.BigInt::from_int(n)
}

///|
/// Public API `abs_bigint`.
///
/// - Does: Returns the absolute value of a BigInt.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn abs_bigint(n : BigInt) -> BigInt {
  if n < bi(0) {
    -n
  } else {
    n
  }
}

///|
/// Public API `is_even`.
///
/// - Does: Tests whether a BigInt is even.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn is_even(n : BigInt) -> Bool {
  (n % bi(2)).is_zero()
}

///|
/// Public API `pow_mod`.
///
/// - Does: Computes modular exponentiation.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn pow_mod(base : BigInt, exp : BigInt, modulus : BigInt) -> BigInt {
  base.pow(exp, modulus~)
}

///|
/// Public API `lcm`.
///
/// - Does: Computes the least common multiple of two integers.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn lcm(a : BigInt, b : BigInt) -> BigInt {
  let g = gcd(a, b)
  a / g * b
}

///|
/// Public API `to_int_checked`.
///
/// - Does: Converts a BigInt to Int after a bit-length guard.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn to_int_checked(n : BigInt, max_bits : Int) -> Int raise {
  if n.bit_length() > max_bits {
    fail("value too large for naive algorithms")
  }
  n.to_int()
}
