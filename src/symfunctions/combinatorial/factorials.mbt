///|
/// Combinatorial factorial-related functions.

///|
fn factorial_bigint(n : Int) -> BigInt {
  if n <= 1 {
    return BigInt::from_int(1)
  }
  let mut acc = BigInt::from_int(1)
  let mut i = 2
  while i <= n {
    acc = acc * BigInt::from_int(i)
    i = i + 1
  }
  acc
}

///|
fn double_factorial_bigint(n : Int) -> BigInt {
  if n <= 0 {
    return BigInt::from_int(1)
  }
  let mut acc = BigInt::from_int(1)
  let mut i = n
  while i > 0 {
    acc = acc * BigInt::from_int(i)
    i = i - 2
  }
  acc
}

///|
fn subfactorial_bigint(n : Int) -> BigInt {
  if n <= 0 {
    return BigInt::from_int(1)
  }
  if n == 1 {
    return BigInt::from_int(0)
  }
  let mut a = BigInt::from_int(1)
  let mut b = BigInt::from_int(0)
  let mut k = 2
  while k <= n {
    let next = BigInt::from_int(k - 1) * (a + b)
    a = b
    b = next
    k = k + 1
  }
  b
}

///|
fn binomial_bigint(n : Int, k : Int) -> BigInt {
  if k < 0 || k > n {
    return BigInt::from_int(0)
  }
  let kk = if k > n - k { n - k } else { k }
  let mut acc = BigInt::from_int(1)
  let mut i = 1
  while i <= kk {
    acc = acc * BigInt::from_int(n - kk + i)
    acc = acc / BigInt::from_int(i)
    i = i + 1
  }
  acc
}

///|
fn rising_factorial_bigint(x : Int, k : Int) -> BigInt {
  if k <= 0 {
    return BigInt::from_int(1)
  }
  let mut acc = BigInt::from_int(1)
  let mut i = 0
  while i < k {
    acc = acc * BigInt::from_int(x + i)
    i = i + 1
  }
  acc
}

///|
fn falling_factorial_bigint(x : Int, k : Int) -> BigInt {
  if k <= 0 {
    return BigInt::from_int(1)
  }
  let mut acc = BigInt::from_int(1)
  let mut i = 0
  while i < k {
    acc = acc * BigInt::from_int(x - i)
    i = i + 1
  }
  acc
}

///|
pub fn factorial(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni < 0 {
        @symcore.function("factorial", [n])
      } else {
        expr_from_bigint(factorial_bigint(ni))
      }
    }
    None => @symcore.function("factorial", [n])
  }
}

///|
pub fn factorial2(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni < 0 {
        @symcore.function("factorial2", [n])
      } else {
        expr_from_bigint(double_factorial_bigint(ni))
      }
    }
    None => @symcore.function("factorial2", [n])
  }
}

///|
pub fn subfactorial(n : @symcore.Expr) -> @symcore.Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni < 0 {
        @symcore.function("subfactorial", [n])
      } else {
        expr_from_bigint(subfactorial_bigint(ni))
      }
    }
    None => @symcore.function("subfactorial", [n])
  }
}

///|
pub fn rf(x : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  match (int_value(x), int_value(k)) {
    (Some(xi), Some(ki)) => {
      let kint = ki.to_int()
      if kint < 0 {
        @symcore.function("rf", [x, k])
      } else {
        expr_from_bigint(rising_factorial_bigint(xi.to_int(), kint))
      }
    }
    _ => @symcore.function("rf", [x, k])
  }
}

///|
pub fn ff(x : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  match (int_value(x), int_value(k)) {
    (Some(xi), Some(ki)) => {
      let kint = ki.to_int()
      if kint < 0 {
        @symcore.function("ff", [x, k])
      } else {
        expr_from_bigint(falling_factorial_bigint(xi.to_int(), kint))
      }
    }
    _ => @symcore.function("ff", [x, k])
  }
}

///|
pub fn rising_factorial(x : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("RisingFactorial", [x, k])
}

///|
pub fn falling_factorial(x : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("FallingFactorial", [x, k])
}

///|
pub fn binomial(n : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  match (int_value(n), int_value(k)) {
    (Some(ni), Some(ki)) => {
      let nint = ni.to_int()
      let kint = ki.to_int()
      expr_from_bigint(binomial_bigint(nint, kint))
    }
    _ => @symcore.function("binomial", [n, k])
  }
}
