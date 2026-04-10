///|
type ExactRatRows = Array[Array[@symnum.BigRational]]

///|
fn exact_rational_from_expr(expr : Expr) -> @symnum.BigRational? {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) => {
      let exact : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
        num,
        den,
      )
      match exact {
        Ok(value) => Some(value)
        Err(_) => None
      }
    }
    None => None
  }
}

///|
fn exact_expr_from_rational(value : @symnum.BigRational) -> Expr {
  Expr::Number(value)
}

///|
fn clone_exact_rows(rows : ExactRatRows) -> ExactRatRows {
  let out : ExactRatRows = []
  for row in rows {
    let copied : Array[@symnum.BigRational] = []
    for item in row {
      copied.push(item)
    }
    out.push(copied)
  }
  out
}

///|
fn swap_exact_rows(data : ExactRatRows, i : Int, j : Int) -> Unit {
  let tmp = data[i]
  data[i] = data[j]
  data[j] = tmp
}

///|
fn exact_zero_rows(rows : Int, cols : Int) -> ExactRatRows {
  Array::makei(rows, fn(_) {
    Array::make(cols, @symnum.BigRational::zero())
  })
}

///|
fn exact_eye_rows(size : Int) -> ExactRatRows {
  let out = exact_zero_rows(size, size)
  for i in 0..<size {
    out[i][i] = @symnum.BigRational::one()
  }
  out
}

///|
fn matrix_exact_rational_data(rows : Array[Array[Expr]]) -> ExactRatRows? {
  let out : ExactRatRows = []
  for row in rows {
    let converted : Array[@symnum.BigRational] = []
    for item in row {
      match exact_rational_from_expr(item) {
        Some(value) => converted.push(value)
        None => return None
      }
    }
    out.push(converted)
  }
  Some(out)
}

///|
fn exact_expr_rows(rows : ExactRatRows) -> Array[Array[Expr]] {
  let out : Array[Array[Expr]] = []
  for row in rows {
    let converted : Array[Expr] = []
    for item in row {
      converted.push(exact_expr_from_rational(item))
    }
    out.push(converted)
  }
  out
}

///|
fn exact_div_unchecked(
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
) -> @symnum.BigRational {
  lhs.div_r(rhs) catch {
    _ => abort("exact_div_unchecked: zero pivot")
  }
}

///|
fn exact_pivot_row(data : ExactRatRows, start : Int, col : Int) -> Int {
  let mut pivot = start
  while pivot < data.length() && data[pivot][col].is_zero() {
    pivot += 1
  }
  pivot
}

///|
fn exact_rational_det(data0 : ExactRatRows) -> @symnum.BigRational {
  if data0.is_empty() {
    return @symnum.BigRational::one()
  }
  let data = clone_exact_rows(data0)
  let mut sign = @symnum.BigRational::one()
  let mut det = @symnum.BigRational::one()
  for col in 0..<data.length() {
    let pivot_row = exact_pivot_row(data, col, col)
    if pivot_row == data.length() {
      return @symnum.BigRational::zero()
    }
    if pivot_row != col {
      swap_exact_rows(data, pivot_row, col)
      sign = sign.neg_r()
    }
    let pivot = data[col][col]
    det = det.mul_r(pivot)
    for row in (col + 1)..<data.length() {
      if data[row][col].is_zero() {
        continue
      }
      let factor = exact_div_unchecked(data[row][col], pivot)
      data[row][col] = @symnum.BigRational::zero()
      for j in (col + 1)..<data.length() {
        data[row][j] = data[row][j].add_r(factor.mul_r(data[col][j]).neg_r())
      }
    }
  }
  sign.mul_r(det)
}

///|
fn exact_rational_gauss_jordan(
  lhs0 : ExactRatRows,
  rhs0 : ExactRatRows,
) -> ExactRatRows raise MatrixError {
  let n = lhs0.length()
  let lhs = clone_exact_rows(lhs0)
  let rhs = clone_exact_rows(rhs0)
  let rhs_cols = if rhs.is_empty() { 0 } else { rhs[0].length() }
  for col in 0..<n {
    let pivot_row = exact_pivot_row(lhs, col, col)
    if pivot_row == n {
      raise MatrixError::SingularMatrixError("matrix is singular")
    }
    if pivot_row != col {
      swap_exact_rows(lhs, pivot_row, col)
      swap_exact_rows(rhs, pivot_row, col)
    }
    let pivot = lhs[col][col]
    for j in col..<n {
      lhs[col][j] = exact_div_unchecked(lhs[col][j], pivot)
    }
    for j in 0..<rhs_cols {
      rhs[col][j] = exact_div_unchecked(rhs[col][j], pivot)
    }
    for row in 0..<n {
      if row == col || lhs[row][col].is_zero() {
        continue
      }
      let factor = lhs[row][col]
      lhs[row][col] = @symnum.BigRational::zero()
      for j in (col + 1)..<n {
        lhs[row][j] = lhs[row][j].add_r(factor.mul_r(lhs[col][j]).neg_r())
      }
      for j in 0..<rhs_cols {
        rhs[row][j] = rhs[row][j].add_r(factor.mul_r(rhs[col][j]).neg_r())
      }
    }
  }
  rhs
}

///|
fn exact_rational_matmul(lhs : ExactRatRows, rhs : ExactRatRows) -> ExactRatRows {
  if lhs.is_empty() || rhs.is_empty() {
    return []
  }
  let rows = lhs.length()
  let inner = rhs.length()
  let cols = rhs[0].length()
  let out = exact_zero_rows(rows, cols)
  for i in 0..<rows {
    for k in 0..<inner {
      let lhs_ik = lhs[i][k]
      if lhs_ik.is_zero() {
        continue
      }
      for j in 0..<cols {
        if rhs[k][j].is_zero() {
          continue
        }
        out[i][j] = out[i][j].add_r(lhs_ik.mul_r(rhs[k][j]))
      }
    }
  }
  out
}

///|
fn exact_rational_trace(data : ExactRatRows) -> @symnum.BigRational {
  let mut out = @symnum.BigRational::zero()
  for i in 0..<data.length() {
    out = out.add_r(data[i][i])
  }
  out
}

///|
fn exact_rational_charpoly_coeffs(
  data : ExactRatRows,
) -> Array[@symnum.BigRational] {
  let n = data.length()
  if n == 0 {
    return [@symnum.BigRational::one()]
  }
  let coeffs : Array[@symnum.BigRational] = [@symnum.BigRational::one()]
  let mut b = exact_eye_rows(n)
  for k in 1..=n {
    let ab = exact_rational_matmul(data, b)
    let trace = exact_rational_trace(ab)
    let c = exact_div_unchecked(
      trace.neg_r(),
      @symnum.BigRational::from_int(k),
    )
    coeffs.push(c)
    if k < n {
      for i in 0..<n {
        ab[i][i] = ab[i][i].add_r(c)
      }
      b = ab
    }
  }
  coeffs
}

///|
fn exact_rational_charpoly_expr(
  data : ExactRatRows,
  x : Expr,
) -> Expr {
  let coeffs = exact_rational_charpoly_coeffs(data)
  let mut out = exact_expr_from_rational(coeffs[0])
  for i in 1..<coeffs.length() {
    out = @symcore.add([
      @symcore.mul([out, x]),
      exact_expr_from_rational(coeffs[i]),
    ])
  }
  out
}
