///|
/// Combinatorial number sequences.

///|
fn fib_bigint(n : Int) -> BigInt {
  if n <= 0 {
    return BigInt::from_int(0)
  }
  if n == 1 {
    return BigInt::from_int(1)
  }
  let mut a = BigInt::from_int(0)
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
fn bernoulli_small(n : Int) -> @symnum.BigRational? {
  // B0..B10
  match n {
    0 => Some(@symnum.BigRational::from_int(1))
    1 => combinatorial_rational(-1, 2)
    2 => combinatorial_rational(1, 6)
    3 => Some(@symnum.BigRational::from_int(0))
    4 => combinatorial_rational(-1, 30)
    5 => Some(@symnum.BigRational::from_int(0))
    6 => combinatorial_rational(1, 42)
    7 => Some(@symnum.BigRational::from_int(0))
    8 => combinatorial_rational(-1, 30)
    9 => Some(@symnum.BigRational::from_int(0))
    10 => combinatorial_rational(5, 66)
    _ => None
  }
}

///|
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
pub fn bernoulli(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      match bernoulli_small(ni) {
        Some(v) => @symcore.Expr::Number(v)
        None => @symcore.function("bernoulli", [n])
      }
    }
    None => @symcore.function("bernoulli", [n])
  }
}

///|
pub fn bell(n : Expr) -> Expr {
  @symcore.function("bell", [n])
}

///|
pub fn euler(n : Expr) -> Expr {
  @symcore.function("euler", [n])
}

///|
pub fn catalan(n : Expr) -> Expr {
  @symcore.function("catalan", [n])
}

///|
pub fn genocchi(n : Expr) -> Expr {
  @symcore.function("genocchi", [n])
}

///|
pub fn andre(n : Expr) -> Expr {
  @symcore.function("andre", [n])
}

///|
pub fn partition(n : Expr) -> Expr {
  @symcore.function("partition", [n])
}

///|
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
pub fn udivisor_sigma(n : Expr, k? : Expr = int(1)) -> Expr {
  @symcore.function("udivisor_sigma", [n, k])
}

///|
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
pub fn kronecker_symbol(a : Expr, n : Expr) -> Expr {
  @symcore.function("kronecker_symbol", [a, n])
}

///|
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
pub fn primenu(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_int(@symntheory.primenu(ni))
    None => @symcore.function("primenu", [n])
  }
}

///|
pub fn primeomega(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_int(@symntheory.primeomega(ni))
    None => @symcore.function("primeomega", [n])
  }
}

///|
pub fn totient(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.totient(ni))
    None => @symcore.function("totient", [n])
  }
}

///|
pub fn reduced_totient(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.reduced_totient(ni))
    None => @symcore.function("reduced_totient", [n])
  }
}

///|
pub fn primepi(n : Expr) -> Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.primepi(ni))
    None => @symcore.function("primepi", [n])
  }
}

///|
pub fn motzkin(n : Expr) -> Expr {
  @symcore.function("motzkin", [n])
}

///|
pub fn carmichael(n : Expr) -> Expr {
  @symcore.function("carmichael", [n])
}
