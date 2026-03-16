///|
pub enum MatrixExpr {
  Concrete(Matrix)
  Symbol(String, Int, Int)
  Identity(Int)
  Zero(Int, Int)
  Add(Array[MatrixExpr])
  Mul(Array[MatrixExpr])
  BlockDiag(Array[MatrixExpr])
  Block(Array[Array[MatrixExpr]])
  Transpose(MatrixExpr)
  Inverse(MatrixExpr)
  Pow(MatrixExpr, Int)
}

///|
pub fn matrix_symbol(name : String, rows : Int, cols : Int) -> MatrixExpr {
  MatrixExpr::Symbol(name, rows, cols)
}

///|
pub fn matrix_expr(m : Matrix) -> MatrixExpr {
  MatrixExpr::Concrete(m)
}

///|
pub fn identity_expr(n : Int) -> MatrixExpr {
  MatrixExpr::Identity(n)
}

///|
pub fn zero_matrix_expr(rows : Int, cols : Int) -> MatrixExpr {
  MatrixExpr::Zero(rows, cols)
}

///|
pub fn matrix_expr_add(items : Array[MatrixExpr]) -> MatrixExpr {
  MatrixExpr::Add(items)
}

///|
pub fn matrix_expr_mul(items : Array[MatrixExpr]) -> MatrixExpr {
  MatrixExpr::Mul(items)
}

///|
pub fn matrix_expr_block_diag(items : Array[MatrixExpr]) -> MatrixExpr {
  MatrixExpr::BlockDiag(items)
}

///|
pub fn matrix_expr_block(rows : Array[Array[MatrixExpr]]) -> MatrixExpr {
  MatrixExpr::Block(rows)
}

///|
pub fn matrix_expr_transpose(expr : MatrixExpr) -> MatrixExpr {
  MatrixExpr::Transpose(expr)
}

///|
pub fn matrix_expr_inverse(expr : MatrixExpr) -> MatrixExpr {
  MatrixExpr::Inverse(expr)
}

///|
pub fn matrix_expr_pow(expr : MatrixExpr, exp : Int) -> MatrixExpr {
  MatrixExpr::Pow(expr, exp)
}

///|
pub fn MatrixExpr::shape(self : MatrixExpr) -> (Int, Int) raise MatrixError {
  match self {
    MatrixExpr::Concrete(m) => m.shape()
    MatrixExpr::Symbol(_, rows, cols) => (rows, cols)
    MatrixExpr::Identity(n) => (n, n)
    MatrixExpr::Zero(rows, cols) => (rows, cols)
    MatrixExpr::Add(items) => {
      guard !items.is_empty() else {
        raise MatrixError::ShapeError("empty MatrixExpr Add")
      }
      let shape = items[0].shape()
      for item in items[1:] {
        if item.shape() != shape {
          raise MatrixError::ShapeError(
            "matrix expression add expects equal shapes",
          )
        }
      }
      shape
    }
    MatrixExpr::Mul(items) => {
      guard !items.is_empty() else {
        raise MatrixError::ShapeError("empty MatrixExpr Mul")
      }
      let first = items[0].shape()
      let mut last = first
      for item in items[1:] {
        let current = item.shape()
        if last.1 != current.0 {
          raise MatrixError::ShapeError(
            "matrix expression mul expects aligned dimensions",
          )
        }
        last = current
      }
      (first.0, last.1)
    }
    MatrixExpr::BlockDiag(items) => {
      let mut rows = 0
      let mut cols = 0
      for item in items {
        let shape = item.shape()
        rows += shape.0
        cols += shape.1
      }
      (rows, cols)
    }
    MatrixExpr::Block(rows0) => {
      guard !rows0.is_empty() else { return (0, 0) }
      let mut rows = 0
      let col_widths : Array[Int] = []
      let first_width = rows0[0].length()
      for row in rows0 {
        if row.length() != first_width {
          raise MatrixError::ShapeError(
            "block matrix expression expects rectangular block layout",
          )
        }
      }
      for j in 0..<first_width {
        let mut width = 0
        for i in 0..<rows0.length() {
          let shape = rows0[i][j].shape()
          if i == 0 {
            width = shape.1
          } else if width != shape.1 {
            raise MatrixError::ShapeError(
              "blocks in the same column must have equal widths",
            )
          }
        }
        col_widths.push(width)
      }
      for row in rows0 {
        let mut height = 0
        for item in row {
          let shape = item.shape()
          if height == 0 {
            height = shape.0
          } else if height != shape.0 {
            raise MatrixError::ShapeError(
              "blocks in the same row must have equal heights",
            )
          }
        }
        rows += height
      }
      let cols = col_widths.fold(init=0, fn(acc, v) { acc + v })
      (rows, cols)
    }
    MatrixExpr::Transpose(inner) => {
      let shape = inner.shape()
      (shape.1, shape.0)
    }
    MatrixExpr::Inverse(inner) | MatrixExpr::Pow(inner, _) => inner.shape()
  }
}

///|
pub fn MatrixExpr::to_string(self : MatrixExpr) -> String {
  match self {
    MatrixExpr::Concrete(m) => m.to_string()
    MatrixExpr::Symbol(name, _, _) => name
    MatrixExpr::Identity(n) => "Identity(" + n.to_string() + ")"
    MatrixExpr::Zero(rows, cols) =>
      "ZeroMatrix(" + rows.to_string() + ", " + cols.to_string() + ")"
    MatrixExpr::Add(items) =>
      "(" + items.map(fn(item) { item.to_string() }).join(" + ") + ")"
    MatrixExpr::Mul(items) =>
      "(" + items.map(fn(item) { item.to_string() }).join(" * ") + ")"
    MatrixExpr::BlockDiag(items) =>
      "BlockDiag(" + items.map(fn(item) { item.to_string() }).join(", ") + ")"
    MatrixExpr::Block(rows) =>
      "Block(" +
      rows
      .map(fn(row) {
        "[" + row.map(fn(item) { item.to_string() }).join(", ") + "]"
      })
      .join(", ") +
      ")"
    MatrixExpr::Transpose(inner) => inner.to_string() + ".T"
    MatrixExpr::Inverse(inner) => inner.to_string() + "^-1"
    MatrixExpr::Pow(inner, exp) => inner.to_string() + "^" + exp.to_string()
  }
}

///|
pub fn MatrixExpr::eval(
  self : MatrixExpr,
  env : Map[String, Matrix],
) -> Matrix raise MatrixError {
  match self {
    MatrixExpr::Concrete(m) => m
    MatrixExpr::Symbol(name, rows, cols) =>
      match env.get(name) {
        Some(value) => {
          if value.shape() != (rows, cols) {
            raise MatrixError::ShapeError(
              "matrix symbol binding has wrong shape",
            )
          }
          value
        }
        None => raise MatrixError::ValueError("missing matrix symbol binding")
      }
    MatrixExpr::Identity(n) => eye(n)
    MatrixExpr::Zero(rows, cols) => zeros(rows, cols=Some(cols))
    MatrixExpr::Add(items) => {
      guard !items.is_empty() else { return zeros(0, cols=Some(0)) }
      let mut acc = items[0].eval(env)
      for item in items[1:] {
        let next = item.eval(env)
        if acc.shape() != next.shape() {
          raise MatrixError::ShapeError(
            "matrix expression add expects equal shapes",
          )
        }
        acc = acc + next
      }
      acc
    }
    MatrixExpr::Mul(items) => {
      guard !items.is_empty() else { return zeros(0, cols=Some(0)) }
      let mut acc = items[0].eval(env)
      for item in items[1:] {
        let next = item.eval(env)
        if acc.cols != next.rows {
          raise MatrixError::ShapeError(
            "matrix expression mul expects aligned dimensions",
          )
        }
        acc = acc * next
      }
      acc
    }
    MatrixExpr::BlockDiag(items) => {
      let mats : Array[Matrix] = []
      for item in items {
        mats.push(item.eval(env))
      }
      block_diag(mats)
    }
    MatrixExpr::Block(rows) => {
      let mats : Array[Array[Matrix]] = []
      for row in rows {
        let mat_row : Array[Matrix] = []
        for item in row {
          mat_row.push(item.eval(env))
        }
        mats.push(mat_row)
      }
      block_matrix(mats)
    }
    MatrixExpr::Transpose(inner) => inner.eval(env).transpose()
    MatrixExpr::Inverse(inner) => inner.eval(env).inv()
    MatrixExpr::Pow(inner, exp) => {
      let base = inner.eval(env)
      if !base.is_square() {
        raise MatrixError::NonSquareMatrixError(
          "matrix power requires a square matrix",
        )
      }
      if exp == 0 {
        return eye(base.rows)
      }
      if exp < 0 {
        let inv = base.inv()
        let mut out = inv
        for _ in 1..<-exp {
          out = out * inv
        }
        return out
      }
      let mut out = base
      for _ in 1..<exp {
        out = out * base
      }
      out
    }
  }
}
