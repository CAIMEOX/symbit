///|
/// Prime generation utilities (naive, deterministic).

///|
/// Public struct `Sieve`.
///
/// - Does: Stores cached prime numbers for prime generation utilities.
/// - Input: Construct or reference it through the declared public type shape.
/// - Returns: `a struct value when constructed`.
/// - Limits: This declaration does not validate values by itself; validation is performed by the functions that consume it.
pub struct Sieve {
  primes : Array[BigInt]
}

///|
/// Public API `Sieve::new`.
///
/// - Does: Constructs a prime sieve with a small initial cache.
/// - Input: No runtime input beyond the receiver or declared parameters.
/// - Returns: `Sieve`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn Sieve::new() -> Sieve {
  let p : Array[BigInt] = [bi(2), bi(3), bi(5), bi(7), bi(11), bi(13)]
  { primes: p }
}

///|
/// Public API `Sieve::extend_`.
///
/// - Does: Extends the cached primes up to at least the requested bound.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Unit`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
#alias(extend, deprecated="Use `Sieve::extend_` instead")
pub fn Sieve::extend_(self : Sieve, n0 : BigInt) -> Unit {
  let n = abs_bigint(n0)
  let len = self.primes.length()
  let last = self.primes[len - 1]
  if last >= n {
    return
  }
  if n.bit_length() <= 30 {
    let end = n.to_int()
    let root = isqrt_int(end)
    if last < bi(root) {
      self.extend_(bi(root))
    }
    self.extend_segmented_int(end)
    return
  }
  let mut candidate = last + bi(1)
  while candidate <= n {
    if isprime(candidate) {
      self.primes.push(candidate)
    }
    candidate = candidate + bi(1)
  }
}

///|
/// Public API `Sieve::extend_to_no`.
///
/// - Does: Extends the cached primes until it contains at least count primes.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Unit`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn Sieve::extend_to_no(self : Sieve, count : Int) -> Unit {
  if count < 1 {
    return
  }
  let mut candidate = self.primes[self.primes.length() - 1] + bi(1)
  while self.primes.length() < count {
    if isprime(candidate) {
      self.primes.push(candidate)
    }
    candidate = candidate + bi(1)
  }
}

///|
/// Public API `Sieve::prime`.
///
/// - Does: Returns the n-th prime using 1-based indexing.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn Sieve::prime(self : Sieve, n : Int) -> BigInt raise {
  if n < 1 {
    fail("n should be >= 1")
  }
  self.extend_to_no(n)
  self.primes[n - 1]
}

///|
/// Public API `Sieve::primerange`.
///
/// - Does: Returns cached/generated primes in the half-open interval [a, b).
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
pub fn Sieve::primerange(
  self : Sieve,
  a0 : BigInt,
  b0 : BigInt,
) -> Array[BigInt] {
  let a = abs_bigint(a0)
  let b = abs_bigint(b0)
  if b <= a {
    return []
  }
  self.extend_(b - bi(1))
  let lo = prime_lower_bound(self.primes, a)
  let hi = prime_lower_bound(self.primes, b)
  let out : Array[BigInt] = Array::new()
  for i in lo..<hi {
    out.push(self.primes[i])
  }
  out
}

///|
/// Public value `sieve`.
///
/// - Does: Exposes the shared module-level sieve used by prime generation helpers.
/// - Input: Read this value directly; callers do not pass runtime parameters.
/// - Returns: `Sieve`.
/// - Limits: This is static package data and does not perform validation by itself.
pub let sieve : Sieve = Sieve::new()

///|
/// Public API `prime`.
///
/// - Does: Returns the n-th prime using 1-based indexing.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn prime(n : Int) -> BigInt raise {
  sieve.prime(n)
}

///|
/// Public API `primerange`.
///
/// - Does: Lists primes below a bound or inside a half-open interval.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Returns an empty array when no values are found; generator-style flags are accepted only as compatibility inputs where implemented.
pub fn primerange(a : BigInt, b? : BigInt = bi(0)) -> Array[BigInt] {
  if b == bi(0) {
    return sieve.primerange(bi(2), a)
  }
  sieve.primerange(a, b)
}

///|
/// Public API `nextprime`.
///
/// - Does: Returns the smallest prime strictly greater than n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn nextprime(n0 : BigInt) -> BigInt {
  if n0 < bi(2) {
    return bi(2)
  }
  if abs_bigint(n0).bit_length() <= 30 {
    let mut bound = n0 + bi(64)
    while true {
      sieve.extend_(bound)
      let idx = prime_upper_bound(sieve.primes, n0)
      if idx < sieve.primes.length() {
        return sieve.primes[idx]
      }
      bound = bound * bi(2)
    }
  }
  let mut n = n0
  n = n + bi(1)
  if is_even(n) {
    n = n + bi(1)
  }
  while !isprime(n) {
    n = n + bi(2)
  }
  n
}

///|
/// Public API `prevprime`.
///
/// - Does: Returns the largest prime strictly smaller than n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn prevprime(n0 : BigInt) -> BigInt raise {
  if n0 <= bi(2) {
    fail("n should be greater than 2")
  }
  let mut n = n0 - bi(1)
  if n == bi(2) {
    return bi(2)
  }
  if is_even(n) {
    n = n - bi(1)
  }
  while n >= bi(2) {
    if isprime(n) {
      return n
    }
    n = n - bi(2)
  }
  fail("no prime found")
}

///|
/// Public API `primepi`.
///
/// - Does: Counts primes less than or equal to n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn primepi(n0 : BigInt) -> BigInt {
  let n = abs_bigint(n0)
  if n < bi(2) {
    return bi(0)
  }
  sieve.extend_(n)
  bi(prime_upper_bound(sieve.primes, n))
}

///|
fn Sieve::extend_segmented_int(self : Sieve, end : Int) -> Unit {
  let last = self.primes[self.primes.length() - 1].to_int()
  if end <= last {
    return
  }
  let start = last + 1
  let marks : Array[Bool] = Array::new()
  for _ in start..<=end {
    marks.push(true)
  }
  for prime_big in self.primes {
    let prime = prime_big.to_int()
    if prime * prime > end {
      break
    }
    let mut first = prime * prime
    if first < start {
      let rem = start % prime
      first = if rem == 0 { start } else { start + (prime - rem) }
    }
    let mut composite = first
    while composite <= end {
      marks[composite - start] = false
      composite += prime
    }
  }
  for value in start..<=end {
    if value >= 2 && marks[value - start] {
      self.primes.push(bi(value))
    }
  }
}

///|
fn isqrt_int(n : Int) -> Int {
  let mut root = 0
  while (root + 1) * (root + 1) <= n {
    root += 1
  }
  root
}

///|
fn prime_lower_bound(primes : Array[BigInt], target : BigInt) -> Int {
  let mut lo = 0
  let mut hi = primes.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if primes[mid] < target {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
fn prime_upper_bound(primes : Array[BigInt], target : BigInt) -> Int {
  let mut lo = 0
  let mut hi = primes.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if primes[mid] <= target {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
/// Public API `randprime`.
///
/// - Does: Returns a prime from the half-open interval [a, b).
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn randprime(a0 : BigInt, b0 : BigInt) -> BigInt raise {
  let a = abs_bigint(a0)
  let b = abs_bigint(b0)
  if b <= a {
    fail("empty range")
  }
  let mut n = if a < bi(2) { bi(2) } else { a }
  while n < b {
    if isprime(n) {
      return n
    }
    n = n + bi(1)
  }
  fail("no prime in range")
}

///|
/// Public API `primorial`.
///
/// - Does: Computes a product of primes, either by count or by value limit.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn primorial(n : Int, nth? : Bool = true) -> BigInt raise {
  if n < 1 {
    fail("primorial argument must be >= 1")
  }
  let mut acc = bi(1)
  if nth {
    for i in 1..<=n {
      acc = acc * prime(i)
    }
    return acc
  }
  let limit = bi(n)
  let ps = primerange(bi(2), b=limit + bi(1))
  for p in ps {
    acc = acc * p
  }
  acc
}

///|
/// Public API `composite`.
///
/// - Does: Returns the n-th positive composite number.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn composite(n : Int) -> BigInt raise {
  if n < 1 {
    fail("n should be >= 1")
  }
  let mut count = 0
  let mut k = bi(3)
  while true {
    k = k + bi(1)
    if !isprime(k) {
      count += 1
      if count == n {
        return k
      }
    }
  }
  bi(0)
}

///|
/// Public API `compositepi`.
///
/// - Does: Counts composite numbers less than or equal to n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn compositepi(n0 : BigInt) -> BigInt {
  let n = abs_bigint(n0)
  if n < bi(4) {
    return bi(0)
  }
  let mut count = bi(0)
  let mut k = bi(4)
  while k <= n {
    if !isprime(k) {
      count = count + bi(1)
    }
    k = k + bi(1)
  }
  count
}

///|
/// Public enum `CycleLengthResult`.
///
/// - Does: Represents either cycle parameters or visited values returned by cycle_length.
/// - Input: Construct or reference it through the declared public type shape.
/// - Returns: `one of the enum variants`.
/// - Limits: This declaration does not validate values by itself; validation is performed by the functions that consume it.
pub enum CycleLengthResult {
  Params(Int, Int?)
  Values(Array[Int])
}

///|
/// Public API `cycle_length`.
///
/// - Does: Detects the cycle length and preperiod of an iterated integer function.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int, x0 : Int, nmax? : Int`.
/// - Limits: Returns `None` when the requested value does not exist or the supported search fails.
pub fn cycle_length(
  f : (Int) -> Int,
  x0 : Int,
  nmax? : Int = -1,
  values? : Bool = false,
) -> CycleLengthResult {
  let nmax_val = if nmax < 0 { 0 } else { nmax }
  let mut power = 1
  let mut lam = 1
  let mut tortoise = x0
  let mut hare = f(x0)
  let mut i = 1
  if values {
    let out : Array[Int] = Array::new()
    out.push(tortoise)
    while tortoise != hare && (nmax_val == 0 || i < nmax_val) {
      i += 1
      if power == lam {
        tortoise = hare
        power = power * 2
        lam = 0
      }
      out.push(hare)
      hare = f(hare)
      lam += 1
    }
    if nmax_val != 0 && i == nmax_val {
      return Values(out)
    }
    return Values(out)
  }
  while tortoise != hare && (nmax_val == 0 || i < nmax_val) {
    i += 1
    if power == lam {
      tortoise = hare
      power = power * 2
      lam = 0
    }
    hare = f(hare)
    lam += 1
  }
  if nmax_val != 0 && i == nmax_val {
    return Params(nmax_val, None)
  }
  let mut mu = 0
  tortoise = x0
  hare = x0
  for _ in 0..<lam {
    hare = f(hare)
  }
  while tortoise != hare {
    tortoise = f(tortoise)
    hare = f(hare)
    mu += 1
  }
  Params(lam, Some(mu))
}
