///|
/// Discrete transforms.

///|
fn bit_length(n : Int) -> Int {
  if n <= 0 {
    return 0
  }
  let mut v = n
  let mut bits = 0
  while v > 0 {
    bits = bits + 1
    v = v >> 1
  }
  bits
}

///|
fn next_pow2(n : Int) -> (Int, Int) {
  if n <= 1 {
    return (n, 0)
  }
  let mut b = bit_length(n) - 1
  let mut pow = n
  if (n & (n - 1)) != 0 {
    b = b + 1
    pow = 1 << b
  }
  (pow, b)
}

///|
fn bit_reverse(x0 : Int, bits : Int) -> Int {
  let mut x = x0
  let mut out = 0
  for _ in 0..<bits {
    out = (out << 1) | (x & 1)
    x = x >> 1
  }
  out
}

///|
fn cos_sin_table(n : Int, k : Int) -> (Expr, Expr) {
  if n <= 0 {
    return (expr_one(), expr_zero())
  }
  let mut idx = k % n
  if idx < 0 {
    idx = idx + n
  }
  if n == 1 {
    return (expr_one(), expr_zero())
  }
  if n == 2 {
    return match idx {
      0 => (expr_one(), expr_zero())
      _ => (expr_neg_one(), expr_zero())
    }
  }
  if n == 4 {
    return match idx {
      0 => (expr_one(), expr_zero())
      1 => (expr_zero(), expr_one())
      2 => (expr_neg_one(), expr_zero())
      _ => (expr_zero(), expr_neg_one())
    }
  }
  if n == 8 {
    let sqrt2 = expr_sqrt(expr_int(2))
    let half = expr_rational(1, 2)
    let s2 = expr_mul2(sqrt2, half)
    return match idx {
      0 => (expr_one(), expr_zero())
      1 => (s2, s2)
      2 => (expr_zero(), expr_one())
      3 => (expr_neg(s2), s2)
      4 => (expr_neg_one(), expr_zero())
      5 => (expr_neg(s2), expr_neg(s2))
      6 => (expr_zero(), expr_neg_one())
      _ => (s2, expr_neg(s2))
    }
  }
  let angle = expr_mul2(expr_rational(2 * idx, n), expr_pi())
  let cosv = @symcore.function("cos", [angle])
  let sinv = @symcore.function("sin", [angle])
  (cosv, sinv)
}

///|
fn root_unity(n : Int, k : Int, inverse : Bool) -> Expr {
  let (c, s) = cos_sin_table(n, k)
  let sinv = if inverse { expr_neg(s) } else { s }
  expr_add2(c, expr_mul2(expr_i(), sinv))
}

///|
fn fourier_transform(
  seq : Array[Expr],
  inverse : Bool,
  dps : Int?,
) -> Array[Expr] raise DiscreteError {
  if seq.length() < 2 {
    let out : Array[Expr] = Array::new()
    for v in seq {
      out.push(v)
    }
    return out
  }
  let a : Array[Expr] = Array::new()
  for v in seq {
    if expr_has_symbol(v) {
      raise DiscreteError::ValueError("expected non-symbolic coefficients")
    }
    a.push(v)
  }
  let (n2, bits) = next_pow2(a.length())
  for _ in a.length()..<n2 {
    a.push(expr_zero())
  }
  for i in 1..<n2 {
    let j = bit_reverse(i, bits)
    if i < j {
      let tmp = a[i]
      a[i] = a[j]
      a[j] = tmp
    }
  }
  let w : Array[Expr] = Array::new()
  let half = n2 / 2
  for i in 0..<half {
    w.push(root_unity(n2, i, inverse))
  }
  let mut h = 2
  while h <= n2 {
    let hf = h / 2
    let ut = n2 / h
    let mut i = 0
    while i < n2 {
      for j in 0..<hf {
        let u = a[i + j]
        let v = expand_mul(@symcore.mul([a[i + j + hf], w[ut * j]]))
        a[i + j] = expr_add2(u, v)
        a[i + j + hf] = expr_sub(u, v)
      }
      i = i + h
    }
    h = h * 2
  }
  if inverse {
    for i in 0..<n2 {
      a[i] = expr_div_int(a[i], n2)
    }
    let _ = dps
  }
  a
}

///|
pub fn fft(seq : Array[Expr], dps? : Int) -> Array[Expr] raise DiscreteError {
  fourier_transform(seq, false, dps)
}

///|
pub fn ifft(seq : Array[Expr], dps? : Int) -> Array[Expr] raise DiscreteError {
  fourier_transform(seq, true, dps)
}

///|
fn mod_positive(x : Int, p : Int) -> Int {
  let mut r = x % p
  if r < 0 {
    r = r + p
  }
  r
}

///|
fn pow_mod_int(base : Int, exp : Int, modulus : Int) -> Int {
  let b = @bigint.BigInt::from_int(base)
  let e = @bigint.BigInt::from_int(exp)
  let m = @bigint.BigInt::from_int(modulus)
  let res = @symntheory.pow_mod(b, e, m)
  res.to_int()
}

///|
fn factorize_int(n0 : Int) -> Array[Int] {
  let mut n = n0
  let factors : Array[Int] = Array::new()
  let mut d = 2
  while d * d <= n {
    if n % d == 0 {
      factors.push(d)
      while n % d == 0 {
        n = n / d
      }
    }
    d = d + 1
  }
  if n > 1 {
    factors.push(n)
  }
  factors
}

///|
fn primitive_root_prime(p : Int) -> Int raise DiscreteError {
  let phi = p - 1
  let factors = factorize_int(phi)
  for g in 2..<p {
    let mut ok = true
    for q in factors {
      if pow_mod_int(g, phi / q, p) == 1 {
        ok = false
        break
      }
    }
    if ok {
      return g
    }
  }
  raise DiscreteError::ValueError("primitive root not found")
}

///|
fn number_theoretic_transform_int(
  seq : Array[Int],
  prime : Int,
  inverse : Bool,
) -> Array[Int] raise DiscreteError {
  let p = @bigint.BigInt::from_int(prime)
  if !@symntheory.isprime(p) {
    raise DiscreteError::ValueError("expected prime modulus")
  }
  let a_int : Array[Int] = Array::new()
  for v in seq {
    a_int.push(mod_positive(v, prime))
  }
  if a_int.length() < 1 {
    return a_int
  }
  let (n2, bits) = next_pow2(a_int.length())
  if (prime - 1) % n2 != 0 {
    raise DiscreteError::ValueError("expected modulus of form (m*2**k + 1)")
  }
  for _ in a_int.length()..<n2 {
    a_int.push(0)
  }
  for i in 1..<n2 {
    let j = bit_reverse(i, bits)
    if i < j {
      let tmp = a_int[i]
      a_int[i] = a_int[j]
      a_int[j] = tmp
    }
  }
  let pr = primitive_root_prime(prime)
  let mut rt = pow_mod_int(pr, (prime - 1) / n2, prime)
  if inverse {
    rt = pow_mod_int(rt, prime - 2, prime)
  }
  let w : Array[Int] = Array::make(n2 / 2, 1)
  for i in 1..<w.length() {
    w[i] = mul_mod_int(w[i - 1], rt, prime)
  }
  let mut h = 2
  while h <= n2 {
    let hf = h / 2
    let ut = n2 / h
    let mut i = 0
    while i < n2 {
      for j in 0..<hf {
        let u = a_int[i + j]
        let v = mul_mod_int(a_int[i + j + hf], w[ut * j], prime)
        a_int[i + j] = mod_positive(u + v, prime)
        a_int[i + j + hf] = mod_positive(u - v, prime)
      }
      i = i + h
    }
    h = h * 2
  }
  if inverse {
    let inv_n = pow_mod_int(n2, prime - 2, prime)
    for i in 0..<n2 {
      a_int[i] = mul_mod_int(a_int[i], inv_n, prime)
    }
  }
  a_int
}

///|
fn number_theoretic_transform(
  seq : Array[Expr],
  prime : Int,
  inverse : Bool,
) -> Array[Expr] raise DiscreteError {
  let values : Array[Int] = Array::new()
  for v in seq {
    let x = expr_to_int_checked(v, "ntt coefficient")
    values.push(x)
  }
  let out = number_theoretic_transform_int(values, prime, inverse)
  out.map(expr_int)
}

///|
pub fn ntt(seq : Array[Expr], prime : Int) -> Array[Expr] raise DiscreteError {
  number_theoretic_transform(seq, prime, false)
}

///|
pub fn intt(seq : Array[Expr], prime : Int) -> Array[Expr] raise DiscreteError {
  number_theoretic_transform(seq, prime, true)
}

///|
fn walsh_hadamard_transform(seq : Array[Expr], inverse : Bool) -> Array[Expr] {
  if seq.length() < 2 {
    let out : Array[Expr] = Array::new()
    for v in seq {
      out.push(v)
    }
    return out
  }
  let a : Array[Expr] = Array::new()
  for v in seq {
    a.push(v)
  }
  let (n2, _) = next_pow2(a.length())
  for _ in a.length()..<n2 {
    a.push(expr_zero())
  }
  let mut h = 2
  while h <= n2 {
    let hf = h / 2
    let mut i = 0
    while i < n2 {
      for j in 0..<hf {
        let u = a[i + j]
        let v = a[i + j + hf]
        a[i + j] = expr_add2(u, v)
        a[i + j + hf] = expr_sub(u, v)
      }
      i = i + h
    }
    h = h * 2
  }
  if inverse {
    for i in 0..<n2 {
      a[i] = expr_div_int(a[i], n2)
    }
  }
  a
}

///|
pub fn fwht(seq : Array[Expr]) -> Array[Expr] {
  walsh_hadamard_transform(seq, false)
}

///|
pub fn ifwht(seq : Array[Expr]) -> Array[Expr] {
  walsh_hadamard_transform(seq, true)
}

///|
fn mobius_transform_core(
  seq : Array[Expr],
  sgn : Int,
  subset : Bool,
) -> Array[Expr] raise DiscreteError {
  let a : Array[Expr] = Array::new()
  for v in seq {
    a.push(v)
  }
  if a.length() < 2 {
    return a
  }
  let (n2, _) = next_pow2(a.length())
  for _ in a.length()..<n2 {
    a.push(expr_zero())
  }
  let mut i = 1
  while i < n2 {
    for j in 0..<n2 {
      if subset {
        if (j & i) != 0 {
          a[j] = expr_add2(a[j], expr_mul2(expr_int(sgn), a[j ^ i]))
        }
      } else if (j & i) == 0 {
        a[j] = expr_add2(a[j], expr_mul2(expr_int(sgn), a[j ^ i]))
      }
    }
    i = i * 2
  }
  a
}

///|
pub fn mobius_transform(
  seq : Array[Expr],
  subset? : Bool = true,
) -> Array[Expr] raise DiscreteError {
  mobius_transform_core(seq, 1, subset)
}

///|
pub fn inverse_mobius_transform(
  seq : Array[Expr],
  subset? : Bool = true,
) -> Array[Expr] raise DiscreteError {
  mobius_transform_core(seq, -1, subset)
}
