///|
/// Matrix representation for the current explicit-matrix quantum subset.
///
/// This is the first concrete `represent` layer: qubits, bras, gates,
/// tensor products, outer products, daggers, scalar factors, and products of
/// those objects are mapped to `ExplicitMatrix` values or scalar expressions.

///|
fn represent_add(
  lhs : MatrixScalarValue,
  rhs : MatrixScalarValue,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  match (lhs, rhs) {
    (MatrixScalarValue::Scalar(a), MatrixScalarValue::Scalar(b)) =>
      MatrixScalarValue::Scalar(a + b)
    (MatrixScalarValue::Matrix(a), MatrixScalarValue::Matrix(b)) =>
      MatrixScalarValue::Matrix(a.add(b))
    _ =>
      raise @symphysics.PhysicsError::ShapeError(
        "Cannot add scalar and matrix quantum representations",
      )
  }
}

///|
fn represent_mul(
  lhs : MatrixScalarValue,
  rhs : MatrixScalarValue,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  match (lhs, rhs) {
    (MatrixScalarValue::Scalar(a), MatrixScalarValue::Scalar(b)) =>
      MatrixScalarValue::Scalar(a * b)
    (MatrixScalarValue::Scalar(a), MatrixScalarValue::Matrix(b)) =>
      MatrixScalarValue::Matrix(b.scale(a))
    (MatrixScalarValue::Matrix(a), MatrixScalarValue::Scalar(b)) =>
      MatrixScalarValue::Matrix(a.scale(b))
    (MatrixScalarValue::Matrix(a), MatrixScalarValue::Matrix(b)) =>
      MatrixScalarValue::Matrix(a.mul(b))
  }
}

///|
fn default_spin_j() -> @symcore.Expr {
  try! @symcore.rational_from_ints(1, 2)
}

///|
pub fn represent(
  expr : @symcore.Expr,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = default_spin_j(),
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  match expr {
    @symcore.Expr::Add(args) => {
      guard !args.is_empty() else { return MatrixScalarValue::Scalar(@symcore.int(0)) }
      let mut acc = represent(args[0], nqubits=nqubits, spin_j=spin_j)
      for idx in 1..<args.length() {
        acc = represent_add(acc, represent(args[idx], nqubits=nqubits, spin_j=spin_j))
      }
      acc
    }
    @symcore.Expr::Mul(args) => {
      guard !args.is_empty() else { return MatrixScalarValue::Scalar(@symcore.int(1)) }
      let mut acc = represent(args[0], nqubits=nqubits, spin_j=spin_j)
      for idx in 1..<args.length() {
        acc = represent_mul(acc, represent(args[idx], nqubits=nqubits, spin_j=spin_j))
      }
      acc
    }
    @symcore.Expr::Function("Dagger", args) if args.length() == 1 => {
      let represented = represent(args[0], nqubits=nqubits, spin_j=spin_j)
      match represented {
        MatrixScalarValue::Scalar(value) => MatrixScalarValue::Scalar(expr_conjugate(value))
        MatrixScalarValue::Matrix(matrix) => MatrixScalarValue::Matrix(matrix_dagger(matrix))
      }
    }
    @symcore.Expr::Function(name, args) if name == "TensorProduct" => {
      guard !args.is_empty() else {
        return MatrixScalarValue::Scalar(@symcore.int(1))
      }
      let matrices : Array[@symphysics.ExplicitMatrix] = []
      let mut scalar = @symcore.int(1)
      for arg in args {
        let represented = represent(arg, nqubits=nqubits, spin_j=spin_j)
        match represented {
          MatrixScalarValue::Scalar(value) => scalar = scalar * value
          MatrixScalarValue::Matrix(matrix) => matrices.push(matrix)
        }
      }
      let matrix = if matrices.is_empty() {
        @symphysics.explicit_matrix_from_rows([[@symcore.int(1)]])
      } else {
        matrix_tensor_product(matrices)
      }
      if scalar == @symcore.int(1) {
        MatrixScalarValue::Matrix(matrix)
      } else {
        MatrixScalarValue::Matrix(matrix.scale(scalar))
      }
    }
    @symcore.Expr::Function(name, args) if name == "OuterProduct" && args.length() == 2 =>
      represent_mul(
        represent(args[0], nqubits=nqubits, spin_j=spin_j),
        represent(args[1], nqubits=nqubits, spin_j=spin_j),
      )
    @symcore.Expr::Function(name, _) if name == "InnerProduct" =>
      MatrixScalarValue::Scalar(inner_product_doit(expr))
    _ =>
      match wavefunction_from_expr(expr) {
        Some(wf) => MatrixScalarValue::Scalar(wf.as_expr())
        None =>
          match qubit_from_expr(expr) {
            Some(_) => MatrixScalarValue::Matrix(qubit_to_matrix(expr, nqubits=nqubits))
            None =>
              match jz_state_from_expr(expr) {
                Some(_) => MatrixScalarValue::Matrix(try! represent_spin_jz_state(expr))
                None =>
                  match gate_support(expr) {
                    Some(_) => MatrixScalarValue::Matrix(try! represent_gate_expr_zbasis(expr, nqubits))
                    None =>
                      match expr {
                        @symcore.Expr::Symbol(name) =>
                          if ["Jplus", "Jminus", "Jx", "Jy", "Jz", "J2"].contains(name) {
                            MatrixScalarValue::Matrix(try! represent_spin_jz_operator(expr, spin_j))
                          } else {
                            MatrixScalarValue::Scalar(expr)
                          }
                        _ => MatrixScalarValue::Scalar(expr)
                      }
                  }
              }
          }
      }
  }
}

///|
pub fn represent_matrix(
  expr : @symcore.Expr,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = default_spin_j(),
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let represented = represent(expr, nqubits=nqubits, spin_j=spin_j)
  match represented {
    MatrixScalarValue::Matrix(matrix) => matrix
    MatrixScalarValue::Scalar(value) => @symphysics.explicit_matrix_from_rows([[value]])
  }
}
