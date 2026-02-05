///|
/// Convolution utilities and helpers.

///|
fn sum_stride_expr(values : Array[Expr], start : Int, step : Int) -> Expr {
  let mut acc = expr_zero()
  let mut i = start
  while i < values.length() {
    acc = expr_add2(acc, values[i])
    i = i + step
  }
  acc
}

///|
fn sum_stride_int(
  values : Array[Int],
  start : Int,
  step : Int,
  prime : Int,
) -> Int {
  let mut acc = 0
  let mut i = start
  while i < values.length() {
    acc = (acc + values[i]) % prime
    i = i + step
  }
  acc
}

///|
pub fn convolution_fft(
  a : Array[Expr],
  b : Array[Expr],
  dps? : Int,
) -> Array[Expr] raise DiscreteError {
  for v in a {
    if expr_has_symbol(v) {
      raise DiscreteError::ValueError("expected non-symbolic coefficients")
    }
  }
  for v in b {
    if expr_has_symbol(v) {
      raise DiscreteError::ValueError("expected non-symbolic coefficients")
    }
  }
  if a.is_empty() || b.is_empty() {
    return []
  }
  let m = a.length() + b.length() - 1
  let out : Array[Expr] = Array::make(m, expr_zero())
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let prod = expand_mul(expr_mul2(a[i], b[j]))
      out[i + j] = expr_add2(out[i + j], prod)
    }
  }
  let _ = dps
  out
}

///|
pub fn convolution_fwht(a : Array[Expr], b : Array[Expr]) -> Array[Expr] {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let n = if a.length() > b.length() { a.length() } else { b.length() }
  let (n2, _) = next_pow2(n)
  let aa : Array[Expr] = Array::new()
  let bb : Array[Expr] = Array::new()
  for v in a {
    aa.push(v)
  }
  for v in b {
    bb.push(v)
  }
  for _ in aa.length()..<n2 {
    aa.push(expr_zero())
  }
  for _ in bb.length()..<n2 {
    bb.push(expr_zero())
  }
  let fa = fwht(aa)
  let fb = fwht(bb)
  let prod : Array[Expr] = Array::new()
  for i in 0..<fa.length() {
    prod.push(expand_mul(expr_mul2(fa[i], fb[i])))
  }
  ifwht(prod)
}

///|
pub fn convolution_subset(
  a : Array[Expr],
  b : Array[Expr],
) -> Array[Expr] raise DiscreteError {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let n = if a.length() > b.length() { a.length() } else { b.length() }
  let (n2, _) = next_pow2(n)
  let aa : Array[Expr] = Array::new()
  let bb : Array[Expr] = Array::new()
  for v in a {
    aa.push(v)
  }
  for v in b {
    bb.push(v)
  }
  for _ in aa.length()..<n2 {
    aa.push(expr_zero())
  }
  for _ in bb.length()..<n2 {
    bb.push(expr_zero())
  }
  let c : Array[Expr] = Array::make(n2, expr_zero())
  for mask in 0..<n2 {
    let mut smask = mask
    while smask > 0 {
      c[mask] = expr_add2(
        c[mask],
        expand_mul(expr_mul2(aa[smask], bb[mask ^ smask])),
      )
      smask = (smask - 1) & mask
    }
    c[mask] = expr_add2(
      c[mask],
      expand_mul(expr_mul2(aa[smask], bb[mask ^ smask])),
    )
  }
  c
}

///|
pub fn covering_product(
  a : Array[Expr],
  b : Array[Expr],
) -> Array[Expr] raise DiscreteError {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let n = if a.length() > b.length() { a.length() } else { b.length() }
  let (n2, _) = next_pow2(n)
  let aa : Array[Expr] = Array::new()
  let bb : Array[Expr] = Array::new()
  for v in a {
    aa.push(v)
  }
  for v in b {
    bb.push(v)
  }
  for _ in aa.length()..<n2 {
    aa.push(expr_zero())
  }
  for _ in bb.length()..<n2 {
    bb.push(expr_zero())
  }
  let ta = mobius_transform(aa)
  let tb = mobius_transform(bb)
  let prod : Array[Expr] = Array::new()
  for i in 0..<ta.length() {
    prod.push(expand_mul(expr_mul2(ta[i], tb[i])))
  }
  inverse_mobius_transform(prod)
}

///|
pub fn intersecting_product(
  a : Array[Expr],
  b : Array[Expr],
) -> Array[Expr] raise DiscreteError {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let n = if a.length() > b.length() { a.length() } else { b.length() }
  let (n2, _) = next_pow2(n)
  let aa : Array[Expr] = Array::new()
  let bb : Array[Expr] = Array::new()
  for v in a {
    aa.push(v)
  }
  for v in b {
    bb.push(v)
  }
  for _ in aa.length()..<n2 {
    aa.push(expr_zero())
  }
  for _ in bb.length()..<n2 {
    bb.push(expr_zero())
  }
  let ta = mobius_transform(aa, subset=false)
  let tb = mobius_transform(bb, subset=false)
  let prod : Array[Expr] = Array::new()
  for i in 0..<ta.length() {
    prod.push(expand_mul(expr_mul2(ta[i], tb[i])))
  }
  inverse_mobius_transform(prod, subset=false)
}

///|
pub fn convolution_ntt(
  a : Array[Expr],
  b : Array[Expr],
  prime : Int,
) -> Array[Expr] raise DiscreteError {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let a_int : Array[Int] = Array::new()
  let b_int : Array[Int] = Array::new()
  for v in a {
    a_int.push(expr_to_int_checked(v, "convolution_ntt"))
  }
  for v in b {
    b_int.push(expr_to_int_checked(v, "convolution_ntt"))
  }
  let m = a_int.length() + b_int.length() - 1
  let (n2, _) = next_pow2(m)
  for _ in a_int.length()..<n2 {
    a_int.push(0)
  }
  for _ in b_int.length()..<n2 {
    b_int.push(0)
  }
  let fa = number_theoretic_transform_int(a_int, prime, false)
  let fb = number_theoretic_transform_int(b_int, prime, false)
  let fc : Array[Int] = Array::make(n2, 0)
  for i in 0..<n2 {
    fc[i] = mul_mod_int(fa[i], fb[i], prime)
  }
  let inv = number_theoretic_transform_int(fc, prime, true)
  let out : Array[Expr] = Array::new()
  for i in 0..<m {
    out.push(expr_int(inv[i]))
  }
  out
}

///|
pub fn convolution(
  a : Array[Expr],
  b : Array[Expr],
  cycle? : Int = 0,
  dps? : Int,
  prime? : Int,
  dyadic? : Bool,
  subset? : Bool,
) -> Array[Expr] raise DiscreteError {
  if cycle < 0 {
    raise DiscreteError::ValueError("cycle must be non-negative")
  }
  let dyadic_hint = match dyadic {
    Some(true) => true
    _ => false
  }
  let subset_hint = match subset {
    Some(true) => true
    _ => false
  }
  let mut hint_count = 0
  match prime {
    Some(_) => hint_count = hint_count + 1
    None => ()
  }
  match dps {
    Some(_) => hint_count = hint_count + 1
    None => ()
  }
  if dyadic_hint {
    hint_count = hint_count + 1
  }
  if subset_hint {
    hint_count = hint_count + 1
  }
  if hint_count > 1 {
    raise DiscreteError::TypeError("ambiguous convolution hints")
  }
  match prime {
    Some(p) => {
      let ls = convolution_ntt(a, b, p)
      if cycle == 0 {
        return ls
      }
      let ints : Array[Int] = Array::new()
      for v in ls {
        ints.push(expr_to_int_checked(v, "convolution"))
      }
      let out : Array[Expr] = Array::new()
      for i in 0..<cycle {
        out.push(expr_int(sum_stride_int(ints, i, cycle, p)))
      }
      return out
    }
    None => ()
  }
  let ls = if dyadic_hint {
    convolution_fwht(a, b)
  } else if subset_hint {
    convolution_subset(a, b)
  } else {
    match dps {
      Some(v) => convolution_fft(a, b, dps=v)
      None => convolution_fft(a, b)
    }
  }
  if cycle == 0 {
    return ls
  }
  let out : Array[Expr] = Array::new()
  for i in 0..<cycle {
    out.push(sum_stride_expr(ls, i, cycle))
  }
  out
}
