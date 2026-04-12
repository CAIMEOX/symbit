///|
type ExactRatRows = Array[Array[@symnum.BigRational]]

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
