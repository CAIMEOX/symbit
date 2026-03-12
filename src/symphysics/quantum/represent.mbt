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
  basis? : @symcore.Expr? = None,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = default_spin_j(),
  ndim? : Int = 4,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  match expr {
    @symcore.Expr::Add(args) => {
      guard !args.is_empty() else {
        return MatrixScalarValue::Scalar(@symcore.int(0))
      }
      let mut acc = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      for idx in 1..<args.length() {
        acc = represent_add(
          acc,
          represent(args[idx], basis~, nqubits~, spin_j~, ndim~),
        )
      }
      acc
    }
    @symcore.Expr::Mul(args) => {
      guard !args.is_empty() else {
        return MatrixScalarValue::Scalar(@symcore.int(1))
      }
      let mut acc = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      for idx in 1..<args.length() {
        acc = represent_mul(
          acc,
          represent(args[idx], basis~, nqubits~, spin_j~, ndim~),
        )
      }
      acc
    }
    @symcore.Expr::Function("Dagger", args) if args.length() == 1 => {
      let represented = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      match represented {
        MatrixScalarValue::Scalar(value) =>
          MatrixScalarValue::Scalar(expr_conjugate(value))
        MatrixScalarValue::Matrix(matrix) =>
          MatrixScalarValue::Matrix(matrix_dagger(matrix))
      }
    }
    @symcore.Expr::Function(name, args) if name == "TensorProduct" => {
      guard !args.is_empty() else {
        return MatrixScalarValue::Scalar(@symcore.int(1))
      }
      let matrices : Array[@symphysics.ExplicitMatrix] = []
      let mut scalar = @symcore.int(1)
      for arg in args {
        let represented = represent(arg, basis~, nqubits~, spin_j~, ndim~)
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
    @symcore.Expr::Function(name, args) if name == "OuterProduct" &&
      args.length() == 2 =>
      represent_mul(
        represent(args[0], basis~, nqubits~, spin_j~, ndim~),
        represent(args[1], basis~, nqubits~, spin_j~, ndim~),
      )
    @symcore.Expr::Function("IdentityOperator", args) =>
      match args {
        [dimension] =>
          match quantum_integer_value(dimension) {
            Some(n) if n >= 0 =>
              MatrixScalarValue::Matrix(@symphysics.explicit_matrix_eye(n))
            _ => MatrixScalarValue::Scalar(expr)
          }
        _ => MatrixScalarValue::Scalar(expr)
      }
    @symcore.Expr::Function(name, _) if name == "InnerProduct" =>
      MatrixScalarValue::Scalar(inner_product_doit(expr))
    _ =>
      match cartesian_represent(expr, basis~) {
        Some(value) => MatrixScalarValue::Scalar(value)
        None =>
          match piab_represent(expr) {
            Some(value) => MatrixScalarValue::Scalar(value)
            None =>
              match sho_represent(expr, basis~, ndim~) {
                Some(value) => value
                None =>
                  match grover_represent(expr, nqubits) {
                    Some(value) => value
                    None =>
                      match qft_represent(expr, nqubits) {
                        Some(value) => value
                        None =>
                          match (try? shor_represent(expr, nqubits)) {
                            Ok(Some(value)) => value
                            _ =>
                              match density_from_expr(expr) {
                                Some(d) =>
                                  try! density_matrix(
                                    d, basis, nqubits, spin_j, ndim,
                                  )
                                None =>
                                  match wavefunction_from_expr(expr) {
                                    Some(wf) =>
                                      MatrixScalarValue::Scalar(wf.as_expr())
                                    None =>
                                      match sigma_z_state_from_expr(expr) {
                                        Some(_) =>
                                          MatrixScalarValue::Matrix(
                                            try! represent_pauli_state(expr),
                                          )
                                        None =>
                                          match pauli_from_expr(expr) {
                                            Some(_) =>
                                              MatrixScalarValue::Matrix(
                                                try! represent_pauli_operator(
                                                  expr,
                                                ),
                                              )
                                            None =>
                                              match
                                                (try? represent_spin_rotation(
                                                  expr, spin_j,
                                                )) {
                                                Ok(Some(matrix)) =>
                                                  MatrixScalarValue::Matrix(
                                                    matrix,
                                                  )
                                                _ =>
                                                  match qubit_from_expr(expr) {
                                                    Some(_) =>
                                                      MatrixScalarValue::Matrix(
                                                        qubit_to_matrix(
                                                          expr,
                                                          nqubits~,
                                                        ),
                                                      )
                                                    None =>
                                                      match
                                                        jz_state_from_expr(expr) {
                                                        Some(_) =>
                                                          MatrixScalarValue::Matrix(
                                                            try! represent_spin_jz_state(
                                                              expr,
                                                            ),
                                                          )
                                                        None =>
                                                          match
                                                            gate_support(expr) {
                                                            Some(_) =>
                                                              MatrixScalarValue::Matrix(
                                                                try! represent_gate_expr_zbasis(
                                                                  expr, nqubits,
                                                                ),
                                                              )
                                                            None =>
                                                              match expr {
                                                                @symcore.Expr::Symbol(
                                                                  name
                                                                ) =>
                                                                if [
                                                                      "Jplus", "Jminus",
                                                                      "Jx", "Jy",
                                                                      "Jz", "J2",
                                                                    ].contains(
                                                                      name,
                                                                    ) {
                                                                    MatrixScalarValue::Matrix(
                                                                      try! represent_spin_jz_operator(
                                                                        expr, spin_j,
                                                                      ),
                                                                    )
                                                                  } else {
                                                                    MatrixScalarValue::Scalar(
                                                                      expr,
                                                                    )
                                                                  }
                                                                _ =>
                                                                  try rep_innerproduct(
                                                                    expr,
                                                                    basis~,
                                                                  ) catch {
                                                                    _ =>
                                                                      try rep_expectation(
                                                                        expr,
                                                                        basis~,
                                                                      ) catch {
                                                                        _ =>
                                                                          MatrixScalarValue::Scalar(
                                                                            expr,
                                                                          )
                                                                      } noraise {
                                                                        value =>
                                                                          MatrixScalarValue::Scalar(
                                                                            value,
                                                                          )
                                                                      }
                                                                  } noraise {
                                                                    value =>
                                                                      MatrixScalarValue::Scalar(
                                                                        value,
                                                                      )
                                                                  }
                                                              }
                                                          }
                                                      }
                                                  }
                                              }
                                          }
                                      }
                                  }
                              }
                          }
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
  basis? : @symcore.Expr? = None,
  nqubits? : Int = 0,
  spin_j? : @symcore.Expr = default_spin_j(),
  ndim? : Int = 4,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let represented = represent(expr, basis~, nqubits~, spin_j~, ndim~)
  match represented {
    MatrixScalarValue::Matrix(matrix) => matrix
    MatrixScalarValue::Scalar(value) =>
      @symphysics.explicit_matrix_from_rows([[value]])
  }
}
