///|
/// One-dimensional simple-harmonic-oscillator ladder operators and number states.
///
/// This covers the operator/state subset from `sympy.physics.quantum.sho1d`
/// that is most widely reused: `RaisingOp`, `LoweringOp`, `NumberOp`,
/// `Hamiltonian`, and the number-basis states `SHOKet/SHOBra`. The central
/// rules are exact ladder action, Kronecker-delta overlaps, and matrix
/// representations in the number basis.

///|
pub let sho_omega : @symcore.Expr = @symcore.symbol("omega")

///|
pub let sho_mass : @symcore.Expr = @symcore.symbol("m")

///|
pub fn raising_op(
  label? : @symcore.Expr = @symcore.symbol("a"),
) -> @symcore.Expr {
  @symcore.raw_function("RaisingOp", [label])
}

///|
pub fn lowering_op(
  label? : @symcore.Expr = @symcore.symbol("a"),
) -> @symcore.Expr {
  @symcore.raw_function("LoweringOp", [label])
}

///|
pub fn number_op(
  label? : @symcore.Expr = @symcore.symbol("N"),
) -> @symcore.Expr {
  @symcore.raw_function("NumberOp", [label])
}

///|
pub fn sho_hamiltonian(
  label? : @symcore.Expr = @symcore.symbol("H"),
) -> @symcore.Expr {
  @symcore.raw_function("Hamiltonian", [label])
}

///|
pub fn sho_ket(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("SHOKet", [n])
}

///|
pub fn sho_bra(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("SHOBra", [n])
}

///|
fn sho_half() -> @symcore.Expr {
  try! @symcore.rational_from_ints(1, 2)
}

///|
fn sho_xp_prefactor() -> @symcore.Expr {
  let denom = @symcore.int(2) * hbar * sho_mass * sho_omega
  @symcore.raw_pow(@symcore.raw_function("sqrt", [denom]), @symcore.int(-1))
}

///|
pub fn sho_rewrite_as_xp(expr : @symcore.Expr) -> @symcore.Expr {
  let xp_scale = sho_xp_prefactor()
  let x_term = sho_mass * sho_omega * x_op()
  let px_term = @symcore.symbol("I") * px_op()
  let px_sq = @symcore.raw_pow(px_op(), @symcore.int(2))
  let x_sq = @symcore.raw_pow(sho_mass * sho_omega * x_op(), @symcore.int(2))
  match expr {
    @symcore.Expr::Function("RaisingOp", _) => xp_scale * (x_term - px_term)
    @symcore.Expr::Function("LoweringOp", _) => xp_scale * (x_term + px_term)
    @symcore.Expr::Function("NumberOp", _) =>
      (px_sq + x_sq) *
      @symcore.raw_pow(
        @symcore.int(2) * sho_mass * hbar * sho_omega,
        @symcore.int(-1),
      ) -
      sho_half()
    @symcore.Expr::Function("Hamiltonian", _) =>
      (px_sq + x_sq) *
      @symcore.raw_pow(@symcore.int(2) * sho_mass, @symcore.int(-1))
    _ => expr
  }
}

///|
pub fn sho_rewrite_as_a(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("NumberOp", _) =>
      @symcore.raw_mul([raising_op(), lowering_op()])
    @symcore.Expr::Function("Hamiltonian", _) =>
      hbar *
      sho_omega *
      (@symcore.raw_mul([raising_op(), lowering_op()]) + sho_half())
    _ => expr
  }
}

///|
pub fn sho_rewrite_as_h(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("NumberOp", _) =>
      sho_hamiltonian() * @symcore.raw_pow(hbar * sho_omega, @symcore.int(-1)) -
      sho_half()
    _ => expr
  }
}

///|
pub fn sho_rewrite_as_n(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("Hamiltonian", _) =>
      hbar * sho_omega * (number_op() + sho_half())
    _ => expr
  }
}

///|
fn sho_is_zero_state(n : @symcore.Expr) -> Bool {
  n == @symcore.int(0)
}

///|
pub fn sho_apply_operator_to_ket(
  op_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (op_expr, ket_expr) {
    (
      @symcore.Expr::Function("RaisingOp", _),
      @symcore.Expr::Function("SHOKet", args),
    ) if args.length() == 1 => {
      let n = args[0]
      Some(
        @symcore.raw_function("sqrt", [n + @symcore.int(1)]) *
        sho_ket(n + @symcore.int(1)),
      )
    }
    (
      @symcore.Expr::Function("LoweringOp", _),
      @symcore.Expr::Function("SHOKet", args),
    ) if args.length() == 1 => {
      let n = args[0]
      if sho_is_zero_state(n) {
        Some(@symcore.int(0))
      } else {
        Some(@symcore.raw_function("sqrt", [n]) * sho_ket(n - @symcore.int(1)))
      }
    }
    (
      @symcore.Expr::Function("NumberOp", _),
      @symcore.Expr::Function("SHOKet", args),
    ) if args.length() == 1 => {
      let n = args[0]
      Some(n * ket_expr)
    }
    (
      @symcore.Expr::Function("Hamiltonian", _),
      @symcore.Expr::Function("SHOKet", args),
    ) if args.length() == 1 => {
      let n = args[0]
      let half = try! @symcore.rational_from_ints(1, 2)
      Some(hbar * sho_omega * (n + half) * ket_expr)
    }
    _ => None
  }
}

///|
fn sho_n_value(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() && n.numerator().to_int() >= 0 =>
      Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn sho_zero_matrix(ndim : Int) -> Array[Array[@symcore.Expr]] {
  let rows : Array[Array[@symcore.Expr]] = []
  for _ in 0..<ndim {
    rows.push(Array::make(ndim, @symcore.int(0)))
  }
  rows
}

///|
fn sho_number_basis_matrix(
  expr : @symcore.Expr,
  ndim : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  guard ndim > 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "ndim must be positive for SHO representations",
    )
  }
  let rows = sho_zero_matrix(ndim)
  match expr {
    @symcore.Expr::Function("RaisingOp", _) => {
      for i in 0..<(ndim - 1) {
        rows[i + 1][i] = @symcore.raw_function("sqrt", [@symcore.int(i + 1)])
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    @symcore.Expr::Function("LoweringOp", _) => {
      for i in 0..<(ndim - 1) {
        rows[i][i + 1] = @symcore.raw_function("sqrt", [@symcore.int(i + 1)])
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    @symcore.Expr::Function("NumberOp", _) => {
      for i in 0..<ndim {
        rows[i][i] = @symcore.int(i)
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    @symcore.Expr::Function("Hamiltonian", _) => {
      let half = try! @symcore.rational_from_ints(1, 2)
      for i in 0..<ndim {
        rows[i][i] = hbar * sho_omega * (@symcore.int(i) + half)
      }
      @symphysics.explicit_matrix_from_rows(rows)
    }
    @symcore.Expr::Function("SHOKet", args) if args.length() == 1 =>
      match sho_n_value(args[0]) {
        Some(n) => {
          guard n < ndim else {
            raise @symphysics.PhysicsError::IndexError(
              "state index exceeds ndim",
            )
          }
          let out : Array[Array[@symcore.Expr]] = []
          for i in 0..<ndim {
            out.push([if i == n { @symcore.int(1) } else { @symcore.int(0) }])
          }
          @symphysics.explicit_matrix_from_rows(out)
        }
        None =>
          raise @symphysics.PhysicsError::ValueError(
            "SHOKet representation needs a concrete nonnegative integer index",
          )
      }
    @symcore.Expr::Function("SHOBra", args) if args.length() == 1 =>
      match sho_n_value(args[0]) {
        Some(n) => {
          guard n < ndim else {
            raise @symphysics.PhysicsError::IndexError(
              "state index exceeds ndim",
            )
          }
          let row = Array::make(ndim, @symcore.int(0))
          row[n] = @symcore.int(1)
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
  expr : @symcore.Expr,
  basis? : @symcore.Expr? = None,
  ndim? : Int = 4,
) -> MatrixScalarValue? raise @symphysics.PhysicsError {
  let is_number_basis = match basis {
    None => true
    Some(basis_expr) =>
      match basis_expr {
        @symcore.Expr::Function("NumberOp", _) => true
        _ => false
      }
  }
  if !is_number_basis {
    return None
  }
  match expr {
    @symcore.Expr::Function(name, _) if name == "RaisingOp" ||
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
