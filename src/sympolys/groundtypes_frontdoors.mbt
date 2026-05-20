///|
/// Integer ground-type helpers re-exported by SymPy's polynomial domains.

///|
fn groundtypes_abs(n : Int) -> Int {
  if n < 0 {
    -n
  } else {
    n
  }
}

///|
/// Compute the integer greatest common divisor.
///
/// - Does: Mirrors SymPy's `python_gcd` helper.
/// - Input: Two integers.
/// - Returns: A non-negative greatest common divisor.
/// - Limits: Uses MoonBit `Int`, so very large Python integers are outside
///   this front door.
pub fn python_gcd(a : Int, b : Int) -> Int {
  let mut x = groundtypes_abs(a)
  let mut y = groundtypes_abs(b)
  while y != 0 {
    let r = x % y
    x = y
    y = r
  }
  x
}

///|
/// Compute the integer least common multiple.
///
/// - Does: Mirrors SymPy's `python_lcm` helper.
/// - Input: Two integers.
/// - Returns: A non-negative least common multiple; zero if either input is
///   zero.
/// - Limits: Uses MoonBit `Int`, so very large Python integers are outside
///   this front door.
pub fn python_lcm(a : Int, b : Int) -> Int {
  if a == 0 || b == 0 {
    0
  } else {
    groundtypes_abs(a / python_gcd(a, b) * b)
  }
}

///|
/// Compute extended integer gcd coefficients.
///
/// - Does: Mirrors SymPy's `python_gcdex`: returns `s, t, g` such that
///   `s*a + t*b == g`.
/// - Input: Two integers.
/// - Returns: Bezout coefficients and a non-negative gcd.
/// - Limits: Uses MoonBit `Int`, so very large Python integers are outside
///   this front door.
pub fn python_gcdex(a : Int, b : Int) -> (Int, Int, Int) {
  if a == 0 && b == 0 {
    return (0, 1, 0)
  }
  let sign_a = if a < 0 { -1 } else { 1 }
  let sign_b = if b < 0 { -1 } else { 1 }
  let mut old_r = groundtypes_abs(a)
  let mut r = groundtypes_abs(b)
  let mut old_s = 1
  let mut s = 0
  let mut old_t = 0
  let mut t = 1
  while r != 0 {
    let q = old_r / r
    let next_r = old_r - q * r
    old_r = r
    r = next_r
    let next_s = old_s - q * s
    old_s = s
    s = next_s
    let next_t = old_t - q * t
    old_t = t
    t = next_t
  }
  (old_s * sign_a, old_t * sign_b, old_r)
}
