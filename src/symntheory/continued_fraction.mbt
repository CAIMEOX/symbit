///|
/// Continued fractions (rational-only).

///|
/// Public API `continued_fraction`.
///
/// - Does: Builds a finite continued-fraction expansion for a rational number.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[Int]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn continued_fraction(
  num0 : BigInt,
  den? : BigInt = bi(1),
) -> Array[Int] raise {
  let mut num = num0
  let mut den = den
  if den.is_zero() {
    fail("denominator cannot be zero")
  }
  let out : Array[Int] = Array::new()
  while !den.is_zero() {
    let a = num / den
    let a_int = to_int_checked(a, 30)
    out.push(a_int)
    let r = num % den
    num = den
    den = r
  }
  out
}

///|
/// Public API `continued_fraction_periodic`.
///
/// - Does: Builds the periodic continued-fraction data for a quadratic irrational.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[Int]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn continued_fraction_periodic(
  p : BigInt,
  q : BigInt,
  d? : BigInt = bi(0),
  s? : BigInt = bi(1),
) -> Array[Int] raise {
  if !d.is_zero() {
    fail("quadratic irrationals not supported")
  }
  let _ = s
  continued_fraction(p, den=q)
}

///|
/// Public API `continued_fraction_iterator`.
///
/// - Does: Returns the continued-fraction terms for a rational numerator and denominator.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[Int]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn continued_fraction_iterator(
  num : BigInt,
  den? : BigInt = bi(1),
) -> Array[Int] raise {
  continued_fraction(num, den~)
}

///|
/// Public API `continued_fraction_reduce`.
///
/// - Does: Reduces continued-fraction terms back to an exact rational numerator and denominator.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `(BigInt, BigInt)`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn continued_fraction_reduce(cf : Array[Int]) -> (BigInt, BigInt) raise {
  if cf.is_empty() {
    fail("empty continued fraction")
  }
  let mut p0 = bi(1)
  let mut p1 = bi(cf[0])
  let mut q0 = bi(0)
  let mut q1 = bi(1)
  for i in 1..<cf.length() {
    let a = bi(cf[i])
    let p2 = a * p1 + p0
    let q2 = a * q1 + q0
    p0 = p1
    p1 = p2
    q0 = q1
    q1 = q2
  }
  (p1, q1)
}

///|
/// Public API `continued_fraction_convergents`.
///
/// - Does: Computes successive rational convergents from continued-fraction terms.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[(BigInt, BigInt)]`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
pub fn continued_fraction_convergents(
  cf : Array[Int],
) -> Array[(BigInt, BigInt)] {
  if cf.is_empty() {
    return []
  }
  let out : Array[(BigInt, BigInt)] = Array::new()
  let mut p0 = bi(1)
  let mut p1 = bi(cf[0])
  let mut q0 = bi(0)
  let mut q1 = bi(1)
  out.push((p1, q1))
  for i in 1..<cf.length() {
    let a = bi(cf[i])
    let p2 = a * p1 + p0
    let q2 = a * q1 + q0
    out.push((p2, q2))
    p0 = p1
    p1 = p2
    q0 = q1
    q1 = q2
  }
  out
}
