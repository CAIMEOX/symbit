///|
fn swap_dense_rows(data : Array[Array[Expr]], i : Int, j : Int) -> Unit {
  let tmp = data[i]
  data[i] = data[j]
  data[j] = tmp
}

///|
fn symbolic_pivot_better(candidate : Expr, current : Expr) -> Bool {
  let candidate_exact = @symcore.exact_number_num_den(candidate) is Some(_)
  let current_exact = @symcore.exact_number_num_den(current) is Some(_)
  if candidate_exact != current_exact {
    return candidate_exact
  }
  let candidate_free = @symcore.free_symbols(candidate).length()
  let current_free = @symcore.free_symbols(current).length()
  if candidate_free != current_free {
    return candidate_free < current_free
  }
  @symprint.pretty_string(candidate).length() <
  @symprint.pretty_string(current).length()
}

///|
fn symbolic_pivot_row(
  data : Array[Array[Expr]],
  row : Int,
  rows : Int,
  col : Int,
) -> Int {
  let mut pivot_row = -1
  for candidate in row..<rows {
    let value = data[candidate][col]
    if expr_is_zero(value) {
      continue
    }
    if pivot_row == -1 || symbolic_pivot_better(value, data[pivot_row][col]) {
      pivot_row = candidate
    }
  }
  pivot_row
}

///|
fn raw_expr_sub(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])])
}

///|
fn raw_expr_mul(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.mul([lhs, rhs])
}

///|
fn raw_expr_div(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))])
}

///|
fn matrix_exact_dm(
  rows : Array[Array[Expr]],
) -> @sympolys.DomainMatrix raise MatrixError {
  @sympolys.DomainMatrix::from_Matrix(rows, fmt="dense") catch {
    _ =>
      raise ValueError(
        "matrix entries are not supported by the exact DomainMatrix linear algebra path",
      )
  }
}

///|
fn matrix_from_domain_matrix(
  dm : @sympolys.DomainMatrix,
) -> Matrix raise MatrixError {
  let rows = dm.to_Matrix() catch {
    _ =>
      raise ValueError(
        "exact DomainMatrix result could not be converted back to a symbolic matrix",
      )
  }
  { rows: dm.rows, cols: dm.cols, data: rows }
}

///|
fn matrix_index_range(start : Int, end_ : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for i in start..<end_ {
    out.push(i)
  }
  out
}

///|
fn matrix_exact_inverse(matrix : Matrix) -> Matrix raise MatrixError {
  match matrix_exact_integer_data(matrix.to_list()) {
    Some(data) =>
      match exact_integer_inverse(data) {
        Some((num, den)) =>
          return {
            rows: matrix.rows,
            cols: matrix.cols,
            data: exact_integer_fraction_rows_to_expr_rows(num, den),
          }
        None => raise SingularMatrixError("matrix is singular")
      }
    None => ()
  }
  let dm = matrix_exact_dm(matrix.to_list())
  let identity = @sympolys.DomainMatrix::eye(matrix.rows, dm.domain) catch {
    _ =>
      raise ValueError(
        "exact DomainMatrix inverse identity construction failed",
      )
  }
  let aug = dm.hstack(identity) catch {
    _ => raise ValueError("exact DomainMatrix inverse augmentation failed")
  }
  let (aug_rref, den0, pivots) = aug.rref_den(rref_method="FF_dense") catch {
    _ => raise SingularMatrixError("matrix is singular")
  }
  if pivots.length() != matrix.rows {
    raise SingularMatrixError("matrix is singular")
  }
  for i in 0..<matrix.rows {
    if pivots[i] != i {
      raise SingularMatrixError("matrix is singular")
    }
  }
  let num0 = aug_rref.extract(
    matrix_index_range(0, matrix.rows),
    matrix_index_range(matrix.rows, aug.cols),
  ) catch {
    _ => raise ValueError("exact DomainMatrix inverse extraction failed")
  }
  let num = if @sympolys.domain_is_field_pred(num0.domain) {
    num0
  } else {
    num0.to_field() catch {
      _ =>
        raise ValueError(
          "exact DomainMatrix inverse could not be converted into its field domain",
        )
    }
  }
  let den = (@sympolys.DomainScalar::new(den0, num0.domain) catch {
      _ =>
        raise MatrixError::ValueError(
          "exact DomainMatrix inverse denominator could not be reconstructed",
        )
    }).convert_to(num.domain).element catch {
      _ =>
        raise ValueError(
          "exact DomainMatrix inverse denominator could not be converted into the field domain",
        )
    }
  let inverse = num.mul(@sympolys.fe_inv(den)) catch {
    _ =>
      raise ValueError(
        "exact DomainMatrix inverse could not be normalized in its field domain",
      )
  }
  matrix_from_domain_matrix(inverse)
}

///|
fn matrix_exact_solve(lhs : Matrix, rhs : Matrix) -> Matrix raise MatrixError {
  match
    (
      matrix_exact_integer_data(lhs.to_list()),
      matrix_exact_integer_data(rhs.to_list()),
    ) {
    (Some(lhs_data), Some(rhs_data)) =>
      match exact_integer_solve(lhs_data, rhs_data) {
        Some((num, den)) =>
          return {
            rows: lhs.cols,
            cols: rhs.cols,
            data: exact_integer_fraction_rows_to_expr_rows(num, den),
          }
        None => raise SingularMatrixError("matrix is singular")
      }
    _ => ()
  }
  let lhs_dm = matrix_exact_dm(lhs.to_list())
  let rhs_dm = matrix_exact_dm(rhs.to_list())
  let aug = lhs_dm.hstack(rhs_dm) catch {
    _ => raise ValueError("exact DomainMatrix solve augmentation failed")
  }
  let (aug_rref, den0, pivots) = aug.rref_den(rref_method="FF_dense") catch {
    _ => raise SingularMatrixError("matrix is singular")
  }
  if pivots.length() != lhs.cols {
    raise SingularMatrixError("matrix is singular")
  }
  if !pivots.is_empty() && pivots[pivots.length() - 1] >= lhs.cols {
    raise SingularMatrixError("matrix is singular")
  }
  let num0 = aug_rref.extract(
    matrix_index_range(0, lhs.cols),
    matrix_index_range(lhs.cols, aug.cols),
  ) catch {
    _ => raise ValueError("exact DomainMatrix solve extraction failed")
  }
  let num = if @sympolys.domain_is_field_pred(num0.domain) {
    num0
  } else {
    num0.to_field() catch {
      _ =>
        raise ValueError(
          "exact DomainMatrix solve result could not be converted into its field domain",
        )
    }
  }
  let den = (@sympolys.DomainScalar::new(den0, num0.domain) catch {
      _ =>
        raise MatrixError::ValueError(
          "exact DomainMatrix solve denominator could not be reconstructed",
        )
    }).convert_to(num.domain).element catch {
      _ =>
        raise ValueError(
          "exact DomainMatrix solve denominator could not be converted into the field domain",
        )
    }
  let solution = num.mul(@sympolys.fe_inv(den)) catch {
    _ =>
      raise ValueError(
        "exact DomainMatrix solve result could not be normalized in its field domain",
      )
  }
  matrix_from_domain_matrix(solution)
}

///|
fn matrix_try_exact_inverse(matrix : Matrix) -> Matrix? raise MatrixError {
  try matrix_exact_inverse(matrix) catch {
    ValueError(_) => None
    err => raise err
  } noraise {
    value => Some(value)
  }
}

///|
fn matrix_try_exact_solve(
  lhs : Matrix,
  rhs : Matrix,
) -> Matrix? raise MatrixError {
  try matrix_exact_solve(lhs, rhs) catch {
    ValueError(_) => None
    err => raise err
  } noraise {
    value => Some(value)
  }
}

///|
fn matrix_echelon_internal(matrix : Matrix) -> (Array[Array[Expr]], Array[Int]) {
  let data = clone_expr_rows(matrix.data)
  let pivots : Array[Int] = []
  let mut row = 0
  let mut col = 0
  let mut prev = @symcore.int(1)
  while row < matrix.rows && col < matrix.cols {
    let pivot_row = symbolic_pivot_row(data, row, matrix.rows, col)
    if pivot_row == -1 {
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
      data[i][col] = @symcore.int(0)
      for j in (col + 1)..<matrix.cols {
        let numer = raw_expr_sub(
          raw_expr_mul(pivot, data[i][j]),
          raw_expr_mul(factor, data[row][j]),
        )
        data[i][j] = raw_expr_div(numer, prev)
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
    let pivot_row = symbolic_pivot_row(data, row, matrix.rows, col)
    if pivot_row == -1 {
      col += 1
      continue
    }
    if pivot_row != row {
      swap_dense_rows(data, pivot_row, row)
    }
    let pivot = data[row][col]
    for j in col..<matrix.cols {
      data[row][j] = raw_expr_div(data[row][j], pivot)
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
        data[i][j] = raw_expr_sub(
          data[i][j],
          raw_expr_mul(factor, data[row][j]),
        )
      }
    }
    pivots.push(col)
    row += 1
    col += 1
  }
  (data, pivots)
}

///|
/// Compute the reduced row echelon form of a matrix.
///
/// - Does: Returns the row-reduced form together with the pivot column indices.
/// - Input: Any dense `Matrix`.
/// - Returns: `(reduced_matrix, pivots)` where `pivots` lists pivot columns in ascending order.
/// - Limits: Numeric matrices use a floating elimination path; symbolic matrices use exact expression elimination and may return unsimplified expressions.
///
/// ```mbt check
/// test "rref reports pivot columns" {
///   let m = @symmatrices.matrix([
///     [@symcore.int(1), @symcore.int(2)],
///     [@symcore.int(2), @symcore.int(4)],
///   ])
///   let (_, pivots) = m.rref()
///   debug_inspect(pivots, content="[0]")
/// }
/// ```
pub fn Matrix::rref(self : Matrix) -> (Matrix, Array[Int]) {
  let numeric_prec = expr_numeric_precision(self.data)
  if matrix_has_floating_leaf(self.data) &&
    matrix_all_numeric(self.data, numeric_prec) {
    let data = clone_expr_rows(self.data).map(row => {
      row.map(cell => @symcore.evalf(cell, prec=numeric_prec))
    })
    let pivots : Array[Int] = []
    let mut row = 0
    let mut col = 0
    while row < self.rows && col < self.cols {
      let mut pivot_row = row
      let mut pivot_measure = expr_numeric_abs(data[row][col], numeric_prec)
      for candidate in (row + 1)..<self.rows {
        match
          (expr_numeric_abs(data[candidate][col], numeric_prec), pivot_measure) {
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
/// Compute the rank of a matrix.
///
/// - Does: Counts pivot columns in the reduced row echelon form.
/// - Input: Any dense `Matrix`.
/// - Returns: An `Int` rank.
/// - Limits: Uses `rref()` internally, so symbolic expressions follow the same pivot heuristics as that front door.
pub fn Matrix::rank(self : Matrix) -> Int {
  self.rref().1.length()
}

///|
/// Compute an echelon form of a matrix.
///
/// - Does: Performs elimination without normalizing pivots to one.
/// - Input: Any dense `Matrix`.
/// - Returns: A dense `Matrix` in echelon form.
/// - Limits: This front door does not report pivot columns; use `echelon_form_with_pivots` when callers need them.
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
/// Compute the determinant of a square matrix.
///
/// - Does: Uses exact rational, numeric, or symbolic elimination to compute the determinant.
/// - Input: A square dense `Matrix`.
/// - Returns: One symbolic `Expr`.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` for non-square inputs. Symbolic paths may keep expressions unevaluated instead of fully simplifying them.
///
/// ```mbt check
/// test "det computes the determinant of a dense matrix" {
///   let m = @symmatrices.matrix([
///     [@symcore.int(1), @symcore.int(2)],
///     [@symcore.int(3), @symcore.int(4)],
///   ])
///   inspect(@symprint.pretty_string(m.det()), content="-2")
/// }
/// ```
pub fn Matrix::det(self : Matrix) -> Expr raise MatrixError {
  if !self.is_square() {
    raise NonSquareMatrixError("determinant requires a square matrix")
  }
  if self.rows == 0 {
    return @symcore.int(1)
  }
  match matrix_exact_rational_data(self.data) {
    Some(data) => return exact_expr_from_rational(exact_rational_det(data))
    None => ()
  }
  let numeric_prec = expr_numeric_precision(self.data)
  if matrix_has_floating_leaf(self.data) &&
    matrix_all_numeric(self.data, numeric_prec) {
    let data = clone_expr_rows(self.evalf(prec=numeric_prec).data)
    let mut sign = @symcore.int(1)
    let mut col = 0
    while col < self.rows {
      let mut pivot_row = col
      let mut pivot_measure = expr_numeric_abs(data[col][col], numeric_prec)
      for candidate in (col + 1)..<self.rows {
        match
          (expr_numeric_abs(data[candidate][col], numeric_prec), pivot_measure) {
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
        return @symcore.int(0)
      }
      if pivot_row != col {
        swap_dense_rows(data, pivot_row, col)
        sign = expr_numeric_mul(sign, expr_neg(@symcore.int(1)), numeric_prec)
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
  let mut sign = @symcore.int(1)
  let mut prev = @symcore.int(1)
  for k in 0..<(self.rows - 1) {
    let mut pivot_row = k
    while pivot_row < self.rows && expr_is_zero(data[pivot_row][k]) {
      pivot_row += 1
    }
    if pivot_row == self.rows {
      return @symcore.int(0)
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
/// Build the minor submatrix for one position.
///
/// - Does: Deletes the requested row and column from the matrix.
/// - Input: A `Matrix`, a row index, and a column index.
/// - Returns: A smaller dense `Matrix`.
/// - Limits: Raises `MatrixError::IndexError` when either index is out of range.
pub fn Matrix::minor_submatrix(
  self : Matrix,
  row : Int,
  col : Int,
) -> Matrix raise MatrixError {
  self.row_del(row).col_del(col)
}

///|
/// Compute one matrix minor.
///
/// - Does: Takes the determinant of the submatrix formed by removing one row and one column.
/// - Input: A `Matrix`, a row index, and a column index.
/// - Returns: One symbolic `Expr`.
/// - Limits: Propagates index and determinant errors from `minor_submatrix()` and `det()`.
pub fn Matrix::minor(
  self : Matrix,
  row : Int,
  col : Int,
) -> Expr raise MatrixError {
  self.minor_submatrix(row, col).det()
}

///|
/// Compute one cofactor.
///
/// - Does: Multiplies the selected minor by the alternating sign `(-1)^(row + col)`.
/// - Input: A `Matrix`, a row index, and a column index.
/// - Returns: One symbolic `Expr`.
/// - Limits: Propagates index and determinant errors from `minor()`.
pub fn Matrix::cofactor(
  self : Matrix,
  row : Int,
  col : Int,
) -> Expr raise MatrixError {
  let sign = if (row + col) % 2 == 0 {
    @symcore.int(1)
  } else {
    expr_neg(@symcore.int(1))
  }
  expr_mul(sign, self.minor(row, col))
}

///|
/// Compute the cofactor matrix.
///
/// - Does: Replaces each entry with its cofactor.
/// - Input: A square dense `Matrix`.
/// - Returns: A dense `Matrix` of the same shape.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` when the matrix is not square.
pub fn Matrix::cofactor_matrix(self : Matrix) -> Matrix raise MatrixError {
  if !self.is_square() {
    raise NonSquareMatrixError("cofactor matrix requires a square matrix")
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
/// Compute the adjugate matrix.
///
/// - Does: Transposes the cofactor matrix.
/// - Input: A square dense `Matrix`.
/// - Returns: A dense `Matrix` of the same shape.
/// - Limits: Propagates the same square-matrix requirement as `cofactor_matrix()`.
pub fn Matrix::adjugate(self : Matrix) -> Matrix raise MatrixError {
  self.cofactor_matrix().transpose()
}

///|
/// Compute the inverse of a square matrix.
///
/// - Does: Chooses an exact or numeric elimination path and returns the matrix inverse.
/// - Input: A square dense `Matrix`.
/// - Returns: A dense `Matrix` whose product with the input is the identity when the input is invertible.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` for non-square inputs and `MatrixError::SingularMatrixError` for singular matrices.
///
/// ```mbt check
/// test "inv computes a dense matrix inverse" {
///   let m = @symmatrices.matrix([
///     [@symcore.int(1), @symcore.int(2)],
///     [@symcore.int(3), @symcore.int(4)],
///   ])
///   inspect(Show::to_string(m.inv()), content="Matrix([[-2, 1], [3/2, -1/2]])")
/// }
/// ```
pub fn Matrix::inv(self : Matrix) -> Matrix raise MatrixError {
  if !self.is_square() {
    raise NonSquareMatrixError("inverse requires a square matrix")
  }
  let n = self.rows
  if !matrix_has_floating_leaf(self.data) {
    match matrix_try_exact_inverse(self) {
      Some(inverse) => return inverse
      None => ()
    }
  }
  let numeric_prec = expr_numeric_precision(self.data)
  if matrix_has_floating_leaf(self.data) &&
    matrix_all_numeric(self.data, numeric_prec) {
    let left = clone_expr_rows(self.evalf(prec=numeric_prec).data)
    let right = clone_expr_rows(eye(n).evalf(prec=numeric_prec).data)
    for col in 0..<n {
      let mut pivot_row = col
      let mut pivot_measure = expr_numeric_abs(left[col][col], numeric_prec)
      for candidate in (col + 1)..<n {
        match
          (expr_numeric_abs(left[candidate][col], numeric_prec), pivot_measure) {
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
        raise SingularMatrixError("matrix is singular")
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
      raise SingularMatrixError("matrix is singular")
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
/// Solve a square linear system `A * X = rhs`.
///
/// - Does: Solves the system with an exact or LU-based path depending on the matrix data.
/// - Input: A square left-hand-side `Matrix` and a right-hand-side `Matrix` with the same row count.
/// - Returns: A dense `Matrix` solution with `self.cols` rows and `rhs.cols` columns.
/// - Limits: Raises `MatrixError::ShapeError` when the row counts do not match, `MatrixError::NonSquareMatrixError` when the left-hand side is not square, and `MatrixError::SingularMatrixError` for singular systems.
///
/// ```mbt check
/// test "solve returns the dense solution matrix" {
///   let lhs = @symmatrices.matrix([
///     [@symcore.int(2), @symcore.int(1)],
///     [@symcore.int(1), @symcore.int(3)],
///   ])
///   let rhs = @symmatrices.matrix([[@symcore.int(1)], [@symcore.int(2)]])
///   inspect(Show::to_string(lhs.solve(rhs)), content="Matrix([[1/5], [3/5]])")
/// }
/// ```
pub fn Matrix::solve(self : Matrix, rhs : Matrix) -> Matrix raise MatrixError {
  if self.rows != rhs.rows {
    raise ShapeError("solve expects rhs with the same number of rows")
  }
  if !self.is_square() {
    raise NonSquareMatrixError("solve requires a square lhs")
  }
  if !matrix_has_floating_leaf(self.data) && !matrix_has_floating_leaf(rhs.data) {
    match matrix_try_exact_solve(self, rhs) {
      Some(solution) => return solution
      None => ()
    }
  }
  let (l, u, swaps) = self.lu()
  let permuted_rhs = clone_expr_rows(rhs.data)
  for swap in swaps {
    swap_dense_rows(permuted_rhs, swap.0, swap.1)
  }
  let y = l.lower_triangular_solve({
    rows: rhs.rows,
    cols: rhs.cols,
    data: permuted_rhs,
  })
  u.upper_triangular_solve(y)
}

///|
pub fn Matrix::rref_rhs(
  self : Matrix,
  rhs : Matrix,
) -> (Matrix, Matrix) raise MatrixError {
  if self.rows != rhs.rows {
    raise ShapeError("rref_rhs expects rhs with the same number of rows")
  }
  let augmented = hstack([self, eye(self.rows), rhs])
  let (reduced0, _) = augmented.rref()
  let reduced = reduced0.applyfunc(expr_simplify)
  let left_cols : Array[Int] = []
  let right_cols : Array[Int] = []
  for j in 0..<self.cols {
    left_cols.push(j)
  }
  for j in (reduced.cols - rhs.cols)..<reduced.cols {
    right_cols.push(j)
  }
  (
    reduced.extract(Array::makei(self.rows, fn(i) { i }), left_cols),
    reduced.extract(Array::makei(self.rows, fn(i) { i }), right_cols),
  )
}

///|
/// Return a basis for the row space.
///
/// - Does: Extracts the nonzero rows of the reduced row echelon form.
/// - Input: Any dense `Matrix`.
/// - Returns: `Array[Array[Expr]]`, one basis vector per row.
/// - Limits: Basis vectors are returned in echelon order, not normalized to any additional canonical form.
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
/// Return a basis for the column space.
///
/// - Does: Selects the pivot columns from the original matrix.
/// - Input: Any dense `Matrix`.
/// - Returns: `Array[Array[Expr]]`, one basis vector per column.
/// - Limits: Uses pivot detection from `rref()`, so symbolic pivot choices follow the same heuristics.
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
/// Return a basis for the nullspace.
///
/// - Does: Solves the homogeneous system `self * x = 0` from the reduced row echelon form.
/// - Input: Any dense `Matrix`.
/// - Returns: `Array[Array[Expr]]`, one basis vector per free variable.
/// - Limits: Returns an empty array when the nullspace is trivial.
pub fn Matrix::nullspace(self : Matrix) -> Array[Array[Expr]] {
  let (rref, pivots) = self.rref()
  let pivot_set : Map[Int, Bool] = Map([])
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
    let vec = Array::make(self.cols, @symcore.int(0))
    vec[free_col] = @symcore.int(1)
    for i in 0..<pivots.length() {
      let pivot_col = pivots[i]
      vec[pivot_col] = expr_neg(rref.data[i][free_col])
    }
    basis.push(vec)
  }
  basis
}

///|
/// Compute an LU decomposition with recorded row swaps.
///
/// - Does: Factors the matrix into `L`, `U`, and the sequence of row swaps applied during elimination.
/// - Input: A square dense `Matrix`.
/// - Returns: `(L, U, swaps)` where `L` has unit diagonal and `swaps` records permutation steps.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` for non-square inputs. Zero pivots are skipped rather than forcing a full pivoting strategy.
pub fn Matrix::lu(
  self : Matrix,
) -> (Matrix, Matrix, Array[(Int, Int)]) raise MatrixError {
  if !self.is_square() {
    raise NonSquareMatrixError("LU decomposition requires a square matrix")
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
/// Solve a lower-triangular linear system.
///
/// - Does: Performs forward substitution on `self * X = rhs`.
/// - Input: A square lower-triangular left-hand-side `Matrix` and a right-hand-side `Matrix` with the same row count.
/// - Returns: A dense `Matrix` solution.
/// - Limits: Raises `MatrixError::ShapeError` when the left-hand side is not square or the row counts do not match. Callers must ensure the diagonal is invertible.
pub fn Matrix::lower_triangular_solve(
  self : Matrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if !self.is_square() || self.rows != rhs.rows {
    raise ShapeError(
      "lower_triangular_solve expects a square lhs and matching rhs rows",
    )
  }
  let numeric_prec = {
    let lhs_prec = expr_numeric_precision(self.data)
    let rhs_prec = expr_numeric_precision(rhs.data)
    if lhs_prec > rhs_prec {
      lhs_prec
    } else {
      rhs_prec
    }
  }
  let numeric_mode = (
      matrix_has_floating_leaf(self.data) || matrix_has_floating_leaf(rhs.data)
    ) &&
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
/// Solve an upper-triangular linear system.
///
/// - Does: Performs backward substitution on `self * X = rhs`.
/// - Input: A square upper-triangular left-hand-side `Matrix` and a right-hand-side `Matrix` with the same row count.
/// - Returns: A dense `Matrix` solution.
/// - Limits: Raises `MatrixError::ShapeError` when the left-hand side is not square or the row counts do not match. Callers must ensure the diagonal is invertible.
pub fn Matrix::upper_triangular_solve(
  self : Matrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if !self.is_square() || self.rows != rhs.rows {
    raise ShapeError(
      "upper_triangular_solve expects a square lhs and matching rhs rows",
    )
  }
  let numeric_prec = {
    let lhs_prec = expr_numeric_precision(self.data)
    let rhs_prec = expr_numeric_precision(rhs.data)
    if lhs_prec > rhs_prec {
      lhs_prec
    } else {
      rhs_prec
    }
  }
  let numeric_mode = (
      matrix_has_floating_leaf(self.data) || matrix_has_floating_leaf(rhs.data)
    ) &&
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
/// Compute a Cholesky factorization.
///
/// - Does: Returns a lower-triangular matrix `L` such that `L * L.T` matches the input on supported inputs.
/// - Input: A square dense `Matrix`.
/// - Returns: A lower-triangular dense `Matrix`.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` for non-square inputs. This front door does not prove positive definiteness before taking square roots.
pub fn Matrix::cholesky(self : Matrix) -> Matrix raise MatrixError {
  if !self.is_square() {
    raise NonSquareMatrixError(
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
/// Compute an LDL decomposition.
///
/// - Does: Returns matrices `L` and `D` such that `self = L * D * L.T` on supported inputs.
/// - Input: A square dense `Matrix`.
/// - Returns: `(L, D)` where `L` has unit diagonal and `D` is diagonal.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` for non-square inputs. This front door does not validate definiteness or symmetry up front.
pub fn Matrix::ldl(self : Matrix) -> (Matrix, Matrix) raise MatrixError {
  if !self.is_square() {
    raise NonSquareMatrixError("LDL decomposition requires a square matrix")
  }
  let n = self.rows
  let l0 = zeros(n, cols=Some(n))
  let d0 = zeros(n, cols=Some(n))
  let l = clone_expr_rows(l0.data)
  let d = clone_expr_rows(d0.data)
  for i in 0..<n {
    l[i][i] = @symcore.int(1)
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
/// Compute a QR decomposition.
///
/// - Does: Runs a Gram-Schmidt style factorization and returns `Q` and `R`.
/// - Input: Any dense `Matrix`.
/// - Returns: `(Q, R)` with `Q` shaped like the input columns and `R` upper triangular.
/// - Limits: Zero columns can leave unevaluated square roots or divisions in symbolic mode; empty matrices return zero-shaped factors.
pub fn Matrix::qr(self : Matrix) -> (Matrix, Matrix) raise MatrixError {
  if self.rows == 0 || self.cols == 0 {
    return (
      zeros(self.rows, cols=Some(self.cols)),
      zeros(self.cols, cols=Some(self.cols)),
    )
  }
  let q = clone_expr_rows(self.data)
  let r = Array::makei(self.cols, fn(_) {
    Array::make(self.cols, @symcore.int(0))
  })
  let ranked : Array[Int] = []
  for j in 0..<self.cols {
    for i in 0..<j {
      let mut dot_ii = @symcore.int(0)
      let mut dot_ij = @symcore.int(0)
      for k in 0..<self.rows {
        dot_ii = expr_add(dot_ii, expr_mul(q[k][i], q[k][i]))
        dot_ij = expr_add(dot_ij, expr_mul(q[k][i], q[k][j]))
      }
      dot_ii = @symsimplify.simplify(dot_ii)
      if expr_is_zero(dot_ii) {
        continue
      }
      let rij = @symsimplify.simplify(expr_div(dot_ij, dot_ii))
      r[i][j] = rij
      for k in 0..<self.rows {
        q[k][j] = @symsimplify.simplify(
          expr_sub(q[k][j], expr_mul(q[k][i], rij)),
        )
      }
    }
    let mut zero_col = true
    for k in 0..<self.rows {
      q[k][j] = @symsimplify.simplify(q[k][j])
      if !expr_is_zero(q[k][j]) {
        zero_col = false
      }
    }
    if !zero_col {
      ranked.push(j)
      r[j][j] = @symcore.int(1)
    }
  }
  let qrows : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in ranked {
      row.push(q[i][j])
    }
    qrows.push(row)
  }
  let rrows : Array[Array[Expr]] = []
  for i in ranked {
    let row : Array[Expr] = []
    for j in 0..<self.cols {
      row.push(r[i][j])
    }
    rrows.push(row)
  }
  for i in 0..<ranked.length() {
    let mut norm_sq = @symcore.int(0)
    for k in 0..<self.rows {
      norm_sq = expr_add(norm_sq, expr_mul(qrows[k][i], qrows[k][i]))
    }
    let norm = @symsimplify.simplify(@symcore.function("sqrt", [norm_sq]))
    for k in 0..<self.rows {
      qrows[k][i] = @symsimplify.simplify(expr_div(qrows[k][i], norm))
    }
    for j in 0..<self.cols {
      rrows[i][j] = @symsimplify.simplify(expr_mul(rrows[i][j], norm))
    }
  }
  (
    { rows: self.rows, cols: ranked.length(), data: qrows },
    { rows: ranked.length(), cols: self.cols, data: rrows },
  )
}
