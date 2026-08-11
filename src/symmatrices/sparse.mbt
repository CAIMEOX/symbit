///|
/// Sparse symbolic matrices stored in dictionary-of-keys form.
///
/// Current Limits:
/// - Most structural front doors stay sparse, but several decomposition paths return dense matrices.
/// - This file focuses on DOK-style sparse values rather than a separate symbolic matrix-expression layer.
pub struct SparseMatrix {
  rows : Int
  cols : Int
  entries : Map[(Int, Int), Expr]
}

///|
pub type ImmutableSparseMatrix = SparseMatrix

///|
pub type MutableSparseMatrix = SparseMatrix

///|
fn clone_sparse_entries(
  entries : Map[(Int, Int), Expr],
) -> Map[(Int, Int), Expr] {
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in entries {
    out[key] = value
  }
  out
}

///|
fn sparse_accumulate(
  out : Map[(Int, Int), Expr],
  key : (Int, Int),
  value : Expr,
) -> Unit {
  if expr_is_zero(value) {
    return
  }
  match out.get(key) {
    Some(prev) => {
      let merged = expr_add(prev, value)
      if expr_is_zero(merged) {
        ignore(out.remove(key))
      } else {
        out[key] = merged
      }
    }
    None => out[key] = value
  }
}

///|
fn sparse_row_entries(matrix : SparseMatrix) -> Array[Array[(Int, Expr)]] {
  let rows = Array::makei(matrix.rows, fn(_) { [] })
  for key, value in matrix.entries {
    rows[key.0].push((key.1, value))
  }
  rows
}

///|
fn sparse_row_maps(matrix : SparseMatrix) -> Array[Map[Int, Expr]] {
  let rows = Array::makei(matrix.rows, fn(_) { Map([]) })
  for key, value in matrix.entries {
    rows[key.0][key.1] = value
  }
  rows
}

///|
fn clone_sparse_row_map(row : Map[Int, Expr]) -> Map[Int, Expr] {
  let out : Map[Int, Expr] = Map([])
  for key, value in row {
    out[key] = value
  }
  out
}

///|
fn clone_sparse_row_maps(rows : Array[Map[Int, Expr]]) -> Array[Map[Int, Expr]] {
  let out : Array[Map[Int, Expr]] = []
  for row in rows {
    out.push(clone_sparse_row_map(row))
  }
  out
}

///|
fn sparse_row_get(row : Map[Int, Expr], col : Int) -> Expr {
  match row.get(col) {
    Some(value) => value
    None => @symcore.int(0)
  }
}

///|
fn sparse_row_set(row : Map[Int, Expr], col : Int, value : Expr) -> Unit {
  if expr_is_zero(value) {
    ignore(row.remove(col))
  } else {
    row[col] = value
  }
}

///|
fn sparse_swap_row_maps(rows : Array[Map[Int, Expr]], i : Int, j : Int) -> Unit {
  let tmp = rows[i]
  rows[i] = rows[j]
  rows[j] = tmp
}

///|
fn sparse_row_active_cols(
  lhs : Map[Int, Expr],
  rhs : Map[Int, Expr],
  min_col : Int,
) -> Array[Int] {
  let seen : Map[Int, Bool] = Map([])
  for col, _ in lhs {
    if col >= min_col {
      seen[col] = true
    }
  }
  for col, _ in rhs {
    if col >= min_col {
      seen[col] = true
    }
  }
  let cols : Array[Int] = []
  for col, _ in seen {
    cols.push(col)
  }
  cols.sort()
  cols
}

///|
fn sparse_row_scale(row : Map[Int, Expr], scalar : Expr) -> Unit {
  let cols : Array[Int] = []
  for col, _ in row {
    cols.push(col)
  }
  for col in cols {
    sparse_row_set(row, col, expr_div(sparse_row_get(row, col), scalar))
  }
}

///|
fn sparse_row_to_dense(row : Map[Int, Expr], cols : Int) -> Array[Expr] {
  let out = Array::make(cols, @symcore.int(0))
  for col, value in row {
    out[col] = value
  }
  out
}

///|
fn sparse_row_maps_to_dense(
  rows : Array[Map[Int, Expr]],
  ncols : Int,
) -> Matrix {
  let data : Array[Array[Expr]] = []
  for row in rows {
    data.push(sparse_row_to_dense(row, ncols))
  }
  { rows: rows.length(), cols: ncols, data }
}

///|
fn sparse_apply_row_swaps_rhs(
  rhs : Matrix,
  swaps : Array[(Int, Int)],
) -> Matrix {
  let data = clone_expr_rows(rhs.data)
  for swap in swaps {
    let tmp = data[swap.0]
    data[swap.0] = data[swap.1]
    data[swap.1] = tmp
  }
  { rows: rhs.rows, cols: rhs.cols, data }
}

///|
fn sparse_rref_internal(
  matrix : SparseMatrix,
) -> (Array[Map[Int, Expr]], Array[Int]) {
  let rows = clone_sparse_row_maps(sparse_row_maps(matrix))
  let pivots : Array[Int] = []
  let mut row = 0
  let mut col = 0
  while row < matrix.rows && col < matrix.cols {
    let mut pivot_row = row
    while pivot_row < matrix.rows &&
          expr_is_zero(sparse_row_get(rows[pivot_row], col)) {
      pivot_row += 1
    }
    if pivot_row == matrix.rows {
      col += 1
      continue
    }
    if pivot_row != row {
      sparse_swap_row_maps(rows, pivot_row, row)
    }
    let pivot = sparse_row_get(rows[row], col)
    sparse_row_scale(rows[row], pivot)
    sparse_row_set(rows[row], col, @symcore.int(1))
    for i in 0..<matrix.rows {
      if i == row {
        continue
      }
      let factor = sparse_row_get(rows[i], col)
      if expr_is_zero(factor) {
        continue
      }
      let active_cols = sparse_row_active_cols(rows[i], rows[row], col)
      for active_col in active_cols {
        let updated = expr_sub(
          sparse_row_get(rows[i], active_col),
          expr_mul(factor, sparse_row_get(rows[row], active_col)),
        )
        sparse_row_set(rows[i], active_col, updated)
      }
      sparse_row_set(rows[i], col, @symcore.int(0))
    }
    pivots.push(col)
    row += 1
    col += 1
  }
  (rows, pivots)
}

///|
fn sparse_echelon_internal(
  matrix : SparseMatrix,
) -> (Array[Map[Int, Expr]], Array[Int]) {
  let rows = clone_sparse_row_maps(sparse_row_maps(matrix))
  let pivots : Array[Int] = []
  let mut row = 0
  let mut col = 0
  let mut prev = @symcore.int(1)
  while row < matrix.rows && col < matrix.cols {
    let mut pivot_row = row
    while pivot_row < matrix.rows &&
          expr_is_zero(sparse_row_get(rows[pivot_row], col)) {
      pivot_row += 1
    }
    if pivot_row == matrix.rows {
      col += 1
      continue
    }
    if pivot_row != row {
      sparse_swap_row_maps(rows, pivot_row, row)
    }
    let pivot = sparse_row_get(rows[row], col)
    for i in (row + 1)..<matrix.rows {
      let factor = sparse_row_get(rows[i], col)
      if expr_is_zero(factor) {
        continue
      }
      sparse_row_set(rows[i], col, @symcore.int(0))
      let active_cols = sparse_row_active_cols(rows[i], rows[row], col + 1)
      for active_col in active_cols {
        let numer = expr_sub(
          expr_mul(pivot, sparse_row_get(rows[i], active_col)),
          expr_mul(factor, sparse_row_get(rows[row], active_col)),
        )
        sparse_row_set(rows[i], active_col, expr_div(numer, prev))
      }
    }
    pivots.push(col)
    prev = pivot
    row += 1
    col += 1
  }
  (rows, pivots)
}

///|
/// Return a mutable-style copy of a sparse matrix.
///
/// - Does: Clones the sparse entry dictionary so callers can keep editing the returned value.
/// - Input: A `SparseMatrix`.
/// - Returns: Another `SparseMatrix` with the same shape and stored entries.
/// - Limits: This package uses value semantics, so the original sparse matrix is never mutated in place.
pub fn SparseMatrix::as_mutable(self : SparseMatrix) -> MutableSparseMatrix {
  SparseMatrix::{
    rows: self.rows,
    cols: self.cols,
    entries: clone_sparse_entries(self.entries),
  }
}

///|
/// Return an immutable-style copy of a sparse matrix.
///
/// - Does: Clones the sparse entry dictionary while preserving the stored sparsity pattern.
/// - Input: A `SparseMatrix`.
/// - Returns: Another `SparseMatrix` with the same shape and stored entries.
/// - Limits: This is a compatibility front door; it does not freeze or alias the original value.
pub fn SparseMatrix::as_immutable(self : SparseMatrix) -> ImmutableSparseMatrix {
  self.as_mutable()
}

///|
/// Build a sparse matrix from explicit nonzero entries.
///
/// - Does: Validates the declared shape, drops explicit zero values, and stores the remaining entries in DOK form.
/// - Input: Row count, column count, and a `Map[(Int, Int), Expr]` of entries.
/// - Returns: A `SparseMatrix`.
/// - Limits: Raises `MatrixError::ShapeError` for negative dimensions and `MatrixError::IndexError` when any stored coordinate lies outside the declared shape.
pub fn sparse_matrix(
  rows : Int,
  cols : Int,
  entries : Map[(Int, Int), Expr],
) -> SparseMatrix raise MatrixError {
  if rows < 0 || cols < 0 {
    raise MatrixError::ShapeError("matrix dimensions must be non-negative")
  }
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in entries {
    if key.0 < 0 || key.0 >= rows || key.1 < 0 || key.1 >= cols {
      raise MatrixError::IndexError("sparse entry index out of range")
    }
    if !expr_is_zero(value) {
      out[key] = value
    }
  }
  { rows, cols, entries: out }
}

///|
/// Return the sparse matrix shape.
///
/// - Does: Reports the number of rows and columns.
/// - Input: A `SparseMatrix`.
/// - Returns: A pair `(rows, cols)`.
/// - Limits: This is metadata only.
pub fn SparseMatrix::shape(self : SparseMatrix) -> (Int, Int) {
  (self.rows, self.cols)
}

///|
/// Clone a sparse matrix.
///
/// - Does: Returns a sparse matrix with copied metadata and entries.
/// - Input: A `SparseMatrix`.
/// - Returns: Another `SparseMatrix`.
/// - Limits: Equivalent to `as_mutable()` for this value-semantic API.
pub fn SparseMatrix::copy(self : SparseMatrix) -> SparseMatrix {
  self.as_mutable()
}

///|
/// Count stored nonzero entries.
///
/// - Does: Reports how many entries are currently present in the sparse dictionary.
/// - Input: A `SparseMatrix`.
/// - Returns: An `Int`.
/// - Limits: This is structural sparsity only; mathematically equivalent but unsimplified zeros are excluded at construction time.
pub fn SparseMatrix::nnz(self : SparseMatrix) -> Int {
  self.entries.length()
}

///|
/// Convert a sparse matrix to dictionary-of-keys form.
///
/// - Does: Clones the underlying `(row, col) -> Expr` map.
/// - Input: A `SparseMatrix`.
/// - Returns: `Map[(Int, Int), Expr]`.
/// - Limits: The returned map contains only stored nonzero entries.
pub fn SparseMatrix::todok(self : SparseMatrix) -> Map[(Int, Int), Expr] {
  clone_sparse_entries(self.entries)
}

///|
pub fn SparseMatrix::to_list(self : SparseMatrix) -> Array[Array[Expr]] {
  self.to_dense().to_list()
}

///|
pub fn SparseMatrix::tolist(self : SparseMatrix) -> Array[Array[Expr]] {
  self.to_list()
}

///|
/// Compare two sparse matrices by value.
///
/// - Does: Checks whether both matrices have the same shape and the same explicit entries.
/// - Input: Two `SparseMatrix` values.
/// - Returns: `Bool`.
/// - Limits: Comparison is delegated through dense equality, so semantically equal but differently simplified expressions may compare unequal.
pub fn SparseMatrix::equals(self : SparseMatrix, other : SparseMatrix) -> Bool {
  self.to_dense().equals(other.to_dense())
}

///|
/// Read one sparse matrix entry.
///
/// - Does: Returns the stored expression at `(row, col)` or symbolic zero if the coordinate is absent.
/// - Input: A `SparseMatrix`, row index, and column index. Negative indices count from the end.
/// - Returns: An `Expr`.
/// - Limits: Raises `MatrixError::IndexError` when either index falls outside the matrix bounds.
pub fn SparseMatrix::getitem(
  self : SparseMatrix,
  row : Int,
  col : Int,
) -> Expr raise MatrixError {
  let r = normalize_index(row, self.rows)
  let c = normalize_index(col, self.cols)
  match self.entries.get((r, c)) {
    Some(value) => value
    None => @symcore.int(0)
  }
}

///|
/// Return a copy of the sparse matrix with one entry replaced.
///
/// - Does: Writes `value` into `(row, col)` and removes the key entirely when `value` is zero.
/// - Input: A `SparseMatrix`, row index, column index, and replacement `Expr`. Negative indices count from the end.
/// - Returns: A new `SparseMatrix`.
/// - Limits: Raises `MatrixError::IndexError` when either index falls outside the matrix bounds.
pub fn SparseMatrix::setitem(
  self : SparseMatrix,
  row : Int,
  col : Int,
  value : Expr,
) -> SparseMatrix raise MatrixError {
  let r = normalize_index(row, self.rows)
  let c = normalize_index(col, self.cols)
  let entries = clone_sparse_entries(self.entries)
  if expr_is_zero(value) {
    ignore(entries.remove((r, c)))
  } else {
    entries[(r, c)] = value
  }
  { rows: self.rows, cols: self.cols, entries }
}

///|
/// Convert a sparse matrix into a dense matrix.
///
/// - Does: Materializes all missing entries as symbolic zero and returns a dense grid.
/// - Input: A `SparseMatrix`.
/// - Returns: A dense `Matrix`.
/// - Limits: Large sparse matrices can allocate large dense outputs.
pub fn SparseMatrix::to_dense(self : SparseMatrix) -> Matrix {
  let data : Array[Array[Expr]] = Array::new()
  for _ in 0..<self.rows {
    data.push(Array::make(self.cols, @symcore.int(0)))
  }
  for key, value in self.entries {
    data[key.0][key.1] = value
  }
  { rows: self.rows, cols: self.cols, data }
}

///|
/// Convert a dense matrix into sparse DOK form.
///
/// - Does: Drops zero entries and stores the remaining coordinates explicitly.
/// - Input: A dense `Matrix`.
/// - Returns: A `SparseMatrix`.
/// - Limits: Zero detection depends on the current symbolic zero predicate.
pub fn Matrix::to_sparse(self : Matrix) -> SparseMatrix {
  let entries : Map[(Int, Int), Expr] = Map([])
  for i in 0..<self.rows {
    for j in 0..<self.cols {
      if !expr_is_zero(self.data[i][j]) {
        entries[(i, j)] = self.data[i][j]
      }
    }
  }
  { rows: self.rows, cols: self.cols, entries }
}

///|
/// Transpose a sparse matrix.
///
/// - Does: Swaps row and column coordinates while preserving stored nonzero values.
/// - Input: A `SparseMatrix`.
/// - Returns: A transposed `SparseMatrix`.
/// - Limits: The sparsity pattern is rewritten structurally; no additional simplification is performed.
pub fn SparseMatrix::transpose(self : SparseMatrix) -> SparseMatrix {
  let entries : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    entries[(key.1, key.0)] = value
  }
  { rows: self.cols, cols: self.rows, entries }
}

///|
pub impl Show for SparseMatrix with fn to_string(self) {
  self.to_dense().to_string()
}

///|
pub impl Show for SparseMatrix with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn SparseMatrix::row_list(self : SparseMatrix) -> Array[(Int, Int, Expr)] {
  let out : Array[(Int, Int, Expr)] = []
  for i in 0..<self.rows {
    for j in 0..<self.cols {
      match self.entries.get((i, j)) {
        Some(value) => out.push((i, j, value))
        None => ()
      }
    }
  }
  out
}

///|
pub fn SparseMatrix::col_list(self : SparseMatrix) -> Array[(Int, Int, Expr)] {
  let out : Array[(Int, Int, Expr)] = []
  for j in 0..<self.cols {
    for i in 0..<self.rows {
      match self.entries.get((i, j)) {
        Some(value) => out.push((i, j, value))
        None => ()
      }
    }
  }
  out
}

///|
/// Multiply every stored sparse entry by a scalar.
///
/// - Does: Scales all explicit entries and drops any that simplify to zero.
/// - Input: A `SparseMatrix` and one scalar `Expr`.
/// - Returns: A `SparseMatrix`.
/// - Limits: Raises any construction errors from `sparse_matrix()` if the rebuilt sparse value becomes invalid.
pub fn SparseMatrix::scalar_multiply(
  self : SparseMatrix,
  scalar : Expr,
) -> SparseMatrix raise MatrixError {
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    let scaled = expr_mul(value, scalar)
    if !expr_is_zero(scaled) {
      out[key] = scaled
    }
  }
  sparse_matrix(self.rows, self.cols, out)
}

///|
/// Apply a function to each stored sparse entry.
///
/// - Does: Maps `f` over explicitly stored entries and drops results that simplify to zero.
/// - Input: A `SparseMatrix` and a function `(Expr) -> Expr`.
/// - Returns: A `SparseMatrix`.
/// - Limits: Implicit zero entries are not passed through `f`.
pub fn SparseMatrix::applyfunc(
  self : SparseMatrix,
  f : (Expr) -> Expr,
) -> SparseMatrix raise MatrixError {
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    let mapped = f(value)
    if !expr_is_zero(mapped) {
      out[key] = mapped
    }
  }
  sparse_matrix(self.rows, self.cols, out)
}

///|
/// Reshape a sparse matrix without densifying it.
///
/// - Does: Reinterprets each stored coordinate in row-major order under a new shape.
/// - Input: A `SparseMatrix` and target `rows` and `cols`.
/// - Returns: A new `SparseMatrix`.
/// - Limits: Raises `MatrixError::ShapeError` when the new shape is negative or changes the total number of entries.
pub fn SparseMatrix::reshape(
  self : SparseMatrix,
  rows : Int,
  cols : Int,
) -> SparseMatrix raise MatrixError {
  if rows < 0 || cols < 0 || rows * cols != self.rows * self.cols {
    raise MatrixError::ShapeError(
      "cannot reshape matrix to incompatible dimensions",
    )
  }
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    let flat = key.0 * self.cols + key.1
    out[(flat / cols, flat % cols)] = value
  }
  sparse_matrix(rows, cols, out)
}

///|
/// Extract a sparse submatrix by row and column index lists.
///
/// - Does: Reindexes the selected rows and columns into a new sparse matrix.
/// - Input: A `SparseMatrix`, `row_ids`, and `col_ids`. Indices may be negative.
/// - Returns: A new `SparseMatrix`.
/// - Limits: Raises `MatrixError::IndexError` when any requested index is out of range.
pub fn SparseMatrix::extract(
  self : SparseMatrix,
  row_ids : Array[Int],
  col_ids : Array[Int],
) -> SparseMatrix raise MatrixError {
  let rows = row_ids.map(index => normalize_index(index, self.rows))
  let cols = col_ids.map(index => normalize_index(index, self.cols))
  let out : Map[(Int, Int), Expr] = Map([])
  for i in 0..<rows.length() {
    for j in 0..<cols.length() {
      match self.entries.get((rows[i], cols[j])) {
        Some(value) => out[(i, j)] = value
        None => ()
      }
    }
  }
  sparse_matrix(rows.length(), cols.length(), out)
}

///|
pub fn SparseMatrix::row_join(
  self : SparseMatrix,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  if self.rows != other.rows {
    raise MatrixError::ShapeError(
      "row_join requires matrices with the same row count",
    )
  }
  let out = clone_sparse_entries(self.entries)
  for key, value in other.entries {
    out[(key.0, key.1 + self.cols)] = value
  }
  sparse_matrix(self.rows, self.cols + other.cols, out)
}

///|
pub fn SparseMatrix::col_join(
  self : SparseMatrix,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  if self.cols != other.cols {
    raise MatrixError::ShapeError(
      "col_join requires matrices with the same column count",
    )
  }
  let out = clone_sparse_entries(self.entries)
  for key, value in other.entries {
    out[(key.0 + self.rows, key.1)] = value
  }
  sparse_matrix(self.rows + other.rows, self.cols, out)
}

///|
pub fn SparseMatrix::row_insert(
  self : SparseMatrix,
  pos : Int,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  if self.cols != other.cols {
    raise MatrixError::ShapeError(
      "row_insert requires matrices with the same column count",
    )
  }
  let insert_at = normalize_insert_pos(pos, self.rows)
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    let row = if key.0 >= insert_at { key.0 + other.rows } else { key.0 }
    out[(row, key.1)] = value
  }
  for key, value in other.entries {
    out[(insert_at + key.0, key.1)] = value
  }
  sparse_matrix(self.rows + other.rows, self.cols, out)
}

///|
pub fn SparseMatrix::col_insert(
  self : SparseMatrix,
  pos : Int,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  if self.rows != other.rows {
    raise MatrixError::ShapeError(
      "col_insert requires matrices with the same row count",
    )
  }
  let insert_at = normalize_insert_pos(pos, self.cols)
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    let col = if key.1 >= insert_at { key.1 + other.cols } else { key.1 }
    out[(key.0, col)] = value
  }
  for key, value in other.entries {
    out[(key.0, insert_at + key.1)] = value
  }
  sparse_matrix(self.rows, self.cols + other.cols, out)
}

///|
pub fn SparseMatrix::row_del(
  self : SparseMatrix,
  pos : Int,
) -> SparseMatrix raise MatrixError {
  let removed = normalize_index(pos, self.rows)
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    if key.0 == removed {
      continue
    }
    let row = if key.0 > removed { key.0 - 1 } else { key.0 }
    out[(row, key.1)] = value
  }
  sparse_matrix(self.rows - 1, self.cols, out)
}

///|
pub fn SparseMatrix::col_del(
  self : SparseMatrix,
  pos : Int,
) -> SparseMatrix raise MatrixError {
  let removed = normalize_index(pos, self.cols)
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    if key.1 == removed {
      continue
    }
    let col = if key.1 > removed { key.1 - 1 } else { key.1 }
    out[(key.0, col)] = value
  }
  sparse_matrix(self.rows, self.cols - 1, out)
}

///|
/// Check whether the sparse matrix stores only zeros.
///
/// - Does: Tests whether there are no explicit nonzero entries.
/// - Input: A `SparseMatrix`.
/// - Returns: `Bool`.
/// - Limits: This is structural and assumes explicit zeros were removed on construction.
pub fn SparseMatrix::is_zero_matrix(self : SparseMatrix) -> Bool {
  self.nnz() == 0
}

///|
pub fn SparseMatrix::is_diagonal(self : SparseMatrix) -> Bool {
  for key, value in self.entries {
    if key.0 != key.1 && !expr_is_zero(value) {
      return false
    }
  }
  true
}

///|
pub fn SparseMatrix::is_symmetric(self : SparseMatrix) -> Bool {
  if self.rows != self.cols {
    return false
  }
  for key, value in self.entries {
    match self.entries.get((key.1, key.0)) {
      Some(other) => if !expr_eq(value, other) { return false }
      None => if !expr_is_zero(value) { return false }
    }
  }
  true
}

///|
pub fn SparseMatrix::is_upper(self : SparseMatrix) -> Bool {
  if self.rows != self.cols {
    return false
  }
  for key, value in self.entries {
    if key.0 > key.1 && !expr_is_zero(value) {
      return false
    }
  }
  true
}

///|
pub fn SparseMatrix::is_lower(self : SparseMatrix) -> Bool {
  if self.rows != self.cols {
    return false
  }
  for key, value in self.entries {
    if key.0 < key.1 && !expr_is_zero(value) {
      return false
    }
  }
  true
}

///|
/// Compute the trace of a sparse matrix.
///
/// - Does: Adds the explicitly stored diagonal entries and treats missing ones as zero.
/// - Input: A square `SparseMatrix`.
/// - Returns: One symbolic `Expr`.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` when the matrix is not square.
pub fn SparseMatrix::trace(self : SparseMatrix) -> Expr raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError("trace requires a square matrix")
  }
  let mut acc = @symcore.int(0)
  for i in 0..<self.rows {
    match self.entries.get((i, i)) {
      Some(value) => acc = expr_add(acc, value)
      None => ()
    }
  }
  acc
}

///|
/// Compute the rank of a sparse matrix.
///
/// - Does: Counts pivot columns in the reduced row echelon form.
/// - Input: Any `SparseMatrix`.
/// - Returns: An `Int` rank.
/// - Limits: This front door materializes dense row data during elimination.
pub fn SparseMatrix::rank(self : SparseMatrix) -> Int {
  self.rref().1.length()
}

///|
/// Compute the determinant of a sparse square matrix.
///
/// - Does: Uses diagonal shortcuts when available and otherwise delegates to dense determinant computation.
/// - Input: A square `SparseMatrix`.
/// - Returns: One symbolic `Expr`.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` for non-square inputs. General sparse determinants currently fall back to dense evaluation.
pub fn SparseMatrix::det(self : SparseMatrix) -> Expr raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError(
      "determinant requires a square matrix",
    )
  }
  if self.rows == 0 {
    return @symcore.int(1)
  }
  if self.is_diagonal() || self.is_upper() || self.is_lower() {
    let mut acc = @symcore.int(1)
    for i in 0..<self.rows {
      acc = expr_mul(
        acc,
        match self.entries.get((i, i)) {
          Some(value) => value
          None => @symcore.int(0)
        },
      )
    }
    return acc
  }
  self.to_dense().det()
}

///|
/// Compute the inverse of a sparse square matrix.
///
/// - Does: Delegates through the dense inverse path.
/// - Input: A square `SparseMatrix`.
/// - Returns: A dense `Matrix`.
/// - Limits: Raises `MatrixError::NonSquareMatrixError` or `MatrixError::SingularMatrixError` under the same conditions as dense inversion, and it does not preserve sparsity in the return type.
pub fn SparseMatrix::inv(self : SparseMatrix) -> Matrix raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError("inverse requires a square matrix")
  }
  self.solve(eye(self.rows))
}

///|
pub fn SparseMatrix::echelon_form(self : SparseMatrix) -> Matrix {
  let (rows, _) = sparse_echelon_internal(self)
  sparse_row_maps_to_dense(rows, self.cols)
}

///|
pub fn SparseMatrix::rref(self : SparseMatrix) -> (Matrix, Array[Int]) {
  let (rows, pivots) = sparse_rref_internal(self)
  (sparse_row_maps_to_dense(rows, self.cols), pivots)
}

///|
pub fn SparseMatrix::rowspace(self : SparseMatrix) -> Array[Array[Expr]] {
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
pub fn SparseMatrix::columnspace(self : SparseMatrix) -> Array[Array[Expr]] {
  let (_, pivots) = self.rref()
  let out : Array[Array[Expr]] = []
  for pivot in pivots {
    let col : Array[Expr] = []
    for i in 0..<self.rows {
      col.push(
        match self.entries.get((i, pivot)) {
          Some(value) => value
          None => @symcore.int(0)
        },
      )
    }
    out.push(col)
  }
  out
}

///|
pub fn SparseMatrix::nullspace(self : SparseMatrix) -> Array[Array[Expr]] {
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
pub fn SparseMatrix::lu(
  self : SparseMatrix,
) -> (Matrix, Matrix, Array[(Int, Int)]) raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError(
      "LU decomposition requires a square matrix",
    )
  }
  let n = self.rows
  let u_rows = clone_sparse_row_maps(sparse_row_maps(self))
  let l = clone_expr_rows(eye(n).data)
  let swaps : Array[(Int, Int)] = []
  for k in 0..<n {
    let mut pivot_row = k
    while pivot_row < n && expr_is_zero(sparse_row_get(u_rows[pivot_row], k)) {
      pivot_row += 1
    }
    if pivot_row == n {
      continue
    }
    if pivot_row != k {
      sparse_swap_row_maps(u_rows, pivot_row, k)
      for j in 0..<k {
        let tmp = l[pivot_row][j]
        l[pivot_row][j] = l[k][j]
        l[k][j] = tmp
      }
      swaps.push((k, pivot_row))
    }
    let pivot = sparse_row_get(u_rows[k], k)
    for i in (k + 1)..<n {
      let factor_num = sparse_row_get(u_rows[i], k)
      if expr_is_zero(factor_num) {
        continue
      }
      let factor = expr_div(factor_num, pivot)
      l[i][k] = factor
      let active_cols = sparse_row_active_cols(u_rows[i], u_rows[k], k)
      for active_col in active_cols {
        let updated = expr_sub(
          sparse_row_get(u_rows[i], active_col),
          expr_mul(factor, sparse_row_get(u_rows[k], active_col)),
        )
        sparse_row_set(u_rows[i], active_col, updated)
      }
      sparse_row_set(u_rows[i], k, @symcore.int(0))
    }
  }
  ({ rows: n, cols: n, data: l }, sparse_row_maps_to_dense(u_rows, n), swaps)
}

///|
pub fn SparseMatrix::eigenvals(
  self : SparseMatrix,
) -> Array[EigenValueMult] raise MatrixError {
  self.to_dense().eigenvals()
}

///|
pub fn SparseMatrix::eigenvects(
  self : SparseMatrix,
) -> Array[EigenVectData] raise MatrixError {
  self.to_dense().eigenvects()
}

///|
pub fn SparseMatrix::jordan_form(
  self : SparseMatrix,
  calc_transform? : Bool = true,
) -> (Matrix, Matrix) raise MatrixError {
  self.to_dense().jordan_form(calc_transform~)
}

///|
/// Solve a sparse linear system `A * X = rhs`.
///
/// - Does: Solves the system using sparse LU where possible and falls back through dense-style triangular solves.
/// - Input: A square left-hand-side `SparseMatrix` and a dense right-hand-side `Matrix` with matching row count.
/// - Returns: A dense `Matrix` solution.
/// - Limits: Raises shape and singularity errors under the same conditions as dense `solve`, and the result is returned as a dense matrix.
pub fn SparseMatrix::solve(
  self : SparseMatrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError("solve requires a square matrix")
  }
  if rhs.rows != self.rows {
    raise MatrixError::ShapeError(
      "solve expects rhs with the same number of rows",
    )
  }
  let dense = self.to_dense()
  let numeric_prec = {
    let lhs_prec = expr_numeric_precision(dense.data)
    let rhs_prec = expr_numeric_precision(rhs.data)
    if lhs_prec > rhs_prec {
      lhs_prec
    } else {
      rhs_prec
    }
  }
  if (
      matrix_has_floating_leaf(dense.data) || matrix_has_floating_leaf(rhs.data)
    ) &&
    matrix_all_numeric(dense.data, numeric_prec) &&
    matrix_all_numeric(rhs.data, numeric_prec) {
    return dense.solve(rhs)
  }
  let (l, u, swaps) = self.lu()
  let rhs_swapped = sparse_apply_row_swaps_rhs(rhs, swaps)
  u.upper_triangular_solve(l.lower_triangular_solve(rhs_swapped))
}

///|
pub fn SparseMatrix::solve_least_squares(
  self : SparseMatrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  let dense = self.to_dense()
  let normal = dense.transpose() * dense
  let projected = dense.transpose() * rhs
  normal.solve(projected)
}

///|
pub fn SparseMatrix::lower_triangular_solve(
  self : SparseMatrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError(
      "lower_triangular_solve requires a square matrix",
    )
  }
  if rhs.rows != self.rows {
    raise MatrixError::ShapeError(
      "lower_triangular_solve expects matching row counts",
    )
  }
  let dense = self.to_dense()
  let numeric_prec = {
    let lhs_prec = expr_numeric_precision(dense.data)
    let rhs_prec = expr_numeric_precision(rhs.data)
    if lhs_prec > rhs_prec {
      lhs_prec
    } else {
      rhs_prec
    }
  }
  if (
      matrix_has_floating_leaf(dense.data) || matrix_has_floating_leaf(rhs.data)
    ) &&
    matrix_all_numeric(dense.data, numeric_prec) &&
    matrix_all_numeric(rhs.data, numeric_prec) {
    return dense.lower_triangular_solve(rhs)
  }
  let row_entries = sparse_row_entries(self)
  let out = zeros(self.rows, cols=Some(rhs.cols))
  let data = clone_expr_rows(out.data)
  for i in 0..<self.rows {
    let mut diag = @symcore.int(0)
    for item in row_entries[i] {
      let (col, value) = item
      if col == i {
        diag = value
      } else if col > i && !expr_is_zero(value) {
        raise MatrixError::ValueError("matrix is not lower triangular")
      }
    }
    if expr_is_zero(diag) {
      raise MatrixError::SingularMatrixError("matrix is singular")
    }
    for j in 0..<rhs.cols {
      let mut acc = rhs.data[i][j]
      for item in row_entries[i] {
        let (col, value) = item
        if col < i {
          acc = expr_sub(acc, expr_mul(value, data[col][j]))
        }
      }
      data[i][j] = expr_div(acc, diag)
    }
  }
  { rows: self.rows, cols: rhs.cols, data }
}

///|
pub fn SparseMatrix::upper_triangular_solve(
  self : SparseMatrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError(
      "upper_triangular_solve requires a square matrix",
    )
  }
  if rhs.rows != self.rows {
    raise MatrixError::ShapeError(
      "upper_triangular_solve expects matching row counts",
    )
  }
  let dense = self.to_dense()
  let numeric_prec = {
    let lhs_prec = expr_numeric_precision(dense.data)
    let rhs_prec = expr_numeric_precision(rhs.data)
    if lhs_prec > rhs_prec {
      lhs_prec
    } else {
      rhs_prec
    }
  }
  if (
      matrix_has_floating_leaf(dense.data) || matrix_has_floating_leaf(rhs.data)
    ) &&
    matrix_all_numeric(dense.data, numeric_prec) &&
    matrix_all_numeric(rhs.data, numeric_prec) {
    return dense.upper_triangular_solve(rhs)
  }
  let row_entries = sparse_row_entries(self)
  let out = zeros(self.rows, cols=Some(rhs.cols))
  let data = clone_expr_rows(out.data)
  for offset in 0..<self.rows {
    let i = self.rows - 1 - offset
    let mut diag = @symcore.int(0)
    for item in row_entries[i] {
      let (col, value) = item
      if col == i {
        diag = value
      } else if col < i && !expr_is_zero(value) {
        raise MatrixError::ValueError("matrix is not upper triangular")
      }
    }
    if expr_is_zero(diag) {
      raise MatrixError::SingularMatrixError("matrix is singular")
    }
    for j in 0..<rhs.cols {
      let mut acc = rhs.data[i][j]
      for item in row_entries[i] {
        let (col, value) = item
        if col > i {
          acc = expr_sub(acc, expr_mul(value, data[col][j]))
        }
      }
      data[i][j] = expr_div(acc, diag)
    }
  }
  { rows: self.rows, cols: rhs.cols, data }
}

///|
pub fn SparseMatrix::cholesky(self : SparseMatrix) -> Matrix raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError(
      "cholesky decomposition requires a square matrix",
    )
  }
  let dense = self.to_dense()
  let numeric_prec = expr_numeric_precision(dense.data)
  if matrix_has_floating_leaf(dense.data) &&
    matrix_all_numeric(dense.data, numeric_prec) {
    return dense.cholesky()
  }
  let n = self.rows
  let out = zeros(n, cols=Some(n))
  let l = clone_expr_rows(out.data)
  for i in 0..<n {
    for j in 0..<=i {
      let mut acc = self.getitem(i, j)
      for k in 0..<j {
        acc = expr_sub(acc, expr_mul(l[i][k], l[j][k]))
      }
      if i == j {
        l[i][j] = expr_simplify(@symcore.function("sqrt", [acc]))
      } else {
        l[i][j] = expr_div(acc, l[j][j])
      }
    }
  }
  { rows: n, cols: n, data: l }
}

///|
pub fn SparseMatrix::ldl(
  self : SparseMatrix,
) -> (Matrix, Matrix) raise MatrixError {
  if self.rows != self.cols {
    raise MatrixError::NonSquareMatrixError(
      "LDL decomposition requires a square matrix",
    )
  }
  let dense = self.to_dense()
  let numeric_prec = expr_numeric_precision(dense.data)
  if matrix_has_floating_leaf(dense.data) &&
    matrix_all_numeric(dense.data, numeric_prec) {
    return dense.ldl()
  }
  let n = self.rows
  let l0 = zeros(n, cols=Some(n))
  let d0 = zeros(n, cols=Some(n))
  let l = clone_expr_rows(l0.data)
  let d = clone_expr_rows(d0.data)
  for i in 0..<n {
    l[i][i] = @symcore.int(1)
  }
  for j in 0..<n {
    let mut diag = self.getitem(j, j)
    for k in 0..<j {
      diag = expr_sub(diag, expr_mul(expr_mul(l[j][k], l[j][k]), d[k][k]))
    }
    d[j][j] = diag
    for i in (j + 1)..<n {
      let mut value = self.getitem(i, j)
      for k in 0..<j {
        value = expr_sub(value, expr_mul(expr_mul(l[i][k], l[j][k]), d[k][k]))
      }
      l[i][j] = expr_div(value, d[j][j])
    }
  }
  ({ rows: n, cols: n, data: l }, { rows: n, cols: n, data: d })
}

///|
pub fn SparseMatrix::qr(
  self : SparseMatrix,
) -> (Matrix, Matrix) raise MatrixError {
  if self.rows == 0 || self.cols == 0 {
    return (
      zeros(self.rows, cols=Some(self.cols)),
      zeros(self.cols, cols=Some(self.cols)),
    )
  }
  self.to_dense().qr()
}

///|
pub impl Add for SparseMatrix with fn add(self, other) {
  let out = clone_sparse_entries(self.entries)
  for key, value in other.entries {
    sparse_accumulate(out, key, value)
  }
  { rows: self.rows, cols: self.cols, entries: out }
}

///|
pub impl Sub for SparseMatrix with fn sub(self, other) {
  let out = clone_sparse_entries(self.entries)
  for key, value in other.entries {
    sparse_accumulate(out, key, expr_neg(value))
  }
  { rows: self.rows, cols: self.cols, entries: out }
}

///|
pub impl Mul for SparseMatrix with fn mul(self, other) {
  let rhs_rows = sparse_row_entries(other)
  let out : Map[(Int, Int), Expr] = Map([])
  for key, value in self.entries {
    let (row, inner) = key
    for item in rhs_rows[inner] {
      let (col, rhs_value) = item
      sparse_accumulate(out, (row, col), expr_mul(value, rhs_value))
    }
  }
  { rows: self.rows, cols: other.cols, entries: out }
}
