///|
/// Explicit dense matrix of symbolic expressions.
pub struct ExplicitMatrix {
  rows : Array[Array[Expr]]
} derive(Eq)

///|
pub fn explicit_matrix_from_rows(
  rows : Array[Array[Expr]],
) -> ExplicitMatrix raise PhysicsError {
  if rows.is_empty() {
    return { rows, }
  }
  let width = rows[0].length()
  for row in rows {
    if row.length() != width {
      raise ShapeError("matrix rows must have equal length")
    }
  }
  { rows, }
}

///|
pub fn explicit_matrix_from_ints(rows : Array[Array[Int]]) -> ExplicitMatrix {
  let out : Array[Array[Expr]] = Array::new()
  for row in rows {
    let next : Array[Expr] = Array::new()
    for value in row {
      next.push(int(value))
    }
    out.push(next)
  }
  { rows: out }
}

///|
pub fn explicit_matrix_column(exprs : Array[Expr]) -> ExplicitMatrix {
  let rows : Array[Array[Expr]] = Array::new()
  for expr in exprs {
    rows.push([expr])
  }
  { rows, }
}

///|
pub fn explicit_matrix_eye(n : Int) -> ExplicitMatrix {
  let rows : Array[Array[Expr]] = Array::new()
  for i in 0..<n {
    let row = Array::make(n, int(0))
    row[i] = int(1)
    rows.push(row)
  }
  { rows, }
}

///|
pub fn explicit_matrix_zeros(rows : Int, cols : Int) -> ExplicitMatrix {
  let out : Array[Array[Expr]] = Array::new()
  for _ in 0..<rows {
    out.push(Array::make(cols, int(0)))
  }
  { rows: out }
}

///|
pub fn explicit_matrix_horizontal_concat(
  lhs : ExplicitMatrix,
  rhs : ExplicitMatrix,
) -> ExplicitMatrix raise PhysicsError {
  if lhs.height() != rhs.height() {
    raise ShapeError("matrix row join requires equal heights")
  }
  let rows : Array[Array[Expr]] = Array::new()
  for i in 0..<lhs.height() {
    rows.push(lhs.rows[i].copy() + rhs.rows[i].copy())
  }
  { rows, }
}

///|
pub fn explicit_matrix_vertical_concat(
  top : ExplicitMatrix,
  bottom : ExplicitMatrix,
) -> ExplicitMatrix raise PhysicsError {
  if top.width() != bottom.width() {
    raise ShapeError("matrix column join requires equal widths")
  }
  { rows: top.rows_copy() + bottom.rows_copy() }
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
pub fn ExplicitMatrix::rows_copy(self : ExplicitMatrix) -> Array[Array[Expr]] {
  let out : Array[Array[Expr]] = Array::new()
  for row in self.rows {
    out.push(row.copy())
  }
  out
}

///|
pub fn ExplicitMatrix::get(
  self : ExplicitMatrix,
  row : Int,
  col : Int,
) -> Expr raise PhysicsError {
  if row < 0 || row >= self.height() || col < 0 || col >= self.width() {
    raise IndexError("matrix index out of range")
  }
  self.rows[row][col]
}

///|
pub fn ExplicitMatrix::scale(
  self : ExplicitMatrix,
  scalar : Expr,
) -> ExplicitMatrix {
  let out : Array[Array[Expr]] = Array::new()
  for row in self.rows {
    let next : Array[Expr] = Array::new()
    for value in row {
      next.push(scalar * value)
    }
    out.push(next)
  }
  { rows: out }
}

///|
pub fn ExplicitMatrix::neg(self : ExplicitMatrix) -> ExplicitMatrix {
  self.scale(int(-1))
}

///|
pub fn ExplicitMatrix::map(
  self : ExplicitMatrix,
  f : (Expr) -> Expr,
) -> ExplicitMatrix {
  let out : Array[Array[Expr]] = Array::new()
  for row in self.rows {
    let next : Array[Expr] = Array::new()
    for value in row {
      next.push(f(value))
    }
    out.push(next)
  }
  { rows: out }
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
    raise ShapeError("matrix shapes differ")
  }
  let out : Array[Array[Expr]] = Array::new()
  for i in 0..<self.height() {
    let row : Array[Expr] = Array::new()
    for j in 0..<self.width() {
      row.push(self.rows[i][j] + other.rows[i][j])
    }
    out.push(row)
  }
  { rows: out }
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
    raise ShapeError("matrix product shape mismatch")
  }
  let out : Array[Array[Expr]] = Array::new()
  for i in 0..<self.height() {
    let row : Array[Expr] = Array::new()
    for j in 0..<other.width() {
      let mut acc = int(0)
      for k in 0..<self.width() {
        acc = acc + self.rows[i][k] * other.rows[k][j]
      }
      row.push(acc)
    }
    out.push(row)
  }
  { rows: out }
}

///|
fn explicit_matrix_cell_string(value : Expr) -> String {
  let txt = @symprint.pretty_string(value)
  if txt == "-1" {
    "-1"
  } else if txt.has_prefix("-1*") {
    "-" + txt[3:].to_owned()
  } else {
    txt
  }
}

///|
pub fn explicit_matrix_rows_string(matrix : ExplicitMatrix) -> String {
  let rows : Array[String] = Array::new()
  for row in matrix.rows {
    let items : Array[String] = Array::new()
    for value in row {
      items.push(explicit_matrix_cell_string(value))
    }
    let joined_items = items.join(", ")
    rows.push("[\{joined_items}]")
  }
  let joined_rows = rows.join(", ")
  "[\{joined_rows}]"
}
