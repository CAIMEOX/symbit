///|
/// Primality testing utilities (naive + Miller-Rabin).

///|
pub let mersenne_prime_exponents : Array[Int] = [
  2, 3, 5, 7, 13, 17, 19, 31, 61, 89, 107, 127, 521, 607, 1279, 2203, 2281, 3217,
  4253, 4423, 9689, 9941, 11213, 19937, 21701, 23209, 44497, 86243, 110503, 132049,
  216091, 756839, 859433, 1257787, 1398269, 2976221, 3021377, 6972593, 13466917,
  20996011, 24036583, 25964951, 30402457, 32582657, 37156667, 42643801, 43112609,
  57885161, 74207281, 77232917, 82589933, 136279841,
]

///|
fn decompose(n : BigInt) -> (BigInt, Int) {
  let mut d = n
  let mut s = 0
  while (d % bi(2)).is_zero() {
    d = d / bi(2)
    s += 1
  }
  (d, s)
}

///|
fn miller_rabin_check(n : BigInt, a : BigInt, d : BigInt, s : Int) -> Bool {
  let mut x = pow_mod(a, d, n)
  if x == bi(1) || x == n - bi(1) {
    return true
  }
  let mut i = 1
  while i < s {
    x = x * x % n
    if x == n - bi(1) {
      return true
    }
    i += 1
  }
  false
}

///|
pub fn isprime(n0 : BigInt) -> Bool {
  let n = abs_bigint(n0)
  if n < bi(2) {
    return false
  }
  if n == bi(2) || n == bi(3) {
    return true
  }
  if is_even(n) {
    return false
  }
  let (d, s) = decompose(n - bi(1))
  let bases = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
  for b in bases {
    let a = bi(b)
    if a >= n {
      continue
    }
    if !miller_rabin_check(n, a, d, s) {
      return false
    }
  }
  true
}

///|
pub fn is_gaussian_prime(a0 : BigInt, b? : BigInt = bi(0)) -> Bool {
  let a = a0
  let b = b
  if a.is_zero() && b.is_zero() {
    return false
  }
  if a.is_zero() {
    let bb = abs_bigint(b)
    return isprime(bb) && bb % bi(4) == bi(3)
  }
  if b.is_zero() {
    let aa = abs_bigint(a)
    return isprime(aa) && aa % bi(4) == bi(3)
  }
  let norm = a * a + b * b
  isprime(norm)
}

///|
pub fn is_mersenne_prime(n0 : BigInt) -> Bool {
  let n = abs_bigint(n0)
  if n <= bi(1) {
    return false
  }
  let n1 = n + bi(1)
  if (n1 & (n1 - bi(1))).is_zero() {
    return isprime(n)
  }
  false
}
