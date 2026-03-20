///|
/// Matrix helpers aligned with the matrix-only surface of
/// `sympy.physics.quantum.matrixutils`.

///|
pub enum MatrixScalarValue {
  Matrix(@symphysics.ExplicitMatrix)
  Scalar(Expr)
} derive(Eq)

///|
pub fn matrix_eye(n : Int) -> @symphysics.ExplicitMatrix {
  @symphysics.explicit_matrix_eye(n)
}

///|
pub fn matrix_zeros(rows : Int, cols : Int) -> @symphysics.ExplicitMatrix {
  @symphysics.explicit_matrix_zeros(rows, cols)
}

///|
pub fn matrix_flat_strings(
  matrix : @symphysics.ExplicitMatrix,
) -> Array[String] raise @symphysics.PhysicsError {
  let out : Array[String] = Array::new()
  for i in 0..<matrix.height() {
    for j in 0..<matrix.width() {
      out.push(@symprint.to_string(matrix.get(i, j)))
    }
  }
  out
}

///|
fn is_zero_matrix(
  matrix : @symphysics.ExplicitMatrix,
) -> Bool raise @symphysics.PhysicsError {
  for i in 0..<matrix.height() {
    for j in 0..<matrix.width() {
      if matrix.get(i, j) != int(0) {
        return false
      }
    }
  }
  true
}

///|
pub fn flatten_scalar(
  matrix : @symphysics.ExplicitMatrix,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  if matrix.height() == 1 && matrix.width() == 1 {
    MatrixScalarValue::Scalar(matrix.get(0, 0))
  } else {
    MatrixScalarValue::Matrix(matrix)
  }
}

///|
pub fn matrix_to_zero(
  matrix : @symphysics.ExplicitMatrix,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  if is_zero_matrix(matrix) {
    MatrixScalarValue::Scalar(int(0))
  } else {
    MatrixScalarValue::Matrix(matrix)
  }
}

///|
fn kronecker_pair(
  lhs : @symphysics.ExplicitMatrix,
  rhs : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let out_rows = lhs.height() * rhs.height()
  let out_cols = lhs.width() * rhs.width()
  let rows : Array[Array[Expr]] = Array::new()
  for _ in 0..<out_rows {
    rows.push(Array::make(out_cols, int(0)))
  }
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      let coeff = lhs.get(i, j)
      for k in 0..<rhs.height() {
        for l in 0..<rhs.width() {
          rows[i * rhs.height() + k][j * rhs.width() + l] = coeff *
            rhs.get(k, l)
        }
      }
    }
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn matrix_tensor_product(
  product : Array[@symphysics.ExplicitMatrix],
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  guard !product.is_empty() else {
    raise @symphysics.PhysicsError::ValueError(
      "matrix_tensor_product expects at least one matrix",
    )
  }
  let mut acc = product[0]
  for idx in 1..<product.length() {
    acc = kronecker_pair(acc, product[idx])
  }
  acc
}

///|
pub fn matrix_scalar_value_to_string(value : MatrixScalarValue) -> String {
  match value {
    MatrixScalarValue::Matrix(matrix) =>
      @symphysics.explicit_matrix_rows_string(matrix)
    MatrixScalarValue::Scalar(expr) => @symprint.to_string(expr)
  }
}
