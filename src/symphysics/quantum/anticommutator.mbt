///|
/// Symbolic anticommutator helpers aligned with the operator-free core of
/// `sympy.physics.quantum.anticommutator`.

///|
fn quantum_anticommutator_raw(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("AntiCommutator", [lhs, rhs])
}

///|
fn quantum_make_anticommutator(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  if lhs == @symcore.int(0) || rhs == @symcore.int(0) {
    return @symcore.int(0)
  }
  if lhs == rhs {
    return @symcore.int(2) * @symcore.raw_pow(lhs, @symcore.int(2))
  }
  if quantum_is_scalar_like(lhs) || quantum_is_scalar_like(rhs) {
    return @symcore.int(2) * lhs * rhs
  }
  let (lhs_scalar, lhs_body) = quantum_split_scalar_factors(lhs)
  let (rhs_scalar, rhs_body) = quantum_split_scalar_factors(rhs)
  match (lhs_body, rhs_body) {
    (Some(nlhs), Some(nrhs)) => {
      if lhs_scalar != @symcore.int(1) || rhs_scalar != @symcore.int(1) {
        return lhs_scalar * rhs_scalar * quantum_make_anticommutator(nlhs, nrhs)
      }
      match (pauli_from_expr(nlhs), pauli_from_expr(nrhs)) {
        (Some(lhs_pauli), Some(rhs_pauli)) if !pauli_name_equal(lhs_pauli.name, rhs_pauli.name) =>
          return @symcore.int(2) * nlhs * nrhs
        (Some(lhs_pauli), Some(rhs_pauli)) =>
          match (lhs_pauli.kind, rhs_pauli.kind) {
            (PauliKind::X, PauliKind::Y) | (PauliKind::Y, PauliKind::X) |
            (PauliKind::X, PauliKind::Z) | (PauliKind::Z, PauliKind::X) |
            (PauliKind::Y, PauliKind::Z) | (PauliKind::Z, PauliKind::Y) |
            (PauliKind::Minus, PauliKind::Z) | (PauliKind::Z, PauliKind::Minus) |
            (PauliKind::Plus, PauliKind::Z) | (PauliKind::Z, PauliKind::Plus) =>
              return @symcore.int(0)
            (PauliKind::Minus, PauliKind::X) | (PauliKind::X, PauliKind::Minus) |
            (PauliKind::Plus, PauliKind::X) | (PauliKind::X, PauliKind::Plus) |
            (PauliKind::Minus, PauliKind::Plus) | (PauliKind::Plus, PauliKind::Minus) =>
              return @symcore.int(1)
            (PauliKind::Minus, PauliKind::Y) | (PauliKind::Y, PauliKind::Minus) =>
              return @symcore.int(-1) * @symcore.symbol("I")
            (PauliKind::Plus, PauliKind::Y) | (PauliKind::Y, PauliKind::Plus) =>
              return @symcore.symbol("I")
            _ => ()
          }
        _ => ()
      }
      match (nlhs, nrhs) {
        (@symcore.Expr::Function("FermionOp", largs), @symcore.Expr::Function("FermionOp", rargs)) => {
          if largs.length() == 2 &&
            rargs.length() == 2 &&
            largs[0] == rargs[0] &&
            largs[1] == @symcore.int(0) &&
            rargs[1] != @symcore.int(0) {
            return @symcore.int(1)
          }
        }
        (@symcore.Expr::Function("FermionOp", _), @symcore.Expr::Function("BosonOp", _)) =>
          return @symcore.int(2) * nlhs * nrhs
        (@symcore.Expr::Function("BosonOp", _), @symcore.Expr::Function("FermionOp", _)) =>
          return @symcore.int(2) * nlhs * nrhs
        _ => ()
      }
      if lhs.compare(rhs) > 0 {
        return quantum_make_anticommutator(rhs, lhs)
      }
      quantum_anticommutator_raw(lhs, rhs)
    }
    _ => @symcore.int(0)
  }
}

///|
pub fn anticommutator(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
  evaluate? : Bool = true,
) -> @symcore.Expr {
  if evaluate {
    quantum_make_anticommutator(lhs, rhs)
  } else {
    quantum_anticommutator_raw(lhs, rhs)
  }
}

///|
pub fn anticommutator_doit(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("AntiCommutator", args) if args.length() == 2 =>
      quantum_add_from_args_preserve([
        quantum_mul_from_args_preserve([args[0], args[1]]),
        quantum_mul_from_args_preserve([args[1], args[0]]),
      ])
    _ => expr
  }
}
