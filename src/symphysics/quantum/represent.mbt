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
    (Scalar(a), Scalar(b)) => Scalar(a + b)
    (Matrix(a), Matrix(b)) => Matrix(a.add(b))
    _ =>
      raise ShapeError("Cannot add scalar and matrix quantum representations")
  }
}

///|
fn represent_mul(
  lhs : MatrixScalarValue,
  rhs : MatrixScalarValue,
) -> MatrixScalarValue raise @symphysics.PhysicsError {
  match (lhs, rhs) {
    (Scalar(a), Scalar(b)) => Scalar(a * b)
    (Scalar(a), Matrix(b)) => Matrix(b.scale(a))
    (Matrix(a), Scalar(b)) => Matrix(a.scale(b))
    (Matrix(a), Matrix(b)) => Matrix(a.mul(b))
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
    raise ValueError(
      "represent only supports nonnegative integer powers for matrix inputs",
    )
  }
  match value {
    Scalar(expr) =>
      if exp == 0 {
        Scalar(int(1))
      } else {
        Scalar(@symcore.raw_pow(expr, int(exp)))
      }
    Matrix(matrix) => {
      guard matrix.height() == matrix.width() else {
        raise ShapeError("matrix powers require square matrices")
      }
      if exp == 0 {
        Matrix(@symphysics.explicit_matrix_eye(matrix.height()))
      } else {
        let mut acc = matrix
        for _ in 1..<exp {
          acc = acc.mul(matrix)
        }
        Matrix(acc)
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
fn quantum_named_args(expr : Expr, name : String, arity : Int) -> Array[Expr]? {
  guard quantum_expr_has_name(expr, name) else { return None }
  match quantum_expr_args(expr) {
    Some(args) if args.length() == arity => Some(args)
    _ => None
  }
}

///|
fn represent_application(
  expr : Expr,
  basis : Expr?,
  nqubits : Int,
  spin_j : Expr,
  ndim : Int,
) -> MatrixScalarValue? raise @symphysics.PhysicsError {
  match quantum_named_args(expr, "Dagger", 1) {
    Some([inner]) => {
      let represented = represent(inner, basis~, nqubits~, spin_j~, ndim~)
      return Some(
        match represented {
          Scalar(value) => Scalar(expr_conjugate(value))
          Matrix(matrix) => Matrix(matrix_dagger(matrix))
        },
      )
    }
    _ => ()
  }
  if quantum_named_args(expr, "Commutator", 2) != None {
    return Some(
      represent(commutator_doit(expr), basis~, nqubits~, spin_j~, ndim~),
    )
  }
  if quantum_named_args(expr, "AntiCommutator", 2) != None {
    return Some(
      represent(anticommutator_doit(expr), basis~, nqubits~, spin_j~, ndim~),
    )
  }
  match quantum_expr_args(expr) {
    Some(args) if quantum_expr_has_name(expr, "TensorProduct") => {
      guard !args.is_empty() else { return Some(Scalar(int(1))) }
      let matrices : Array[@symphysics.ExplicitMatrix] = []
      let mut scalar = int(1)
      for arg in args {
        let represented = represent(arg, basis~, nqubits~, spin_j~, ndim~)
        match represented {
          Scalar(value) => scalar = scalar * value
          Matrix(matrix) => matrices.push(matrix)
        }
      }
      let matrix = if matrices.is_empty() {
        @symphysics.explicit_matrix_from_rows([[int(1)]])
      } else {
        matrix_tensor_product(matrices)
      }
      return Some(
        if scalar == int(1) {
          Matrix(matrix)
        } else {
          Matrix(matrix.scale(scalar))
        },
      )
    }
    _ => ()
  }
  match quantum_named_args(expr, "OuterProduct", 2) {
    Some([lhs, rhs]) =>
      return Some(
        represent_mul(
          represent(lhs, basis~, nqubits~, spin_j~, ndim~),
          represent(rhs, basis~, nqubits~, spin_j~, ndim~),
        ),
      )
    _ => ()
  }
  match quantum_named_args(expr, "IdentityOperator", 1) {
    Some([dimension]) =>
      return Some(
        match quantum_integer_value(dimension) {
          Some(n) if n >= 0 => Matrix(@symphysics.explicit_matrix_eye(n))
          _ => Scalar(expr)
        },
      )
    _ => ()
  }
  if quantum_expr_has_name(expr, "InnerProduct") {
    return Some(Scalar(inner_product_doit(expr)))
  }
  None
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
    Add(args) => {
      guard !args.is_empty() else { return Scalar(int(0)) }
      let mut acc = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      for idx in 1..<args.length() {
        acc = represent_add(
          acc,
          represent(args[idx], basis~, nqubits~, spin_j~, ndim~),
        )
      }
      acc
    }
    Mul(args) => {
      if args.any(arg => gate_support(arg) != None) {
        match represent_gate_simplified(expr, basis, nqubits, spin_j, ndim) {
          Some(value) => return value
          None => ()
        }
      }
      guard !args.is_empty() else { return Scalar(int(1)) }
      let mut acc = represent(args[0], basis~, nqubits~, spin_j~, ndim~)
      for idx in 1..<args.length() {
        acc = represent_mul(
          acc,
          represent(args[idx], basis~, nqubits~, spin_j~, ndim~),
        )
      }
      acc
    }
    Pow(base, exp) =>
      match quantum_integer_value(exp) {
        Some(0) => Scalar(int(1))
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
        _ => Scalar(expr)
      }
    _ =>
      match represent_application(expr, basis, nqubits, spin_j, ndim) {
        Some(value) => value
        None =>
          match cartesian_represent(expr, basis~) {
            Some(value) => Scalar(value)
            None =>
              match piab_represent(expr) {
                Some(value) => Scalar(value)
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
                                (shor_represent(expr, nqubits) catch {
                                  _ => None
                                }) {
                                Some(value) => value
                                None =>
                                  match density_from_expr(expr) {
                                    Some(d) =>
                                      density_matrix(
                                        d, basis, nqubits, spin_j, ndim,
                                      )
                                    None =>
                                      match wavefunction_from_expr(expr) {
                                        Some(wf) => Scalar(wf.as_expr())
                                        None =>
                                          match sigma_z_state_from_expr(expr) {
                                            Some(_) =>
                                              Matrix(
                                                represent_pauli_state(expr),
                                              )
                                            None =>
                                              match pauli_from_expr(expr) {
                                                Some(_) =>
                                                  Matrix(
                                                    represent_pauli_operator(
                                                      expr,
                                                    ),
                                                  )
                                                None =>
                                                  match
                                                    (represent_spin_rotation(
                                                      expr, spin_j,
                                                    ) catch {
                                                      _ => None
                                                    }) {
                                                    Some(matrix) =>
                                                      Matrix(matrix)
                                                    None =>
                                                      match
                                                        qubit_from_expr(expr) {
                                                        Some(_) =>
                                                          Matrix(
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
                                                                Matrix(
                                                                  represent_spin_coupled_state(
                                                                    expr,
                                                                    basis~,
                                                                  ),
                                                                )
                                                              } else {
                                                                Matrix(
                                                                  represent_spin_state(
                                                                    expr,
                                                                    basis~,
                                                                  ),
                                                                )
                                                              }
                                                            None =>
                                                              match
                                                                gate_support(
                                                                  expr,
                                                                ) {
                                                                Some(_) =>
                                                                  Matrix(
                                                                    represent_gate_expr_zbasis(
                                                                      expr, nqubits,
                                                                    ),
                                                                  )
                                                                None =>
                                                                  match expr {
                                                                    Symbol(name) =>
                                                                      if [
                                                                          "Jplus",
                                                                          "Jminus",
                                                                          "Jx", "Jy",
                                                                          "Jz", "J2",
                                                                        ].contains(
                                                                          name,
                                                                        ) {
                                                                        Matrix(
                                                                          represent_spin_operator(
                                                                            expr,
                                                                            spin_j,
                                                                            basis~,
                                                                          ),
                                                                        )
                                                                      } else {
                                                                        Scalar(
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
                                                                              Scalar(
                                                                                expr,
                                                                              )
                                                                          } noraise {
                                                                            value =>
                                                                              Scalar(
                                                                                value,
                                                                              )
                                                                          }
                                                                      } noraise {
                                                                        value =>
                                                                          Scalar(
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
    Matrix(matrix) => matrix
    Scalar(value) => @symphysics.explicit_matrix_from_rows([[value]])
  }
}
