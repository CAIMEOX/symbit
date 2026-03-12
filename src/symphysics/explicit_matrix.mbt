///|
/// Explicit dense matrix of symbolic expressions.
pub struct ExplicitMatrix {
  rows : Array[Array[@symcore.Expr]]
} derive(Eq)

///|
pub fn explicit_matrix_from_rows(
  rows : Array[Array[@symcore.Expr]],
) -> ExplicitMatrix raise PhysicsError {
  if rows.is_empty() {
    return ExplicitMatrix::{ rows, }
  }
  let width = rows[0].length()
  for row in rows {
    if row.length() != width {
      raise PhysicsError::ShapeError("matrix rows must have equal length")
    }
  }
  ExplicitMatrix::{ rows, }
}

///|
pub fn explicit_matrix_from_ints(rows : Array[Array[Int]]) -> ExplicitMatrix {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for row in rows {
    let next : Array[@symcore.Expr] = Array::new()
    for value in row {
      next.push(@symcore.int(value))
    }
    out.push(next)
  }
  ExplicitMatrix::{ rows: out }
}

///|
pub fn explicit_matrix_eye(n : Int) -> ExplicitMatrix {
  let rows : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<n {
    let row = Array::make(n, @symcore.int(0))
    row[i] = @symcore.int(1)
    rows.push(row)
  }
  ExplicitMatrix::{ rows, }
}

///|
pub fn explicit_matrix_zeros(rows : Int, cols : Int) -> ExplicitMatrix {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for _ in 0..<rows {
    out.push(Array::make(cols, @symcore.int(0)))
  }
  ExplicitMatrix::{ rows: out }
}

///|
pub fn ExplicitMatrix::height(self : ExplicitMatrix) -> Int {
  self.rows.length()
}

///|
pub fn ExplicitMatrix::width(self : ExplicitMatrix) -> Int {
  if self.rows.is_empty() {
    0
  } else {
    self.rows[0].length()
  }
}

///|
pub fn ExplicitMatrix::get(
  self : ExplicitMatrix,
  row : Int,
  col : Int,
) -> @symcore.Expr raise PhysicsError {
  if row < 0 || row >= self.height() || col < 0 || col >= self.width() {
    raise PhysicsError::IndexError("matrix index out of range")
  }
  self.rows[row][col]
}

///|
pub fn ExplicitMatrix::scale(
  self : ExplicitMatrix,
  scalar : @symcore.Expr,
) -> ExplicitMatrix {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for row in self.rows {
    let next : Array[@symcore.Expr] = Array::new()
    for value in row {
      next.push(scalar * value)
    }
    out.push(next)
  }
  ExplicitMatrix::{ rows: out }
}

///|
pub fn ExplicitMatrix::neg(self : ExplicitMatrix) -> ExplicitMatrix {
  self.scale(@symcore.int(-1))
}

///|
pub fn ExplicitMatrix::map(
  self : ExplicitMatrix,
  f : (@symcore.Expr) -> @symcore.Expr,
) -> ExplicitMatrix {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for row in self.rows {
    let next : Array[@symcore.Expr] = Array::new()
    for value in row {
      next.push(f(value))
    }
    out.push(next)
  }
  ExplicitMatrix::{ rows: out }
}

///|
pub fn ExplicitMatrix::transpose(self : ExplicitMatrix) -> ExplicitMatrix {
  let out = explicit_matrix_zeros(self.width(), self.height())
  for i in 0..<self.height() {
    for j in 0..<self.width() {
      out.rows[j][i] = self.rows[i][j]
    }
  }
  out
}

///|
pub fn ExplicitMatrix::add(
  self : ExplicitMatrix,
  other : ExplicitMatrix,
) -> ExplicitMatrix raise PhysicsError {
  if self.height() != other.height() || self.width() != other.width() {
    raise PhysicsError::ShapeError("matrix shapes differ")
  }
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<self.height() {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<self.width() {
      row.push(self.rows[i][j] + other.rows[i][j])
    }
    out.push(row)
  }
  ExplicitMatrix::{ rows: out }
}

///|
pub fn ExplicitMatrix::sub(
  self : ExplicitMatrix,
  other : ExplicitMatrix,
) -> ExplicitMatrix raise PhysicsError {
  self.add(other.neg())
}

///|
pub fn ExplicitMatrix::mul(
  self : ExplicitMatrix,
  other : ExplicitMatrix,
) -> ExplicitMatrix raise PhysicsError {
  if self.width() != other.height() {
    raise PhysicsError::ShapeError("matrix product shape mismatch")
  }
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<self.height() {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<other.width() {
      let mut acc = @symcore.int(0)
      for k in 0..<self.width() {
        acc = acc + self.rows[i][k] * other.rows[k][j]
      }
      row.push(acc)
    }
    out.push(row)
  }
  ExplicitMatrix::{ rows: out }
}

///|
pub fn explicit_matrix_rows_string(matrix : ExplicitMatrix) -> String {
  let rows : Array[String] = Array::new()
  for row in matrix.rows {
    let items : Array[String] = Array::new()
    for value in row {
      items.push(@symprint.to_string(value))
    }
    let joined_items = items.join(", ")
    rows.push("[\{joined_items}]")
  }
  let joined_rows = rows.join(", ")
  "[\{joined_rows}]"
}
