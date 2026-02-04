///|
/// Polynomial helpers for series expansion.

///|
fn zero_expr() -> @symcore.Expr {
  @symcore.int(0)
}

///|
fn one_expr() -> @symcore.Expr {
  @symcore.int(1)
}

///|
fn is_zero_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn is_one_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_one()
    _ => false
  }
}

///|
fn expr_add(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(a) {
    b
  } else if is_zero_expr(b) {
    a
  } else {
    @symcore.add([a, b])
  }
}

///|
fn expr_mul(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(a) || is_zero_expr(b) {
    zero_expr()
  } else if is_one_expr(a) {
    b
  } else if is_one_expr(b) {
    a
  } else {
    @symcore.mul([a, b])
  }
}

///|
fn expr_neg(a : @symcore.Expr) -> @symcore.Expr {
  expr_mul(@symcore.int(-1), a)
}

///|
fn expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  expr_add(a, expr_neg(b))
}

///|
fn expr_inv(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Number(n) =>
      if n.is_zero() {
        None
      } else {
        try n.reciprocal() catch {
          _ => None
        } noraise {
          v => Some(@symcore.number(v))
        }
      }
    _ => Some(@symcore.pow(expr, @symcore.int(-1)))
  }
}

///|
fn poly_coeff(poly : Array[@symcore.Expr], idx : Int) -> @symcore.Expr {
  if idx < poly.length() {
    poly[idx]
  } else {
    zero_expr()
  }
}

///|
fn poly_trim(poly : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let mut end = poly.length()
  while end > 0 && is_zero_expr(poly[end - 1]) {
    end -= 1
  }
  let out : Array[@symcore.Expr] = Array::new()
  for i in 0..<end {
    out.push(poly[i])
  }
  out
}

///|
fn poly_add(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let len = if a.length() > b.length() { a.length() } else { b.length() }
  let out : Array[@symcore.Expr] = Array::new()
  for i in 0..<len {
    out.push(expr_add(poly_coeff(a, i), poly_coeff(b, i)))
  }
  poly_trim(out)
}

///|
fn poly_mul(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let out_len = a.length() + b.length() - 1
  let out : Array[@symcore.Expr] = Array::new()
  for _ in 0..<out_len {
    out.push(zero_expr())
  }
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let idx = i + j
      out[idx] = expr_add(out[idx], expr_mul(a[i], b[j]))
    }
  }
  poly_trim(out)
}

///|
fn poly_scale(
  poly : Array[@symcore.Expr],
  factor : @symcore.Expr,
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for c in poly {
    out.push(expr_mul(c, factor))
  }
  poly_trim(out)
}

///|
fn poly_pow(base : Array[@symcore.Expr], exp : Int) -> Array[@symcore.Expr] {
  if exp <= 0 {
    return [one_expr()]
  }
  let mut result : Array[@symcore.Expr] = [one_expr()]
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = poly_mul(result, b)
    }
    e = e / 2
    if e > 0 {
      b = poly_mul(b, b)
    }
  }
  result
}

///|
fn int_exp(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => {
      let num = n.numerator()
      if num.bit_length() > 30 {
        None
      } else {
        Some(num.to_int())
      }
    }
    _ => None
  }
}

///|
fn poly_from_expr(
  expr : @symcore.Expr,
  x : @symcore.Expr,
) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Number(_) => Some([expr])
    @symcore.Expr::Symbol(_) =>
      if expr == x {
        Some([zero_expr(), one_expr()])
      } else {
        Some([expr])
      }
    @symcore.Expr::Add(args) => {
      let mut acc : Array[@symcore.Expr] = [zero_expr()]
      for arg in args {
        match poly_from_expr(arg, x) {
          Some(poly) => acc = poly_add(acc, poly)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc : Array[@symcore.Expr] = [one_expr()]
      for arg in args {
        match poly_from_expr(arg, x) {
          Some(poly) => acc = poly_mul(acc, poly)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match int_exp(exp) {
        Some(e) if e >= 0 =>
          match poly_from_expr(base, x) {
            Some(poly) => Some(poly_pow(poly, e))
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn poly_series_div(
  num : Array[@symcore.Expr],
  den : Array[@symcore.Expr],
  n : Int,
) -> Array[@symcore.Expr]? {
  if den.is_empty() {
    return None
  }
  let b0 = den[0]
  if is_zero_expr(b0) {
    return None
  }
  let inv_b0 = match expr_inv(b0) {
    Some(v) => v
    None => return None
  }
  let out : Array[@symcore.Expr] = Array::new()
  for k in 0..<n {
    let mut acc = poly_coeff(num, k)
    let max_i = if k < den.length() - 1 { k } else { den.length() - 1 }
    for i in 1..<=max_i {
      let term = expr_mul(den[i], out[k - i])
      acc = expr_sub(acc, term)
    }
    let rk = expr_mul(acc, inv_b0)
    out.push(rk)
  }
  Some(poly_trim(out))
}

///|
fn poly_needs_order(poly : Array[@symcore.Expr], n : Int) -> Bool {
  if n <= 0 {
    return true
  }
  let mut i = n
  while i < poly.length() {
    if !is_zero_expr(poly[i]) {
      return true
    }
    i += 1
  }
  false
}
