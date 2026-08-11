///|
/// One-dimensional simple-harmonic-oscillator ladder operators and number states.
///
/// This covers the operator/state subset from `sympy.physics.quantum.sho1d`
/// that is most widely reused: `RaisingOp`, `LoweringOp`, `NumberOp`,
/// `Hamiltonian`, and the number-basis states `SHOKet/SHOBra`. The central
/// rules are exact ladder action, Kronecker-delta overlaps, and matrix
/// representations in the number basis.

///|
pub let sho_omega : Expr = Symbol("omega")

///|
pub let sho_mass : Expr = Symbol("m")

///|
pub fn raising_op(label? : Expr = Symbol("a")) -> Expr {
  @symcore.raw_function("RaisingOp", [label])
}

///|
pub fn lowering_op(label? : Expr = Symbol("a")) -> Expr {
  @symcore.raw_function("LoweringOp", [label])
}

///|
pub fn number_op(label? : Expr = Symbol("N")) -> Expr {
  @symcore.raw_function("NumberOp", [label])
}

///|
pub fn sho_hamiltonian(label? : Expr = Symbol("H")) -> Expr {
  @symcore.raw_function("Hamiltonian", [label])
}

///|
pub fn sho_ket(n : Expr) -> Expr {
  @symcore.raw_function("SHOKet", [n])
}

///|
pub fn sho_bra(n : Expr) -> Expr {
  @symcore.raw_function("SHOBra", [n])
}

///|
fn sho_half() -> Expr {
  @symcore.rational_from_ints(1, 2) catch {
    _ => @symcore.function("Rational", [int(1), int(2)])
  }
}

///|
fn sho_xp_prefactor() -> Expr {
  let denom = int(2) * hbar * sho_mass * sho_omega
  @symcore.raw_pow(@symcore.raw_function("sqrt", [denom]), int(-1))
}

///|
pub fn sho_rewrite_as_xp(expr : Expr) -> Expr {
  let xp_scale = sho_xp_prefactor()
  let x_term = sho_mass * sho_omega * x_op()
  let px_term = @symcore.Expr::NumberSymbol(ImaginaryUnit) * px_op()
  let px_sq = @symcore.raw_pow(px_op(), int(2))
  let x_sq = @symcore.raw_pow(sho_mass * sho_omega * x_op(), int(2))
  if quantum_expr_has_name(expr, "RaisingOp") {
    xp_scale * (x_term - px_term)
  } else if quantum_expr_has_name(expr, "LoweringOp") {
    xp_scale * (x_term + px_term)
  } else if quantum_expr_has_name(expr, "NumberOp") {
    (px_sq + x_sq) *
    @symcore.raw_pow(int(2) * sho_mass * hbar * sho_omega, int(-1)) -
    sho_half()
  } else if quantum_expr_has_name(expr, "Hamiltonian") {
    (px_sq + x_sq) * @symcore.raw_pow(int(2) * sho_mass, int(-1))
  } else {
    expr
  }
}

///|
pub fn sho_rewrite_as_a(expr : Expr) -> Expr {
  if quantum_expr_has_name(expr, "NumberOp") {
    @symcore.raw_mul([raising_op(), lowering_op()])
  } else if quantum_expr_has_name(expr, "Hamiltonian") {
    hbar *
    sho_omega *
    (@symcore.raw_mul([raising_op(), lowering_op()]) + sho_half())
  } else {
    expr
  }
}

///|
pub fn sho_rewrite_as_h(expr : Expr) -> Expr {
  if quantum_expr_has_name(expr, "NumberOp") {
    sho_hamiltonian() * @symcore.raw_pow(hbar * sho_omega, int(-1)) - sho_half()
  } else {
    expr
  }
}

///|
pub fn sho_rewrite_as_n(expr : Expr) -> Expr {
  if quantum_expr_has_name(expr, "Hamiltonian") {
    hbar * sho_omega * (number_op() + sho_half())
  } else {
    expr
  }
}

///|
fn sho_is_zero_state(n : Expr) -> Bool {
  n == int(0)
}

///|
pub fn sho_apply_operator_to_ket(op_expr : Expr, ket_expr : Expr) -> Expr? {
  match quantum_expr_args(ket_expr) {
    Some([n]) if quantum_expr_has_name(ket_expr, "SHOKet") =>
      if quantum_expr_has_name(op_expr, "RaisingOp") {
        Some(@symcore.raw_function("sqrt", [n + int(1)]) * sho_ket(n + int(1)))
      } else if quantum_expr_has_name(op_expr, "LoweringOp") {
        if sho_is_zero_state(n) {
          Some(int(0))
        } else {
          Some(@symcore.raw_function("sqrt", [n]) * sho_ket(n - int(1)))
        }
      } else if quantum_expr_has_name(op_expr, "NumberOp") {
        Some(n * ket_expr)
      } else if quantum_expr_has_name(op_expr, "Hamiltonian") {
        let half = sho_half()
        Some(hbar * sho_omega * (n + half) * ket_expr)
      } else {
        None
      }
    _ => None
  }
}

///|
fn sho_n_value(expr : Expr) -> Int? {
  match expr {
    Number(n) if n.is_integral() && n.numerator().to_int() >= 0 =>
      Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn sho_zero_matrix(ndim : Int) -> Array[Array[Expr]] {
  let rows : Array[Array[Expr]] = []
  for _ in 0..<ndim {
    rows.push(Array::make(ndim, int(0)))
  }
  rows
}

///|
fn sho_number_basis_matrix(
  expr : Expr,
  ndim : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  guard ndim > 0 else {
    raise ValueError("ndim must be positive for SHO representations")
  }
  let rows = sho_zero_matrix(ndim)
  match quantum_expr_args(expr) {
    _ if quantum_expr_has_name(expr, "RaisingOp") => {
      for i in 0..<(ndim - 1) {
        rows[i + 1][i] = @symcore.raw_function("sqrt", [int(i + 1)])
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    _ if quantum_expr_has_name(expr, "LoweringOp") => {
      for i in 0..<(ndim - 1) {
        rows[i][i + 1] = @symcore.raw_function("sqrt", [int(i + 1)])
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    _ if quantum_expr_has_name(expr, "NumberOp") => {
      for i in 0..<ndim {
        rows[i][i] = int(i)
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    _ if quantum_expr_has_name(expr, "Hamiltonian") => {
      let half = sho_half()
      for i in 0..<ndim {
        rows[i][i] = hbar * sho_omega * (int(i) + half)
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    Some([n_expr]) if quantum_expr_has_name(expr, "SHOKet") =>
      match sho_n_value(n_expr) {
        Some(n) => {
          guard n < ndim else { raise IndexError("state index exceeds ndim") }
          let out : Array[Array[Expr]] = []
          for i in 0..<ndim {
            out.push([if i == n { int(1) } else { int(0) }])
          }
          @symphysics.explicit_matrix_from_rows(out)
        }
        None =>
          raise ValueError(
            "SHOKet representation needs a concrete nonnegative integer index",
          )
      }
    Some([n_expr]) if quantum_expr_has_name(expr, "SHOBra") =>
      match sho_n_value(n_expr) {
        Some(n) => {
          guard n < ndim else { raise IndexError("state index exceeds ndim") }
          let row = Array::make(ndim, int(0))
          row[n] = int(1)
          @symphysics.explicit_matrix_from_rows([row])
        }
        None =>
          raise ValueError(
            "SHOBra representation needs a concrete nonnegative integer index",
          )
      }
    _ => raise ValueError("unsupported SHO number-basis object")
  }
}

///|
pub fn sho_represent(
  expr : Expr,
  basis? : Expr? = None,
  ndim? : Int = 4,
) -> MatrixScalarValue? raise @symphysics.PhysicsError {
  let is_number_basis = match basis {
    None => true
    Some(basis_expr) => quantum_expr_has_name(basis_expr, "NumberOp")
  }
  if !is_number_basis {
    return None
  }
  if quantum_expr_has_name(expr, "RaisingOp") ||
    quantum_expr_has_name(expr, "LoweringOp") ||
    quantum_expr_has_name(expr, "NumberOp") ||
    quantum_expr_has_name(expr, "Hamiltonian") ||
    quantum_expr_has_name(expr, "SHOKet") ||
    quantum_expr_has_name(expr, "SHOBra") {
    let matrix = sho_number_basis_matrix(expr, ndim)
    Some(Matrix(matrix))
  } else {
    None
  }
}
