///|
/// Symbolic commutator helpers aligned with the operator-free core of
/// `sympy.physics.quantum.commutator`.

///|
fn quantum_commutator_raw(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("Commutator", [lhs, rhs])
}

///|
fn quantum_make_commutator(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  if lhs == @symcore.int(0) || rhs == @symcore.int(0) {
    return @symcore.int(0)
  }
  if lhs == rhs {
    return @symcore.int(0)
  }
  if quantum_is_scalar_like(lhs) || quantum_is_scalar_like(rhs) {
    return @symcore.int(0)
  }
  let (lhs_scalar, lhs_body) = quantum_split_scalar_factors(lhs)
  let (rhs_scalar, rhs_body) = quantum_split_scalar_factors(rhs)
  match (lhs_body, rhs_body) {
    (Some(nlhs), Some(nrhs)) => {
      if lhs_scalar != @symcore.int(1) || rhs_scalar != @symcore.int(1) {
        return lhs_scalar * rhs_scalar * quantum_make_commutator(nlhs, nrhs)
      }
      match (nlhs, nrhs) {
        (@symcore.Expr::Symbol(lhs_name), @symcore.Expr::Symbol(rhs_name)) => {
          match (lhs_name, rhs_name) {
            ("Jx", "Jy") => return @symcore.symbol("I") * hbar * @symcore.symbol("Jz")
            ("Jy", "Jz") => return @symcore.symbol("I") * hbar * @symcore.symbol("Jx")
            ("Jz", "Jx") => return @symcore.symbol("I") * hbar * @symcore.symbol("Jy")
            ("Jplus", "Jminus") => return @symcore.int(2) * hbar * @symcore.symbol("Jz")
            ("Jz", "Jplus") => return hbar * @symcore.symbol("Jplus")
            ("Jz", "Jminus") => return @symcore.int(-1) * hbar * @symcore.symbol("Jminus")
            _ => ()
          }
        }
        (@symcore.Expr::Function("BosonOp", largs), @symcore.Expr::Function("BosonOp", rargs)) => {
          if largs.length() == 2 &&
            rargs.length() == 2 &&
            largs[0] == rargs[0] &&
            largs[1] == @symcore.int(0) &&
            rargs[1] != @symcore.int(0) {
            return @symcore.int(-1)
          }
        }
        (@symcore.Expr::Function("FermionOp", _), @symcore.Expr::Function("BosonOp", _)) =>
          return @symcore.int(0)
        (@symcore.Expr::Function("BosonOp", _), @symcore.Expr::Function("FermionOp", _)) =>
          return @symcore.int(0)
        _ => ()
      }
      if lhs.compare(rhs) > 0 {
        return @symcore.int(-1) * quantum_make_commutator(rhs, lhs)
      }
      quantum_commutator_raw(lhs, rhs)
    }
    _ => @symcore.int(0)
  }
}

///|
pub fn commutator(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
  evaluate? : Bool = true,
) -> @symcore.Expr {
  if evaluate {
    quantum_make_commutator(lhs, rhs)
  } else {
    quantum_commutator_raw(lhs, rhs)
  }
}

///|
pub fn commutator_doit(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("Commutator", args) if args.length() == 2 =>
      quantum_add_from_args_preserve([
        quantum_mul_from_args_preserve([args[0], args[1]]),
        quantum_mul_from_args_preserve([@symcore.int(-1), args[1], args[0]]),
      ])
    _ => expr
  }
}

///|
fn quantum_expand_pow_commutator(
  base_expr : @symcore.Expr,
  other : @symcore.Expr,
  sign : Int,
) -> @symcore.Expr {
  match base_expr {
    @symcore.Expr::Pow(base, exp_expr) =>
      match quantum_integer_value(exp_expr) {
        Some(exp) if exp.abs() > 1 => {
          let mut effective_base = base
          let mut effective_exp = exp
          if exp < 0 {
            effective_base = @symcore.raw_pow(base, @symcore.int(-1))
            effective_exp = -exp
          }
          let comm = commutator_expand(commutator(effective_base, other, evaluate=false))
          let terms : Array[@symcore.Expr] = []
          for idx in 0..<effective_exp {
            let left_power = effective_exp - 1 - idx
            let right_power = idx
            let parts : Array[@symcore.Expr] = []
            if left_power > 0 {
              parts.push(@symcore.raw_pow(effective_base, @symcore.int(left_power)))
            }
            parts.push(comm)
            if right_power > 0 {
              parts.push(@symcore.raw_pow(effective_base, @symcore.int(right_power)))
            }
            terms.push(quantum_mul_from_args_preserve(parts))
          }
          let out = quantum_add_from_args_preserve(terms)
          if sign < 0 { @symcore.int(-1) * out } else { out }
        }
        _ => quantum_commutator_raw(base_expr, other)
      }
    _ => quantum_commutator_raw(base_expr, other)
  }
}

///|
pub fn commutator_expand(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("Commutator", args) if args.length() == 2 => {
      let lhs = args[0]
      let rhs = args[1]
      match lhs {
        @symcore.Expr::Add(lhs_args) =>
          quantum_add_from_args_preserve(lhs_args.map(term => commutator_expand(commutator(term, rhs, evaluate=false))))
        @symcore.Expr::Mul(lhs_args) if lhs_args.length() > 1 => {
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
        @symcore.Expr::Pow(_, _) => quantum_expand_pow_commutator(lhs, rhs, 1)
        _ =>
          match rhs {
            @symcore.Expr::Add(rhs_args) =>
              quantum_add_from_args_preserve(rhs_args.map(term => commutator_expand(commutator(lhs, term, evaluate=false))))
            @symcore.Expr::Mul(rhs_args) if rhs_args.length() > 1 => {
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
            @symcore.Expr::Pow(_, _) => quantum_expand_pow_commutator(rhs, lhs, -1)
            _ => expr
          }
      }
    }
    _ => expr
  }
}
