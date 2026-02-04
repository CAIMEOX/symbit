///|
/// Prime generation utilities (naive, deterministic).

///|
pub struct Sieve {
  primes : Array[BigInt]
}

///|
pub fn Sieve::new() -> Sieve {
  let p : Array[BigInt] = [bi(2), bi(3), bi(5), bi(7), bi(11), bi(13)]
  Sieve::{ primes: p }
}

///|
pub fn Sieve::extend(self : Sieve, n0 : BigInt) -> Unit {
  let n = abs_bigint(n0)
  let len = self.primes.length()
  let last = self.primes[len - 1]
  if last >= n {
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
pub fn Sieve::prime(self : Sieve, n : Int) -> BigInt raise {
  if n < 1 {
    fail("n should be >= 1")
  }
  self.extend_to_no(n)
  self.primes[n - 1]
}

///|
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
  self.extend(b - bi(1))
  let out : Array[BigInt] = Array::new()
  for p in self.primes {
    if p < a {
      continue
    }
    if p >= b {
      break
    }
    out.push(p)
  }
  out
}

///|
pub let sieve : Sieve = Sieve::new()

///|
pub fn prime(n : Int) -> BigInt raise {
  sieve.prime(n)
}

///|
pub fn primerange(a : BigInt, b? : BigInt = bi(0)) -> Array[BigInt] {
  if b == bi(0) {
    return sieve.primerange(bi(2), a)
  }
  sieve.primerange(a, b)
}

///|
pub fn nextprime(n0 : BigInt) -> BigInt {
  let mut n = n0
  if n < bi(2) {
    return bi(2)
  }
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
pub fn primepi(n0 : BigInt) -> BigInt {
  let n = abs_bigint(n0)
  if n < bi(2) {
    return bi(0)
  }
  let ps = sieve.primerange(bi(2), n + bi(1))
  bi(ps.length())
}

///|
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
pub enum CycleLengthResult {
  Params(Int, Int?)
  Values(Array[Int])
}

///|
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
      return CycleLengthResult::Values(out)
    }
    return CycleLengthResult::Values(out)
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
    return CycleLengthResult::Params(nmax_val, None)
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
  CycleLengthResult::Params(lam, Some(mu))
}
