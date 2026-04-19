///|
/// Integer factorization utilities.

///|
fn inc_factor(map : Map[BigInt, Int], p : BigInt, delta : Int) -> Unit {
  match map.get(p) {
    Some(v) => map[p] = v + delta
    None => map[p] = delta
  }
}

///|
fn factorint_small_done(n : Int, d : Int) -> (Int, Int) {
  if d * d <= n {
    (n, d)
  } else {
    (n, 0)
  }
}

///|
fn factorint_small_trial(
  factors : Map[BigInt, Int],
  n0 : Int,
  limit : Int,
  fail_max : Int,
  next_p? : Int = 2,
) -> (Int, Int) {
  let limit2 = limit * limit
  let mut n = n0
  let mut threshold2 = if n < limit2 { n } else { limit2 }
  let mut next_p = next_p

  if next_p < 3 {
    if n % 2 == 0 {
      let mut m = 0
      while n % 2 == 0 {
        n /= 2
        m += 1
      }
      factors[bi(2)] = m
      threshold2 = if n < limit2 { n } else { limit2 }
    }
    next_p = 3
    if threshold2 < 9 {
      return factorint_small_done(n, next_p)
    }
  }

  if next_p < 5 {
    if n % 3 == 0 {
      n /= 3
      let mut m = 1
      while n % 3 == 0 {
        n /= 3
        m += 1
      }
      factors[bi(3)] = m
      threshold2 = if n < limit2 { n } else { limit2 }
    }
    next_p = 5
    if threshold2 < 25 {
      return factorint_small_done(n, next_p)
    }
  }

  let p6 = next_p % 6
  next_p += (if p6 < 2 { -1 } else { 5 }) - p6

  let mut fails = 0
  while fails < fail_max {
    if n % next_p != 0 {
      fails += 1
    } else {
      n /= next_p
      let mut m = 1
      while n % next_p == 0 {
        n /= next_p
        m += 1
      }
      factors[bi(next_p)] = m
      fails = 0
      threshold2 = if n < limit2 { n } else { limit2 }
    }
    next_p += 2
    if threshold2 < next_p * next_p {
      return factorint_small_done(n, next_p)
    }

    if n % next_p != 0 {
      fails += 1
    } else {
      n /= next_p
      let mut m = 1
      while n % next_p == 0 {
        n /= next_p
        m += 1
      }
      factors[bi(next_p)] = m
      fails = 0
      threshold2 = if n < limit2 { n } else { limit2 }
    }
    next_p += 4
    if threshold2 < next_p * next_p {
      return factorint_small_done(n, next_p)
    }
  }
  factorint_small_done(n, next_p)
}

///|
fn factorint_small_abs(n0 : BigInt) -> Map[BigInt, Int] {
  let factors : Map[BigInt, Int] = {}
  let n = n0.to_int()
  if n < 2 {
    return factors
  }
  let small = if n < 1 << 15 { n } else { 1 << 15 }
  let fail_max = 600
  let (rest, next_p) = factorint_small_trial(factors, n, small, fail_max)
  if next_p == 0 || rest < next_p * next_p {
    if rest > 1 {
      factors[bi(rest)] = factors.get_or_default(bi(rest), 0) + 1
    }
    return factors
  }
  let mut remaining = bi(rest)
  let mut d = bi(next_p)
  while d * d <= remaining {
    let mut count = 0
    while (remaining % d).is_zero() {
      remaining = remaining / d
      count += 1
    }
    if count > 0 {
      factors[d] = factors.get_or_default(d, 0) + count
    }
    d = d + bi(2)
  }
  if remaining > bi(1) {
    factors[remaining] = factors.get_or_default(remaining, 0) + 1
  }
  factors
}

///|
fn factorint_small_int_pairs(n : Int) -> Array[(Int, Int)] {
  let factors : Map[Int, Int] = {}
  if n < 2 {
    return []
  }
  let small = if n < 1 << 15 { n } else { 1 << 15 }
  let fail_max = 600
  let limit2 = small * small
  let mut remaining = n
  let mut threshold2 = if remaining < limit2 { remaining } else { limit2 }

  if remaining % 2 == 0 {
    let mut m = 0
    while remaining % 2 == 0 {
      remaining /= 2
      m += 1
    }
    factors[2] = m
    threshold2 = if remaining < limit2 { remaining } else { limit2 }
  }
  let mut next_p = 3
  if threshold2 >= 9 {
    if remaining % 3 == 0 {
      remaining /= 3
      let mut m = 1
      while remaining % 3 == 0 {
        remaining /= 3
        m += 1
      }
      factors[3] = m
      threshold2 = if remaining < limit2 { remaining } else { limit2 }
    }
    next_p = 5
  }

  if threshold2 >= 25 {
    let mut fails = 0
    while fails < fail_max {
      if remaining % next_p != 0 {
        fails += 1
      } else {
        remaining /= next_p
        let mut m = 1
        while remaining % next_p == 0 {
          remaining /= next_p
          m += 1
        }
        factors[next_p] = m
        fails = 0
        threshold2 = if remaining < limit2 { remaining } else { limit2 }
      }
      next_p += 2
      if threshold2 < next_p * next_p {
        break
      }

      if remaining % next_p != 0 {
        fails += 1
      } else {
        remaining /= next_p
        let mut m = 1
        while remaining % next_p == 0 {
          remaining /= next_p
          m += 1
        }
        factors[next_p] = m
        fails = 0
        threshold2 = if remaining < limit2 { remaining } else { limit2 }
      }
      next_p += 4
      if threshold2 < next_p * next_p {
        break
      }
    }
  }

  if remaining > 1 {
    let mut d = if next_p < 5 { 5 } else { next_p }
    let p6 = d % 6
    d += (if p6 < 2 { -1 } else { 5 }) - p6
    while d * d <= remaining {
      if remaining % d == 0 {
        let mut m = 0
        while remaining % d == 0 {
          remaining /= d
          m += 1
        }
        factors[d] = factors.get_or_default(d, 0) + m
      }
      d += 2
      if d * d > remaining {
        break
      }
      if remaining % d == 0 {
        let mut m = 0
        while remaining % d == 0 {
          remaining /= d
          m += 1
        }
        factors[d] = factors.get_or_default(d, 0) + m
      }
      d += 4
    }
  }

  if remaining > 1 {
    factors[remaining] = factors.get_or_default(remaining, 0) + 1
  }

  let pairs : Array[(Int, Int)] = Array::new()
  for p, e in factors {
    pairs.push((p, e))
  }
  pairs.sort_by(fn(a, b) { a.0.compare(b.0) })
  pairs
}

///|
fn pow_int(base : Int, exp : Int) -> Int {
  let mut acc = 1
  for _ in 0..<exp {
    acc *= base
  }
  acc
}

///|
/// Public API `factorint`.
///
/// - Does: Factors an integer into prime factors and integer exponents.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Map[BigInt, Int]`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
  if n.bit_length() <= 30 {
    let small_factors = factorint_small_abs(n)
    for p, e in small_factors {
      factors[p] = e
    }
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
/// Public API `multiplicity`.
///
/// - Does: Counts the exponent of p in the factorization of n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `multiplicity_in_factorial`.
///
/// - Does: Counts the exponent of p in n factorial.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `divisors`.
///
/// - Does: Lists the positive divisors of an integer.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
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
/// Public API `proper_divisors`.
///
/// - Does: Lists all positive divisors except the integer itself.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
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
/// Public API `primefactors`.
///
/// - Does: Lists the distinct positive prime factors of an integer.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
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
/// Public API `totient`.
///
/// - Does: Computes Euler phi for an integer.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn totient(n : BigInt) -> BigInt {
  let n_abs = abs_bigint(n)
  if n_abs.bit_length() <= 30 {
    let mut result = 1
    for pair in factorint_small_int_pairs(n_abs.to_int()) {
      let (p, e) = pair
      let mut term = p - 1
      for _ in 1..<e {
        term *= p
      }
      result *= term
    }
    return bi(result)
  }
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
/// Public API `divisor_count`.
///
/// - Does: Counts the positive divisors of an integer.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn divisor_count(n : BigInt) -> BigInt {
  let n_abs = abs_bigint(n)
  if n_abs.bit_length() <= 30 {
    let mut count = 1
    for pair in factorint_small_int_pairs(n_abs.to_int()) {
      let (_, e) = pair
      count *= e + 1
    }
    return bi(count)
  }
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
/// Public API `proper_divisor_count`.
///
/// - Does: Counts positive divisors excluding the integer itself.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn proper_divisor_count(n : BigInt) -> BigInt {
  let total = divisor_count(n)
  if total > bi(0) {
    total - bi(1)
  } else {
    bi(0)
  }
}

///|
/// Public API `divisor_sigma`.
///
/// - Does: Computes the sum of k-th powers of positive divisors.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn divisor_sigma(n0 : BigInt, k? : Int = 1) -> BigInt {
  let n = abs_bigint(n0)
  if n.is_zero() {
    return bi(0)
  }
  if n.bit_length() <= 30 {
    if k == 0 {
      return divisor_count(n)
    }
    if k > 0 && k * n.bit_length() < 60 {
      let mut acc = 1
      for pair in factorint_small_int_pairs(n.to_int()) {
        let (p, e) = pair
        let numerator = pow_int(p, k * (e + 1)) - 1
        let denominator = pow_int(p, k) - 1
        acc *= numerator / denominator
      }
      return bi(acc)
    }
    let mut acc = bi(1)
    for pair in factorint_small_int_pairs(n.to_int()) {
      let (p, e) = pair
      let prime = bi(p)
      let numerator = prime.pow(bi(k * (e + 1))) - bi(1)
      let denominator = prime.pow(bi(k)) - bi(1)
      acc = acc * (numerator / denominator)
    }
    return acc
  }
  if k == 0 {
    return divisor_count(n)
  }
  let factors = factorint(n)
  let mut acc = bi(1)
  for p, e in factors {
    if p == bi(-1) || e <= 0 {
      continue
    }
    let pk = p.pow(bi(k))
    let mut term = bi(1)
    let mut current = bi(1)
    for _ in 0..<e {
      current = current * pk
      term = term + current
    }
    acc = acc * term
  }
  acc
}

///|
/// Public API `factorrat`.
///
/// - Does: Factors a rational numerator/denominator pair into signed prime exponents.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Map[BigInt, Int]`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `reduced_totient`.
///
/// - Does: Computes the Carmichael reduced totient function.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `primenu`.
///
/// - Does: Counts distinct prime factors.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `primeomega`.
///
/// - Does: Counts prime factors with multiplicity.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `mersenne_prime_exponent`.
///
/// - Does: Returns a known Mersenne-prime exponent by 1-based index.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn mersenne_prime_exponent(nth : Int) -> Int raise {
  if nth < 1 || nth > mersenne_prime_exponents.length() {
    fail("nth must be in range")
  }
  mersenne_prime_exponents[nth - 1]
}

///|
/// Public API `is_perfect`.
///
/// - Does: Tests whether an integer is perfect.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn is_perfect(n0 : BigInt) -> Bool {
  let n = abs_bigint(n0)
  if n < bi(1) {
    return false
  }
  divisor_sigma(n) == n * bi(2)
}

///|
/// Public API `abundance`.
///
/// - Does: Computes divisor-sum abundance sigma(n) - 2*n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn abundance(n0 : BigInt) -> BigInt {
  let n = abs_bigint(n0)
  divisor_sigma(n) - n * bi(2)
}

///|
/// Public API `is_abundant`.
///
/// - Does: Tests whether an integer is abundant.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn is_abundant(n0 : BigInt) -> Bool {
  abundance(n0) > bi(0)
}

///|
/// Public API `is_deficient`.
///
/// - Does: Tests whether an integer is deficient.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn is_deficient(n0 : BigInt) -> Bool {
  abundance(n0) < bi(0)
}

///|
/// Public API `is_amicable`.
///
/// - Does: Tests whether two integers form an amicable pair.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn is_amicable(m0 : BigInt, n0 : BigInt) -> Bool {
  let m = abs_bigint(m0)
  let n = abs_bigint(n0)
  if m == n {
    return false
  }
  divisor_sigma(m) - m == n && divisor_sigma(n) - n == m
}

///|
/// Public API `is_carmichael`.
///
/// - Does: Tests Korselt-style Carmichael-number conditions.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
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
/// Public API `perfect_power`.
///
/// - Does: Detects whether an integer is an exact power b**e with e greater than 1.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `(BigInt, Int)?`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
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
/// Public API `pollard_rho`.
///
/// - Does: Attempts to find a non-trivial factor with Pollard rho.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt?`.
/// - Limits: Returns `None` when the requested value does not exist or the supported search fails.
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
/// Public API `pollard_pm1`.
///
/// - Does: Attempts to find a non-trivial factor with Pollard p-1.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt?`.
/// - Limits: Returns `None` when the requested value does not exist or the supported search fails.
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
/// Public API `dra`.
///
/// - Does: Computes the additive digital root in the selected base.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
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
/// Public API `drm`.
///
/// - Does: Computes the multiplicative digital root in the selected base.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
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
