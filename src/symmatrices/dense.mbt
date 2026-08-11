///|
/// Dense symbolic matrix values and structural operations.
///
/// Current Limits:
/// - This file covers dense construction and reshaping front doors only.
/// - Decompositions and exact linear algebra live in other `symmatrices` files.
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
/// Return a mutable-style copy of a dense matrix.
///
/// - Does: Clones the matrix so callers can keep editing the returned value.
/// - Input: A dense `Matrix`.
/// - Returns: Another `Matrix` with the same shape and entries.
/// - Limits: This package uses value semantics, so the original matrix is never mutated in place.
pub fn Matrix::as_mutable(self : Matrix) -> MutableDenseMatrix {
  self.copy()
}

///|
/// Return an immutable-style copy of a dense matrix.
///
/// - Does: Clones the matrix while preserving its current entries.
/// - Input: A dense `Matrix`.
/// - Returns: Another `Matrix` with the same shape and entries.
/// - Limits: This is a compatibility front door; it does not freeze or alias the original value.
pub fn Matrix::as_immutable(self : Matrix) -> ImmutableDenseMatrix {
  self.copy()
}

///|
/// Build a dense matrix from nested rows.
///
/// - Does: Validates row widths and stores a cloned rectangular grid of expressions.
/// - Input: An array of rows where each row is an `Array[Expr]`.
/// - Returns: A `Matrix` whose shape matches the input grid, or an empty `0 x 0` matrix for `[]`.
/// - Limits: Raises `MatrixError::ShapeError` when rows have inconsistent lengths.
///
/// ```mbt check
/// test "matrix builds a rectangular dense value" {
///   let m = @symmatrices.matrix([
///     [@symcore.int(1), @symcore.int(2)],
///     [@symcore.int(3), @symcore.int(4)],
///   ])
///   guard m.shape() == (2, 2) else { fail("unexpected dense matrix shape") }
///   inspect(m.to_string(), content="Matrix([[1, 2], [3, 4]])")
/// }
/// ```
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
/// Build a dense matrix from a flat row-major array.
///
/// - Does: Splits a flat value buffer into `rows * cols` entries and delegates to `matrix`.
/// - Input: Non-negative `rows`, non-negative `cols`, and a flat `Array[Expr]`.
/// - Returns: A `Matrix` with the requested shape.
/// - Limits: Raises `MatrixError::ShapeError` when dimensions are negative or the flat buffer length does not match `rows * cols`.
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
/// Build a zero-filled dense matrix.
///
/// - Does: Creates a dense matrix whose entries are all exact symbolic zero.
/// - Input: A required row count and an optional column count. When `cols` is omitted, it builds a square matrix.
/// - Returns: A `Matrix` of shape `(rows, cols)` or `(rows, rows)`.
/// - Limits: Raises `MatrixError::ShapeError` when either dimension is negative.
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
    out.push(Array::make(cols, @symcore.int(0)))
  }
  { rows, cols, data: out }
}

///|
/// Build a one-filled dense matrix.
///
/// - Does: Creates a dense matrix whose entries are all exact symbolic one.
/// - Input: A required row count and an optional column count. When `cols` is omitted, it builds a square matrix.
/// - Returns: A `Matrix` of shape `(rows, cols)` or `(rows, rows)`.
/// - Limits: Raises `MatrixError::ShapeError` when either dimension is negative.
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
    out.push(Array::make(cols, @symcore.int(1)))
  }
  { rows, cols, data: out }
}

///|
/// Build an identity matrix.
///
/// - Does: Creates a square matrix with ones on the diagonal and zeros elsewhere.
/// - Input: A non-negative matrix size `n`.
/// - Returns: An `n x n` dense `Matrix`.
/// - Limits: Raises `MatrixError::ShapeError` when `n` is negative.
///
/// ```mbt check
/// test "eye builds an identity matrix" {
///   let ident = @symmatrices.eye(3)
///   inspect(
///     ident.to_string(),
///     content="Matrix([[1, 0, 0], [0, 1, 0], [0, 0, 1]])",
///   )
/// }
/// ```
pub fn eye(n : Int) -> Matrix raise MatrixError {
  let out = zeros(n, cols=Some(n))
  let data = clone_expr_rows(out.data)
  for i in 0..<n {
    data[i][i] = @symcore.int(1)
  }
  { rows: n, cols: n, data }
}

///|
/// Build a diagonal matrix from a list of entries.
///
/// - Does: Places the given values on the main diagonal and fills all other entries with zero.
/// - Input: A diagonal value array plus optional row and column counts.
/// - Returns: A dense `Matrix` whose diagonal is populated up to the shortest of `values.length()`, `rows`, and `cols`.
/// - Limits: Raises `MatrixError::ShapeError` when the delegated zero matrix construction rejects the requested dimensions.
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
/// Return the matrix shape.
///
/// - Does: Reports the number of rows and columns stored in the dense matrix.
/// - Input: A `Matrix`.
/// - Returns: A pair `(rows, cols)`.
/// - Limits: This is metadata only; it never validates contents.
pub fn Matrix::shape(self : Matrix) -> (Int, Int) {
  (self.rows, self.cols)
}

///|
/// Convert a dense matrix into nested row arrays.
///
/// - Does: Clones the internal grid so callers can inspect or reuse row-major data safely.
/// - Input: A `Matrix`.
/// - Returns: `Array[Array[Expr]]` in row-major order.
/// - Limits: The returned arrays are copies, so later edits do not mutate the original matrix.
pub fn Matrix::to_list(self : Matrix) -> Array[Array[Expr]] {
  clone_expr_rows(self.data)
}

///|
pub fn Matrix::tolist(self : Matrix) -> Array[Array[Expr]] {
  self.to_list()
}

///|
pub impl Show for Matrix with fn to_string(self) {
  matrix_string(self.data)
}

///|
pub impl Show for Matrix with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
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
/// Read a single matrix entry.
///
/// - Does: Returns the expression stored at `(row, col)`.
/// - Input: A `Matrix` plus row and column indices. Negative indices count from the end.
/// - Returns: The selected `Expr`.
/// - Limits: Raises `MatrixError::IndexError` when either index falls outside the matrix bounds.
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
/// Return a copy of the matrix with one entry replaced.
///
/// - Does: Clones the matrix, writes `value` into `(row, col)`, and returns the new matrix.
/// - Input: A `Matrix`, row index, column index, and replacement `Expr`. Negative indices count from the end.
/// - Returns: A new `Matrix` with the same shape.
/// - Limits: Raises `MatrixError::IndexError` when either index falls outside the matrix bounds.
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
/// Extract a full row as expressions.
///
/// - Does: Clones one row from the dense matrix.
/// - Input: A `Matrix` and a row index. Negative indices count from the end.
/// - Returns: `Array[Expr]` for that row.
/// - Limits: Raises `MatrixError::IndexError` when the row index is out of range.
pub fn Matrix::row(self : Matrix, row : Int) -> Array[Expr] raise MatrixError {
  let r = normalize_index(row, self.rows)
  let out : Array[Expr] = []
  for value in self.data[r] {
    out.push(value)
  }
  out
}

///|
/// Extract a full column as expressions.
///
/// - Does: Clones one column from the dense matrix.
/// - Input: A `Matrix` and a column index. Negative indices count from the end.
/// - Returns: `Array[Expr]` for that column.
/// - Limits: Raises `MatrixError::IndexError` when the column index is out of range.
pub fn Matrix::col(self : Matrix, col : Int) -> Array[Expr] raise MatrixError {
  let c = normalize_index(col, self.cols)
  let out : Array[Expr] = []
  for r in 0..<self.rows {
    out.push(self.data[r][c])
  }
  out
}

///|
/// Transpose a dense matrix.
///
/// - Does: Swaps rows and columns and returns the transposed matrix.
/// - Input: A `Matrix`.
/// - Returns: A new `Matrix` of shape `(cols, rows)`.
/// - Limits: Raises `MatrixError` only if zero-matrix allocation for the output shape fails.
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
/// Reshape a dense matrix without changing entry order.
///
/// - Does: Reinterprets the current row-major entry sequence with a new shape.
/// - Input: A `Matrix` and target `rows` and `cols`.
/// - Returns: A new `Matrix` with the requested shape.
/// - Limits: Raises `MatrixError::ShapeError` when the new shape is negative or changes the total number of entries.
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
/// Select a submatrix by row and column index lists.
///
/// - Does: Builds a new matrix from the requested row and column positions, preserving order and duplicates.
/// - Input: A `Matrix`, `row_indices`, and `col_indices`. Indices may be negative.
/// - Returns: A new dense `Matrix`.
/// - Limits: Raises `MatrixError::IndexError` when any requested index is out of range.
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
/// Concatenate dense matrices horizontally.
///
/// - Does: Joins matrices side-by-side in their existing row order.
/// - Input: A non-empty `Array[Matrix]` whose members all have the same row count.
/// - Returns: A new dense `Matrix` with summed column count.
/// - Limits: Raises `MatrixError::ShapeError` when row counts differ. Returns `0 x 0` for an empty input list.
///
/// ```mbt check
/// test "hstack joins matrices side by side" {
///   let left = @symmatrices.eye(2)
///   let right = @symmatrices.ones(2, cols=Some(1))
///   inspect(
///     @symmatrices.hstack([left, right]).to_string(),
///     content="Matrix([[1, 0, 1], [0, 1, 1]])",
///   )
/// }
/// ```
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
/// Concatenate dense matrices vertically.
///
/// - Does: Stacks matrices top-to-bottom in their existing row order.
/// - Input: A non-empty `Array[Matrix]` whose members all have the same column count.
/// - Returns: A new dense `Matrix` with summed row count.
/// - Limits: Raises `MatrixError::ShapeError` when column counts differ. Returns `0 x 0` for an empty input list.
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
pub impl Add for Matrix with fn add(self, other) {
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
pub impl Sub for Matrix with fn sub(self, other) {
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
pub impl Mul for Matrix with fn mul(self, other) {
  let out : Array[Array[Expr]] = []
  for i in 0..<self.rows {
    let row : Array[Expr] = []
    for j in 0..<other.cols {
      let mut acc = @symcore.int(0)
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
/// Compute the trace of a dense matrix.
///
/// - Does: Adds the main-diagonal entries.
/// - Input: A square `Matrix`.
/// - Returns: One symbolic `Expr`.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` when the matrix is not square.
pub fn Matrix::trace(self : Matrix) -> Expr raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError("trace requires a square matrix")
  }
  let mut acc = @symcore.int(0)
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
  let out : Map[(Int, Int), Expr] = Map([])
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
  let out : Map[Int, Map[Int, Expr]] = Map([])
  for i in 0..<self.rows {
    let row : Map[Int, Expr] = Map([])
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
