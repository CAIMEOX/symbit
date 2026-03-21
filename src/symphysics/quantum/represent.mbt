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
fn represent_gate_simplified(
  expr : Expr,
  basis : Expr?,
  nqubits : Int,
  spin_j : Expr,
  ndim : Int,
) -> MatrixScalarValue? raise @symphysics.PhysicsError {
  let simplified = gate_simp(expr)
  if simplified == expr {
    None
  } else {
    Some(represent(simplified, basis~, nqubits~, spin_j~, ndim~))
  }
}

///|
fn represent_pow_nonnegative(
  value : MatrixScalarValue,
  exp : Int,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  guard exp >= 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "represent only supports nonnegative integer powers for matrix inputs",
    )
  }
  match value {
    MatrixScalarValue::Scalar(expr) =>
      if exp == 0 {
        MatrixScalarValue::Scalar(int(1))
      } else {
        MatrixScalarValue::Scalar(@symcore.raw_pow(expr, int(exp)))
      }
    MatrixScalarValue::Matrix(matrix) => {
      guard matrix.height() == matrix.width() else {
        raise @symphysics.PhysicsError::ShapeError(
          "matrix powers require square matrices",
        )
      }
      if exp == 0 {
        MatrixScalarValue::Matrix(
          @symphysics.explicit_matrix_eye(matrix.height()),
        )
      } else {
        let mut acc = matrix
        for _ in 1..<exp {
          acc = acc.mul(matrix)
        }
        MatrixScalarValue::Matrix(acc)
      }
    }
  }
}

///|
fn default_spin_j() -> Expr {
  @symcore.rational_from_ints(1, 2) catch {
    _ => @symcore.function("Rational", [int(1), int(2)])
  }
}

///|
pub fn represent(
  expr : Expr,
  basis? : Expr? = None,
  nqubits? : Int = 0,
  spin_j? : Expr = default_spin_j(),
  ndim? : Int = 4,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  match expr {
    Expr::Add(args) => {
      guard !args.is_empty() else { return MatrixScalarValue::Scalar(int(0)) }
      let mut acc = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      for idx in 1..<args.length() {
        acc = represent_add(
          acc,
          represent(args[idx], basis~, nqubits~, spin_j~, ndim~),
        )
      }
      acc
    }
    Expr::Mul(args) => {
      if args.any(arg => gate_support(arg) != None) {
        match represent_gate_simplified(expr, basis, nqubits, spin_j, ndim) {
          Some(value) => return value
          None => ()
        }
      }
      guard !args.is_empty() else { return MatrixScalarValue::Scalar(int(1)) }
      let mut acc = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      for idx in 1..<args.length() {
        acc = represent_mul(
          acc,
          represent(args[idx], basis~, nqubits~, spin_j~, ndim~),
        )
      }
      acc
    }
    Expr::Pow(base, exp) =>
      match quantum_integer_value(exp) {
        Some(0) => MatrixScalarValue::Scalar(int(1))
        Some(power) if power > 0 && gate_support(base) != None => {
          let factors : Array[Expr] = []
          for _ in 0..<power {
            factors.push(base)
          }
          represent(
            gate_simp(quantum_mul_from_args_preserve(factors)),
            basis~,
            nqubits~,
            spin_j~,
            ndim~,
          )
        }
        Some(power) if power > 0 =>
          represent_pow_nonnegative(
            represent(base, basis~, nqubits~, spin_j~, ndim~),
            power,
          )
        _ => MatrixScalarValue::Scalar(expr)
      }
    Expr::Function("Dagger", args) if args.length() == 1 => {
      let represented = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      match represented {
        MatrixScalarValue::Scalar(value) =>
          MatrixScalarValue::Scalar(expr_conjugate(value))
        MatrixScalarValue::Matrix(matrix) =>
          MatrixScalarValue::Matrix(matrix_dagger(matrix))
      }
    }
    Expr::Function("Commutator", args) if args.length() == 2 =>
      represent(commutator_doit(expr), basis~, nqubits~, spin_j~, ndim~)
    Expr::Function("AntiCommutator", args) if args.length() == 2 =>
      represent(anticommutator_doit(expr), basis~, nqubits~, spin_j~, ndim~)
    Expr::Function(name, args) if name == "TensorProduct" => {
      guard !args.is_empty() else { return MatrixScalarValue::Scalar(int(1)) }
      let matrices : Array[@symphysics.ExplicitMatrix] = []
      let mut scalar = int(1)
      for arg in args {
        let represented = represent(arg, basis~, nqubits~, spin_j~, ndim~)
        match represented {
          MatrixScalarValue::Scalar(value) => scalar = scalar * value
          MatrixScalarValue::Matrix(matrix) => matrices.push(matrix)
        }
      }
      let matrix = if matrices.is_empty() {
        @symphysics.explicit_matrix_from_rows([[int(1)]])
      } else {
        matrix_tensor_product(matrices)
      }
      if scalar == int(1) {
        MatrixScalarValue::Matrix(matrix)
      } else {
        MatrixScalarValue::Matrix(matrix.scale(scalar))
      }
    }
    Expr::Function(name, args) if name == "OuterProduct" && args.length() == 2 =>
      represent_mul(
        represent(args[0], basis~, nqubits~, spin_j~, ndim~),
        represent(args[1], basis~, nqubits~, spin_j~, ndim~),
      )
    Expr::Function("IdentityOperator", args) =>
      match args {
        [dimension] =>
          match quantum_integer_value(dimension) {
            Some(n) if n >= 0 =>
              MatrixScalarValue::Matrix(@symphysics.explicit_matrix_eye(n))
            _ => MatrixScalarValue::Scalar(expr)
          }
        _ => MatrixScalarValue::Scalar(expr)
      }
    Expr::Function(name, _) if name == "InnerProduct" =>
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
                          match
                            (shor_represent(expr, nqubits) catch { _ => None }) {
                            Some(value) => value
                            None =>
                              match density_from_expr(expr) {
                                Some(d) =>
                                  density_matrix(
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
                                            represent_pauli_state(expr),
                                          )
                                        None =>
                                          match pauli_from_expr(expr) {
                                            Some(_) =>
                                              MatrixScalarValue::Matrix(
                                                represent_pauli_operator(expr),
                                              )
                                            None =>
                                              match
                                                (represent_spin_rotation(
                                                  expr, spin_j,
                                                ) catch {
                                                  _ => None
                                                }) {
                                                Some(matrix) =>
                                                  MatrixScalarValue::Matrix(
                                                    matrix,
                                                  )
                                                None =>
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
                                                        spin_state_from_expr(
                                                          expr,
                                                        ) {
                                                        Some(state) =>
                                                          if state.is_coupled() {
                                                            MatrixScalarValue::Matrix(
                                                              represent_spin_coupled_state(
                                                                expr,
                                                                basis~,
                                                              ),
                                                            )
                                                          } else {
                                                            MatrixScalarValue::Matrix(
                                                              represent_spin_state(
                                                                expr,
                                                                basis~,
                                                              ),
                                                            )
                                                          }
                                                        None =>
                                                          match
                                                            gate_support(expr) {
                                                            Some(_) =>
                                                              MatrixScalarValue::Matrix(
                                                                represent_gate_expr_zbasis(
                                                                  expr, nqubits,
                                                                ),
                                                              )
                                                            None =>
                                                              match expr {
                                                                Expr::Symbol(
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
                                                                      represent_spin_operator(
                                                                        expr,
                                                                        spin_j,
                                                                        basis~,
                                                                      ),
                                                                    )
                                                                  } else {
                                                                    MatrixScalarValue::Scalar(
                                                                      expr,
                                                                    )
                                                                  }
                                                                _ =>
                                                                  try
                                                                    rep_innerproduct(
                                                                      expr,
                                                                      basis~,
                                                                    )
                                                                  catch {
                                                                    _ =>
                                                                      try
                                                                        rep_expectation(
                                                                          expr,
                                                                          basis~,
                                                                        )
                                                                      catch {
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
  expr : Expr,
  basis? : Expr? = None,
  nqubits? : Int = 0,
  spin_j? : Expr = default_spin_j(),
  ndim? : Int = 4,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let represented = represent(expr, basis~, nqubits~, spin_j~, ndim~)
  match represented {
    MatrixScalarValue::Matrix(matrix) => matrix
    MatrixScalarValue::Scalar(value) =>
      @symphysics.explicit_matrix_from_rows([[value]])
  }
}
