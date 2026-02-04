///|
/// Egyptian fraction decomposition (greedy).

///|
pub fn egyptian_fraction(num0 : BigInt, den0 : BigInt) -> Array[BigInt] raise {
  if den0.is_zero() {
    fail("denominator cannot be zero")
  }
  let mut num = num0
  let mut den = den0
  if num <= bi(0) || den <= bi(0) {
    fail("expecting positive rational")
  }
  let g = gcd(num, den)
  num = num / g
  den = den / g
  let out : Array[BigInt] = Array::new()
  while !num.is_zero() {
    let d = (den + num - bi(1)) / num
    out.push(d)
    num = num * d - den
    den = den * d
    if num.is_zero() {
      break
    }
    let g2 = gcd(num, den)
    num = num / g2
    den = den / g2
  }
  out
}
