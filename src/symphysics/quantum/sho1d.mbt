///|
/// One-dimensional simple-harmonic-oscillator ladder operators and number states.
///
/// This covers the operator/state subset from `sympy.physics.quantum.sho1d`
/// that is most widely reused: `RaisingOp`, `LoweringOp`, `NumberOp`,
/// `Hamiltonian`, and the number-basis states `SHOKet/SHOBra`. The central
/// rules are exact ladder action, Kronecker-delta overlaps, and matrix
/// representations in the number basis.

///|
pub let sho_omega : Expr = Expr::Symbol("omega")

///|
pub let sho_mass : Expr = Expr::Symbol("m")

///|
pub fn raising_op(label? : Expr = Expr::Symbol("a")) -> Expr {
  @symcore.raw_function("RaisingOp", [label])
}

///|
pub fn lowering_op(label? : Expr = Expr::Symbol("a")) -> Expr {
  @symcore.raw_function("LoweringOp", [label])
}

///|
pub fn number_op(label? : Expr = Expr::Symbol("N")) -> Expr {
  @symcore.raw_function("NumberOp", [label])
}

///|
pub fn sho_hamiltonian(label? : Expr = Expr::Symbol("H")) -> Expr {
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
  let px_term = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit) * px_op()
  let px_sq = @symcore.raw_pow(px_op(), int(2))
  let x_sq = @symcore.raw_pow(sho_mass * sho_omega * x_op(), int(2))
  match expr {
    Expr::Function("RaisingOp", _) => xp_scale * (x_term - px_term)
    Expr::Function("LoweringOp", _) => xp_scale * (x_term + px_term)
    Expr::Function("NumberOp", _) =>
      (px_sq + x_sq) *
      @symcore.raw_pow(int(2) * sho_mass * hbar * sho_omega, int(-1)) -
      sho_half()
    Expr::Function("Hamiltonian", _) =>
      (px_sq + x_sq) * @symcore.raw_pow(int(2) * sho_mass, int(-1))
    _ => expr
  }
}

///|
pub fn sho_rewrite_as_a(expr : Expr) -> Expr {
  match expr {
    Expr::Function("NumberOp", _) =>
      @symcore.raw_mul([raising_op(), lowering_op()])
    Expr::Function("Hamiltonian", _) =>
      hbar *
      sho_omega *
      (@symcore.raw_mul([raising_op(), lowering_op()]) + sho_half())
    _ => expr
  }
}

///|
pub fn sho_rewrite_as_h(expr : Expr) -> Expr {
  match expr {
    Expr::Function("NumberOp", _) =>
      sho_hamiltonian() * @symcore.raw_pow(hbar * sho_omega, int(-1)) -
      sho_half()
    _ => expr
  }
}

///|
pub fn sho_rewrite_as_n(expr : Expr) -> Expr {
  match expr {
    Expr::Function("Hamiltonian", _) =>
      hbar * sho_omega * (number_op() + sho_half())
    _ => expr
  }
}

///|
fn sho_is_zero_state(n : Expr) -> Bool {
  n == int(0)
}

///|
pub fn sho_apply_operator_to_ket(op_expr : Expr, ket_expr : Expr) -> Expr? {
  match (op_expr, ket_expr) {
    (Expr::Function("RaisingOp", _), Expr::Function("SHOKet", args)) if args.length() ==
      1 => {
      let n = args[0]
      Some(@symcore.raw_function("sqrt", [n + int(1)]) * sho_ket(n + int(1)))
    }
    (Expr::Function("LoweringOp", _), Expr::Function("SHOKet", args)) if args.length() ==
      1 => {
      let n = args[0]
      if sho_is_zero_state(n) {
        Some(int(0))
      } else {
        Some(@symcore.raw_function("sqrt", [n]) * sho_ket(n - int(1)))
      }
    }
    (Expr::Function("NumberOp", _), Expr::Function("SHOKet", args)) if args.length() ==
      1 => {
      let n = args[0]
      Some(n * ket_expr)
    }
    (Expr::Function("Hamiltonian", _), Expr::Function("SHOKet", args)) if args.length() ==
      1 => {
      let n = args[0]
      let half = sho_half()
      Some(hbar * sho_omega * (n + half) * ket_expr)
    }
    _ => None
  }
}

///|
fn sho_n_value(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) if n.is_integral() && n.numerator().to_int() >= 0 =>
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
    raise @symphysics.PhysicsError::ValueError(
      "ndim must be positive for SHO representations",
    )
  }
  let rows = sho_zero_matrix(ndim)
  match expr {
    Expr::Function("RaisingOp", _) => {
      for i in 0..<(ndim - 1) {
        rows[i + 1][i] = @symcore.raw_function("sqrt", [int(i + 1)])
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    Expr::Function("LoweringOp", _) => {
      for i in 0..<(ndim - 1) {
        rows[i][i + 1] = @symcore.raw_function("sqrt", [int(i + 1)])
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    Expr::Function("NumberOp", _) => {
      for i in 0..<ndim {
        rows[i][i] = int(i)
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    Expr::Function("Hamiltonian", _) => {
      let half = sho_half()
      for i in 0..<ndim {
        rows[i][i] = hbar * sho_omega * (int(i) + half)
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    Expr::Function("SHOKet", args) if args.length() == 1 =>
      match sho_n_value(args[0]) {
        Some(n) => {
          guard n < ndim else {
            raise @symphysics.PhysicsError::IndexError(
              "state index exceeds ndim",
            )
          }
          let out : Array[Array[Expr]] = []
          for i in 0..<ndim {
            out.push([if i == n { int(1) } else { int(0) }])
          }
          @symphysics.explicit_matrix_from_rows(out)
        }
        None =>
          raise @symphysics.PhysicsError::ValueError(
            "SHOKet representation needs a concrete nonnegative integer index",
          )
      }
    Expr::Function("SHOBra", args) if args.length() == 1 =>
      match sho_n_value(args[0]) {
        Some(n) => {
          guard n < ndim else {
            raise @symphysics.PhysicsError::IndexError(
              "state index exceeds ndim",
            )
          }
          let row = Array::make(ndim, int(0))
          row[n] = int(1)
          @symphysics.explicit_matrix_from_rows([row])
        }
        None =>
          raise @symphysics.PhysicsError::ValueError(
            "SHOBra representation needs a concrete nonnegative integer index",
          )
      }
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "unsupported SHO number-basis object",
      )
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
    Some(basis_expr) =>
      match basis_expr {
        Expr::Function("NumberOp", _) => true
        _ => false
      }
  }
  if !is_number_basis {
    return None
  }
  match expr {
    Expr::Function(name, _) if name == "RaisingOp" ||
      name == "LoweringOp" ||
      name == "NumberOp" ||
      name == "Hamiltonian" ||
      name == "SHOKet" ||
      name == "SHOBra" => {
      let matrix = sho_number_basis_matrix(expr, ndim)
      Some(MatrixScalarValue::Matrix(matrix))
    }
    _ => None
  }
}
