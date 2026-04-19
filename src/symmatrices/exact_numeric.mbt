///|
type ExactRatRows = Array[Array[@symnum.BigRational]]

///|
type ExactIntRows = Array[Array[BigInt]]

///|
fn exact_rational_from_expr(expr : Expr) -> @symnum.BigRational? {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) => {
      let exact : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
        num, den,
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
fn exact_integer_from_expr(expr : Expr) -> BigInt? {
  match @symcore.exact_number_num_den(expr) {
    Some((num, den)) if den.equal_int(1) => Some(num)
    _ => None
  }
}

///|
fn exact_expr_from_rational(value : @symnum.BigRational) -> Expr {
  Expr::Number(value)
}

///|
fn exact_expr_from_integer(value : BigInt) -> Expr {
  Expr::Number(@symnum.BigRational::from_bigint(value))
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
fn clone_exact_int_rows(rows : ExactIntRows) -> ExactIntRows {
  let out : ExactIntRows = []
  for row in rows {
    let copied : Array[BigInt] = []
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
fn swap_exact_int_rows(data : ExactIntRows, i : Int, j : Int) -> Unit {
  let tmp = data[i]
  data[i] = data[j]
  data[j] = tmp
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
fn matrix_exact_integer_data(rows : Array[Array[Expr]]) -> ExactIntRows? {
  let out : ExactIntRows = []
  for row in rows {
    let converted : Array[BigInt] = []
    for item in row {
      match exact_integer_from_expr(item) {
        Some(value) => converted.push(value)
        None => return None
      }
    }
    out.push(converted)
  }
  Some(out)
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
fn exact_int_div_unchecked(lhs : BigInt, rhs : BigInt) -> BigInt {
  if rhs.is_zero() {
    abort("exact_int_div_unchecked: zero pivot")
  }
  lhs.div(rhs)
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
fn make_exact_int_dense(rows : Int, cols : Int, fill : BigInt) -> ExactIntRows {
  let out : ExactIntRows = []
  for _ in 0..<rows {
    let row : Array[BigInt] = []
    for _ in 0..<cols {
      row.push(fill)
    }
    out.push(row)
  }
  out
}

///|
fn tail_bigint_slice(row : Array[BigInt], start : Int) -> Array[BigInt] {
  let out : Array[BigInt] = []
  for i in start..<row.length() {
    out.push(row[i])
  }
  out
}

///|
fn exact_integer_dense_imatmul(
  acc : ExactIntRows,
  left : ExactIntRows,
  right : ExactIntRows,
) -> Unit {
  if left.is_empty() || right.is_empty() {
    return
  }
  let right_cols = right[0].length()
  let zero = 0N
  let right_t = make_exact_int_dense(right_cols, right.length(), zero)
  for i in 0..<right.length() {
    for j in 0..<right_cols {
      right_t[j][i] = right[i][j]
    }
  }
  for i in 0..<left.length() {
    let left_row = left[i]
    let acc_row = acc[i]
    for j in 0..<right_t.length() {
      let mut total = acc_row[j]
      let right_col = right_t[j]
      for k in 0..<left_row.length() {
        total = total.add(left_row[k].mul(right_col[k]))
      }
      acc_row[j] = total
    }
  }
}

///|
fn exact_integer_rref_den(
  data0 : ExactIntRows,
) -> (ExactIntRows, BigInt, Array[Int]) {
  let data = clone_exact_int_rows(data0)
  let m = data.length()
  if m == 0 {
    return (data, 1N, [])
  }
  let n = data[0].length()
  let mut d : BigInt? = None
  let pivots : Array[Int] = []
  let no_pivots : Array[Int] = []
  let zero = 0N
  let mut i = 0
  for j in 0..<n {
    if i >= m {
      break
    }
    let mut aij = data[i][j]
    if aij.is_zero() {
      let mut ip = i + 1
      while ip < m && data[ip][j].is_zero() {
        ip += 1
      }
      if ip == m {
        no_pivots.push(j)
        continue
      }
      swap_exact_int_rows(data, i, ip)
      aij = data[i][j]
    }

    if !pivots.is_empty() {
      let mut pivot_val = aij.mul(data[0][pivots[0]])
      match d {
        Some(prev) => pivot_val = exact_int_div_unchecked(pivot_val, prev)
        None => ()
      }
      for ip in 0..<pivots.length() {
        data[ip][pivots[ip]] = pivot_val
      }
    }

    for jnp in no_pivots {
      for ip in 0..<i {
        let mut value = data[ip][jnp]
        if value.is_zero() {
          continue
        }
        value = value.mul(aij)
        match d {
          Some(prev) => value = exact_int_div_unchecked(value, prev)
          None => ()
        }
        data[ip][jnp] = value
      }
    }

    for jp in 0..<m {
      if jp == i {
        continue
      }
      for kp in (j + 1)..<n {
        let mut value = aij.mul(data[jp][kp]).sub(data[jp][j].mul(data[i][kp]))
        match d {
          Some(prev) => value = exact_int_div_unchecked(value, prev)
          None => ()
        }
        data[jp][kp] = value
      }
      data[jp][j] = zero
    }

    pivots.push(j)
    i += 1
    if i >= m {
      break
    }
    d = if aij.equal_int(1) { None } else { Some(aij) }
  }

  let denom = if pivots.is_empty() { 1N } else { data[0][pivots[0]] }
  (data, denom, pivots)
}

///|
fn exact_integer_fraction_rows_to_expr_rows(
  rows : ExactIntRows,
  den0 : BigInt,
) -> Array[Array[Expr]] {
  let den_negative = den0.op_lt(0N)
  let den = if den_negative { den0.neg() } else { den0 }
  let out : Array[Array[Expr]] = []
  for row in rows {
    let rendered : Array[Expr] = []
    for item0 in row {
      let item = if den_negative { item0.neg() } else { item0 }
      if item.is_zero() {
        rendered.push(@symcore.int(0))
      } else if den.equal_int(1) {
        rendered.push(exact_expr_from_integer(item))
      } else {
        let value = @symnum.BigRational::new(item, den) catch {
          _ =>
            abort(
              "exact_integer_fraction_rows_to_expr_rows: invalid denominator",
            )
        }
        rendered.push(Expr::Number(value))
      }
    }
    out.push(rendered)
  }
  out
}

///|
fn exact_integer_inverse(data0 : ExactIntRows) -> (ExactIntRows, BigInt)? {
  if data0.is_empty() {
    return Some(([], 1N))
  }
  let n = data0.length()
  let one = 1N
  let zero = 0N
  let aug : ExactIntRows = []
  for i in 0..<n {
    let row = data0[i].copy()
    for j in 0..<n {
      row.push(if i == j { one } else { zero })
    }
    aug.push(row)
  }
  let (aug_rref, den, pivots) = exact_integer_rref_den(aug)
  if pivots.length() != n {
    return None
  }
  for i in 0..<n {
    if pivots[i] != i {
      return None
    }
  }
  let num : ExactIntRows = []
  for i in 0..<n {
    let row : Array[BigInt] = []
    for j in 0..<n {
      row.push(aug_rref[i][n + j])
    }
    num.push(row)
  }
  Some((num, den))
}

///|
fn exact_integer_solve(
  lhs0 : ExactIntRows,
  rhs0 : ExactIntRows,
) -> (ExactIntRows, BigInt)? {
  if lhs0.is_empty() {
    return Some(([], 1N))
  }
  let rows = lhs0.length()
  let cols = lhs0[0].length()
  let rhs_cols = rhs0[0].length()
  let aug : ExactIntRows = []
  for i in 0..<rows {
    let row = lhs0[i].copy()
    for value in rhs0[i] {
      row.push(value)
    }
    aug.push(row)
  }
  let (aug_rref, den, pivots) = exact_integer_rref_den(aug)
  if pivots.length() != cols {
    return None
  }
  if !pivots.is_empty() && pivots[pivots.length() - 1] >= cols {
    return None
  }
  let num : ExactIntRows = []
  for i in 0..<cols {
    let row : Array[BigInt] = []
    for j in 0..<rhs_cols {
      row.push(aug_rref[i][cols + j])
    }
    num.push(row)
  }
  Some((num, den))
}

///|
fn exact_integer_charpoly_berk(rows : ExactIntRows) -> Array[BigInt] {
  let m = rows.length()
  if m == 0 {
    return [1N]
  }
  let n = rows[0].length()
  if n == 1 {
    return [1N, rows[0][0].neg()]
  }

  let a = rows[0][0]
  let r : ExactIntRows = [tail_bigint_slice(rows[0], 1)]
  let c : ExactIntRows = []
  let minor : ExactIntRows = []
  for i in 1..<n {
    c.push([rows[i][0]])
    minor.push(tail_bigint_slice(rows[i], 1))
  }

  let q = exact_integer_charpoly_berk(minor)
  let zero = 0N
  let one = 1N
  let t = make_exact_int_dense(n + 1, n, zero)
  for i in 0..<n {
    t[i][i] = one
    t[i + 1][i] = a.neg()
  }

  let mut an_c = c
  for i in 2..<=n {
    if i > 2 {
      let prev = an_c
      an_c = make_exact_int_dense(prev.length(), 1, zero)
      exact_integer_dense_imatmul(an_c, minor, prev)
    }
    let ran_c = make_exact_int_dense(1, 1, zero)
    exact_integer_dense_imatmul(ran_c, r, an_c)
    for j in 0..<(n + 1 - i) {
      t[i + j][j] = ran_c[0][0].neg()
    }
  }

  let q_col : ExactIntRows = []
  for coeff in q {
    q_col.push([coeff])
  }
  let out = make_exact_int_dense(n + 1, 1, zero)
  exact_integer_dense_imatmul(out, t, q_col)
  let coeffs : Array[BigInt] = []
  for row in out {
    coeffs.push(row[0])
  }
  coeffs
}

///|
fn exact_integer_charpoly_expr(rows : ExactIntRows, x : Expr) -> Expr {
  let coeffs = exact_integer_charpoly_berk(rows)
  let degree = coeffs.length() - 1
  let terms : Array[Expr] = []
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if coeff.is_zero() {
      continue
    }
    let coeff_expr = exact_expr_from_integer(coeff)
    let exp = degree - i
    let term = match exp {
      0 => coeff_expr
      1 => if coeff.equal_int(1) { x } else { @symcore.mul([coeff_expr, x]) }
      _ => {
        let x_pow = @symcore.pow(x, @symcore.int(exp))
        if coeff.equal_int(1) {
          x_pow
        } else {
          @symcore.mul([coeff_expr, x_pow])
        }
      }
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(terms)
  }
}
