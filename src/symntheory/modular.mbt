///|
/// Modular arithmetic utilities.

///|
/// Public type alias `BigInt`.
///
/// - Does: Aliases the core arbitrary-precision integer type used by ntheory.
/// - Input: Construct or reference it through the declared public type shape.
/// - Returns: `@bigint.BigInt`.
/// - Limits: This declaration does not validate values by itself; validation is performed by the functions that consume it.
pub type BigInt = @bigint.BigInt

///|
fn bi_zero() -> BigInt {
  @bigint.BigInt::from_int(0)
}

///|
fn bi_one() -> BigInt {
  @bigint.BigInt::from_int(1)
}

///|
fn bi_two() -> BigInt {
  @bigint.BigInt::from_int(2)
}

///|
fn bi_abs(x : BigInt) -> BigInt {
  if x < bi_zero() {
    -x
  } else {
    x
  }
}

///|
/// Public API `mod_positive`.
///
/// - Does: Normalizes a residue into the non-negative range modulo m.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn mod_positive(a : BigInt, m : BigInt) -> BigInt {
  let mut r = a % m
  if r < bi_zero() {
    r = r + m
  }
  r
}

///|
/// Public API `gcd`.
///
/// - Does: Computes the greatest common divisor of two integers.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn gcd(a : BigInt, b : BigInt) -> BigInt {
  let mut x = bi_abs(a)
  let mut y = bi_abs(b)
  while !y.is_zero() {
    let temp = x % y
    x = y
    y = temp
  }
  x
}

///|
/// Public API `gcd3`.
///
/// - Does: Computes the greatest common divisor of three integers.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn gcd3(a : BigInt, b : BigInt, c : BigInt) -> BigInt {
  gcd(gcd(a, b), c)
}

///|
/// Public API `gcdext`.
///
/// - Does: Computes gcd and Bezout coefficients for two integers.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `(BigInt, BigInt, BigInt)`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn gcdext(a : BigInt, b : BigInt) -> (BigInt, BigInt, BigInt) {
  if b.is_zero() {
    return (a, bi_one(), bi_zero())
  }
  let (g, x1, y1) = gcdext(b, a % b)
  let q = a / b
  (g, y1, x1 - q * y1)
}

///|
/// Public API `mod_inverse`.
///
/// - Does: Computes a modular inverse when one exists.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt?`.
/// - Limits: Returns `None` when the requested value does not exist or the supported search fails.
pub fn mod_inverse(a : BigInt, m : BigInt) -> BigInt? {
  let (g, x, _) = gcdext(a, m)
  if g != bi_one() {
    return None
  }
  Some(mod_positive(x, m))
}

///|
/// Public API `symmetric_residue`.
///
/// - Does: Returns the representative closest to zero modulo m.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn symmetric_residue(a : BigInt, m : BigInt) -> BigInt {
  let half = m / bi_two()
  if a <= half {
    a
  } else {
    a - m
  }
}

///|
fn prod(values : Array[BigInt]) -> BigInt {
  let mut acc = bi_one()
  for v in values {
    acc = acc * v
  }
  acc
}

///|
fn crt_coprime(v : Array[BigInt], m : Array[BigInt]) -> BigInt {
  let p = prod(m)
  let mut acc = bi_zero()
  for i in 0..<m.length() {
    let mi = m[i]
    let vi = v[i]
    let e = p / mi
    let inv = match mod_inverse(e, mi) {
      Some(value) => value
      None => bi_zero()
    }
    acc = acc + e * (vi * inv % mi)
  }
  mod_positive(acc, p)
}

///|
/// Public API `crt1`.
///
/// - Does: Precomputes Chinese-remainder data for a fixed modulus list.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `(BigInt, Array[BigInt], Array[BigInt])`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
pub fn crt1(m : Array[BigInt]) -> (BigInt, Array[BigInt], Array[BigInt]) {
  let p = prod(m)
  let e : Array[BigInt] = Array::new()
  let s : Array[BigInt] = Array::new()
  for mi in m {
    let ei = p / mi
    let inv = match mod_inverse(ei, mi) {
      Some(value) => value
      None => bi_zero()
    }
    e.push(ei)
    s.push(inv)
  }
  (p, e, s)
}

///|
/// Public API `crt2`.
///
/// - Does: Combines residues using data from crt1.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `(BigInt, BigInt)`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn crt2(
  m : Array[BigInt],
  v : Array[BigInt],
  mm : BigInt,
  e : Array[BigInt],
  s : Array[BigInt],
  symmetric? : Bool = false,
) -> (BigInt, BigInt) {
  let mut acc = bi_zero()
  for i in 0..<m.length() {
    let mi = m[i]
    acc = acc + e[i] * (v[i] * s[i] % mi)
  }
  let result = mod_positive(acc, mm)
  if symmetric {
    return (symmetric_residue(result, mm), mm)
  }
  (result, mm)
}

///|
/// Public API `crt`.
///
/// - Does: Solves a Chinese-remainder system.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `(BigInt, BigInt)?`.
/// - Limits: Returns `None` when the requested value does not exist or the supported search fails.
pub fn crt(
  m : Array[BigInt],
  v : Array[BigInt],
  symmetric? : Bool = false,
  check? : Bool = true,
) -> (BigInt, BigInt)? {
  if m.is_empty() {
    return None
  }
  let mm = prod(m)
  let mut result = crt_coprime(v, m)
  if check {
    for i in 0..<m.length() {
      let mi = m[i]
      let vi = mod_positive(v[i], mi)
      if mod_positive(result, mi) != vi {
        let alt = solve_congruence(zip_pairs(v, m), symmetric~, check=false)
        return alt
      }
    }
  }
  if symmetric {
    result = symmetric_residue(result, mm)
  }
  Some((result, mm))
}

///|
fn zip_pairs(
  remainders : Array[BigInt],
  moduli : Array[BigInt],
) -> Array[(BigInt, BigInt)] {
  let out : Array[(BigInt, BigInt)] = Array::new()
  for i in 0..<remainders.length() {
    out.push((remainders[i], moduli[i]))
  }
  out
}

///|
fn combine(c1 : (BigInt, BigInt), c2 : (BigInt, BigInt)) -> (BigInt, BigInt)? {
  let (a1, m1) = c1
  let (a2, m2) = c2
  let mut a = m1
  let mut b = a2 - a1
  let mut c = m2
  let g = gcd3(a, b, c)
  a = a / g
  b = b / g
  c = c / g
  if a != bi_one() {
    let (g2, inv_a, _) = gcdext(a, c)
    if g2 != bi_one() {
      return None
    }
    b = b * inv_a
  }
  let n = a1 + m1 * b
  let m = m1 * c
  Some((n, m))
}

///|
/// Public API `solve_congruence`.
///
/// - Does: Solves pairwise congruence data and returns a combined residue/modulus pair.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `(BigInt, BigInt)?`.
/// - Limits: Returns `None` when the requested value does not exist or the supported search fails.
pub fn solve_congruence(
  pairs : Array[(BigInt, BigInt)],
  symmetric? : Bool = false,
  check? : Bool = true,
) -> (BigInt, BigInt)? {
  let mut rm = pairs
  if check {
    let rebuilt : Array[(BigInt, BigInt)] = Array::new()
    for pair in rm {
      let (r0, m0) = pair
      let r = mod_positive(r0, m0)
      let mut found = false
      for i in 0..<rebuilt.length() {
        let (r_old, m_old) = rebuilt[i]
        if m_old == m0 {
          found = true
          if r_old != r {
            return None
          }
          break
        }
      }
      if !found {
        rebuilt.push((r, m0))
      }
    }
    rm = rebuilt
  }
  let mut current : (BigInt, BigInt) = (bi_zero(), bi_one())
  for pair in rm {
    match combine(current, pair) {
      Some(next) => {
        let (n, m) = next
        current = (mod_positive(n, m), m)
      }
      None => return None
    }
  }
  let (n, m) = current
  if symmetric {
    return Some((symmetric_residue(n, m), m))
  }
  Some((n, m))
}
