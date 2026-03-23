///|
fn swap_dense_rows(data : Array[Array[Expr]], i : Int, j : Int) -> Unit {
  let tmp = data[i]
  data[i] = data[j]
  data[j] = tmp
}

///|
fn matrix_echelon_internal(matrix : Matrix) -> (Array[Array[Expr]], Array[Int]) {
  let data = clone_expr_rows(matrix.data)
  let pivots : Array[Int] = []
  let mut row = 0
  let mut col = 0
  let mut prev = expr_one()
  while row < matrix.rows && col < matrix.cols {
    let mut pivot_row = row
    while pivot_row < matrix.rows && expr_is_zero(data[pivot_row][col]) {
      pivot_row += 1
    }
    if pivot_row == matrix.rows {
      col += 1
      continue
    }
    if pivot_row != row {
      swap_dense_rows(data, pivot_row, row)
    }
    let pivot = data[row][col]
    for i in (row + 1)..<matrix.rows {
      let factor = data[i][col]
      if expr_is_zero(factor) {
        continue
      }
      data[i][col] = expr_zero()
      for j in (col + 1)..<matrix.cols {
        let numer = expr_sub(
          expr_mul(pivot, data[i][j]),
          expr_mul(factor, data[row][j]),
        )
        data[i][j] = expr_div(numer, prev)
      }
    }
    pivots.push(col)
    prev = pivot
    row += 1
    col += 1
  }
  (data, pivots)
}

///|
fn matrix_rref_internal(matrix : Matrix) -> (Array[Array[Expr]], Array[Int]) {
  let data = clone_expr_rows(matrix.data)
  let pivots : Array[Int] = []
  let mut row = 0
  let mut col = 0
  while row < matrix.rows && col < matrix.cols {
    let mut pivot_row = row
    while pivot_row < matrix.rows && expr_is_zero(data[pivot_row][col]) {
      pivot_row += 1
    }
    if pivot_row == matrix.rows {
      col += 1
      continue
    }
    if pivot_row != row {
      swap_dense_rows(data, pivot_row, row)
    }
    let pivot = data[row][col]
    for j in col..<matrix.cols {
      data[row][j] = expr_div(data[row][j], pivot)
    }
    for i in 0..<matrix.rows {
      if i == row {
        continue
      }
      let factor = data[i][col]
      if expr_is_zero(factor) {
        continue
      }
      for j in col..<matrix.cols {
        data[i][j] = expr_sub(data[i][j], expr_mul(factor, data[row][j]))
      }
    }
    pivots.push(col)
    row += 1
    col += 1
  }
  (data, pivots)
}

///|
pub fn Matrix::rref(self : Matrix) -> (Matrix, Array[Int]) {
  let numeric_prec = expr_numeric_precision(self.data)
  if matrix_has_floating_leaf(self.data) && matrix_all_numeric(self.data, numeric_prec) {
    let data = clone_expr_rows(self.data).map(row => row.map(cell => {
      @symcore.evalf(cell, prec=numeric_prec)
    }))
    let pivots : Array[Int] = []
    let mut row = 0
    let mut col = 0
    while row < self.rows && col < self.cols {
      let mut pivot_row = row
      let mut pivot_measure = expr_numeric_abs(data[row][col], numeric_prec)
      for candidate in (row + 1)..<self.rows {
        match (expr_numeric_abs(data[candidate][col], numeric_prec), pivot_measure) {
          (Some(measure), Some(best)) if @symnum.mpf_cmp(measure, best) > 0 => {
            pivot_row = candidate
            pivot_measure = Some(measure)
          }
          (Some(measure), None) => {
            pivot_row = candidate
            pivot_measure = Some(measure)
          }
          _ => ()
        }
      }
      if expr_numeric_zero(data[pivot_row][col], numeric_prec) {
        col += 1
        continue
      }
      if pivot_row != row {
        swap_dense_rows(data, pivot_row, row)
      }
      let pivot = data[row][col]
      for j in col..<self.cols {
        data[row][j] = expr_numeric_div(data[row][j], pivot, numeric_prec)
      }
      for i in 0..<self.rows {
        if i == row {
          continue
        }
        let factor = data[i][col]
        if expr_numeric_zero(factor, numeric_prec) {
          continue
        }
        for j in col..<self.cols {
          data[i][j] = expr_numeric_sub(
            data[i][j],
            expr_numeric_mul(factor, data[row][j], numeric_prec),
            numeric_prec,
          )
        }
      }
      pivots.push(col)
      row += 1
      col += 1
    }
    return ({ rows: self.rows, cols: self.cols, data }, pivots)
  }
  let (data, pivots) = matrix_rref_internal(self)
  ({ rows: self.rows, cols: self.cols, data }, pivots)
}

///|
pub fn Matrix::rank(self : Matrix) -> Int {
  self.rref().1.length()
}

///|
pub fn Matrix::echelon_form(self : Matrix) -> Matrix {
  let (data, _) = matrix_echelon_internal(self)
  { rows: self.rows, cols: self.cols, data }
}

///|
pub fn Matrix::echelon_form_with_pivots(self : Matrix) -> (Matrix, Array[Int]) {
  let (data, pivots) = matrix_echelon_internal(self)
  ({ rows: self.rows, cols: self.cols, data }, pivots)
}

///|
pub fn Matrix::is_echelon(self : Matrix) -> Bool {
  let mut last_pivot = -1
  let mut seen_zero_row = false
  for i in 0..<self.rows {
    let mut pivot = -1
    for j in 0..<self.cols {
      if !expr_is_zero(self.data[i][j]) {
        pivot = j
        break
      }
    }
    if pivot == -1 {
      seen_zero_row = true
      continue
    }
    if seen_zero_row || pivot <= last_pivot {
      return false
    }
    last_pivot = pivot
  }
  true
}

///|
pub fn Matrix::det(self : Matrix) -> Expr raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "determinant requires a square matrix",
    )
  }
  if self.rows == 0 {
    return expr_one()
  }
  let numeric_prec = expr_numeric_precision(self.data)
  if matrix_has_floating_leaf(self.data) && matrix_all_numeric(self.data, numeric_prec) {
    let data = clone_expr_rows(self.evalf(prec=numeric_prec).data)
    let mut sign = expr_one()
    let mut col = 0
    while col < self.rows {
      let mut pivot_row = col
      let mut pivot_measure = expr_numeric_abs(data[col][col], numeric_prec)
      for candidate in (col + 1)..<self.rows {
        match (expr_numeric_abs(data[candidate][col], numeric_prec), pivot_measure) {
          (Some(measure), Some(best)) if @symnum.mpf_cmp(measure, best) > 0 => {
            pivot_row = candidate
            pivot_measure = Some(measure)
          }
          (Some(measure), None) => {
            pivot_row = candidate
            pivot_measure = Some(measure)
          }
          _ => ()
        }
      }
      if expr_numeric_zero(data[pivot_row][col], numeric_prec) {
        return expr_zero()
      }
      if pivot_row != col {
        swap_dense_rows(data, pivot_row, col)
        sign = expr_numeric_mul(sign, expr_neg(expr_one()), numeric_prec)
      }
      let pivot = data[col][col]
      for row in (col + 1)..<self.rows {
        if expr_numeric_zero(data[row][col], numeric_prec) {
          continue
        }
        let factor = expr_numeric_div(data[row][col], pivot, numeric_prec)
        for j in col..<self.cols {
          data[row][j] = expr_numeric_sub(
            data[row][j],
            expr_numeric_mul(factor, data[col][j], numeric_prec),
            numeric_prec,
          )
        }
      }
      col += 1
    }
    let mut det = sign
    for i in 0..<self.rows {
      det = expr_numeric_mul(det, data[i][i], numeric_prec)
    }
    return det
  }
  let data = clone_expr_rows(self.data)
  let mut sign = expr_one()
  let mut prev = expr_one()
  for k in 0..<(self.rows - 1) {
    let mut pivot_row = k
    while pivot_row < self.rows && expr_is_zero(data[pivot_row][k]) {
      pivot_row += 1
    }
    if pivot_row == self.rows {
      return expr_zero()
    }
    if pivot_row != k {
      swap_dense_rows(data, pivot_row, k)
      sign = expr_neg(sign)
    }
    let pivot = data[k][k]
    for i in (k + 1)..<self.rows {
      for j in (k + 1)..<self.cols {
        let numer = expr_sub(
          expr_mul(pivot, data[i][j]),
          expr_mul(data[i][k], data[k][j]),
        )
        data[i][j] = expr_div(numer, prev)
      }
    }
    prev = pivot
  }
  expr_mul(sign, data[self.rows - 1][self.cols - 1])
}

///|
pub fn Matrix::minor_submatrix(
  self : Matrix,
  row : Int,
  col : Int,
) -> Matrix raise MatrixError {
  self.row_del(row).col_del(col)
}

///|
pub fn Matrix::minor(
  self : Matrix,
  row : Int,
  col : Int,
) -> Expr raise MatrixError {
  self.minor_submatrix(row, col).det()
}

///|
pub fn Matrix::cofactor(
  self : Matrix,
  row : Int,
  col : Int,
) -> Expr raise MatrixError {
  let sign = if (row + col) % 2 == 0 {
    expr_one()
  } else {
    expr_neg(expr_one())
  }
  expr_mul(sign, self.minor(row, col))
}

///|
pub fn Matrix::cofactor_matrix(self : Matrix) -> Matrix raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "cofactor matrix requires a square matrix",
    )
  }
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<self.cols {
      row.push(self.cofactor(i, j))
    }
    out.push(row)
  }
  matrix(out)
}

///|
pub fn Matrix::adjugate(self : Matrix) -> Matrix raise MatrixError {
  self.cofactor_matrix().transpose()
}

///|
pub fn Matrix::inv(self : Matrix) -> Matrix raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError("inverse requires a square matrix")
  }
  let n = self.rows
  let numeric_prec = expr_numeric_precision(self.data)
  if matrix_has_floating_leaf(self.data) && matrix_all_numeric(self.data, numeric_prec) {
    let left = clone_expr_rows(self.evalf(prec=numeric_prec).data)
    let right = clone_expr_rows(eye(n).evalf(prec=numeric_prec).data)
    for col in 0..<n {
      let mut pivot_row = col
      let mut pivot_measure = expr_numeric_abs(left[col][col], numeric_prec)
      for candidate in (col + 1)..<n {
        match (expr_numeric_abs(left[candidate][col], numeric_prec), pivot_measure) {
          (Some(measure), Some(best)) if @symnum.mpf_cmp(measure, best) > 0 => {
            pivot_row = candidate
            pivot_measure = Some(measure)
          }
          (Some(measure), None) => {
            pivot_row = candidate
            pivot_measure = Some(measure)
          }
          _ => ()
        }
      }
      if expr_numeric_zero(left[pivot_row][col], numeric_prec) {
        raise MatrixError::SingularMatrixError("matrix is singular")
      }
      if pivot_row != col {
        swap_dense_rows(left, pivot_row, col)
        swap_dense_rows(right, pivot_row, col)
      }
      let pivot = left[col][col]
      for j in 0..<n {
        left[col][j] = expr_numeric_div(left[col][j], pivot, numeric_prec)
        right[col][j] = expr_numeric_div(right[col][j], pivot, numeric_prec)
      }
      for i in 0..<n {
        if i == col {
          continue
        }
        let factor = left[i][col]
        if expr_numeric_zero(factor, numeric_prec) {
          continue
        }
        for j in 0..<n {
          left[i][j] = expr_numeric_sub(
            left[i][j],
            expr_numeric_mul(factor, left[col][j], numeric_prec),
            numeric_prec,
          )
          right[i][j] = expr_numeric_sub(
            right[i][j],
            expr_numeric_mul(factor, right[col][j], numeric_prec),
            numeric_prec,
          )
        }
      }
    }
    return { rows: n, cols: n, data: right }
  }
  let left = clone_expr_rows(self.data)
  let right = clone_expr_rows(eye(n).data)
  for col in 0..<n {
    let mut pivot_row = col
    while pivot_row < n && expr_is_zero(left[pivot_row][col]) {
      pivot_row += 1
    }
    if pivot_row == n {
      raise MatrixError::SingularMatrixError("matrix is singular")
    }
    if pivot_row != col {
      swap_dense_rows(left, pivot_row, col)
      swap_dense_rows(right, pivot_row, col)
    }
    let pivot = left[col][col]
    for j in 0..<n {
      left[col][j] = expr_div(left[col][j], pivot)
      right[col][j] = expr_div(right[col][j], pivot)
    }
    for i in 0..<n {
      if i == col {
        continue
      }
      let factor = left[i][col]
      if expr_is_zero(factor) {
        continue
      }
      for j in 0..<n {
        left[i][j] = expr_sub(left[i][j], expr_mul(factor, left[col][j]))
        right[i][j] = expr_sub(right[i][j], expr_mul(factor, right[col][j]))
      }
    }
  }
  { rows: n, cols: n, data: right }
}

///|
pub fn Matrix::solve(self : Matrix, rhs : Matrix) -> Matrix raise MatrixError {
  if self.rows != rhs.rows {
    raise MatrixError::ShapeError(
      "solve expects rhs with the same number of rows",
    )
  }
  self.inv() * rhs
}

///|
pub fn Matrix::rref_rhs(
  self : Matrix,
  rhs : Matrix,
) -> (Matrix, Matrix) raise MatrixError {
  if self.rows != rhs.rows {
    raise MatrixError::ShapeError(
      "rref_rhs expects rhs with the same number of rows",
    )
  }
  let augmented = self.row_join(rhs)
  let (reduced, _) = augmented.rref()
  let left_cols : Array[Int] = []
  let right_cols : Array[Int] = []
  for j in 0..<self.cols {
    left_cols.push(j)
  }
  for j in self.cols..<reduced.cols {
    right_cols.push(j)
  }
  (
    reduced.extract(Array::makei(self.rows, fn(i) { i }), left_cols),
    reduced.extract(Array::makei(self.rows, fn(i) { i }), right_cols),
  )
}

///|
pub fn Matrix::rowspace(self : Matrix) -> Array[Array[Expr]] {
  let (rref, _) = self.rref()
  let out : Array[Array[Expr]] = []
  for row in rref.data {
    if row.any(item => !expr_is_zero(item)) {
      let copied : Array[Expr] = []
      for item in row {
        copied.push(item)
      }
      out.push(copied)
    }
  }
  out
}

///|
pub fn Matrix::columnspace(self : Matrix) -> Array[Array[Expr]] {
  let (_, pivots) = self.rref()
  let out : Array[Array[Expr]] = []
  for pivot in pivots {
    let col : Array[Expr] = []
    for i in 0..<self.rows {
      col.push(self.data[i][pivot])
    }
    out.push(col)
  }
  out
}

///|
pub fn Matrix::nullspace(self : Matrix) -> Array[Array[Expr]] {
  let (rref, pivots) = self.rref()
  let pivot_set : Map[Int, Bool] = {}
  for pivot in pivots {
    pivot_set[pivot] = true
  }
  let free_cols : Array[Int] = []
  for j in 0..<self.cols {
    if !pivot_set.contains(j) {
      free_cols.push(j)
    }
  }
  let basis : Array[Array[Expr]] = []
  for free_col in free_cols {
    let vec = Array::make(self.cols, expr_zero())
    vec[free_col] = expr_one()
    for i in 0..<pivots.length() {
      let pivot_col = pivots[i]
      vec[pivot_col] = expr_neg(rref.data[i][free_col])
    }
    basis.push(vec)
  }
  basis
}

///|
pub fn Matrix::lu(
  self : Matrix,
) -> (Matrix, Matrix, Array[(Int, Int)]) raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "LU decomposition requires a square matrix",
    )
  }
  let n = self.rows
  let u = clone_expr_rows(self.data)
  let l = clone_expr_rows(eye(n).data)
  let swaps : Array[(Int, Int)] = []
  for k in 0..<n {
    let mut pivot_row = k
    while pivot_row < n && expr_is_zero(u[pivot_row][k]) {
      pivot_row += 1
    }
    if pivot_row == n {
      continue
    }
    if pivot_row != k {
      swap_dense_rows(u, pivot_row, k)
      for j in 0..<k {
        let tmp = l[pivot_row][j]
        l[pivot_row][j] = l[k][j]
        l[k][j] = tmp
      }
      swaps.push((k, pivot_row))
    }
    let pivot = u[k][k]
    for i in (k + 1)..<n {
      if expr_is_zero(u[i][k]) {
        continue
      }
      let factor = expr_div(u[i][k], pivot)
      l[i][k] = factor
      for j in k..<n {
        u[i][j] = expr_sub(u[i][j], expr_mul(factor, u[k][j]))
      }
    }
  }
  ({ rows: n, cols: n, data: l }, { rows: n, cols: n, data: u }, swaps)
}

///|
pub fn Matrix::lower_triangular_solve(
  self : Matrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if !self.is_square() || self.rows != rhs.rows {
    raise MatrixError::ShapeError(
      "lower_triangular_solve expects a square lhs and matching rhs rows",
    )
  }
  let numeric_prec = {
    let lhs_prec = expr_numeric_precision(self.data)
    let rhs_prec = expr_numeric_precision(rhs.data)
    if lhs_prec > rhs_prec { lhs_prec } else { rhs_prec }
  }
  let numeric_mode = (matrix_has_floating_leaf(self.data) || matrix_has_floating_leaf(rhs.data)) &&
    matrix_all_numeric(self.data, numeric_prec) &&
    matrix_all_numeric(rhs.data, numeric_prec)
  let out = zeros(self.rows, cols=Some(rhs.cols))
  let data = clone_expr_rows(out.data)
  for j in 0..<rhs.cols {
    for i in 0..<self.rows {
      let mut acc = rhs.data[i][j]
      for k in 0..<i {
        acc = if numeric_mode {
          expr_numeric_sub(
            acc,
            expr_numeric_mul(self.data[i][k], data[k][j], numeric_prec),
            numeric_prec,
          )
        } else {
          expr_sub(acc, expr_mul(self.data[i][k], data[k][j]))
        }
      }
      data[i][j] = if numeric_mode {
        expr_numeric_div(acc, self.data[i][i], numeric_prec)
      } else {
        expr_div(acc, self.data[i][i])
      }
    }
  }
  { rows: self.rows, cols: rhs.cols, data }
}

///|
pub fn Matrix::upper_triangular_solve(
  self : Matrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if !self.is_square() || self.rows != rhs.rows {
    raise MatrixError::ShapeError(
      "upper_triangular_solve expects a square lhs and matching rhs rows",
    )
  }
  let numeric_prec = {
    let lhs_prec = expr_numeric_precision(self.data)
    let rhs_prec = expr_numeric_precision(rhs.data)
    if lhs_prec > rhs_prec { lhs_prec } else { rhs_prec }
  }
  let numeric_mode = (matrix_has_floating_leaf(self.data) || matrix_has_floating_leaf(rhs.data)) &&
    matrix_all_numeric(self.data, numeric_prec) &&
    matrix_all_numeric(rhs.data, numeric_prec)
  let out = zeros(self.rows, cols=Some(rhs.cols))
  let data = clone_expr_rows(out.data)
  for j in 0..<rhs.cols {
    let mut i = self.rows - 1
    while true {
      let mut acc = rhs.data[i][j]
      for k in (i + 1)..<self.cols {
        acc = if numeric_mode {
          expr_numeric_sub(
            acc,
            expr_numeric_mul(self.data[i][k], data[k][j], numeric_prec),
            numeric_prec,
          )
        } else {
          expr_sub(acc, expr_mul(self.data[i][k], data[k][j]))
        }
      }
      data[i][j] = if numeric_mode {
        expr_numeric_div(acc, self.data[i][i], numeric_prec)
      } else {
        expr_div(acc, self.data[i][i])
      }
      if i == 0 {
        break
      }
      i -= 1
    }
  }
  { rows: self.rows, cols: rhs.cols, data }
}

///|
pub fn Matrix::cholesky(self : Matrix) -> Matrix raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "cholesky decomposition requires a square matrix",
    )
  }
  let n = self.rows
  let out = zeros(n, cols=Some(n))
  let l = clone_expr_rows(out.data)
  let numeric_prec = expr_numeric_precision(self.data)
  let numeric_mode = matrix_has_floating_leaf(self.data) &&
    matrix_all_numeric(self.data, numeric_prec)
  for i in 0..<n {
    for j in 0..<=i {
      let mut acc = self.data[i][j]
      for k in 0..<j {
        acc = if numeric_mode {
          expr_numeric_sub(
            acc,
            expr_numeric_mul(l[i][k], l[j][k], numeric_prec),
            numeric_prec,
          )
        } else {
          expr_sub(acc, expr_mul(l[i][k], l[j][k]))
        }
      }
      if i == j {
        l[i][j] = if numeric_mode {
          expr_numeric_sqrt(acc, numeric_prec)
        } else {
          expr_simplify(@symcore.function("sqrt", [acc]))
        }
      } else {
        l[i][j] = if numeric_mode {
          expr_numeric_div(acc, l[j][j], numeric_prec)
        } else {
          expr_div(acc, l[j][j])
        }
      }
    }
  }
  { rows: n, cols: n, data: l }
}

///|
pub fn Matrix::ldl(self : Matrix) -> (Matrix, Matrix) raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "LDL decomposition requires a square matrix",
    )
  }
  let n = self.rows
  let l0 = zeros(n, cols=Some(n))
  let d0 = zeros(n, cols=Some(n))
  let l = clone_expr_rows(l0.data)
  let d = clone_expr_rows(d0.data)
  for i in 0..<n {
    l[i][i] = expr_one()
  }
  let numeric_prec = expr_numeric_precision(self.data)
  let numeric_mode = matrix_has_floating_leaf(self.data) &&
    matrix_all_numeric(self.data, numeric_prec)
  for j in 0..<n {
    let mut diag = self.data[j][j]
    for k in 0..<j {
      diag = if numeric_mode {
        expr_numeric_sub(
          diag,
          expr_numeric_mul(
            expr_numeric_mul(l[j][k], l[j][k], numeric_prec),
            d[k][k],
            numeric_prec,
          ),
          numeric_prec,
        )
      } else {
        expr_sub(diag, expr_mul(expr_mul(l[j][k], l[j][k]), d[k][k]))
      }
    }
    d[j][j] = diag
    for i in (j + 1)..<n {
      let mut value = self.data[i][j]
      for k in 0..<j {
        value = if numeric_mode {
          expr_numeric_sub(
            value,
            expr_numeric_mul(
              expr_numeric_mul(l[i][k], l[j][k], numeric_prec),
              d[k][k],
              numeric_prec,
            ),
            numeric_prec,
          )
        } else {
          expr_sub(value, expr_mul(expr_mul(l[i][k], l[j][k]), d[k][k]))
        }
      }
      l[i][j] = if numeric_mode {
        expr_numeric_div(value, d[j][j], numeric_prec)
      } else {
        expr_div(value, d[j][j])
      }
    }
  }
  ({ rows: n, cols: n, data: l }, { rows: n, cols: n, data: d })
}

///|
pub fn Matrix::qr(self : Matrix) -> (Matrix, Matrix) raise MatrixError {
  if self.rows == 0 || self.cols == 0 {
    return (
      zeros(self.rows, cols=Some(self.cols)),
      zeros(self.cols, cols=Some(self.cols)),
    )
  }
  let numeric_prec = expr_numeric_precision(self.data)
  let numeric_mode = matrix_has_floating_leaf(self.data) &&
    matrix_all_numeric(self.data, numeric_prec)
  let qcols : Array[Array[Expr]] = []
  let r = Array::make(self.cols, Array::make(self.cols, expr_zero()))
  for j in 0..<self.cols {
    let v = self.col(j)
    for i in 0..<j {
      let qi = qcols[i]
      let mut dot = expr_zero()
      for k in 0..<self.rows {
        dot = if numeric_mode {
          expr_numeric_add(
            dot,
            expr_numeric_mul(qi[k], v[k], numeric_prec),
            numeric_prec,
          )
        } else {
          expr_add(dot, expr_mul(qi[k], v[k]))
        }
      }
      r[i][j] = dot
      for k in 0..<self.rows {
        v[k] = if numeric_mode {
          expr_numeric_sub(
            v[k],
            expr_numeric_mul(dot, qi[k], numeric_prec),
            numeric_prec,
          )
        } else {
          expr_sub(v[k], expr_mul(dot, qi[k]))
        }
      }
    }
    let mut norm_sq = expr_zero()
    for k in 0..<self.rows {
      norm_sq = if numeric_mode {
        expr_numeric_add(
          norm_sq,
          expr_numeric_mul(v[k], v[k], numeric_prec),
          numeric_prec,
        )
      } else {
        expr_add(norm_sq, expr_mul(v[k], v[k]))
      }
    }
    let norm = if numeric_mode {
      expr_numeric_sqrt(norm_sq, numeric_prec)
    } else {
      expr_simplify(@symcore.function("sqrt", [norm_sq]))
    }
    r[j][j] = norm
    let qj : Array[Expr] = []
    for k in 0..<self.rows {
      qj.push(if numeric_mode {
        expr_numeric_div(v[k], norm, numeric_prec)
      } else {
        expr_div(v[k], norm)
      })
    }
    qcols.push(qj)
  }
  let qrows : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<self.cols {
      row.push(qcols[j][i])
    }
    qrows.push(row)
  }
  (
    { rows: self.rows, cols: self.cols, data: qrows },
    { rows: self.cols, cols: self.cols, data: r },
  )
}
