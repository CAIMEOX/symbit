///|
/// Minimal matrix support for Lie algebra computations.

///|
pub struct Matrix {
  rows : Array[Array[@symnum.BigRational]]
} derive(Eq)

///|
/// Create a matrix from rational rows.
pub fn matrix_from_rows(rows : Array[Array[@symnum.BigRational]]) -> Matrix {
  Matrix::{ rows, }
}

///|
/// Create a matrix from integer rows.
pub fn matrix_from_ints(rows : Array[Array[Int]]) -> Matrix {
  let out : Array[Array[@symnum.BigRational]] = Array::new()
  for row in rows {
    let next : Array[@symnum.BigRational] = Array::new()
    for value in row {
      next.push(br_int(value))
    }
    out.push(next)
  }
  Matrix::{ rows: out }
}

///|
/// Create an `n x n` identity matrix.
pub fn matrix_eye(n : Int) -> Matrix {
  let rows : Array[Array[@symnum.BigRational]] = Array::new()
  for i in 0..<n {
    let row = Array::make(n, br_int(0))
    row[i] = br_int(1)
    rows.push(row)
  }
  Matrix::{ rows, }
}

///|
/// Number of rows in the matrix.
pub fn Matrix::height(self : Matrix) -> Int {
  self.rows.length()
}

///|
/// Number of columns in the matrix.
pub fn Matrix::width(self : Matrix) -> Int {
  if self.rows.is_empty() {
    return 0
  }
  self.rows[0].length()
}

///|
/// Read element `(r, c)`.
pub fn Matrix::get(self : Matrix, r : Int, c : Int) -> @symnum.BigRational {
  self.rows[r][c]
}

///|
/// Mutate element `(r, c)`.
pub fn Matrix::set(
  self : Matrix,
  r : Int,
  c : Int,
  value : @symnum.BigRational,
) -> Unit {
  self.rows[r][c] = value
}

///|
/// Multiply two matrices.
pub fn matrix_mul(a : Matrix, b : Matrix) -> Matrix {
  let h = a.height()
  let w = b.width()
  let k = a.width()
  let rows : Array[Array[@symnum.BigRational]] = Array::new()
  for i in 0..<h {
    let row = Array::make(w, br_int(0))
    for j in 0..<w {
      let mut acc = br_int(0)
      for t in 0..<k {
        acc = acc + a.get(i, t) * b.get(t, j)
      }
      row[j] = acc
    }
    rows.push(row)
  }
  Matrix::{ rows, }
}

///|
/// Method form of matrix multiplication.
pub fn Matrix::mul(self : Matrix, other : Matrix) -> Matrix {
  matrix_mul(self, other)
}

///|
/// Serialize matrix rows to a deterministic string.
pub fn matrix_rows_string(m : Matrix) -> String {
  let rows : Array[String] = Array::new()
  for row in m.rows {
    let parts : Array[String] = Array::new()
    for value in row {
      parts.push(value.to_string())
    }
    let joined = parts.join(", ")
    rows.push("[\{joined}]")
  }
  if rows.is_empty() {
    return "[]"
  }
  let joined_rows = rows.join(", ")
  "[\{joined_rows}]"
}
