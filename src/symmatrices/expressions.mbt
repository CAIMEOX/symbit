///|
pub enum MatrixExpr {
  Concrete(Matrix)
  Symbol(String, Int, Int)
  Add(Array[MatrixExpr])
  Mul(Array[MatrixExpr])
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
pub fn matrix_expr_add(items : Array[MatrixExpr]) -> MatrixExpr {
  MatrixExpr::Add(items)
}

///|
pub fn matrix_expr_mul(items : Array[MatrixExpr]) -> MatrixExpr {
  MatrixExpr::Mul(items)
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
    MatrixExpr::Add(items) => {
      guard !items.is_empty() else {
        raise MatrixError::ShapeError("empty MatrixExpr Add")
      }
      items[0].shape()
    }
    MatrixExpr::Mul(items) => {
      guard !items.is_empty() else {
        raise MatrixError::ShapeError("empty MatrixExpr Mul")
      }
      let lhs = items[0].shape()
      let rhs = items[items.length() - 1].shape()
      (lhs.0, rhs.1)
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
    MatrixExpr::Add(items) =>
      "(" + items.map(fn(item) { item.to_string() }).join(" + ") + ")"
    MatrixExpr::Mul(items) =>
      "(" + items.map(fn(item) { item.to_string() }).join(" * ") + ")"
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
