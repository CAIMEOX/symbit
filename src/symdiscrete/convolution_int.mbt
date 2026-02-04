///|
/// Integer convolution via packing.

///|
fn abs_int(n : Int) -> Int {
  if n < 0 { -n } else { n }
}

///|
pub fn convolution_int(a : Array[Int], b : Array[Int]) -> Array[Int] raise DiscreteError {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let mut max_a = 0
  for v in a {
    let av = abs_int(v)
    if av > max_a {
      max_a = av
    }
  }
  let mut max_b = 0
  for v in b {
    let bv = abs_int(v)
    if bv > max_b {
      max_b = bv
    }
  }
  let min_deg = if a.length() < b.length() { a.length() - 1 } else { b.length() - 1 }
  let bound = @bigint.BigInt::from_int(max_a) * @bigint.BigInt::from_int(max_b) * @bigint.BigInt::from_int(1 + min_deg)
  let mut x = @bigint.BigInt::from_int(1)
  let mut power = 0
  while x <= bound * @bigint.BigInt::from_int(2) {
    x = x << 1
    power = power + 1
  }

  fn to_integer(poly : Array[Int], power : Int) -> (Int, BigInt) {
    let mut n = @bigint.BigInt::from_int(0)
    let mut mul = 0
    for i in 0..<poly.length() {
      let c = poly[poly.length() - 1 - i]
      if c != 0 && mul == 0 {
        mul = if c < 0 { -1 } else { 1 }
      }
      n = n << power
      n = n + @bigint.BigInt::from_int(mul * c)
    }
    if mul == 0 {
      mul = 1
    }
    (mul, n)
  }

  let (a_mul, a_packed) = to_integer(a, power)
  let (b_mul, b_packed) = to_integer(b, power)
  let mut result = a_packed * b_packed

  let mul = a_mul * b_mul
  let mask = x - @bigint.BigInt::from_int(1)
  let half = x >> 1
  let mut borrow = @bigint.BigInt::from_int(0)
  let out : Array[Int] = Array::new()
  while !result.is_zero() || !borrow.is_zero() {
    let coeff = (result & mask) + borrow
    result = result >> power
    borrow = if coeff >= half { @bigint.BigInt::from_int(1) } else { @bigint.BigInt::from_int(0) }
    let raw = if coeff < half { coeff } else { coeff - x }
    let signed = if mul < 0 { raw.neg() } else { raw }
    let value = bigint_to_int_checked(signed, 62, "convolution_int")
    out.push(value)
  }
  if out.is_empty() {
    [0]
  } else {
    out
  }
}
