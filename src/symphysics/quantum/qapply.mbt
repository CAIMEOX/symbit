///|
/// Operator application for the transferable symbolic subset of
/// `sympy.physics.quantum.qapply`.
///
/// Current coverage focuses on the new symbolic object model, outer products,
/// boson/fermion Fock/coherent states, and scalar extraction. More elaborate
/// gate/spin families can layer on top of the same pairwise application loop.

///|
fn quantum_pair_to_factors(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    @symcore.Expr::Mul(items) => items
    _ => [expr]
  }
}

///|
fn quantum_adjoint(expr : @symcore.Expr) -> @symcore.Expr {
  dagger(expr)
}

///|
fn quantum_qapply_tensorproduct_args(
  args : Array[@symcore.Expr],
  dagger_mode : Bool,
  ip_doit : Bool,
) -> @symcore.Expr {
  @symcore.raw_function(
    "TensorProduct",
    args.map(arg => qapply(arg, dagger=dagger_mode, ip_doit~)),
  )
}

///|
fn quantum_qapply_density_expr(
  expr : @symcore.Expr,
  dagger_mode : Bool,
  ip_doit : Bool,
) -> @symcore.Expr {
  match density_from_expr(expr) {
    Some(rho) =>
      density(
        rho.terms.map(term => (qapply(term.state, dagger=dagger_mode, ip_doit~), term.prob)),
      ).as_expr()
    None => expr
  }
}

///|
fn quantum_has_nontrivial_scalar_factor(expr : @symcore.Expr) -> Bool {
  let (scalar, body) = quantum_split_scalar_factors(expr)
  scalar != @symcore.int(1) && body is Some(_)
}

///|
fn quantum_apply_operator_pair(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
  dagger_mode : Bool,
  ip_doit : Bool,
) -> @symcore.Expr? {
  match quantum_operator_pair_simplify(lhs, rhs) {
    Some(simplified) => return Some(simplified)
    None => ()
  }
  match (lhs, rhs) {
    (@symcore.Expr::Pow(base, exp), _) if quantum_is_operator_expr(base) =>
      match quantum_integer_value(exp) {
        Some(power) if power > 0 =>
          match quantum_apply_operator_pair(base, rhs, dagger_mode, ip_doit) {
            Some(applied) =>
              if power == 1 {
                Some(applied)
              } else {
                Some(
                  quantum_mul_from_args_preserve([
                    @symcore.raw_pow(base, @symcore.int(power - 1)),
                    applied,
                  ]),
                )
              }
            None => None
          }
        _ => None
      }
    (@symcore.Expr::Function("TensorProduct", left_args), @symcore.Expr::Function(
      "TensorProduct",
      right_args,
    )) if left_args.length() == right_args.length() => {
      let factors : Array[@symcore.Expr] = []
      for idx in 0..<left_args.length() {
        factors.push(
          qapply(
            quantum_mul_from_args_preserve([left_args[idx], right_args[idx]]),
            dagger=dagger_mode,
            ip_doit~,
          ),
        )
      }
      Some(@symcore.raw_function("TensorProduct", factors))
    }
    _ if quantum_is_operator_expr(lhs) && quantum_is_scalar_like(rhs) =>
      Some(quantum_mul_from_args_preserve([rhs, lhs]))
    (_, @symcore.Expr::Mul(_)) if quantum_is_operator_expr(lhs) &&
      quantum_has_nontrivial_scalar_factor(rhs) => {
      let (scalar, body) = quantum_split_scalar_factors(rhs)
      match body {
        Some(body_expr) =>
          match
            quantum_apply_operator_pair(lhs, body_expr, dagger_mode, ip_doit) {
            Some(applied) =>
              Some(quantum_mul_from_args_preserve([scalar, applied]))
            None => None
          }
        None => None
      }
    }
    (_, @symcore.Expr::Add(args)) if quantum_is_operator_expr(lhs) =>
      Some(
        quantum_add_from_args_preserve(
          args.map(term => {
            qapply(
              quantum_mul_from_args_preserve([lhs, term]),
              dagger=dagger_mode,
              ip_doit~,
            )
          }),
        ),
      )
    _ if quantum_expr_has_name(lhs, "DifferentialOperator") &&
      quantum_expr_has_name(rhs, "Wavefunction") =>
      differential_operator_apply_to_wavefunction(lhs, rhs)
    (@symcore.Expr::Function("OuterProduct", args), _) if args.length() == 2 &&
      quantum_is_ket_expr(args[0]) &&
      quantum_is_bra_expr(args[1]) &&
      quantum_is_ket_expr(rhs) => {
      let ip = inner_product(args[1], rhs, evaluate=ip_doit)
      Some(quantum_mul_from_args_preserve([ip, args[0]]))
    }
    (_, @symcore.Expr::Function("OuterProduct", args)) if args.length() == 2 &&
      quantum_is_bra_expr(lhs) &&
      quantum_is_ket_expr(args[0]) &&
      quantum_is_bra_expr(args[1]) => {
      let ip = inner_product(lhs, args[0], evaluate=ip_doit)
      Some(quantum_mul_from_args_preserve([ip, args[1]]))
    }
    _ if quantum_is_bra_expr(lhs) && quantum_is_ket_expr(rhs) =>
      Some(inner_product(lhs, rhs, evaluate=ip_doit))
    _ if quantum_is_operator_expr(lhs) && quantum_is_ket_expr(rhs) => {
      let gate_applied : Result[@symcore.Expr?, @symphysics.PhysicsError] = try? gate_apply_to_qubit_expr(
        lhs, rhs,
      )
      match gate_applied {
        Ok(Some(applied)) => Some(applied)
        _ =>
          match spin_apply_operator_to_ket(lhs, rhs) {
            Some(applied) => Some(applied)
            None =>
              match cartesian_apply_operator_to_ket(lhs, rhs) {
                Some(applied) => Some(applied)
                None =>
                  match (try? grover_apply_operator_to_ket(lhs, rhs)) {
                    Ok(Some(applied)) => Some(applied)
                    _ =>
                      match (try? qft_apply_operator_to_ket(lhs, rhs)) {
                        Ok(Some(applied)) => Some(applied)
                        _ =>
                          match (try? shor_apply_operator_to_ket(lhs, rhs)) {
                            Ok(Some(applied)) => Some(applied)
                            _ =>
                              match pauli_apply_operator_to_ket(lhs, rhs) {
                                Some(applied) => Some(applied)
                                None =>
                                  match piab_apply_operator_to_ket(lhs, rhs) {
                                    Some(applied) => Some(applied)
                                    None =>
                                      match
                                        sho_apply_operator_to_ket(lhs, rhs) {
                                        Some(applied) => Some(applied)
                                        None =>
                                          match
                                            boson_apply_operator_to_ket(
                                              lhs, rhs,
                                            ) {
                                            Some(applied) => Some(applied)
                                            None =>
                                              match
                                                fermion_apply_operator_to_ket(
                                                  lhs, rhs,
                                                ) {
                                                Some(applied) => Some(applied)
                                                None => None
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
    _ if dagger_mode &&
      quantum_is_bra_expr(lhs) &&
      quantum_is_operator_expr(rhs) => boson_apply_operator_to_bra(lhs, rhs)
    _ => None
  }
}

///|
fn quantum_qapply_mul(
  args : Array[@symcore.Expr],
  dagger_mode : Bool,
  ip_doit : Bool,
) -> @symcore.Expr {
  let factors : Array[@symcore.Expr] = Array::new()
  for arg in args {
    factors.push(qapply(arg, dagger=dagger_mode, ip_doit~))
  }
  let mut changed = true
  while changed {
    changed = false
    if factors.length() <= 1 {
      break
    }
    for idx in 0..<(factors.length() - 1) {
      match
        quantum_apply_operator_pair(
          factors[idx],
          factors[idx + 1],
          dagger_mode,
          ip_doit,
        ) {
        Some(applied) => {
          let prefix = factors[0:idx]
          let suffix = factors[idx + 2:factors.length()]
          let rebuilt : Array[@symcore.Expr] = Array::new()
          for item in prefix {
            rebuilt.push(item)
          }
          for item in quantum_pair_to_factors(applied) {
            rebuilt.push(item)
          }
          for item in suffix {
            rebuilt.push(item)
          }
          factors.clear()
          for item in rebuilt {
            factors.push(item)
          }
          changed = true
          break
        }
        None => ()
      }
    }
  }
  let out = quantum_mul_from_args_preserve(factors)
  if ip_doit {
    inner_product_doit(out)
  } else {
    out
  }
}

///|
pub fn qapply(
  expr : @symcore.Expr,
  dagger? : Bool = false,
  ip_doit? : Bool = true,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("Density", _) =>
      quantum_qapply_density_expr(expr, dagger, ip_doit)
    @symcore.Expr::Function("TensorProduct", args) =>
      quantum_qapply_tensorproduct_args(args, dagger, ip_doit)
    @symcore.Expr::Function("Sum", args) if !args.is_empty() => {
      let rebuilt : Array[@symcore.Expr] = [qapply(args[0], dagger~, ip_doit~)]
      for idx in 1..<args.length() {
        rebuilt.push(args[idx])
      }
      @symcore.raw_function("Sum", rebuilt)
    }
    @symcore.Expr::Pow(base, exp) =>
      @symcore.raw_pow(qapply(base, dagger~, ip_doit~), exp)
    @symcore.Expr::Add(args) =>
      quantum_add_from_args_preserve(
        args.map(arg => qapply(arg, dagger~, ip_doit~)),
      )
    @symcore.Expr::Mul(args) => {
      let out = quantum_qapply_mul(args, dagger, ip_doit)
      if dagger && out == expr {
        let restored = quantum_adjoint(
          qapply(quantum_adjoint(expr), dagger=false, ip_doit~),
        )
        if restored == expr {
          out
        } else if ip_doit {
          inner_product_doit(restored)
        } else {
          restored
        }
      } else {
        out
      }
    }
    @symcore.Expr::Function("InnerProduct", _) if ip_doit =>
      inner_product_doit(expr)
    _ => expr
  }
}
