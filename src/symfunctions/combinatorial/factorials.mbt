///|
/// Combinatorial factorial-related functions.

///|
let small_factorials : Array[BigInt] = [
  BigInt::from_int(1),
  BigInt::from_int(1),
  BigInt::from_int(2),
  BigInt::from_int(6),
  BigInt::from_int(24),
  BigInt::from_int(120),
  BigInt::from_int(720),
  BigInt::from_int(5040),
  BigInt::from_int(40320),
  BigInt::from_int(362880),
  BigInt::from_int(3628800),
  BigInt::from_int(39916800),
  BigInt::from_int(479001600),
  BigInt::from_string("6227020800"),
  BigInt::from_string("87178291200"),
  BigInt::from_string("1307674368000"),
  BigInt::from_string("20922789888000"),
  BigInt::from_string("355687428096000"),
  BigInt::from_string("6402373705728000"),
  BigInt::from_string("121645100408832000"),
]

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
fn factorial_eval_bigint(n : Int) -> BigInt {
  if n < small_factorials.length() {
    return small_factorials[n]
  }
  factorial_bigint(n)
}

///|
fn pow2_bigint(exp : Int) -> BigInt {
  if exp <= 0 {
    return BigInt::from_int(1)
  }
  let mut acc = BigInt::from_int(1)
  let mut i = 0
  while i < exp {
    acc = acc * BigInt::from_int(2)
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
fn binomial_small_uint64(n : Int, k : Int) -> UInt64 {
  if k < 0 || k > n {
    return UInt64::default()
  }
  let kk = if k > n - k { n - k } else { k }
  let mut acc = UInt64::extend_uint(1)
  let mut i = 1
  while i <= kk {
    acc = acc * (n - kk + i).to_uint64()
    acc = acc / i.to_uint64()
    i = i + 1
  }
  acc
}

///|
fn binomial_bigint(n : Int, k : Int) -> BigInt {
  if k < 0 || k > n {
    return BigInt::from_int(0)
  }
  if n <= 62 {
    return BigInt::from_uint64(binomial_small_uint64(n, k))
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
fn factorial2_eval_nonnegative_bigint(n : Int) -> BigInt {
  if n <= 1 {
    return BigInt::from_int(1)
  }
  if n % 2 == 0 {
    let k = n / 2
    return pow2_bigint(k) * factorial_eval_bigint(k)
  }
  // SymPy rewrites positive odd n!! in terms of factorial/factorial2(n - 1).
  // The direct odd-step product keeps the same integer semantics without
  // building an exact quotient on the hot path.
  double_factorial_bigint(n)
}

///|
pub fn factorial(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni < 0 {
        @symcore.function("factorial", [n])
      } else {
        expr_from_bigint(factorial_eval_bigint(ni))
      }
    }
    None => @symcore.function("factorial", [n])
  }
}

///|
pub fn factorial2(n : Expr) -> Expr {
  match int_value(n) {
    Some(bi) => {
      let ni = bi.to_int()
      if ni >= 0 {
        expr_from_bigint(factorial2_eval_nonnegative_bigint(ni))
      } else if ni % 2 != 0 {
        let sign = if (1 - ni) / 2 % 2 == 0 { 1 } else { -1 }
        let numerator = BigInt::from_int(ni * sign)
        let denominator = factorial2_eval_nonnegative_bigint(-ni)
        let value : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
          numerator, denominator,
        )
        match value {
          Ok(rat) => @symcore.Expr::Number(rat)
          Err(_) => @symcore.function("factorial2", [n])
        }
      } else {
        @symcore.function("factorial2", [n])
      }
    }
    None => @symcore.function("factorial2", [n])
  }
}

///|
pub fn subfactorial(n : Expr) -> Expr {
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
pub fn rf(x : Expr, k : Expr) -> Expr {
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
pub fn ff(x : Expr, k : Expr) -> Expr {
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
pub fn rising_factorial(x : Expr, k : Expr) -> Expr {
  @symcore.function("RisingFactorial", [x, k])
}

///|
pub fn falling_factorial(x : Expr, k : Expr) -> Expr {
  @symcore.function("FallingFactorial", [x, k])
}

///|
pub fn binomial(n : Expr, k : Expr) -> Expr {
  match (int_value(n), int_value(k)) {
    (Some(ni), Some(ki)) => {
      let nint = ni.to_int()
      let kint = ki.to_int()
      expr_from_bigint(binomial_bigint(nint, kint))
    }
    _ => @symcore.function("binomial", [n, k])
  }
}
