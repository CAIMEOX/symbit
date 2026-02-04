///|
/// Shared helpers for ntheory.

///|
pub fn bi(n : Int) -> BigInt {
  @bigint.BigInt::from_int(n)
}

///|
pub fn abs_bigint(n : BigInt) -> BigInt {
  if n < bi(0) {
    -n
  } else {
    n
  }
}

///|
pub fn is_even(n : BigInt) -> Bool {
  (n % bi(2)).is_zero()
}

///|
pub fn pow_mod(base : BigInt, exp : BigInt, modulus : BigInt) -> BigInt {
  base.pow(exp, modulus~)
}

///|
pub fn lcm(a : BigInt, b : BigInt) -> BigInt {
  let g = gcd(a, b)
  a / g * b
}

///|
pub fn to_int_checked(n : BigInt, max_bits : Int) -> Int raise {
  if n.bit_length() > max_bits {
    fail("value too large for naive algorithms")
  }
  n.to_int()
}
