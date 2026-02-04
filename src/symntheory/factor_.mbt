///|
/// Integer factorization utilities (naive).

///|
fn inc_factor(map : Map[BigInt, Int], p : BigInt, delta : Int) -> Unit {
  match map.get(p) {
    Some(v) => map[p] = v + delta
    None => map[p] = delta
  }
}

///|
pub fn factorint(
  n0 : BigInt,
  limit? : BigInt = bi(0),
  use_trial? : Bool = true,
  use_rho? : Bool = true,
  use_pm1? : Bool = true,
) -> Map[BigInt, Int] {
  let _ = limit
  let _ = use_trial
  let _ = use_rho
  let _ = use_pm1
  let mut n = abs_bigint(n0)
  let factors : Map[BigInt, Int] = {}
  if n0 < bi(0) {
    factors[bi(-1)] = 1
  }
  if n < bi(2) {
    return factors
  }
  let mut count = 0
  while (n % bi(2)).is_zero() {
    n = n / bi(2)
    count += 1
  }
  if count > 0 {
    factors[bi(2)] = count
  }
  let mut d = bi(3)
  while d * d <= n {
    count = 0
    while (n % d).is_zero() {
      n = n / d
      count += 1
    }
    if count > 0 {
      factors[d] = count
    }
    d = d + bi(2)
  }
  if n > bi(1) {
    factors[n] = 1
  }
  factors
}

///|
pub fn multiplicity(p0 : BigInt, n0 : BigInt) -> Int {
  let p = abs_bigint(p0)
  let mut n = abs_bigint(n0)
  if p <= bi(1) {
    return 0
  }
  let mut count = 0
  while (n % p).is_zero() {
    n = n / p
    count += 1
  }
  count
}

///|
pub fn multiplicity_in_factorial(p0 : BigInt, n0 : BigInt) -> BigInt {
  let p = abs_bigint(p0)
  let mut n = abs_bigint(n0)
  if p <= bi(1) || n < bi(1) {
    return bi(0)
  }
  let mut count = bi(0)
  while n > bi(0) {
    n = n / p
    count = count + n
  }
  count
}

///|
fn divisors_from_factors(
  factors : Array[(BigInt, Int)],
  idx : Int,
  acc : BigInt,
  out : Array[BigInt],
) -> Unit {
  if idx >= factors.length() {
    out.push(acc)
    return
  }
  let (p, exp) = factors[idx]
  let mut value = bi(1)
  for _ in 0..<=exp {
    divisors_from_factors(factors, idx + 1, acc * value, out)
    value = value * p
  }
}

///|
pub fn divisors(n0 : BigInt, generator? : Bool = false) -> Array[BigInt] {
  let _ = generator
  let n = abs_bigint(n0)
  if n.is_zero() {
    return []
  }
  let f = factorint(n)
  let pairs : Array[(BigInt, Int)] = Array::new()
  for p, e in f {
    if p == bi(-1) {
      continue
    }
    pairs.push((p, e))
  }
  let out : Array[BigInt] = Array::new()
  divisors_from_factors(pairs, 0, bi(1), out)
  out.sort()
  out
}

///|
pub fn proper_divisors(n : BigInt, generator? : Bool = false) -> Array[BigInt] {
  let out = divisors(n, generator~)
  if out.is_empty() {
    return out
  }
  let res : Array[BigInt] = Array::new()
  for i in 0..<(out.length() - 1) {
    res.push(out[i])
  }
  res
}

///|
pub fn primefactors(n : BigInt) -> Array[BigInt] {
  let f = factorint(n)
  let out : Array[BigInt] = Array::new()
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    out.push(p)
  }
  out.sort()
  out
}

///|
pub fn totient(n : BigInt) -> BigInt {
  let f = factorint(n)
  let mut result = abs_bigint(n)
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    result = result / p * (p - bi(1))
  }
  result
}

///|
pub fn divisor_count(n : BigInt) -> BigInt {
  let f = factorint(n)
  let mut count = bi(1)
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    count = count * bi(e + 1)
  }
  count
}

///|
pub fn proper_divisor_count(n : BigInt) -> BigInt {
  let total = divisor_count(n)
  if total > bi(0) {
    total - bi(1)
  } else {
    bi(0)
  }
}

///|
pub fn divisor_sigma(n0 : BigInt, k? : Int = 1) -> BigInt {
  let n = abs_bigint(n0)
  if n.is_zero() {
    return bi(0)
  }
  if k == 0 {
    return divisor_count(n)
  }
  let divs = divisors(n)
  let mut acc = bi(0)
  for d in divs {
    acc = acc + d.pow(bi(k))
  }
  acc
}

///|
pub fn factorrat(num0 : BigInt, den? : BigInt = bi(1)) -> Map[BigInt, Int] {
  let mut num = num0
  let mut den = den
  let factors : Map[BigInt, Int] = {}
  if num < bi(0) {
    inc_factor(factors, bi(-1), 1)
    num = -num
  }
  if den < bi(0) {
    inc_factor(factors, bi(-1), 1)
    den = -den
  }
  let num_f = factorint(num)
  for p, e in num_f {
    if p == bi(-1) || e == 0 {
      continue
    }
    inc_factor(factors, p, e)
  }
  let den_f = factorint(den)
  for p, e in den_f {
    if p == bi(-1) || e == 0 {
      continue
    }
    inc_factor(factors, p, -e)
  }
  factors
}

///|
pub fn reduced_totient(n0 : BigInt) -> BigInt {
  let n = abs_bigint(n0)
  if n < bi(2) {
    return n
  }
  let f = factorint(n)
  let mut lambda = bi(1)
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    let term = if p == bi(2) {
      if e == 1 {
        bi(1)
      } else if e == 2 {
        bi(2)
      } else {
        bi(2).pow(bi(e - 2))
      }
    } else {
      (p - bi(1)) * p.pow(bi(e - 1))
    }
    lambda = lcm(lambda, term)
  }
  lambda
}

///|
pub fn primenu(n : BigInt) -> Int {
  let f = factorint(n)
  let mut count = 0
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    count += 1
  }
  count
}

///|
pub fn primeomega(n : BigInt) -> Int {
  let f = factorint(n)
  let mut count = 0
  for p, e in f {
    if p == bi(-1) || e <= 0 {
      continue
    }
    count += e
  }
  count
}

///|
pub fn mersenne_prime_exponent(nth : Int) -> Int raise {
  if nth < 1 || nth > mersenne_prime_exponents.length() {
    fail("nth must be in range")
  }
  mersenne_prime_exponents[nth - 1]
}

///|
pub fn is_perfect(n0 : BigInt) -> Bool {
  let n = abs_bigint(n0)
  if n < bi(1) {
    return false
  }
  divisor_sigma(n) == n * bi(2)
}

///|
pub fn abundance(n0 : BigInt) -> BigInt {
  let n = abs_bigint(n0)
  divisor_sigma(n) - n * bi(2)
}

///|
pub fn is_abundant(n0 : BigInt) -> Bool {
  abundance(n0) > bi(0)
}

///|
pub fn is_deficient(n0 : BigInt) -> Bool {
  abundance(n0) < bi(0)
}

///|
pub fn is_amicable(m0 : BigInt, n0 : BigInt) -> Bool {
  let m = abs_bigint(m0)
  let n = abs_bigint(n0)
  if m == n {
    return false
  }
  divisor_sigma(m) - m == n && divisor_sigma(n) - n == m
}

///|
pub fn is_carmichael(n0 : BigInt) -> Bool {
  let n = abs_bigint(n0)
  if n < bi(561) {
    return false
  }
  if isprime(n) {
    return false
  }
  let f = factorint(n)
  for p, e in f {
    if p == bi(-1) {
      continue
    }
    if e != 1 {
      return false
    }
    if (n - bi(1)) % (p - bi(1)) != bi(0) {
      return false
    }
  }
  true
}

///|
pub fn perfect_power(n0 : BigInt) -> (BigInt, Int)? raise {
  let n = abs_bigint(n0)
  if n <= bi(1) {
    return None
  }
  let n_int = to_int_checked(n, 30)
  let max_exp = 10
  let mut exp = max_exp
  while exp >= 2 {
    let mut base = 2
    while true {
      let mut pow = 1
      for _ in 0..<exp {
        pow *= base
      }
      if pow == n_int {
        return Some((bi(base), exp))
      }
      if pow > n_int {
        break
      }
      base += 1
    }
    exp -= 1
  }
  None
}

///|
pub fn pollard_rho(n0 : BigInt) -> BigInt? {
  let n = abs_bigint(n0)
  if n <= bi(1) {
    return None
  }
  if (n % bi(2)).is_zero() {
    return Some(bi(2))
  }
  let mut x = bi(2)
  let mut y = bi(2)
  let c = bi(1)
  let mut d = bi(1)
  while d == bi(1) {
    x = (x * x + c) % n
    y = (y * y + c) % n
    y = (y * y + c) % n
    let diff = if x > y { x - y } else { y - x }
    d = gcd(diff, n)
  }
  if d == n {
    None
  } else {
    Some(d)
  }
}

///|
pub fn pollard_pm1(n0 : BigInt, bound? : Int = 10) -> BigInt? {
  let n = abs_bigint(n0)
  if n <= bi(1) {
    return None
  }
  let mut a = bi(2)
  for _ in 2..<=bound {
    a = pow_mod(a, bi(2), n)
    let g = gcd(a - bi(1), n)
    if g != bi(1) && g != n {
      return Some(g)
    }
  }
  None
}

///|
pub fn dra(n0 : BigInt, b0 : BigInt) -> BigInt raise {
  let n = abs_bigint(n0)
  let b = abs_bigint(b0)
  if b <= bi(1) {
    fail("Base should be an integer greater than 1")
  }
  if n.is_zero() {
    return bi(0)
  }
  bi(1) + (n - bi(1)) % (b - bi(1))
}

///|
pub fn drm(n0 : BigInt, b0 : BigInt) -> BigInt raise {
  let mut n = abs_bigint(n0)
  let b = abs_bigint(b0)
  if b <= bi(1) {
    fail("Base should be an integer greater than 1")
  }
  while n > b {
    let mut mul = bi(1)
    let mut temp = n
    while temp > bi(1) {
      let r = temp % b
      if r.is_zero() {
        return bi(0)
      }
      mul = mul * r
      temp = temp / b
    }
    n = mul
  }
  n
}
