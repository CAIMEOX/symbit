///|
/// Group order number theory helpers.

///|
fn bi_str(value : String) -> BigInt {
  @bigint.BigInt::from_string(value)
}

///|
fn pow_bigint(base : Int, exp : Int) -> BigInt {
  @symntheory.bi(base).pow(@symntheory.bi(exp))
}

///|
fn factorint_int(n : Int) -> Map[Int, Int] {
  let factors = @symntheory.factorint(@symntheory.bi(n))
  let out : Map[Int, Int] = {}
  for p, e in factors {
    if p == @symntheory.bi(-1) {
      continue
    }
    let pi = p.to_int()
    if pi <= 0 {
      continue
    }
    out[pi] = e
  }
  out
}

///|
fn is_nilpotent_number_from_factors(factors : Map[Int, Int]) -> Bool {
  for p, _ in factors {
    for q, e in factors {
      let mut m = 1
      for _ in 0..<e {
        m = (m * q) % p
        if m == 1 {
          return false
        }
      }
    }
  }
  true
}

///|
pub fn is_nilpotent_number(n : Int) -> Bool raise CombinatoricsError {
  if n <= 0 {
    raise CombinatoricsError::ValueError("n must be a positive integer")
  }
  let factors = factorint_int(n)
  is_nilpotent_number_from_factors(factors)
}

///|
pub fn is_abelian_number(n : Int) -> Bool raise CombinatoricsError {
  if n <= 0 {
    raise CombinatoricsError::ValueError("n must be a positive integer")
  }
  let factors = factorint_int(n)
  for _, e in factors {
    if e >= 3 {
      return false
    }
  }
  is_nilpotent_number_from_factors(factors)
}

///|
pub fn is_cyclic_number(n : Int) -> Bool raise CombinatoricsError {
  if n <= 0 {
    raise CombinatoricsError::ValueError("n must be a positive integer")
  }
  let factors = factorint_int(n)
  for _, e in factors {
    if e != 1 {
      return false
    }
  }
  is_nilpotent_number_from_factors(factors)
}

///|
fn contains_int(values : Array[Int], target : Int) -> Bool {
  for v in values {
    if v == target {
      return true
    }
  }
  false
}

///|
fn powerset(values : Array[Int]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = [ [] ]
  for v in values {
    let current = out.length()
    for i in 0..<current {
      let subset = out[i]
      let next : Array[Int] = Array::new()
      for x in subset {
        next.push(x)
      }
      next.push(v)
      out.push(next)
    }
  }
  out
}

///|
fn holder_formula(prime_factors : Array[Int]) -> BigInt {
  let f_set : Array[Int] = Array::new()
  let m_set : Array[Int] = Array::new()
  for p in prime_factors {
    let mut in_F = true
    for q in prime_factors {
      if q % p == 1 {
        in_F = false
        break
      }
    }
    if in_F {
      f_set.push(p)
    } else {
      m_set.push(p)
    }
  }
  let subsets = powerset(m_set)
  let mut total = @symntheory.bi(0)
  for ps in subsets {
    let mut prod = @symntheory.bi(1)
    for p in m_set {
      if contains_int(ps, p) {
        continue
      }
      let mut c = 0
      for q in f_set {
        if q % p == 1 {
          c = c + 1
        }
      }
      for q in ps {
        if q % p == 1 {
          c = c + 1
        }
      }
      let term = (pow_bigint(p, c) - @symntheory.bi(1)) / @symntheory.bi(p - 1)
      prod = prod * term
      if prod.is_zero() {
        break
      }
    }
    total = total + prod
  }
  total
}

///|
pub fn groups_count(n : Int) -> BigInt raise CombinatoricsError {
  if n <= 0 {
    raise CombinatoricsError::ValueError("n must be a positive integer")
  }
  let factors = factorint_int(n)
  let mut count = 0
  let mut prime = 0
  let mut exp = 0
  for p, e in factors {
    count = count + 1
    prime = p
    exp = e
  }
  if count == 1 {
    if prime == 2 {
      let values : Array[BigInt] = [
        @symntheory.bi(1),
        @symntheory.bi(1),
        @symntheory.bi(2),
        @symntheory.bi(5),
        @symntheory.bi(14),
        @symntheory.bi(51),
        @symntheory.bi(267),
        @symntheory.bi(2328),
        @symntheory.bi(56092),
        @symntheory.bi(10494213),
        bi_str("49487367289"),
      ]
      if exp < values.length() {
        return values[exp]
      }
    }
    if prime == 3 {
      let values : Array[BigInt] = [
        @symntheory.bi(1),
        @symntheory.bi(1),
        @symntheory.bi(2),
        @symntheory.bi(5),
        @symntheory.bi(15),
        @symntheory.bi(67),
        @symntheory.bi(504),
        @symntheory.bi(9310),
        @symntheory.bi(1396077),
        bi_str("5937876645"),
      ]
      if exp < values.length() {
        return values[exp]
      }
    }
    if exp <= 2 {
      return @symntheory.bi(exp)
    }
    if exp == 3 {
      return @symntheory.bi(5)
    }
    if exp == 4 {
      return @symntheory.bi(15)
    }
    if exp == 5 {
      return @symntheory.bi(61) + @symntheory.bi(2 * prime) +
        @symntheory.bi(2 * gcd_int(prime - 1, 3)) + @symntheory.bi(gcd_int(prime - 1, 4))
    }
    if exp == 6 {
      return @symntheory.bi(3 * prime * prime + 39 * prime + 344) +
        @symntheory.bi(24 * gcd_int(prime - 1, 3) + 11 * gcd_int(prime - 1, 4) + 2 * gcd_int(prime - 1, 5))
    }
    if exp == 7 {
      if prime == 5 {
        return @symntheory.bi(34297)
      }
      return @symntheory.bi(3) * pow_bigint(prime, 5) +
        @symntheory.bi(12) * pow_bigint(prime, 4) +
        @symntheory.bi(44) * pow_bigint(prime, 3) +
        @symntheory.bi(170 * prime * prime + 707 * prime + 2455) +
        @symntheory.bi(4 * prime * prime + 44 * prime + 291) * @symntheory.bi(gcd_int(prime - 1, 3)) +
        @symntheory.bi(prime * prime + 19 * prime + 135) * @symntheory.bi(gcd_int(prime - 1, 4)) +
        @symntheory.bi(3 * prime + 31) * @symntheory.bi(gcd_int(prime - 1, 5)) +
        @symntheory.bi(4 * gcd_int(prime - 1, 7) + 5 * gcd_int(prime - 1, 8) + gcd_int(prime - 1, 9))
    }
  }
  let mut has_non_squarefree = false
  for _, e in factors {
    if e > 1 {
      has_non_squarefree = true
      break
    }
  }
  if has_non_squarefree {
    let small : Map[Int, Int] = {
      12: 5, 18: 5, 20: 5, 24: 15, 28: 4, 36: 14, 40: 14, 44: 4, 45: 2, 48: 52,
      50: 5, 52: 5, 54: 15, 56: 13, 60: 13, 63: 4, 68: 5, 72: 50, 75: 3, 76: 4,
      80: 52, 84: 15, 88: 12, 90: 10, 92: 4,
    }
    match small.get(n) {
      Some(v) => return @symntheory.bi(v)
      None => raise CombinatoricsError::ValueError("Number of groups of order n is unknown for this n")
    }
  }
  if count == 2 {
    let primes : Array[Int] = Array::new()
    for p, _ in factors {
      primes.push(p)
    }
    let p = if primes[0] < primes[1] { primes[0] } else { primes[1] }
    let q = if primes[0] < primes[1] { primes[1] } else { primes[0] }
    return if q % p == 1 { @symntheory.bi(2) } else { @symntheory.bi(1) }
  }
  let primes : Array[Int] = Array::new()
  for p, _ in factors {
    primes.push(p)
  }
  holder_formula(primes)
}
