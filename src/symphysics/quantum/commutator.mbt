///|
/// Symbolic commutator helpers aligned with the operator-free core of
/// `sympy.physics.quantum.commutator`.

///|
fn quantum_commutator_raw(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.raw_function("Commutator", [lhs, rhs])
}

///|
fn gate_commutator_zero(lhs_gate : GateExpr, rhs_gate : GateExpr) -> Bool {
  if lhs_gate.kind == GateKind::CNot &&
    rhs_gate.kind == GateKind::CNot &&
    lhs_gate.args.length() == 2 &&
    rhs_gate.args.length() == 2 &&
    lhs_gate.args[0] == rhs_gate.args[0] {
    return true
  }
  if lhs_gate.kind == GateKind::CNot &&
    lhs_gate.args.length() == 2 &&
    rhs_gate.args.length() == 1 {
    return match rhs_gate.kind {
      GateKind::Z | GateKind::Phase | GateKind::T =>
        rhs_gate.args[0] == lhs_gate.args[0]
      GateKind::X => rhs_gate.args[0] == lhs_gate.args[1]
      _ => false
    }
  }
  if rhs_gate.kind == GateKind::CNot &&
    rhs_gate.args.length() == 2 &&
    lhs_gate.args.length() == 1 {
    return match lhs_gate.kind {
      GateKind::Z | GateKind::Phase | GateKind::T =>
        lhs_gate.args[0] == rhs_gate.args[0]
      GateKind::X => lhs_gate.args[0] == rhs_gate.args[1]
      _ => false
    }
  }
  false
}

///|
fn quantum_make_commutator(lhs : Expr, rhs : Expr) -> Expr {
  if lhs == int(0) || rhs == int(0) {
    return int(0)
  }
  if lhs == rhs {
    return int(0)
  }
  if quantum_is_scalar_like(lhs) || quantum_is_scalar_like(rhs) {
    return int(0)
  }
  let (lhs_scalar, lhs_body) = quantum_split_scalar_factors(lhs)
  let (rhs_scalar, rhs_body) = quantum_split_scalar_factors(rhs)
  match (lhs_body, rhs_body) {
    (Some(nlhs), Some(nrhs)) => {
      if lhs_scalar != int(1) || rhs_scalar != int(1) {
        return lhs_scalar * rhs_scalar * quantum_make_commutator(nlhs, nrhs)
      }
      match (pauli_from_expr(nlhs), pauli_from_expr(nrhs)) {
        (Some(lhs_pauli), Some(rhs_pauli)) if !pauli_name_equal(
            lhs_pauli.name,
            rhs_pauli.name,
          ) => return int(0)
        (Some(lhs_pauli), Some(rhs_pauli)) =>
          match (lhs_pauli.kind, rhs_pauli.kind) {
            (PauliKind::X, PauliKind::Y) =>
              return int(2) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Y, PauliKind::X) =>
              return int(-2) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Y, PauliKind::Z) =>
              return int(2) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_x(name=lhs_pauli.name).as_expr()
            (PauliKind::Z, PauliKind::Y) =>
              return int(-2) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_x(name=lhs_pauli.name).as_expr()
            (PauliKind::Z, PauliKind::X) =>
              return int(2) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_y(name=lhs_pauli.name).as_expr()
            (PauliKind::X, PauliKind::Z) =>
              return int(-2) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_y(name=lhs_pauli.name).as_expr()
            (PauliKind::Minus, PauliKind::X) =>
              return int(-1) * sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::X, PauliKind::Minus) =>
              return sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Minus, PauliKind::Y) =>
              return @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Y, PauliKind::Minus) =>
              return int(-1) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Minus, PauliKind::Z) =>
              return int(2) * sigma_minus(name=lhs_pauli.name).as_expr()
            (PauliKind::Z, PauliKind::Minus) =>
              return int(-2) * sigma_minus(name=lhs_pauli.name).as_expr()
            (PauliKind::Plus, PauliKind::X) =>
              return sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::X, PauliKind::Plus) =>
              return int(-1) * sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Plus, PauliKind::Y) =>
              return @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Y, PauliKind::Plus) =>
              return int(-1) *
                @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Plus, PauliKind::Z) =>
              return int(-2) * sigma_plus(name=lhs_pauli.name).as_expr()
            (PauliKind::Z, PauliKind::Plus) =>
              return int(2) * sigma_plus(name=lhs_pauli.name).as_expr()
            (PauliKind::Plus, PauliKind::Minus) =>
              return sigma_z(name=lhs_pauli.name).as_expr()
            (PauliKind::Minus, PauliKind::Plus) =>
              return int(-1) * sigma_z(name=lhs_pauli.name).as_expr()
            _ => ()
          }
        _ => ()
      }
      match (gate_support(nlhs), gate_support(nrhs)) {
        (Some(lhs_support), Some(rhs_support)) if supports_disjoint(
            lhs_support, rhs_support,
          ) => return int(0)
        _ => ()
      }
      match (gate_from_expr(nlhs), gate_from_expr(nrhs)) {
        (Some(lhs_gate), Some(rhs_gate)) if gate_commutator_zero(
            lhs_gate, rhs_gate,
          ) => return int(0)
        _ => ()
      }
      match (nlhs, nrhs) {
        (Expr::Symbol(lhs_name), Expr::Symbol(rhs_name)) =>
          match (lhs_name, rhs_name) {
            ("Jx", "Jy") =>
              return @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                hbar *
                Expr::Symbol("Jz")
            ("Jy", "Jz") =>
              return @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                hbar *
                Expr::Symbol("Jx")
            ("Jz", "Jx") =>
              return @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ImaginaryUnit,
                ) *
                hbar *
                Expr::Symbol("Jy")
            ("Jplus", "Jminus") => return int(2) * hbar * Expr::Symbol("Jz")
            ("Jz", "Jplus") => return hbar * Expr::Symbol("Jplus")
            ("Jz", "Jminus") => return int(-1) * hbar * Expr::Symbol("Jminus")
            _ => ()
          }
        _ => ()
      }
      if quantum_expr_has_name(nlhs, "BosonOp") &&
        quantum_expr_has_name(nrhs, "BosonOp") {
        match (quantum_expr_args(nlhs), quantum_expr_args(nrhs)) {
          (Some(largs), Some(rargs)) if largs.length() == 2 &&
            rargs.length() == 2 &&
            largs[0] == rargs[0] &&
            largs[1] == int(0) &&
            rargs[1] != int(0) => return int(-1)
          _ => ()
        }
      }
      if quantum_expr_has_name(nlhs, "AnnihilateBoson") &&
        quantum_expr_has_name(nrhs, "CreateBoson") {
        match (quantum_expr_args(nlhs), quantum_expr_args(nrhs)) {
          (Some(largs), Some(rargs)) if largs.length() == 1 &&
            rargs.length() == 1 &&
            largs[0] == rargs[0] => return int(1)
          _ => ()
        }
      }
      if quantum_expr_has_name(nlhs, "CreateBoson") &&
        quantum_expr_has_name(nrhs, "AnnihilateBoson") {
        match (quantum_expr_args(nlhs), quantum_expr_args(nrhs)) {
          (Some(largs), Some(rargs)) if largs.length() == 1 &&
            rargs.length() == 1 &&
            largs[0] == rargs[0] => return int(-1)
          _ => ()
        }
      }
      if (
          quantum_expr_has_name(nlhs, "FermionOp") &&
          quantum_expr_has_any_name(nrhs, [
            "BosonOp", "AnnihilateBoson", "CreateBoson",
          ])
        ) ||
        (
          quantum_expr_has_name(nrhs, "FermionOp") &&
          quantum_expr_has_any_name(nlhs, [
            "BosonOp", "AnnihilateBoson", "CreateBoson",
          ])
        ) {
        return int(0)
      }
      if quantum_expr_has_name(nlhs, "XOp") &&
        quantum_expr_has_name(nrhs, "PxOp") {
        return @symcore.Expr::NumberSymbol(
            @symcore.NumberSymbolKind::ImaginaryUnit,
          ) *
          hbar
      }
      if quantum_expr_has_name(nlhs, "PxOp") &&
        quantum_expr_has_name(nrhs, "XOp") {
        return int(-1) *
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit) *
          hbar
      }
      if quantum_expr_has_name(nlhs, "RaisingOp") &&
        quantum_expr_has_name(nrhs, "LoweringOp") {
        return int(-1)
      }
      if quantum_expr_has_name(nlhs, "LoweringOp") &&
        quantum_expr_has_name(nrhs, "RaisingOp") {
        return int(1)
      }
      if quantum_expr_has_name(nlhs, "RaisingOp") &&
        quantum_expr_has_name(nrhs, "NumberOp") {
        return int(-1) * nlhs
      }
      if quantum_expr_has_name(nlhs, "LoweringOp") &&
        quantum_expr_has_name(nrhs, "NumberOp") {
        return nlhs
      }
      if quantum_expr_has_name(nlhs, "NumberOp") &&
        quantum_expr_has_name(nrhs, "RaisingOp") {
        return nrhs
      }
      if quantum_expr_has_name(nlhs, "NumberOp") &&
        quantum_expr_has_name(nrhs, "LoweringOp") {
        return int(-1) * nrhs
      }
      if (
          quantum_expr_has_name(nlhs, "NumberOp") &&
          quantum_expr_has_name(nrhs, "Hamiltonian")
        ) ||
        (
          quantum_expr_has_name(nlhs, "Hamiltonian") &&
          quantum_expr_has_name(nrhs, "NumberOp")
        ) {
        return int(0)
      }
      if lhs.compare(rhs) > 0 {
        return int(-1) * quantum_make_commutator(rhs, lhs)
      }
      quantum_commutator_raw(lhs, rhs)
    }
    _ => int(0)
  }
}

///|
pub fn commutator(lhs : Expr, rhs : Expr, evaluate? : Bool = true) -> Expr {
  if evaluate {
    quantum_make_commutator(lhs, rhs)
  } else {
    quantum_commutator_raw(lhs, rhs)
  }
}

///|
pub fn commutator_doit(expr : Expr) -> Expr {
  match quantum_expr_args(expr) {
    Some(args) if quantum_expr_has_name(expr, "Commutator") &&
      args.length() == 2 =>
      quantum_add_from_args_preserve([
        quantum_mul_from_args_preserve([args[0], args[1]]),
        quantum_mul_from_args_preserve([int(-1), args[1], args[0]]),
      ])
    _ => expr
  }
}

///|
fn quantum_expand_pow_commutator(
  base_expr : Expr,
  other : Expr,
  sign : Int,
) -> Expr {
  match base_expr {
    Expr::Pow(base, exp_expr) =>
      match quantum_integer_value(exp_expr) {
        Some(exp) if exp.abs() > 1 => {
          let mut effective_base = base
          let mut effective_exp = exp
          if exp < 0 {
            effective_base = @symcore.raw_pow(base, int(-1))
            effective_exp = -exp
          }
          let comm = commutator_expand(
            commutator(effective_base, other, evaluate=false),
          )
          let terms : Array[Expr] = []
          for idx in 0..<effective_exp {
            let left_power = effective_exp - 1 - idx
            let right_power = idx
            let parts : Array[Expr] = []
            if left_power > 0 {
              parts.push(@symcore.raw_pow(effective_base, int(left_power)))
            }
            parts.push(comm)
            if right_power > 0 {
              parts.push(@symcore.raw_pow(effective_base, int(right_power)))
            }
            terms.push(quantum_mul_from_args_preserve(parts))
          }
          let out = quantum_add_from_args_preserve(terms)
          if sign < 0 {
            int(-1) * out
          } else {
            out
          }
        }
        _ => quantum_commutator_raw(base_expr, other)
      }
    _ => quantum_commutator_raw(base_expr, other)
  }
}

///|
pub fn commutator_expand(expr : Expr) -> Expr {
  match @symcore.application_args(expr) {
    Some([lhs, rhs]) if quantum_expr_has_name(expr, "Commutator") =>
      match lhs {
        Expr::Add(lhs_args) =>
          quantum_add_from_args_preserve(
            lhs_args.map(term => {
              commutator_expand(commutator(term, rhs, evaluate=false))
            }),
          )
        Expr::Mul(lhs_args) if lhs_args.length() > 1 => {
          let head = lhs_args[0]
          let tail = quantum_mul_slice(lhs_args, 1, lhs_args.length())
          quantum_add_from_args_preserve([
            quantum_mul_from_args_preserve([
              head,
              commutator_expand(commutator(tail, rhs, evaluate=false)),
            ]),
            quantum_mul_from_args_preserve([
              commutator_expand(commutator(head, rhs, evaluate=false)),
              tail,
            ]),
          ])
        }
        Expr::Pow(_, _) => quantum_expand_pow_commutator(lhs, rhs, 1)
        _ =>
          match rhs {
            Expr::Add(rhs_args) =>
              quantum_add_from_args_preserve(
                rhs_args.map(term => {
                  commutator_expand(commutator(lhs, term, evaluate=false))
                }),
              )
            Expr::Mul(rhs_args) if rhs_args.length() > 1 => {
              let head = rhs_args[0]
              let tail = quantum_mul_slice(rhs_args, 1, rhs_args.length())
              quantum_add_from_args_preserve([
                quantum_mul_from_args_preserve([
                  commutator_expand(commutator(lhs, head, evaluate=false)),
                  tail,
                ]),
                quantum_mul_from_args_preserve([
                  head,
                  commutator_expand(commutator(lhs, tail, evaluate=false)),
                ]),
              ])
            }
            Expr::Pow(_, _) => quantum_expand_pow_commutator(rhs, lhs, -1)
            _ => expr
          }
      }
    _ => expr
  }
}
