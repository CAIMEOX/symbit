///|
/// Digit utilities.

///|
pub fn digits(
  n0 : BigInt,
  b? : BigInt = bi(10),
  digits? : Int = -1,
) -> Array[Int] raise {
  let base = to_int_checked(b, 30)
  if base < 2 {
    fail("b must be greater than 1")
  }
  let n_int = to_int_checked(n0, 30)
  let mut x = if n_int < 0 { -n_int } else { n_int }
  let out : Array[Int] = Array::new()
  while x >= base {
    let r = x % base
    x = x / base
    out.push(r)
  }
  out.push(x)
  out.push(if n_int < 0 { -base } else { base })
  let rev = out.rev()
  let ndig = rev.length() - 1
  if digits >= 0 {
    if ndig > digits {
      fail("not enough digits")
    }
    if ndig < digits {
      let padded : Array[Int] = Array::new()
      padded.push(rev[0])
      for _ in 0..<(digits - ndig) {
        padded.push(0)
      }
      for i in 1..<rev.length() {
        padded.push(rev[i])
      }
      return padded
    }
  }
  rev
}

///|
pub fn count_digits(n : BigInt, b? : BigInt = bi(10)) -> Map[Int, Int] raise {
  let ds = digits(n, b~)
  let counts : Map[Int, Int] = {}
  for i in 1..<ds.length() {
    let d = ds[i]
    match counts.get(d) {
      Some(v) => counts[d] = v + 1
      None => counts[d] = 1
    }
  }
  counts
}

///|
pub fn is_palindromic(n : BigInt, b? : BigInt = bi(10)) -> Bool raise {
  let ds = digits(n, b~)
  let mut i = 1
  let mut j = ds.length() - 1
  while i < j {
    if ds[i] != ds[j] {
      return false
    }
    i += 1
    j -= 1
  }
  true
}
