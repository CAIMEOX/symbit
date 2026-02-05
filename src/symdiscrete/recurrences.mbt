///|
/// Linear recurrences.

///|
pub fn linrec(
  coeffs : Array[Expr],
  init : Array[Expr],
  n : Int,
) -> Expr raise DiscreteError {
  if coeffs.is_empty() {
    return expr_zero()
  }
  if n < 0 {
    raise DiscreteError::ValueError("n must be non-negative")
  }
  let k = coeffs.length()
  if init.length() > k {
    raise DiscreteError::TypeError("init longer than coeffs")
  }
  let b : Array[Expr] = Array::new()
  for v in init {
    b.push(v)
  }
  for _ in b.length()..<k {
    b.push(expr_zero())
  }
  if n < k {
    return b[n]
  }
  let coeffs_n = linrec_coeffs(coeffs, n)
  let mut acc = expr_zero()
  for i in 0..<k {
    acc = expr_add2(acc, expr_mul2(coeffs_n[i], b[i]))
  }
  acc
}

///|
pub fn linrec_coeffs(c : Array[Expr], n : Int) -> Array[Expr] {
  let k = c.length()
  fn square_and_reduce(
    u : Array[Expr],
    offset : Int,
    c : Array[Expr],
  ) -> Array[Expr] {
    let wlen = 2 * u.length() - 1 + offset
    let w : Array[Expr] = Array::make(wlen, expr_zero())
    for i in 0..<u.length() {
      for j in 0..<u.length() {
        let idx = offset + i + j
        w[idx] = expr_add2(w[idx], expr_mul2(u[i], u[j]))
      }
    }
    let mut j = w.length() - 1
    while j >= k {
      for i in 0..<k {
        let idx = j - i - 1
        w[idx] = expr_add2(w[idx], expr_mul2(w[j], c[i]))
      }
      if j == 0 {
        break
      }
      j = j - 1
    }
    let out : Array[Expr] = Array::new()
    for i in 0..<k {
      out.push(w[i])
    }
    out
  }

  fn final_coeffs(n : Int, k : Int, c : Array[Expr]) -> Array[Expr] {
    if n < k {
      let out : Array[Expr] = Array::new()
      for i in 0..<k {
        out.push(if i == n { expr_one() } else { expr_zero() })
      }
      out
    } else {
      let sub = final_coeffs(n / 2, k, c)
      square_and_reduce(sub, n % 2, c)
    }
  }

  final_coeffs(n, k, c)
}
