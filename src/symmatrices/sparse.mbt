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
pub fn SparseMatrix::as_mutable(self : SparseMatrix) -> MutableSparseMatrix {
  let entries : Map[(Int, Int), Expr] = {}
  for key, value in self.entries {
    entries[key] = value
  }
  SparseMatrix::{ rows: self.rows, cols: self.cols, entries }
}

///|
pub fn SparseMatrix::as_immutable(self : SparseMatrix) -> ImmutableSparseMatrix {
  self.as_mutable()
}

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
pub fn SparseMatrix::copy(self : SparseMatrix) -> SparseMatrix {
  self.as_mutable()
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
pub fn SparseMatrix::to_list(
  self : SparseMatrix,
) -> Array[Array[Expr]] raise MatrixError {
  self.to_dense().to_list()
}

///|
pub fn SparseMatrix::tolist(
  self : SparseMatrix,
) -> Array[Array[Expr]] raise MatrixError {
  self.to_list()
}

///|
pub fn SparseMatrix::equals(
  self : SparseMatrix,
  other : SparseMatrix,
) -> Bool raise MatrixError {
  self.to_dense().equals(other.to_dense())
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
pub fn SparseMatrix::reshape(
  self : SparseMatrix,
  rows : Int,
  cols : Int,
) -> SparseMatrix raise MatrixError {
  self.to_dense().reshape(rows, cols).to_sparse()
}

///|
pub fn SparseMatrix::extract(
  self : SparseMatrix,
  row_ids : Array[Int],
  col_ids : Array[Int],
) -> SparseMatrix raise MatrixError {
  self.to_dense().extract(row_ids, col_ids).to_sparse()
}

///|
pub fn SparseMatrix::row_join(
  self : SparseMatrix,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  self.to_dense().row_join(other.to_dense()).to_sparse()
}

///|
pub fn SparseMatrix::col_join(
  self : SparseMatrix,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  self.to_dense().col_join(other.to_dense()).to_sparse()
}

///|
pub fn SparseMatrix::row_insert(
  self : SparseMatrix,
  pos : Int,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  self.to_dense().row_insert(pos, other.to_dense()).to_sparse()
}

///|
pub fn SparseMatrix::col_insert(
  self : SparseMatrix,
  pos : Int,
  other : SparseMatrix,
) -> SparseMatrix raise MatrixError {
  self.to_dense().col_insert(pos, other.to_dense()).to_sparse()
}

///|
pub fn SparseMatrix::row_del(
  self : SparseMatrix,
  pos : Int,
) -> SparseMatrix raise MatrixError {
  self.to_dense().row_del(pos).to_sparse()
}

///|
pub fn SparseMatrix::col_del(
  self : SparseMatrix,
  pos : Int,
) -> SparseMatrix raise MatrixError {
  self.to_dense().col_del(pos).to_sparse()
}

///|
pub fn SparseMatrix::is_zero_matrix(self : SparseMatrix) -> Bool {
  self.nnz() == 0
}

///|
pub fn SparseMatrix::is_diagonal(self : SparseMatrix) -> Bool raise MatrixError {
  self.to_dense().is_diagonal()
}

///|
pub fn SparseMatrix::is_symmetric(
  self : SparseMatrix,
) -> Bool raise MatrixError {
  self.to_dense().is_symmetric()
}

///|
pub fn SparseMatrix::solve(
  self : SparseMatrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  self.to_dense().solve(rhs)
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
  self.to_dense().lower_triangular_solve(rhs)
}

///|
pub fn SparseMatrix::upper_triangular_solve(
  self : SparseMatrix,
  rhs : Matrix,
) -> Matrix raise MatrixError {
  self.to_dense().upper_triangular_solve(rhs)
}

///|
pub fn SparseMatrix::cholesky(self : SparseMatrix) -> Matrix raise MatrixError {
  self.to_dense().cholesky()
}

///|
pub fn SparseMatrix::ldl(
  self : SparseMatrix,
) -> (Matrix, Matrix) raise MatrixError {
  self.to_dense().ldl()
}
