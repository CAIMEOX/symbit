///|
/// Symbolic anticommutator helpers aligned with the operator-free core of
/// `sympy.physics.quantum.anticommutator`.

///|
fn quantum_anticommutator_raw(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.raw_function("AntiCommutator", [lhs, rhs])
}

///|
fn quantum_make_anticommutator(lhs : Expr, rhs : Expr) -> Expr {
  if lhs == int(0) || rhs == int(0) {
    return int(0)
  }
  if lhs == rhs {
    return int(2) * @symcore.raw_pow(lhs, int(2))
  }
  if quantum_is_scalar_like(lhs) || quantum_is_scalar_like(rhs) {
    return int(2) * lhs * rhs
  }
  let (lhs_scalar, lhs_body) = quantum_split_scalar_factors(lhs)
  let (rhs_scalar, rhs_body) = quantum_split_scalar_factors(rhs)
  match (lhs_body, rhs_body) {
    (Some(nlhs), Some(nrhs)) => {
      if lhs_scalar != int(1) || rhs_scalar != int(1) {
        return lhs_scalar * rhs_scalar * quantum_make_anticommutator(nlhs, nrhs)
      }
      match (pauli_from_expr(nlhs), pauli_from_expr(nrhs)) {
        (Some(lhs_pauli), Some(rhs_pauli)) if !pauli_name_equal(
            lhs_pauli.name,
            rhs_pauli.name,
          ) => return int(2) * nlhs * nrhs
        (Some(lhs_pauli), Some(rhs_pauli)) =>
          match (lhs_pauli.kind, rhs_pauli.kind) {
            (PauliKind::X, PauliKind::Y)
            | (PauliKind::Y, PauliKind::X)
            | (PauliKind::X, PauliKind::Z)
            | (PauliKind::Z, PauliKind::X)
            | (PauliKind::Y, PauliKind::Z)
            | (PauliKind::Z, PauliKind::Y)
            | (PauliKind::Minus, PauliKind::Z)
            | (PauliKind::Z, PauliKind::Minus)
            | (PauliKind::Plus, PauliKind::Z)
            | (PauliKind::Z, PauliKind::Plus) => return int(0)
            (PauliKind::Minus, PauliKind::X)
            | (PauliKind::X, PauliKind::Minus)
            | (PauliKind::Plus, PauliKind::X)
            | (PauliKind::X, PauliKind::Plus)
            | (PauliKind::Minus, PauliKind::Plus)
            | (PauliKind::Plus, PauliKind::Minus) => return int(1)
            (PauliKind::Minus, PauliKind::Y)
            | (PauliKind::Y, PauliKind::Minus) =>
              return int(-1) * @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
            (PauliKind::Plus, PauliKind::Y) | (PauliKind::Y, PauliKind::Plus) =>
              return @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
            _ => ()
          }
        _ => ()
      }
      match (
        @symcore.application_name(nlhs),
        @symcore.application_args(nlhs),
        @symcore.application_name(nrhs),
        @symcore.application_args(nrhs),
      ) {
        (Some("FermionOp"), Some(largs), Some("FermionOp"), Some(rargs)) =>
          if largs.length() == 2 &&
            rargs.length() == 2 &&
            largs[0] == rargs[0] &&
            largs[1] == int(0) &&
            rargs[1] != int(0) {
            return int(1)
          }
        (Some("FermionOp"), Some(_), Some("BosonOp"), Some(_)) =>
          return int(2) * nlhs * nrhs
        (Some("BosonOp"), Some(_), Some("FermionOp"), Some(_)) =>
          return int(2) * nlhs * nrhs
        _ => ()
      }
      match (gate_support(nlhs), gate_support(nrhs)) {
        (Some(lhs_support), Some(rhs_support)) if supports_disjoint(
            lhs_support, rhs_support,
          ) => return int(2) * nlhs * nrhs
        _ => ()
      }
      if lhs.compare(rhs) > 0 {
        return quantum_make_anticommutator(rhs, lhs)
      }
      quantum_anticommutator_raw(lhs, rhs)
    }
    _ => int(0)
  }
}

///|
pub fn anticommutator(lhs : Expr, rhs : Expr, evaluate? : Bool = true) -> Expr {
  if evaluate {
    quantum_make_anticommutator(lhs, rhs)
  } else {
    quantum_anticommutator_raw(lhs, rhs)
  }
}

///|
pub fn anticommutator_doit(expr : Expr) -> Expr {
  match @symcore.application_args(expr) {
    Some([lhs, rhs]) if @symcore.application_has_name(expr, "AntiCommutator", arity=2) =>
      quantum_add_from_args_preserve([
        quantum_mul_from_args_preserve([lhs, rhs]),
        quantum_mul_from_args_preserve([rhs, lhs]),
      ])
    _ => expr
  }
}
