///|
/// Dense symbolic matrix aligned with the high-value surface of
/// `sympy.matrices.dense` and `matrixbase`.
pub struct Matrix {
  rows : Int
  cols : Int
  data : Array[Array[Expr]]
}

///|
pub type MutableDenseMatrix = Matrix

///|
pub type ImmutableDenseMatrix = Matrix

///|
pub type MutableMatrix = Matrix

///|
pub type ImmutableMatrix = Matrix

///|
pub fn Matrix::as_mutable(self : Matrix) -> MutableDenseMatrix {
  self.copy()
}

///|
pub fn Matrix::as_immutable(self : Matrix) -> ImmutableDenseMatrix {
  self.copy()
}

///|
pub fn matrix(rows : Array[Array[Expr]]) -> Matrix raise MatrixError {
  if rows.is_empty() {
    return { rows: 0, cols: 0, data: [] }
  }
  let cols = rows[0].length()
  for row in rows {
    if row.length() != cols {
      raise MatrixError::ShapeError("matrix rows must all have the same length")
    }
  }
  { rows: rows.length(), cols, data: clone_expr_rows(rows) }
}

///|
pub fn matrix_from_flat(
  rows : Int,
  cols : Int,
  values : Array[Expr],
) -> Matrix raise MatrixError {
  if rows < 0 || cols < 0 || values.length() != rows * cols {
    raise MatrixError::ShapeError(
      "flat data length does not match matrix shape",
    )
  }
  let out : Array[Array[Expr]] = []
  for i in 0..<rows {
    let row : Array[Expr] = []
    for j in 0..<cols {
      row.push(values[i * cols + j])
    }
    out.push(row)
  }
  matrix(out)
}

///|
pub fn zeros(rows : Int, cols? : Int? = None) -> Matrix raise MatrixError {
  let cols = match cols {
    Some(value) => value
    None => rows
  }
  if rows < 0 || cols < 0 {
    raise MatrixError::ShapeError("matrix dimensions must be non-negative")
  }
  let out : Array[Array[Expr]] = []
  for _ in 0..<rows {
    out.push(Array::make(cols, expr_zero()))
  }
  { rows, cols, data: out }
}

///|
pub fn ones(rows : Int, cols? : Int? = None) -> Matrix raise MatrixError {
  let cols = match cols {
    Some(value) => value
    None => rows
  }
  if rows < 0 || cols < 0 {
    raise MatrixError::ShapeError("matrix dimensions must be non-negative")
  }
  let out : Array[Array[Expr]] = []
  for _ in 0..<rows {
    out.push(Array::make(cols, expr_one()))
  }
  { rows, cols, data: out }
}

///|
pub fn eye(n : Int) -> Matrix raise MatrixError {
  let out = zeros(n, cols=Some(n))
  let data = clone_expr_rows(out.data)
  for i in 0..<n {
    data[i][i] = expr_one()
  }
  { rows: n, cols: n, data }
}

///|
pub fn diag(
  values : Array[Expr],
  rows? : Int? = None,
  cols? : Int? = None,
) -> Matrix raise MatrixError {
  let nrows = match rows {
    Some(v) => v
    None => values.length()
  }
  let ncols = match cols {
    Some(v) => v
    None => values.length()
  }
  let out = zeros(nrows, cols=Some(ncols))
  let data = clone_expr_rows(out.data)
  let mut limit = if nrows < ncols { nrows } else { ncols }
  if values.length() < limit {
    limit = values.length()
  }
  for i in 0..<limit {
    data[i][i] = values[i]
  }
  { rows: nrows, cols: ncols, data }
}

///|
fn normalize_index(index : Int, size : Int) -> Int raise MatrixError {
  let normalized = if index < 0 { size + index } else { index }
  if normalized < 0 || normalized >= size {
    raise MatrixError::IndexError("matrix index out of range")
  }
  normalized
}

///|
fn normalize_insert_pos(index : Int, size : Int) -> Int raise MatrixError {
  let normalized = if index < 0 { size + index } else { index }
  if normalized < 0 || normalized > size {
    raise MatrixError::IndexError("matrix insertion index out of range")
  }
  normalized
}

///|
pub fn Matrix::shape(self : Matrix) -> (Int, Int) {
  (self.rows, self.cols)
}

///|
pub fn Matrix::to_list(self : Matrix) -> Array[Array[Expr]] {
  clone_expr_rows(self.data)
}

///|
pub fn Matrix::tolist(self : Matrix) -> Array[Array[Expr]] {
  self.to_list()
}

///|
pub fn Matrix::to_string(self : Matrix) -> String {
  matrix_string(self.data)
}

///|
pub fn Matrix::copy(self : Matrix) -> Matrix {
  { rows: self.rows, cols: self.cols, data: clone_expr_rows(self.data) }
}

///|
pub fn Matrix::equals(self : Matrix, other : Matrix) -> Bool {
  if self.shape() != other.shape() {
    return false
  }
  for i in 0..<self.rows {
    for j in 0..<self.cols {
      if !expr_eq(self.data[i][j], other.data[i][j]) {
        return false
      }
    }
  }
  true
}

///|
pub fn Matrix::getitem(
  self : Matrix,
  row : Int,
  col : Int,
) -> Expr raise MatrixError {
  let r = normalize_index(row, self.rows)
  let c = normalize_index(col, self.cols)
  self.data[r][c]
}

///|
pub fn Matrix::setitem(
  self : Matrix,
  row : Int,
  col : Int,
  value : Expr,
) -> Matrix raise MatrixError {
  let r = normalize_index(row, self.rows)
  let c = normalize_index(col, self.cols)
  let data = clone_expr_rows(self.data)
  data[r][c] = value
  { rows: self.rows, cols: self.cols, data }
}

///|
pub fn Matrix::row(self : Matrix, row : Int) -> Array[Expr] raise MatrixError {
  let r = normalize_index(row, self.rows)
  let out : Array[Expr] = []
  for value in self.data[r] {
    out.push(value)
  }
  out
}

///|
pub fn Matrix::col(self : Matrix, col : Int) -> Array[Expr] raise MatrixError {
  let c = normalize_index(col, self.cols)
  let out : Array[Expr] = []
  for r in 0..<self.rows {
    out.push(self.data[r][c])
  }
  out
}

///|
pub fn Matrix::transpose(self : Matrix) -> Matrix raise MatrixError {
  let out = zeros(self.cols, cols=Some(self.rows))
  let data = clone_expr_rows(out.data)
  for i in 0..<self.rows {
    for j in 0..<self.cols {
      data[j][i] = self.data[i][j]
    }
  }
  { rows: self.cols, cols: self.rows, data }
}

///|
pub fn Matrix::reshape(
  self : Matrix,
  rows : Int,
  cols : Int,
) -> Matrix raise MatrixError {
  if rows < 0 || cols < 0 || rows * cols != self.rows * self.cols {
    raise MatrixError::ShapeError(
      "cannot reshape matrix to incompatible dimensions",
    )
  }
  let flat : Array[Expr] = []
  for row in self.data {
    for value in row {
      flat.push(value)
    }
  }
  matrix_from_flat(rows, cols, flat)
}

///|
pub fn Matrix::extract(
  self : Matrix,
  row_indices : Array[Int],
  col_indices : Array[Int],
) -> Matrix raise MatrixError {
  let out : Array[Array[Expr]] = []
  for row in row_indices {
    let rendered : Array[Expr] = []
    for col in col_indices {
      rendered.push(self.getitem(row, col))
    }
    out.push(rendered)
  }
  matrix(out)
}

///|
pub fn Matrix::row_join(
  self : Matrix,
  other : Matrix,
) -> Matrix raise MatrixError {
  hstack([self, other])
}

///|
pub fn Matrix::col_join(
  self : Matrix,
  other : Matrix,
) -> Matrix raise MatrixError {
  vstack([self, other])
}

///|
pub fn Matrix::row_insert(
  self : Matrix,
  pos : Int,
  other : Matrix,
) -> Matrix raise MatrixError {
  if other.cols != self.cols {
    raise MatrixError::ShapeError("row_insert expects matching column counts")
  }
  let insert_at = normalize_insert_pos(pos, self.rows)
  let out : Array[Array[Expr]] = []
  for i in 0..<insert_at {
    out.push(self.row(i))
  }
  for row in other.data {
    let copied : Array[Expr] = []
    for value in row {
      copied.push(value)
    }
    out.push(copied)
  }
  for i in insert_at..<self.rows {
    out.push(self.row(i))
  }
  matrix(out)
}

///|
pub fn Matrix::col_insert(
  self : Matrix,
  pos : Int,
  other : Matrix,
) -> Matrix raise MatrixError {
  if other.rows != self.rows {
    raise MatrixError::ShapeError("col_insert expects matching row counts")
  }
  let insert_at = normalize_insert_pos(pos, self.cols)
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<insert_at {
      row.push(self.data[i][j])
    }
    for value in other.data[i] {
      row.push(value)
    }
    for j in insert_at..<self.cols {
      row.push(self.data[i][j])
    }
    out.push(row)
  }
  matrix(out)
}

///|
pub fn Matrix::row_del(self : Matrix, row : Int) -> Matrix raise MatrixError {
  let delete_at = normalize_index(row, self.rows)
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    if i == delete_at {
      continue
    }
    out.push(self.row(i))
  }
  matrix(out)
}

///|
pub fn Matrix::col_del(self : Matrix, col : Int) -> Matrix raise MatrixError {
  let delete_at = normalize_index(col, self.cols)
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<self.cols {
      if j == delete_at {
        continue
      }
      row.push(self.data[i][j])
    }
    out.push(row)
  }
  matrix(out)
}

///|
pub fn Matrix::applyfunc(
  self : Matrix,
  f : (Expr) -> Expr,
) -> Matrix raise MatrixError {
  let out : Array[Array[Expr]] = []
  for row in self.data {
    out.push(row.map(f))
  }
  matrix(out)
}

///|
pub fn hstack(parts : Array[Matrix]) -> Matrix raise MatrixError {
  if parts.is_empty() {
    return zeros(0, cols=Some(0))
  }
  let rows = parts[0].rows
  for part in parts {
    if part.rows != rows {
      raise MatrixError::ShapeError(
        "hstack expects all matrices to have the same number of rows",
      )
    }
  }
  let out : Array[Array[Expr]] = []
  for i in 0..<rows {
    let row : Array[Expr] = []
    for part in parts {
      for value in part.data[i] {
        row.push(value)
      }
    }
    out.push(row)
  }
  matrix(out)
}

///|
pub fn vstack(parts : Array[Matrix]) -> Matrix raise MatrixError {
  if parts.is_empty() {
    return zeros(0, cols=Some(0))
  }
  let cols = parts[0].cols
  let out : Array[Array[Expr]] = []
  for part in parts {
    if part.cols != cols {
      raise MatrixError::ShapeError(
        "vstack expects all matrices to have the same number of columns",
      )
    }
    for row in part.data {
      let copied : Array[Expr] = []
      for value in row {
        copied.push(value)
      }
      out.push(copied)
    }
  }
  matrix(out)
}

///|
pub fn matrix_multiply_elementwise(
  lhs : Matrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if lhs.shape() != rhs.shape() {
    raise MatrixError::ShapeError(
      "elementwise multiplication expects equal shapes",
    )
  }
  let out : Array[Array[Expr]] = []
  for i in 0..<lhs.rows {
    let row : Array[Expr] = []
    for j in 0..<lhs.cols {
      row.push(expr_mul(lhs.data[i][j], rhs.data[i][j]))
    }
    out.push(row)
  }
  matrix(out)
}

///|
pub impl Add for Matrix with add(self, other) {
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<self.cols {
      row.push(expr_add(self.data[i][j], other.data[i][j]))
    }
    out.push(row)
  }
  { rows: self.rows, cols: self.cols, data: out }
}

///|
pub impl Sub for Matrix with sub(self, other) {
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<self.cols {
      row.push(expr_sub(self.data[i][j], other.data[i][j]))
    }
    out.push(row)
  }
  { rows: self.rows, cols: self.cols, data: out }
}

///|
pub impl Mul for Matrix with mul(self, other) {
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<other.cols {
      let mut acc = expr_zero()
      for k in 0..<self.cols {
        acc = expr_add(acc, expr_mul(self.data[i][k], other.data[k][j]))
      }
      row.push(acc)
    }
    out.push(row)
  }
  { rows: self.rows, cols: other.cols, data: out }
}

///|
pub fn Matrix::scalar_mul(
  self : Matrix,
  scalar : Expr,
) -> Matrix raise MatrixError {
  self.applyfunc(value => expr_mul(value, scalar))
}

///|
pub fn Matrix::trace(self : Matrix) -> Expr raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError("trace requires a square matrix")
  }
  let mut acc = expr_zero()
  for i in 0..<self.rows {
    acc = expr_add(acc, self.data[i][i])
  }
  acc
}

///|
pub fn Matrix::is_square(self : Matrix) -> Bool {
  self.rows == self.cols
}

///|
pub fn Matrix::nnz(self : Matrix) -> Int {
  let mut count = 0
  for row in self.data {
    for value in row {
      if !expr_is_zero(value) {
        count += 1
      }
    }
  }
  count
}

///|
pub fn Matrix::todok(self : Matrix) -> Map[(Int, Int), Expr] {
  let out : Map[(Int, Int), Expr] = {}
  for i in 0..<self.rows {
    for j in 0..<self.cols {
      let value = self.data[i][j]
      if !expr_is_zero(value) {
        out[(i, j)] = value
      }
    }
  }
  out
}

///|
pub fn Matrix::todod(self : Matrix) -> Map[Int, Map[Int, Expr]] {
  let out : Map[Int, Map[Int, Expr]] = {}
  for i in 0..<self.rows {
    let row : Map[Int, Expr] = {}
    for j in 0..<self.cols {
      let value = self.data[i][j]
      if !expr_is_zero(value) {
        row[j] = value
      }
    }
    if !row.is_empty() {
      out[i] = row
    }
  }
  out
}

///|
pub fn Matrix::diagonal(self : Matrix, k? : Int = 0) -> Array[Expr] {
  let out : Array[Expr] = []
  let mut row = if k >= 0 { 0 } else { -k }
  let mut col = if k >= 0 { k } else { 0 }
  while row < self.rows && col < self.cols {
    out.push(self.data[row][col])
    row += 1
    col += 1
  }
  out
}

///|
pub fn Matrix::vec(self : Matrix) -> Matrix raise MatrixError {
  let flat : Array[Expr] = []
  for j in 0..<self.cols {
    for i in 0..<self.rows {
      flat.push(self.data[i][j])
    }
  }
  matrix_from_flat(self.rows * self.cols, 1, flat)
}

///|
pub fn Matrix::simplify(self : Matrix) -> Matrix raise MatrixError {
  self.applyfunc(expr_simplify)
}

///|
pub fn Matrix::is_zero_matrix(self : Matrix) -> Bool {
  self.nnz() == 0
}

///|
pub fn Matrix::is_diagonal(self : Matrix) -> Bool {
  for i in 0..<self.rows {
    for j in 0..<self.cols {
      if i != j && !expr_is_zero(self.data[i][j]) {
        return false
      }
    }
  }
  true
}

///|
pub fn Matrix::is_symmetric(self : Matrix) -> Bool {
  if !self.is_square() {
    return false
  }
  for i in 0..<self.rows {
    for j in (i + 1)..<self.cols {
      if !expr_eq(self.data[i][j], self.data[j][i]) {
        return false
      }
    }
  }
  true
}

///|
pub fn Matrix::is_upper(self : Matrix) -> Bool {
  if !self.is_square() {
    return false
  }
  for i in 0..<self.rows {
    for j in 0..<i {
      if !expr_is_zero(self.data[i][j]) {
        return false
      }
    }
  }
  true
}

///|
pub fn Matrix::is_lower(self : Matrix) -> Bool {
  if !self.is_square() {
    return false
  }
  for i in 0..<self.rows {
    for j in (i + 1)..<self.cols {
      if !expr_is_zero(self.data[i][j]) {
        return false
      }
    }
  }
  true
}
