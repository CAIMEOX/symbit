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
fn harmonic_rational(n : Int) -> @symnum.BigRational {
  let mut acc = @symnum.BigRational::zero()
  let mut k = 1
  while k <= n {
    let term = try! @symnum.BigRational::new(
      BigInt::from_int(1),
      BigInt::from_int(k),
    )
    acc = acc.add_r(term)
    k = k + 1
  }
  acc
}

///|
fn bernoulli_small(n : Int) -> @symnum.BigRational? {
  // B0..B10
  match n {
    0 => Some(@symnum.BigRational::from_int(1))
    1 =>
      Some(
        try! @symnum.BigRational::new(BigInt::from_int(-1), BigInt::from_int(2)),
      )
    2 =>
      Some(
        try! @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(6)),
      )
    3 => Some(@symnum.BigRational::from_int(0))
    4 =>
      Some(
        try! @symnum.BigRational::new(
          BigInt::from_int(-1),
          BigInt::from_int(30),
        ),
      )
    5 => Some(@symnum.BigRational::from_int(0))
    6 =>
      Some(
        try! @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(42)),
      )
    7 => Some(@symnum.BigRational::from_int(0))
    8 =>
      Some(
        try! @symnum.BigRational::new(
          BigInt::from_int(-1),
          BigInt::from_int(30),
        ),
      )
    9 => Some(@symnum.BigRational::from_int(0))
    10 =>
      Some(
        try! @symnum.BigRational::new(BigInt::from_int(5), BigInt::from_int(66)),
      )
    _ => None
  }
}

///|
pub fn fibonacci(n : @symcore.Expr) -> @symcore.Expr {
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
pub fn lucas(n : @symcore.Expr) -> @symcore.Expr {
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
pub fn tribonacci(n : @symcore.Expr) -> @symcore.Expr {
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
pub fn harmonic(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni <= 0 {
        @symcore.function("harmonic", [n])
      } else {
        @symcore.number(harmonic_rational(ni))
      }
    }
    None => @symcore.function("harmonic", [n])
  }
}

///|
pub fn bernoulli(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      match bernoulli_small(ni) {
        Some(v) => @symcore.number(v)
        None => @symcore.function("bernoulli", [n])
      }
    }
    None => @symcore.function("bernoulli", [n])
  }
}

///|
pub fn bell(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("bell", [n])
}

///|
pub fn euler(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("euler", [n])
}

///|
pub fn catalan(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("catalan", [n])
}

///|
pub fn genocchi(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("genocchi", [n])
}

///|
pub fn andre(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("andre", [n])
}

///|
pub fn partition(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("partition", [n])
}

///|
pub fn divisor_sigma(
  n : @symcore.Expr,
  k? : @symcore.Expr = @symcore.int(1),
) -> @symcore.Expr {
  match (int_value(n), int_value(k)) {
    (Some(ni), Some(ki)) => {
      let res = @symntheory.divisor_sigma(ni, k=ki.to_int())
      expr_from_bigint(res)
    }
    _ => @symcore.function("divisor_sigma", [n, k])
  }
}

///|
pub fn udivisor_sigma(
  n : @symcore.Expr,
  k? : @symcore.Expr = @symcore.int(1),
) -> @symcore.Expr {
  @symcore.function("udivisor_sigma", [n, k])
}

///|
pub fn legendre_symbol(a : @symcore.Expr, p : @symcore.Expr) -> @symcore.Expr {
  match (int_value(a), int_value(p)) {
    (Some(ai), Some(pi)) => {
      let res = try! @symntheory.legendre_symbol(ai, pi)
      expr_from_int(res)
    }
    _ => @symcore.function("legendre_symbol", [a, p])
  }
}

///|
pub fn jacobi_symbol(a : @symcore.Expr, n : @symcore.Expr) -> @symcore.Expr {
  match (int_value(a), int_value(n)) {
    (Some(ai), Some(ni)) => {
      let res = try! @symntheory.jacobi_symbol(ai, ni)
      expr_from_int(res)
    }
    _ => @symcore.function("jacobi_symbol", [a, n])
  }
}

///|
pub fn kronecker_symbol(a : @symcore.Expr, n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("kronecker_symbol", [a, n])
}

///|
pub fn mobius(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(ni) => {
      let res = try! @symntheory.mobius(ni)
      expr_from_int(res)
    }
    None => @symcore.function("mobius", [n])
  }
}

///|
pub fn primenu(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(ni) => expr_from_int(@symntheory.primenu(ni))
    None => @symcore.function("primenu", [n])
  }
}

///|
pub fn primeomega(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(ni) => expr_from_int(@symntheory.primeomega(ni))
    None => @symcore.function("primeomega", [n])
  }
}

///|
pub fn totient(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.totient(ni))
    None => @symcore.function("totient", [n])
  }
}

///|
pub fn reduced_totient(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.reduced_totient(ni))
    None => @symcore.function("reduced_totient", [n])
  }
}

///|
pub fn primepi(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(ni) => expr_from_bigint(@symntheory.primepi(ni))
    None => @symcore.function("primepi", [n])
  }
}

///|
pub fn motzkin(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("motzkin", [n])
}

///|
pub fn carmichael(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("carmichael", [n])
}
