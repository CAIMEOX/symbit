///|
/// Residue number theory utilities (naive implementations).

///|
fn isprime_naive(n : BigInt) -> Bool raise {
  if n < bi(2) {
    return false
  }
  if n == bi(2) || n == bi(3) {
    return true
  }
  if is_even(n) {
    return false
  }
  let limit = to_int_checked(n, 30)
  let mut d = 3
  while d * d <= limit {
    let db = bi(d)
    if (n % db).is_zero() {
      return false
    }
    d += 2
  }
  true
}

///|
fn factorint_naive(n0 : BigInt) -> Map[BigInt, Int] raise {
  let mut n = if n0 < bi(0) { -n0 } else { n0 }
  let factors : Map[BigInt, Int] = Map([])
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
  let limit = to_int_checked(n, 30)
  let mut d = 3
  while d * d <= limit && n > bi(1) {
    let db = bi(d)
    count = 0
    while (n % db).is_zero() {
      n = n / db
      count += 1
    }
    if count > 0 {
      factors[db] = count
    }
    d += 2
  }
  if n > bi(1) {
    factors[n] = 1
  }
  factors
}

///|
fn mobius_small_int(n0 : Int) -> Int {
  if n0 == 1 {
    return 1
  }
  let mut n = n0
  let mut count = 0

  if n % 2 == 0 {
    n /= 2
    count += 1
    if n % 2 == 0 {
      return 0
    }
  }

  if n % 3 == 0 {
    n /= 3
    count += 1
    if n % 3 == 0 {
      return 0
    }
  }

  let mut d = 5
  while d * d <= n {
    if n % d == 0 {
      n /= d
      count += 1
      if n % d == 0 {
        return 0
      }
    }
    d += 2
    if d * d > n {
      break
    }
    if n % d == 0 {
      n /= d
      count += 1
      if n % d == 0 {
        return 0
      }
    }
    d += 4
  }

  if n > 1 {
    count += 1
  }
  if count % 2 == 0 {
    1
  } else {
    -1
  }
}

///|
fn totient_naive(n : BigInt) -> BigInt raise {
  if n == bi(0) {
    return bi(0)
  }
  let factors = factorint_naive(n)
  let mut result = n
  for p, _ in factors {
    result = result / p * (p - bi(1))
  }
  result
}

///|
/// Public API `n_order`.
///
/// - Does: Computes the multiplicative order of a modulo n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn n_order(a0 : BigInt, n0 : BigInt) -> BigInt raise {
  if n0 <= bi(1) {
    fail("n should be greater than 1")
  }
  let n = n0
  let a = mod_positive(a0, n)
  if a == bi(1) {
    return bi(1)
  }
  if gcd(a, n) != bi(1) {
    fail("The two numbers should be relatively prime")
  }
  let mut order = totient_naive(n)
  let factors = factorint_naive(order)
  for p, _ in factors {
    let mut div = order / p
    while (order % p).is_zero() && pow_mod(a, div, n) == bi(1) {
      order = div
      div = order / p
    }
  }
  order
}

///|
/// Public API `is_primitive_root`.
///
/// - Does: Tests whether a is a primitive root modulo n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn is_primitive_root(a : BigInt, n : BigInt) -> Bool raise {
  if n <= bi(1) {
    fail("n should be greater than 1")
  }
  if gcd(a, n) != bi(1) {
    return false
  }
  n_order(a, n) == totient_naive(n)
}

///|
/// Public API `primitive_root`.
///
/// - Does: Finds a primitive root modulo n when supported.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt?`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn primitive_root(n : BigInt, smallest? : Bool = true) -> BigInt? raise {
  if n <= bi(1) {
    fail("n should be greater than 1")
  }
  if n <= bi(4) {
    return Some(n - bi(1))
  }
  let limit = to_int_checked(n, 20)
  if !smallest {
    // fallback to smallest search in naive implementation
  }
  for i in 2..<limit {
    let g = bi(i)
    if is_primitive_root(g, n) {
      return Some(g)
    }
  }
  None
}

///|
/// Public API `legendre_symbol`.
///
/// - Does: Computes the Legendre symbol (a | p).
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn legendre_symbol(a0 : BigInt, p : BigInt) -> Int raise {
  if p <= bi(2) {
    fail("p should be an odd prime")
  }
  let a = mod_positive(a0, p)
  if a.is_zero() {
    return 0
  }
  let exp = (p - bi(1)) / bi(2)
  let res = pow_mod(a, exp, p)
  if res == bi(1) {
    1
  } else if res == p - bi(1) {
    -1
  } else {
    0
  }
}

///|
/// Public API `jacobi_symbol`.
///
/// - Does: Computes the Jacobi symbol (a | n).
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn jacobi_symbol(a0 : BigInt, n0 : BigInt) -> Int raise {
  if n0 <= bi(0) || is_even(n0) {
    fail("n should be a positive odd integer")
  }
  let mut a = mod_positive(a0, n0)
  let mut n = n0
  let mut result = 1
  while !a.is_zero() {
    while is_even(a) {
      a = a / bi(2)
      let n_mod8 = (n % bi(8)).to_int()
      if n_mod8 == 3 || n_mod8 == 5 {
        result = -result
      }
    }
    let temp = a
    a = n
    n = temp
    if a % bi(4) == bi(3) && n % bi(4) == bi(3) {
      result = -result
    }
    a = mod_positive(a, n)
  }
  if n == bi(1) {
    result
  } else {
    0
  }
}

///|
/// Public API `is_quad_residue`.
///
/// - Does: Tests whether a is a quadratic residue modulo n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn is_quad_residue(a0 : BigInt, n0 : BigInt) -> Bool raise {
  if n0 <= bi(0) {
    fail("n should be positive")
  }
  if n0 == bi(1) || n0 == bi(2) {
    return true
  }
  let n = n0
  let a = mod_positive(a0, n)
  let n_int = to_int_checked(n, 20)
  if n_int <= 10000 {
    for i in 0..<n_int {
      if pow_mod(bi(i), bi(2), n) == a {
        return true
      }
    }
    return false
  }
  if isprime_naive(n) {
    return legendre_symbol(a, n) != -1
  }
  jacobi_symbol(a, n) != -1
}

///|
/// Public API `quadratic_residues`.
///
/// - Does: Lists quadratic residues modulo n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn quadratic_residues(n0 : BigInt) -> Array[BigInt] raise {
  if n0 <= bi(0) {
    fail("n should be positive")
  }
  let n = n0
  let n_int = to_int_checked(n, 20)
  let seen : Map[BigInt, Bool] = Map([])
  for i in 0..<n_int {
    let r = pow_mod(bi(i), bi(2), n)
    seen[r] = true
  }
  let out : Array[BigInt] = Array::new()
  for k, _ in seen {
    out.push(k)
  }
  out.sort()
  out
}

///|
/// Public API `sqrt_mod`.
///
/// - Does: Finds modular square roots.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn sqrt_mod(
  a0 : BigInt,
  n0 : BigInt,
  all_roots? : Bool = false,
) -> Array[BigInt] raise {
  if n0 <= bi(0) {
    fail("n should be positive")
  }
  let n = n0
  let a = mod_positive(a0, n)
  let n_int = to_int_checked(n, 20)
  let roots : Array[BigInt] = Array::new()
  for i in 0..<n_int {
    let r = pow_mod(bi(i), bi(2), n)
    if r == a {
      roots.push(bi(i))
    }
  }
  roots.sort()
  if all_roots {
    return roots
  }
  if roots.is_empty() {
    return []
  }
  [roots[0]]
}

///|
/// Public API `sqrt_mod_iter`.
///
/// - Does: Returns modular square roots as an iterator.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Iter[BigInt]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn sqrt_mod_iter(a : BigInt, n : BigInt) -> Iter[BigInt] raise {
  sqrt_mod(a, n, all_roots=true).iter()
}

///|
/// Public API `is_nthpow_residue`.
///
/// - Does: Tests whether a is an n-th power residue modulo m.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Bool`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn is_nthpow_residue(a : BigInt, n : BigInt, m : BigInt) -> Bool raise {
  let roots = nthroot_mod(a, n, m, all_roots=true)
  !roots.is_empty()
}

///|
/// Public API `nthroot_mod`.
///
/// - Does: Finds modular n-th roots.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn nthroot_mod(
  a0 : BigInt,
  n0 : BigInt,
  m0 : BigInt,
  all_roots? : Bool = false,
) -> Array[BigInt] raise {
  if m0 <= bi(0) {
    fail("modulus should be positive")
  }
  let m = m0
  let a = mod_positive(a0, m)
  let n_int = to_int_checked(n0, 20)
  let m_int = to_int_checked(m, 20)
  let roots : Array[BigInt] = Array::new()
  for i in 0..<m_int {
    if pow_mod(bi(i), bi(n_int), m) == a {
      roots.push(bi(i))
    }
  }
  roots.sort()
  if all_roots {
    return roots
  }
  if roots.is_empty() {
    return []
  }
  [roots[0]]
}

///|
/// Public API `mobius`.
///
/// - Does: Computes the Mobius function.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Int`.
/// - Limits: Does not add a separate error channel; invalid or degenerate inputs follow the documented return shape of this front door.
pub fn mobius(n0 : BigInt) -> Int {
  let n = if n0 < bi(0) { -n0 } else { n0 }
  if n == bi(1) {
    return 1
  }
  if n.bit_length() <= 30 {
    return mobius_small_int(n.to_int())
  }
  if isprime(n) {
    return -1
  }
  let factors = factorint(n)
  let mut count = 0
  for _, exp in factors {
    if exp > 1 {
      return 0
    }
    count += 1
  }
  if count % 2 == 0 {
    1
  } else {
    -1
  }
}

///|
/// Public API `discrete_log`.
///
/// - Does: Solves a discrete logarithm in the supported modular group cases.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt?`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn discrete_log(n0 : BigInt, a0 : BigInt, b0 : BigInt) -> BigInt? raise {
  if n0 <= bi(0) {
    fail("n should be positive")
  }
  let n = n0
  let a = mod_positive(a0, n)
  let b = mod_positive(b0, n)
  let limit = to_int_checked(n, 20)
  let mut value = bi(1)
  for i in 0..<limit {
    if value == a {
      return Some(bi(i))
    }
    value = value * b % n
  }
  None
}

///|
/// Public API `quadratic_congruence`.
///
/// - Does: Solves a quadratic congruence modulo n.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn quadratic_congruence(
  a0 : BigInt,
  b0 : BigInt,
  c0 : BigInt,
  n0 : BigInt,
) -> Array[BigInt] raise {
  if n0 <= bi(0) {
    fail("modulus should be positive")
  }
  let n = n0
  let limit = to_int_checked(n, 20)
  let out : Array[BigInt] = Array::new()
  for i in 0..<limit {
    let x = bi(i)
    let val = (a0 * x * x + b0 * x + c0) % n
    if val.is_zero() {
      out.push(x)
    }
  }
  out
}

///|
/// Public API `polynomial_congruence`.
///
/// - Does: Solves a polynomial congruence modulo m.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `Array[BigInt]`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn polynomial_congruence(
  coeffs : Array[BigInt],
  m0 : BigInt,
) -> Array[BigInt] raise {
  if m0 <= bi(0) {
    fail("modulus should be positive")
  }
  let m = m0
  let limit = to_int_checked(m, 20)
  let out : Array[BigInt] = Array::new()
  for i in 0..<limit {
    let x = bi(i)
    let mut acc = bi(0)
    for c in coeffs {
      acc = (acc * x + c) % m
    }
    if acc.is_zero() {
      out.push(x)
    }
  }
  out
}

///|
/// Public API `binomial_mod`.
///
/// - Does: Computes a binomial coefficient modulo m.
/// - Input: The parameters in the signature, using exact `BigInt`/`Int` values where declared.
/// - Returns: `BigInt`.
/// - Limits: Raises through the declared error channel for invalid domains, unsupported bounds, or failed validation.
pub fn binomial_mod(n : BigInt, k : BigInt, m0 : BigInt) -> BigInt raise {
  if m0 <= bi(0) {
    fail("modulus should be positive")
  }
  let m = m0
  let n_int = to_int_checked(n, 20)
  let k_int = to_int_checked(k, 20)
  if k_int < 0 || k_int > n_int {
    return bi(0)
  }
  let mut kk = k_int
  if kk > n_int - kk {
    kk = n_int - kk
  }
  let mut num = bi(1)
  let mut den = bi(1)
  for i in 1..<=kk {
    num = num * bi(n_int - kk + i)
    den = den * bi(i)
  }
  let (g, inv_den, _) = gcdext(den, m)
  if g != bi(1) {
    return num / den % m
  }
  num * mod_positive(inv_den, m) % m
}
