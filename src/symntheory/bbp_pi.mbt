///|
/// BBP-based hexadecimal digits of pi.

///|
fn dn(n : Int, prec : Int) -> Int {
  let n1 = n + 1
  let sum = n1 + prec
  let bits = bi(sum).bit_length()
  let base = bits - 1
  let q = if base < 0 { -1 } else { base / 4 }
  q + prec + 3
}

///|
fn series(j : Int, n : Int, prec : Int) -> BigInt {
  let dval = dn(n, prec)
  let d4 = 4 * dval
  let mut s = bi(0)
  let mut d = j
  if n >= 0 {
    for k in 0..<=n {
      let exp = n - k
      let modpow = pow_mod(bi(16), bi(exp), bi(d))
      let term = (modpow << d4) / bi(d)
      s = s + term
      d += 8
    }
  }
  let mut t = bi(0)
  let k = n + 1
  let mut e = d4 - 4
  let mut d2 = 8 * k + j
  while e >= 0 {
    let dt = (bi(1) << e) / bi(d2)
    if dt.is_zero() {
      break
    }
    t = t + dt
    e -= 4
    d2 += 8
  }
  s + t
}

///|
pub fn pi_hex_digits(n0 : Int, prec? : Int = 14) -> String raise {
  let n = n0
  let prec0 = prec
  if n < 0 {
    fail("n cannot be negative")
  }
  if prec0 < 0 {
    fail("prec cannot be negative")
  }
  if prec0 == 0 {
    return ""
  }
  let n1 = n - 1
  let dval = dn(n1, prec0)
  let mask = (bi(1) << (4 * dval)) - bi(1)
  let s0 = series(1, n1, prec0)
  let s1 = series(4, n1, prec0)
  let s2 = series(5, n1, prec0)
  let s3 = series(6, n1, prec0)
  let x = (bi(4) * s0 - bi(2) * s1 - bi(1) * s2 - bi(1) * s3) & mask
  let shift = 4 * (dval - prec0)
  let value = x >> shift
  let digits = value.to_string(radix=16)
  let pad = prec0 - digits.length()
  if pad > 0 {
    "0".repeat(pad) + digits
  } else {
    digits
  }
}
