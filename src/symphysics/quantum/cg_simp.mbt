///|
/// Simplification rules for `CG(...)` sums aligned with the implemented
/// `sympy.physics.quantum.cg` sum identities.

///|
fn quantum_tuple3(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr)? {
  match expr {
    @symcore.Expr::Function("Tuple", [a, b, c]) => Some((a, b, c))
    _ => None
  }
}

///|
fn quantum_neg(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.mul([@symcore.int(-1), expr])
}

///|
fn quantum_kdelta(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("KroneckerDelta", [a, b])
}

///|
fn quantum_cg_args(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function("CG", args) if args.length() == 6 => Some(args)
    _ => None
  }
}

///|
fn quantum_parse_sum_871_1(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function("Sum", [body, limit]) =>
      match (quantum_cg_args(body), quantum_tuple3(limit)) {
        (Some(args), Some((alpha, lower, upper))) => {
          let a = args[0]
          let alpha1 = args[1]
          let b = args[2]
          let zero = args[3]
          let a2 = args[4]
          let alpha2 = args[5]
          if alpha1 == alpha &&
            alpha2 == alpha &&
            a == a2 &&
            zero == @symcore.int(0) &&
            lower == quantum_neg(a) &&
            upper == a {
            Some(@symcore.mul([
              @symcore.add([@symcore.mul([@symcore.int(2), a]), @symcore.int(1)]),
              quantum_kdelta(b, @symcore.int(0)),
            ]))
          } else {
            None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_parse_sum_871_2(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function("Sum", [body, limit]) =>
      match quantum_tuple3(limit) {
        Some((alpha, lower, upper)) =>
          match body {
            @symcore.Expr::Mul(factors) => {
              let mut phase_exp : @symcore.Expr? = None
              let mut a_val : @symcore.Expr? = None
              let mut c_val : @symcore.Expr? = None
              for factor in factors {
                match factor {
                  @symcore.Expr::Pow(base, exp) if base == @symcore.int(-1) =>
                    phase_exp = Some(exp)
                  _ =>
                    match quantum_cg_args(factor) {
                      Some(args) =>
                        if args[1] == alpha &&
                          args[0] == args[2] &&
                          args[3] == quantum_neg(alpha) &&
                          args[5] == @symcore.int(0) {
                          a_val = Some(args[0])
                          c_val = Some(args[4])
                        }
                      None => ()
                    }
                }
              }
              match (phase_exp, a_val, c_val) {
                (Some(exp), Some(a), Some(c)) =>
                  if exp == @symcore.add([a, quantum_neg(alpha)]) &&
                    lower == quantum_neg(a) &&
                    upper == a {
                    Some(@symcore.mul([
                      @symcore.function(
                        "sqrt",
                        [@symcore.add([@symcore.mul([@symcore.int(2), a]), @symcore.int(1)])],
                      ),
                      quantum_kdelta(c, @symcore.int(0)),
                    ]))
                  } else {
                    None
                  }
                _ => None
              }
            }
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn quantum_parse_sum_872_4(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function("Sum", [body, limit1, limit2]) =>
      match (quantum_tuple3(limit1), quantum_tuple3(limit2)) {
        (Some((alpha, lower_a, upper_a)), Some((beta, lower_b, upper_b))) =>
          match body {
            @symcore.Expr::Pow(base, exp) if exp == @symcore.int(2) =>
              match quantum_cg_args(base) {
                Some(args) => {
                  let a = args[0]
                  let alpha1 = args[1]
                  let b = args[2]
                  let beta1 = args[3]
                  if alpha1 == alpha &&
                    beta1 == beta &&
                    lower_a == quantum_neg(a) &&
                    upper_a == a &&
                    lower_b == quantum_neg(b) &&
                    upper_b == b {
                    Some(@symcore.int(1))
                  } else {
                    None
                  }
                }
                None => None
              }
            @symcore.Expr::Mul([lhs, rhs]) =>
              match (quantum_cg_args(lhs), quantum_cg_args(rhs)) {
                (Some(args1), Some(args2)) => {
                  let a = args1[0]
                  let b = args1[2]
                  if args1[1] == alpha &&
                    args2[1] == alpha &&
                    args1[3] == beta &&
                    args2[3] == beta &&
                    args2[0] == a &&
                    args2[2] == b &&
                    lower_a == quantum_neg(a) &&
                    upper_a == a &&
                    lower_b == quantum_neg(b) &&
                    upper_b == b {
                    Some(@symcore.mul([
                      quantum_kdelta(args1[4], args2[4]),
                      quantum_kdelta(args1[5], args2[5]),
                    ]))
                  } else {
                    None
                  }
                }
                _ => None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_cg_simp_sum(expr : @symcore.Expr) -> @symcore.Expr {
  match quantum_parse_sum_871_1(expr) {
    Some(out) => out
    None =>
      match quantum_parse_sum_871_2(expr) {
        Some(out) => out
        None =>
          match quantum_parse_sum_872_4(expr) {
            Some(out) => out
            None => expr
          }
      }
  }
}

///|
pub fn cg_simp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => @symcore.add(args.map(cg_simp))
    @symcore.Expr::Mul(args) => @symcore.mul(args.map(cg_simp))
    @symcore.Expr::Pow(base, exp) => @symcore.pow(cg_simp(base), cg_simp(exp))
    @symcore.Expr::Function("Sum", _) => quantum_cg_simp_sum(expr)
    _ => expr
  }
}
