///|
/// Combinatorial number sequences.
///
/// Current Limits:
/// - Small exact integer cases are evaluated where local algorithms exist.
/// - Many named sequences and number-theoretic functions remain symbolic front
///   doors.
/// - Assumption-based simplification and multi-argument variants are not
///   complete.

///|
fn fib_small_uint64(n : Int) -> UInt64 {
  if n <= 0 {
    return UInt64::default()
  }
  if n == 1 {
    return UInt64::extend_uint(1)
  }
  let mut a = UInt64::default()
  let mut b = UInt64::extend_uint(1)
  let mut i = 1
  while i < n {
    let c = a + b
    a = b
    b = c
    i = i + 1
  }
  b
}

///|
fn fib_bigint(n : Int) -> BigInt {
  if n >= 0 && n <= 92 {
    return BigInt::from_uint64(fib_small_uint64(n))
  }
  @symnum.ifib(n) catch {
    _ => BigInt::from_int(0)
  }
}

///|
fn lucas_bigint(n : Int) -> BigInt {
  if n == 0 {
    return BigInt::from_int(2)
  }
  if n == 1 {
    return BigInt::from_int(1)
  }
  let mut a = BigInt::from_int(2)
  let mut b = BigInt::from_int(1)
  let mut i = 2
  while i <= n {
    let c = a + b
    a = b
    b = c
    i = i + 1
  }
  b
}

///|
fn tribonacci_bigint(n : Int) -> BigInt {
  if n == 0 {
    return BigInt::from_int(0)
  }
  if n == 1 {
    return BigInt::from_int(1)
  }
  if n == 2 {
    return BigInt::from_int(1)
  }
  let mut a = BigInt::from_int(0)
  let mut b = BigInt::from_int(1)
  let mut c = BigInt::from_int(1)
  let mut i = 3
  while i <= n {
    let d = a + b + c
    a = b
    b = c
    c = d
    i = i + 1
  }
  c
}

///|
fn combinatorial_rational(num : Int, den : Int) -> @symnum.BigRational? {
  try @symnum.BigRational::from_ints(num, den) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn exact_combinatorial_rational(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
}

///|
fn harmonic_rational(n : Int) -> @symnum.BigRational? {
  let mut acc = @symnum.BigRational::zero()
  let mut k = 1
  while k <= n {
    let term = match combinatorial_rational(1, k) {
      Some(value) => value
      None => return None
    }
    acc = acc.add_r(term)
    k = k + 1
  }
  Some(acc)
}

///|
let small_bernoulli_values : Array[@symnum.BigRational] = [
  @symnum.BigRational::from_int(1),
  exact_combinatorial_rational(1, 2),
  exact_combinatorial_rational(1, 6),
  @symnum.BigRational::zero(),
  exact_combinatorial_rational(-1, 30),
  @symnum.BigRational::zero(),
  exact_combinatorial_rational(1, 42),
  @symnum.BigRational::zero(),
  exact_combinatorial_rational(-1, 30),
  @symnum.BigRational::zero(),
  exact_combinatorial_rational(5, 66),
]

///|
fn bernoulli_small(n : Int) -> @symnum.BigRational? {
  if n >= 0 && n < small_bernoulli_values.length() {
    Some(small_bernoulli_values[n])
  } else {
    None
  }
}

///|
/// Build or evaluate a Fibonacci number.
///
/// - Does: Evaluates `fibonacci(n)` for non-negative exact integer `n`.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `fibonacci(n)`.
/// - Limits: Negative-index identities and non-integer arguments remain
///   symbolic.
pub fn fibonacci(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni < 0 {
        @symcore.function("fibonacci", [n])
      } else {
        expr_from_bigint(fib_bigint(ni))
      }
    }
    None => @symcore.function("fibonacci", [n])
  }
}

///|
/// Build or evaluate a Lucas number.
///
/// - Does: Evaluates `lucas(n)` for non-negative exact integer `n`.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `lucas(n)`.
/// - Limits: Negative-index identities and non-integer arguments remain
///   symbolic.
pub fn lucas(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni < 0 {
        @symcore.function("lucas", [n])
      } else {
        expr_from_bigint(lucas_bigint(ni))
      }
    }
    None => @symcore.function("lucas", [n])
  }
}

///|
/// Build or evaluate a Tribonacci number.
///
/// - Does: Evaluates `tribonacci(n)` for non-negative exact integer `n`.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `tribonacci(n)`.
/// - Limits: Negative-index identities and non-integer arguments remain
///   symbolic.
pub fn tribonacci(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni < 0 {
        @symcore.function("tribonacci", [n])
      } else {
        expr_from_bigint(tribonacci_bigint(ni))
      }
    }
    None => @symcore.function("tribonacci", [n])
  }
}

///|
/// Build or evaluate a harmonic number.
///
/// - Does: Evaluates positive integer harmonic numbers as exact rationals.
/// - Input: One symbolic expression.
/// - Returns: An exact rational expression or symbolic `harmonic(n)`.
/// - Limits: Generalized harmonic numbers and non-positive integer cases remain
///   symbolic.
pub fn harmonic(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni <= 0 {
        @symcore.function("harmonic", [n])
      } else {
        match harmonic_rational(ni) {
          Some(value) => @symcore.Expr::Number(value)
          None => @symcore.function("harmonic", [n])
        }
      }
    }
    None => @symcore.function("harmonic", [n])
  }
}

///|
/// Build or evaluate a Bernoulli number.
///
/// - Does: Evaluates known small Bernoulli numbers and odd indices greater than
///   one as zero.
/// - Input: One symbolic expression.
/// - Returns: An exact rational/integer expression or symbolic `bernoulli(n)`.
/// - Limits: Values outside the local table remain symbolic.
pub fn bernoulli(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni > 1 && ni % 2 != 0 {
        @symcore.int(0)
      } else {
        match bernoulli_small(ni) {
          Some(v) => @symcore.Expr::Number(v)
          None => @symcore.function("bernoulli", [n])
        }
      }
    }
    None => @symcore.function("bernoulli", [n])
  }
}

///|
/// Build a symbolic Bell number expression.
///
/// - Does: Builds `bell(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Bell-number expression.
/// - Limits: Does not evaluate Bell numbers or Bell polynomials.
pub fn bell(n : Expr) -> Expr {
  @symcore.function("bell", [n])
}

///|
/// Build a symbolic Euler number expression.
///
/// - Does: Builds `euler(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Euler-number expression.
/// - Limits: Does not evaluate Euler numbers.
pub fn euler(n : Expr) -> Expr {
  @symcore.function("euler", [n])
}

///|
/// Build a symbolic Catalan number expression.
///
/// - Does: Builds `catalan(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Catalan-number expression.
/// - Limits: Does not evaluate Catalan numbers.
pub fn catalan(n : Expr) -> Expr {
  @symcore.function("catalan", [n])
}

///|
/// Build a symbolic Genocchi number expression.
///
/// - Does: Builds `genocchi(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Genocchi-number expression.
/// - Limits: Does not evaluate Genocchi numbers.
pub fn genocchi(n : Expr) -> Expr {
  @symcore.function("genocchi", [n])
}

///|
/// Build a symbolic Andre number expression.
///
/// - Does: Builds `andre(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Andre-number expression.
/// - Limits: Does not evaluate Andre numbers.
pub fn andre(n : Expr) -> Expr {
  @symcore.function("andre", [n])
}

///|
/// Build a symbolic partition-count expression.
///
/// - Does: Builds `partition(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic partition-count expression.
/// - Limits: Does not evaluate partition numbers.
pub fn partition(n : Expr) -> Expr {
  @symcore.function("partition", [n])
}

///|
/// Build or evaluate a divisor-sum expression.
///
/// - Does: Evaluates `divisor_sigma(n, k)` when both arguments are exact
///   integers, otherwise builds a symbolic expression.
/// - Input: A symbolic integer candidate `n` and optional symbolic exponent
///   `k`.
/// - Returns: An exact integer expression or symbolic `divisor_sigma(n, k)`.
/// - Limits: Domain errors from the integer backend are not exposed through a
///   dedicated error type here.
pub fn divisor_sigma(n : Expr, k? : Expr = int(1)) -> Expr {
  match (int_value(n), int_value(k)) {
    (Some(ni), Some(ki)) => {
      let res = @symntheory.divisor_sigma(ni, k=ki.to_int())
      expr_from_bigint(res)
    }
    _ => @symcore.function("divisor_sigma", [n, k])
  }
}

///|
/// Build a unitary divisor-sum expression.
///
/// - Does: Builds `udivisor_sigma(n, k)`.
/// - Input: A symbolic integer candidate `n` and optional symbolic exponent
///   `k`.
/// - Returns: A symbolic unitary-divisor-sum expression.
/// - Limits: Does not evaluate unitary divisor sums.
pub fn udivisor_sigma(n : Expr, k? : Expr = int(1)) -> Expr {
  @symcore.function("udivisor_sigma", [n, k])
}

///|
/// Build or evaluate a Legendre symbol.
///
/// - Does: Evaluates exact integer `legendre_symbol(a, p)` through the number
///   theory backend when possible.
/// - Input: Two symbolic expressions.
/// - Returns: An exact integer expression or symbolic `legendre_symbol(a, p)`.
/// - Limits: Invalid modulus cases fall back to a symbolic expression.
pub fn legendre_symbol(a : Expr, p : Expr) -> Expr {
  match (int_value(a), int_value(p)) {
    (Some(ai), Some(pi)) =>
      expr_from_int(
        @symntheory.legendre_symbol(ai, pi) catch {
          _ => return @symcore.function("legendre_symbol", [a, p])
        },
      )
    _ => @symcore.function("legendre_symbol", [a, p])
  }
}

///|
/// Build or evaluate a Jacobi symbol.
///
/// - Does: Evaluates exact integer `jacobi_symbol(a, n)` through the number
///   theory backend when possible.
/// - Input: Two symbolic expressions.
/// - Returns: An exact integer expression or symbolic `jacobi_symbol(a, n)`.
/// - Limits: Invalid modulus cases fall back to a symbolic expression.
pub fn jacobi_symbol(a : Expr, n : Expr) -> Expr {
  match (int_value(a), int_value(n)) {
    (Some(ai), Some(ni)) =>
      expr_from_int(
        @symntheory.jacobi_symbol(ai, ni) catch {
          _ => return @symcore.function("jacobi_symbol", [a, n])
        },
      )
    _ => @symcore.function("jacobi_symbol", [a, n])
  }
}

///|
/// Build a Kronecker symbol expression.
///
/// - Does: Builds `kronecker_symbol(a, n)`.
/// - Input: Two symbolic expressions.
/// - Returns: A symbolic Kronecker-symbol expression.
/// - Limits: Does not evaluate Kronecker symbols.
pub fn kronecker_symbol(a : Expr, n : Expr) -> Expr {
  @symcore.function("kronecker_symbol", [a, n])
}

///|
/// Build or evaluate the Mobius function.
///
/// - Does: Evaluates exact integer `mobius(n)` through the number theory
///   backend when possible.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `mobius(n)`.
/// - Limits: Backend domain errors fall back to a symbolic expression.
pub fn mobius(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) =>
      expr_from_int(
        @symntheory.mobius(ni) catch {
          _ => return @symcore.function("mobius", [n])
        },
      )
    None => @symcore.function("mobius", [n])
  }
}

///|
/// Build or evaluate the count of distinct prime factors.
///
/// - Does: Evaluates exact integer `primenu(n)` through the number theory
///   backend when possible.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `primenu(n)`.
/// - Limits: Non-integer inputs remain symbolic.
pub fn primenu(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_int(@symntheory.primenu(ni))
    None => @symcore.function("primenu", [n])
  }
}

///|
/// Build or evaluate the count of prime factors with multiplicity.
///
/// - Does: Evaluates exact integer `primeomega(n)` through the number theory
///   backend when possible.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `primeomega(n)`.
/// - Limits: Non-integer inputs remain symbolic.
pub fn primeomega(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_int(@symntheory.primeomega(ni))
    None => @symcore.function("primeomega", [n])
  }
}

///|
/// Build or evaluate Euler's totient.
///
/// - Does: Evaluates exact integer `totient(n)` through the number theory
///   backend when possible.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `totient(n)`.
/// - Limits: Non-integer inputs remain symbolic.
pub fn totient(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.totient(ni))
    None => @symcore.function("totient", [n])
  }
}

///|
/// Build or evaluate the reduced totient.
///
/// - Does: Evaluates exact integer `reduced_totient(n)` through the number
///   theory backend when possible.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `reduced_totient(n)`.
/// - Limits: Non-integer inputs remain symbolic.
pub fn reduced_totient(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.reduced_totient(ni))
    None => @symcore.function("reduced_totient", [n])
  }
}

///|
/// Build or evaluate the prime-counting function.
///
/// - Does: Evaluates exact integer `primepi(n)` through the number theory
///   backend when possible.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic `primepi(n)`.
/// - Limits: Non-integer inputs remain symbolic.
pub fn primepi(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.primepi(ni))
    None => @symcore.function("primepi", [n])
  }
}

///|
/// Build a symbolic Motzkin-number expression.
///
/// - Does: Builds `motzkin(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Motzkin-number expression.
/// - Limits: Does not evaluate Motzkin numbers.
pub fn motzkin(n : Expr) -> Expr {
  @symcore.function("motzkin", [n])
}

///|
/// Build a symbolic Carmichael-function expression.
///
/// - Does: Builds `carmichael(n)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Carmichael-function expression.
/// - Limits: Does not evaluate Carmichael values.
pub fn carmichael(n : Expr) -> Expr {
  @symcore.function("carmichael", [n])
}
