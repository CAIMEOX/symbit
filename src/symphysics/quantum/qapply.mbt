///|
/// Operator application for the transferable symbolic subset of
/// `sympy.physics.quantum.qapply`.
///
/// Current coverage focuses on the new symbolic object model, outer products,
/// boson/fermion Fock/coherent states, and scalar extraction. More elaborate
/// gate/spin families can layer on top of the same pairwise application loop.

///|
fn quantum_pair_to_factors(expr : Expr) -> Array[Expr] {
  match expr {
    Mul(items) => items
    _ => [expr]
  }
}

///|
fn quantum_adjoint(expr : Expr) -> Expr {
  dagger(expr)
}

///|
fn quantum_qapply_tensorproduct_args(
  args : Array[Expr],
  dagger_mode : Bool,
  ip_doit : Bool,
  sum_doit : Bool,
) -> Expr {
  @symcore.raw_function(
    "TensorProduct",
    args.map(arg => qapply(arg, dagger=dagger_mode, ip_doit~, sum_doit~)),
  )
}

///|
fn quantum_qapply_density_expr(
  expr : Expr,
  dagger_mode : Bool,
  ip_doit : Bool,
  sum_doit : Bool,
) -> Expr {
  match density_from_expr(expr) {
    Some(rho) =>
      density(
        rho.terms.map(term => {
          (
            qapply(term.state, dagger=dagger_mode, ip_doit~, sum_doit~),
            term.prob,
          )
        }),
      ).as_expr()
    None => expr
  }
}

///|
fn quantum_sum_limits(args : Array[Expr]) -> Array[@symconcrete.LimitSpec]? {
  let limits : Array[@symconcrete.LimitSpec] = []
  for arg in args {
    match @symcore.tuple_items(arg) {
      Some(items) =>
        match items.length() {
          1 => limits.push(@symconcrete.limit_var(items[0]))
          2 => limits.push(@symconcrete.limit_lower(items[0], items[1]))
          3 =>
            limits.push(@symconcrete.limit_range(items[0], items[1], items[2]))
          _ => return None
        }
      None => return None
    }
  }
  Some(limits)
}

///|
fn quantum_sum_expr(
  body : Expr,
  limit_args : Array[Expr],
  sum_doit : Bool,
) -> Expr {
  if !sum_doit {
    let rebuilt : Array[Expr] = [body]
    for arg in limit_args {
      rebuilt.push(arg)
    }
    return @symcore.raw_function("Sum", rebuilt)
  }
  match quantum_sum_limits(limit_args) {
    Some(limits) => @symconcrete.deltasummation(body, limits)
    None => {
      let rebuilt : Array[Expr] = [body]
      for arg in limit_args {
        rebuilt.push(arg)
      }
      @symcore.raw_function("Sum", rebuilt)
    }
  }
}

///|
fn quantum_symbolic_infinite(expr : Expr) -> Bool {
  expr == NumberSymbol(Infinity)
}

///|
fn quantum_single_symbolic_limit(
  limit_args : Array[Expr],
) -> (String, Expr, Expr)? {
  guard limit_args.length() == 1 else { return None }
  match @symcore.tuple_items(limit_args[0]) {
    Some(items) if items.length() == 3 =>
      match items[0] {
        Symbol(name) => Some((name, items[1], items[2]))
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_discrete_ket_info(expr : Expr) -> (String, Expr)? {
  match @symcore.application_parts(expr) {
    Some((head, [arg])) =>
      match @symcore.function_head_name(head) {
        Some(name) =>
          if ["BosonFockKet", "FermionFockKet", "PIABKet", "SHOKet"].contains(
              name,
            ) {
            Some((name, arg))
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_discrete_bra_info(expr : Expr) -> (String, Expr)? {
  match @symcore.application_parts(expr) {
    Some((head, [arg])) =>
      match @symcore.function_head_name(head) {
        Some(name) =>
          if ["BosonFockBra", "FermionFockBra", "PIABBra", "SHOBra"].contains(
              name,
            ) {
            Some((name, arg))
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_matching_bra_name(ket_name : String) -> String? {
  match ket_name {
    "BosonFockKet" => Some("BosonFockBra")
    "FermionFockKet" => Some("FermionFockBra")
    "PIABKet" => Some("PIABBra")
    "SHOKet" => Some("SHOBra")
    _ => None
  }
}

///|
fn quantum_expr_is_symbol_named(expr : Expr, name : String) -> Bool {
  match expr {
    Symbol(sym) => sym == name
    _ => false
  }
}

///|
fn quantum_sum_resolution_kernel(
  expr : Expr,
  sum_name : String,
) -> (Expr, String)? {
  let coeffs : Array[Expr] = []
  let mut ket_name : String? = None
  let mut bra_name : String? = None
  match expr {
    Mul(args) =>
      for arg in args {
        match (quantum_discrete_ket_info(arg), quantum_discrete_bra_info(arg)) {
          (Some((kname, label)), _) if quantum_expr_is_symbol_named(
              label, sum_name,
            ) =>
            match ket_name {
              Some(_) => return None
              None => ket_name = Some(kname)
            }
          (_, Some((bname, label))) if quantum_expr_is_symbol_named(
              label, sum_name,
            ) =>
            match bra_name {
              Some(_) => return None
              None => bra_name = Some(bname)
            }
          _ => coeffs.push(arg)
        }
      }
    _ => return None
  }
  match (ket_name, bra_name) {
    (Some(kname), Some(bname)) =>
      match quantum_matching_bra_name(kname) {
        Some(expected) if expected == bname =>
          Some((quantum_mul_from_args_preserve(coeffs), kname))
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_sum_state_term(expr : Expr, sum_name : String) -> (Expr, String)? {
  let coeffs : Array[Expr] = []
  let mut ket_name : String? = None
  match expr {
    Mul(args) =>
      for arg in args {
        match quantum_discrete_ket_info(arg) {
          Some((name, label)) if quantum_expr_is_symbol_named(label, sum_name) =>
            match ket_name {
              Some(_) => return None
              None => ket_name = Some(name)
            }
          _ => coeffs.push(arg)
        }
      }
    _ =>
      match quantum_discrete_ket_info(expr) {
        Some((name, label)) if quantum_expr_is_symbol_named(label, sum_name) =>
          ket_name = Some(name)
        _ => return None
      }
  }
  match ket_name {
    Some(name) => Some((quantum_mul_from_args_preserve(coeffs), name))
    None => None
  }
}

///|
fn quantum_apply_discrete_sum_to_ket(
  sum_args : Array[Expr],
  rhs : Expr,
) -> Expr? {
  guard !sum_args.is_empty() else { return None }
  let (sum_name, lower, upper) = match
    quantum_single_symbolic_limit(sum_args[1:sum_args.length()].to_owned()) {
    Some(spec) => spec
    None => return None
  }
  guard lower == int(0) && quantum_symbolic_infinite(upper) else { return None }
  let (coeff, ket_name) = match
    quantum_sum_resolution_kernel(sum_args[0], sum_name) {
    Some(info) => info
    None => return None
  }
  let (rhs_name, rhs_label) = match quantum_discrete_ket_info(rhs) {
    Some(info) => info
    None => return None
  }
  guard rhs_name == ket_name else { return None }
  let env : Map[String, Expr] = Map([])
  env[sum_name] = rhs_label
  let coeff_sub = @symcore.subst(coeff, env)
  Some(quantum_mul_from_args_preserve([coeff_sub, rhs]))
}

///|
fn quantum_project_discrete_bra_against_sum(
  lhs : Expr,
  sum_args : Array[Expr],
) -> Expr? {
  guard !sum_args.is_empty() else { return None }
  let (sum_name, lower, upper) = match
    quantum_single_symbolic_limit(sum_args[1:sum_args.length()].to_owned()) {
    Some(spec) => spec
    None => return None
  }
  guard lower == int(0) && quantum_symbolic_infinite(upper) else { return None }
  let (lhs_name, lhs_label) = match quantum_discrete_bra_info(lhs) {
    Some(info) => info
    None => return None
  }
  let (coeff, ket_name) = match quantum_sum_state_term(sum_args[0], sum_name) {
    Some(info) => info
    None => return None
  }
  let expected_bra = match quantum_matching_bra_name(ket_name) {
    Some(name) => name
    None => return None
  }
  guard lhs_name == expected_bra else { return None }
  let env : Map[String, Expr] = Map([])
  env[sum_name] = lhs_label
  Some(@symcore.subst(coeff, env))
}

///|
fn quantum_has_nontrivial_scalar_factor(expr : Expr) -> Bool {
  let (scalar, body) = quantum_split_scalar_factors(expr)
  scalar != int(1) && body is Some(_)
}

///|
fn quantum_apply_operator_pair(
  lhs : Expr,
  rhs : Expr,
  dagger_mode : Bool,
  ip_doit : Bool,
  sum_doit : Bool,
) -> Expr? {
  match quantum_operator_pair_simplify(lhs, rhs) {
    Some(simplified) => return Some(simplified)
    None => ()
  }
  match (lhs, rhs) {
    (Pow(base, exp), _) if quantum_is_operator_expr(base) =>
      match quantum_integer_value(exp) {
        Some(power) if power > 0 =>
          match
            quantum_apply_operator_pair(
              base, rhs, dagger_mode, ip_doit, sum_doit,
            ) {
            Some(applied) =>
              if power == 1 {
                Some(applied)
              } else {
                Some(
                  quantum_mul_from_args_preserve([
                    @symcore.raw_pow(base, int(power - 1)),
                    applied,
                  ]),
                )
              }
            None => None
          }
        _ => None
      }
    _ if @symcore.application_has_name(lhs, "Commutator", arity=2) &&
      quantum_is_ket_expr(rhs) =>
      match @symcore.application_args(lhs) {
        Some(args) =>
          Some(
            quantum_add_from_args_preserve([
              qapply(
                quantum_mul_from_args_preserve([args[0], args[1], rhs]),
                dagger=dagger_mode,
                ip_doit~,
                sum_doit~,
              ),
              int(-1) *
              qapply(
                quantum_mul_from_args_preserve([args[1], args[0], rhs]),
                dagger=dagger_mode,
                ip_doit~,
                sum_doit~,
              ),
            ]),
          )
        None => None
      }
    _ if @symcore.application_has_name(lhs, "AntiCommutator", arity=2) &&
      quantum_is_ket_expr(rhs) =>
      match @symcore.application_args(lhs) {
        Some(args) =>
          Some(
            quantum_add_from_args_preserve([
              qapply(
                quantum_mul_from_args_preserve([args[0], args[1], rhs]),
                dagger=dagger_mode,
                ip_doit~,
                sum_doit~,
              ),
              qapply(
                quantum_mul_from_args_preserve([args[1], args[0], rhs]),
                dagger=dagger_mode,
                ip_doit~,
                sum_doit~,
              ),
            ]),
          )
        None => None
      }
    _ if @symcore.application_has_name(lhs, "TensorProduct") &&
      @symcore.application_has_name(rhs, "TensorProduct") =>
      match (@symcore.application_args(lhs), @symcore.application_args(rhs)) {
        (Some(left_args), Some(right_args)) if left_args.length() ==
          right_args.length() => {
          let factors : Array[Expr] = []
          for idx in 0..<left_args.length() {
            factors.push(
              qapply(
                quantum_mul_from_args_preserve([left_args[idx], right_args[idx]]),
                dagger=dagger_mode,
                ip_doit~,
                sum_doit~,
              ),
            )
          }
          Some(@symcore.raw_function("TensorProduct", factors))
        }
        _ => None
      }
    _ if @symcore.application_has_name(lhs, "Sum") && sum_doit =>
      match @symcore.application_args(lhs) {
        Some(args) => quantum_apply_discrete_sum_to_ket(args, rhs)
        None => None
      }
    _ if @symcore.application_has_name(rhs, "Sum") && sum_doit =>
      match @symcore.application_args(rhs) {
        Some(args) => quantum_project_discrete_bra_against_sum(lhs, args)
        None => None
      }
    _ if @symcore.application_has_name(lhs, "Sum") =>
      match @symcore.application_args(lhs) {
        Some(args) if !args.is_empty() =>
          Some(
            quantum_sum_expr(
              qapply(
                quantum_mul_from_args_preserve([args[0], rhs]),
                dagger=dagger_mode,
                ip_doit~,
                sum_doit~,
              ),
              args[1:args.length()].to_owned(),
              sum_doit,
            ),
          )
        _ => None
      }
    _ if @symcore.application_has_name(rhs, "Sum") =>
      match @symcore.application_args(rhs) {
        Some(args) if !args.is_empty() =>
          Some(
            quantum_sum_expr(
              qapply(
                quantum_mul_from_args_preserve([lhs, args[0]]),
                dagger=dagger_mode,
                ip_doit~,
                sum_doit~,
              ),
              args[1:args.length()].to_owned(),
              sum_doit,
            ),
          )
        _ => None
      }
    _ if quantum_is_operator_expr(lhs) && quantum_is_scalar_like(rhs) =>
      Some(quantum_mul_from_args_preserve([rhs, lhs]))
    (_, Mul(_)) if quantum_is_operator_expr(lhs) &&
      quantum_has_nontrivial_scalar_factor(rhs) => {
      let (scalar, body) = quantum_split_scalar_factors(rhs)
      match body {
        Some(body_expr) =>
          match
            quantum_apply_operator_pair(
              lhs, body_expr, dagger_mode, ip_doit, sum_doit,
            ) {
            Some(applied) =>
              Some(quantum_mul_from_args_preserve([scalar, applied]))
            None => None
          }
        None => None
      }
    }
    (_, Add(args)) if quantum_is_operator_expr(lhs) =>
      Some(
        quantum_add_from_args_preserve(
          args.map(term => {
            qapply(
              quantum_mul_from_args_preserve([lhs, term]),
              dagger=dagger_mode,
              ip_doit~,
              sum_doit~,
            )
          }),
        ),
      )
    _ if quantum_expr_has_name(lhs, "DifferentialOperator") &&
      quantum_expr_has_name(rhs, "Wavefunction") =>
      differential_operator_apply_to_wavefunction(lhs, rhs)
    _ if @symcore.application_has_name(lhs, "OuterProduct", arity=2) &&
      quantum_is_ket_expr(rhs) =>
      match @symcore.application_args(lhs) {
        Some(args) if quantum_is_ket_expr(args[0]) &&
          quantum_is_bra_expr(args[1]) => {
          let ip = inner_product(args[1], rhs, evaluate=ip_doit)
          Some(quantum_mul_from_args_preserve([ip, args[0]]))
        }
        _ => None
      }
    _ if @symcore.application_has_name(rhs, "OuterProduct", arity=2) &&
      quantum_is_bra_expr(lhs) =>
      match @symcore.application_args(rhs) {
        Some(args) if quantum_is_ket_expr(args[0]) &&
          quantum_is_bra_expr(args[1]) => {
          let ip = inner_product(lhs, args[0], evaluate=ip_doit)
          Some(quantum_mul_from_args_preserve([ip, args[1]]))
        }
        _ => None
      }
    _ if quantum_is_bra_expr(lhs) && quantum_is_ket_expr(rhs) =>
      Some(inner_product(lhs, rhs, evaluate=ip_doit))
    _ if quantum_is_operator_expr(lhs) && quantum_is_ket_expr(rhs) => {
      let gate_applied = gate_apply_to_qubit_expr(lhs, rhs) catch { _ => None }
      match gate_applied {
        Some(applied) => Some(applied)
        None =>
          match spin_apply_operator_to_ket(lhs, rhs) {
            Some(applied) => Some(applied)
            None =>
              match cartesian_apply_operator_to_ket(lhs, rhs) {
                Some(applied) => Some(applied)
                None =>
                  match qapply_try_special_operator_to_ket(lhs, rhs) {
                    Some(applied) => Some(applied)
                    None =>
                      match pauli_apply_operator_to_ket(lhs, rhs) {
                        Some(applied) => Some(applied)
                        None =>
                          match piab_apply_operator_to_ket(lhs, rhs) {
                            Some(applied) => Some(applied)
                            None =>
                              match sho_apply_operator_to_ket(lhs, rhs) {
                                Some(applied) => Some(applied)
                                None =>
                                  match boson_apply_operator_to_ket(lhs, rhs) {
                                    Some(applied) => Some(applied)
                                    None =>
                                      match
                                        fermion_apply_operator_to_ket(lhs, rhs) {
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
    _ if dagger_mode &&
      quantum_is_bra_expr(lhs) &&
      quantum_is_operator_expr(rhs) => boson_apply_operator_to_bra(lhs, rhs)
    _ => None
  }
}

///|
fn qapply_try_special_operator_to_ket(lhs : Expr, rhs : Expr) -> Expr? {
  grover_apply_operator_to_ket(lhs, rhs) catch {
    _ =>
      qft_apply_operator_to_ket(lhs, rhs) catch {
        _ => shor_apply_operator_to_ket(lhs, rhs) catch { _ => None }
      }
  }
}

///|
fn quantum_qapply_mul(
  args : Array[Expr],
  dagger_mode : Bool,
  ip_doit : Bool,
  sum_doit : Bool,
) -> Expr {
  let factors : Array[Expr] = Array::new()
  for arg in args {
    let applied = qapply(arg, dagger=dagger_mode, ip_doit~, sum_doit~)
    for factor in quantum_pair_to_factors(applied) {
      factors.push(factor)
    }
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
          sum_doit,
        ) {
        Some(applied) => {
          let prefix = factors[0:idx]
          let suffix = factors[idx + 2:factors.length()]
          let rebuilt : Array[Expr] = Array::new()
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
  expr : Expr,
  dagger? : Bool = false,
  ip_doit? : Bool = true,
  sum_doit? : Bool = false,
) -> Expr {
  match expr {
    _ if @symcore.application_has_name(expr, "Density") =>
      quantum_qapply_density_expr(expr, dagger, ip_doit, sum_doit)
    _ if @symcore.application_has_name(expr, "TensorProduct") =>
      match @symcore.application_args(expr) {
        Some(args) =>
          quantum_qapply_tensorproduct_args(args, dagger, ip_doit, sum_doit)
        None => expr
      }
    _ if @symcore.application_has_name(expr, "Sum") =>
      match @symcore.application_args(expr) {
        Some(args) if !args.is_empty() =>
          quantum_sum_expr(
            qapply(args[0], dagger~, ip_doit~, sum_doit~),
            args[1:args.length()].to_owned(),
            sum_doit,
          )
        _ => expr
      }
    Pow(base, exp) =>
      @symcore.raw_pow(qapply(base, dagger~, ip_doit~, sum_doit~), exp)
    Add(args) =>
      quantum_add_from_args_preserve(
        args.map(arg => qapply(arg, dagger~, ip_doit~, sum_doit~)),
      )
    Mul(args) => {
      let out = quantum_qapply_mul(args, dagger, ip_doit, sum_doit)
      if dagger && out == expr {
        let restored = quantum_adjoint(
          qapply(quantum_adjoint(expr), dagger=false, ip_doit~, sum_doit~),
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
    _ if @symcore.application_has_name(expr, "InnerProduct") && ip_doit =>
      inner_product_doit(expr)
    _ => expr
  }
}
