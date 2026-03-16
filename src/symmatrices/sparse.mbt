///|
/// Sparse symbolic matrix stored in dictionary-of-keys form.
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
pub fn sparse_matrix(
  rows : Int,
  cols : Int,
  entries : Map[(Int, Int), Expr],
) -> SparseMatrix raise MatrixError {
  if rows < 0 || cols < 0 {
    raise MatrixError::ShapeError("matrix dimensions must be non-negative")
  }
  let out : Map[(Int, Int), Expr] = {}
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
pub fn SparseMatrix::shape(self : SparseMatrix) -> (Int, Int) {
  (self.rows, self.cols)
}

///|
pub fn SparseMatrix::nnz(self : SparseMatrix) -> Int {
  self.entries.length()
}

///|
pub fn SparseMatrix::todok(self : SparseMatrix) -> Map[(Int, Int), Expr] {
  let out : Map[(Int, Int), Expr] = {}
  for key, value in self.entries {
    out[key] = value
  }
  out
}

///|
pub fn SparseMatrix::getitem(
  self : SparseMatrix,
  row : Int,
  col : Int,
) -> Expr raise MatrixError {
  let r = normalize_index(row, self.rows)
  let c = normalize_index(col, self.cols)
  match self.entries.get((r, c)) {
    Some(value) => value
    None => expr_zero()
  }
}

///|
pub fn SparseMatrix::setitem(
  self : SparseMatrix,
  row : Int,
  col : Int,
  value : Expr,
) -> SparseMatrix raise MatrixError {
  let r = normalize_index(row, self.rows)
  let c = normalize_index(col, self.cols)
  let entries : Map[(Int, Int), Expr] = {}
  for key, item in self.entries {
    entries[key] = item
  }
  if expr_is_zero(value) {
    ignore(entries.remove((r, c)))
  } else {
    entries[(r, c)] = value
  }
  { rows: self.rows, cols: self.cols, entries }
}

///|
pub fn SparseMatrix::to_dense(self : SparseMatrix) -> Matrix raise MatrixError {
  let out = zeros(self.rows, cols=Some(self.cols))
  let data = clone_expr_rows(out.data)
  for key, value in self.entries {
    data[key.0][key.1] = value
  }
  { rows: self.rows, cols: self.cols, data }
}

///|
pub fn Matrix::to_sparse(self : Matrix) -> SparseMatrix {
  let entries : Map[(Int, Int), Expr] = {}
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
pub fn SparseMatrix::transpose(self : SparseMatrix) -> SparseMatrix {
  let entries : Map[(Int, Int), Expr] = {}
  for key, value in self.entries {
    entries[(key.1, key.0)] = value
  }
  { rows: self.cols, cols: self.rows, entries }
}

///|
pub fn SparseMatrix::to_string(self : SparseMatrix) -> String raise MatrixError {
  self.to_dense().to_string()
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
pub fn SparseMatrix::scalar_multiply(
  self : SparseMatrix,
  scalar : Expr,
) -> SparseMatrix raise MatrixError {
  let out : Map[(Int, Int), Expr] = {}
  for key, value in self.entries {
    let scaled = expr_mul(value, scalar)
    if !expr_is_zero(scaled) {
      out[key] = scaled
    }
  }
  sparse_matrix(self.rows, self.cols, out)
}

///|
pub fn SparseMatrix::applyfunc(
  self : SparseMatrix,
  f : (Expr) -> Expr,
) -> SparseMatrix raise MatrixError {
  let out : Map[(Int, Int), Expr] = {}
  for key, value in self.entries {
    let mapped = f(value)
    if !expr_is_zero(mapped) {
      out[key] = mapped
    }
  }
  sparse_matrix(self.rows, self.cols, out)
}

///|
pub fn SparseMatrix::solve(
  self : SparseMatrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  self.to_dense().solve(rhs)
}
