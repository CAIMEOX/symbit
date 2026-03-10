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
priv struct QuantumEq1Group {
  a : @symcore.Expr
  b : @symcore.Expr
  coeffs : Map[Int, Int]
}

///|
priv struct QuantumEq2Group {
  a : @symcore.Expr
  c : @symcore.Expr
  coeffs : Map[Int, Int]
}

///|
fn quantum_expr_from_doubled_int(value : Int) -> @symcore.Expr {
  if value % 2 == 0 {
    @symcore.int(value / 2)
  } else {
    @symcore.number(
      try! @symnum.BigRational::new(
        @bigint.BigInt::from_int(value),
        @bigint.BigInt::from_int(2),
      )
    )
  }
}

///|
fn quantum_doubled_int_number(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) => {
      if n.denominator().equal_int(1) {
        Some((n.numerator() * @bigint.BigInt::from_int(2)).to_int())
      } else if n.denominator().equal_int(2) {
        Some(n.numerator().to_int())
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn quantum_split_integer_coeff(
  expr : @symcore.Expr,
) -> (Int, @symcore.Expr)? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => Some((n.numerator().to_int(), @symcore.int(1)))
    @symcore.Expr::Mul(factors) => {
      let mut coeff = 1
      let rest : Array[@symcore.Expr] = Array::new()
      for factor in factors {
        match factor {
          @symcore.Expr::Number(n) if n.is_integral() =>
            coeff = coeff * n.numerator().to_int()
          _ => rest.push(factor)
        }
      }
      let core = if rest.is_empty() {
        @symcore.int(1)
      } else if rest.length() == 1 {
        rest[0]
      } else {
        @symcore.mul(rest)
      }
      Some((coeff, core))
    }
    _ => Some((1, expr))
  }
}

///|
fn quantum_phase_sign(da : Int, dalpha : Int) -> Int {
  let exp = (da - dalpha) / 2
  if exp % 2 == 0 { 1 } else { -1 }
}

///|
fn quantum_add_group_coeff(coeffs : Map[Int, Int], alpha : Int, coeff : Int) -> Unit {
  let next = match coeffs.get(alpha) {
    Some(existing) => existing + coeff
    None => coeff
  }
  coeffs[alpha] = next
}

///|
fn quantum_common_signed_coeff(coeffs : Map[Int, Int], da : Int) -> Int? {
  let mut alpha = -da
  let mut common : Int? = None
  while alpha <= da {
    match coeffs.get(alpha) {
      Some(coeff) if coeff != 0 => {
        let sign = if coeff < 0 { -1 } else { 1 }
        let mag = coeff.abs()
        match common {
          Some(current) => {
            let current_sign = if current < 0 { -1 } else { 1 }
            let current_mag = current.abs()
            if current_sign != sign {
              return None
            }
            common = Some(sign * Int::min(current_mag, mag))
          }
          None => common = Some(sign * mag)
        }
      }
      _ => return None
    }
    alpha = alpha + 2
  }
  common
}

///|
fn quantum_scale_expr(coeff : Int, expr : @symcore.Expr) -> @symcore.Expr {
  if coeff == 1 {
    expr
  } else {
    @symcore.mul([@symcore.int(coeff), expr])
  }
}

///|
fn quantum_find_eq1_group(
  groups : Array[QuantumEq1Group],
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> Int? {
  for i in 0..<groups.length() {
    if groups[i].a == a && groups[i].b == b {
      return Some(i)
    }
  }
  None
}

///|
fn quantum_find_eq2_group(
  groups : Array[QuantumEq2Group],
  a : @symcore.Expr,
  c : @symcore.Expr,
) -> Int? {
  for i in 0..<groups.length() {
    if groups[i].a == a && groups[i].c == c {
      return Some(i)
    }
  }
  None
}

///|
fn quantum_parse_eq1_add_term(
  expr : @symcore.Expr,
) -> (Int, @symcore.Expr, @symcore.Expr, Int)? {
  match quantum_split_integer_coeff(expr) {
    Some((coeff, core)) =>
      match quantum_cg_args(core) {
        Some(args) =>
          match (quantum_doubled_int_number(args[0]), quantum_doubled_int_number(args[1])) {
            (Some(da), Some(dalpha)) =>
              if args[3] == @symcore.int(0) &&
                args[0] == args[4] &&
                args[1] == args[5] &&
                dalpha >= -da &&
                dalpha <= da {
                Some((coeff, args[0], args[2], dalpha))
              } else {
                None
              }
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn quantum_parse_eq2_add_term(
  expr : @symcore.Expr,
) -> (Int, @symcore.Expr, @symcore.Expr, Int)? {
  match quantum_split_integer_coeff(expr) {
    Some((coeff, core)) =>
      match quantum_cg_args(core) {
        Some(args) =>
          match (quantum_doubled_int_number(args[0]), quantum_doubled_int_number(args[1])) {
            (Some(da), Some(dalpha)) =>
              if args[0] == args[2] &&
                args[3] == quantum_neg(args[1]) &&
                args[5] == @symcore.int(0) &&
                dalpha >= -da &&
                dalpha <= da {
                Some((coeff * quantum_phase_sign(da, dalpha), args[0], args[4], dalpha))
              } else {
                None
              }
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn quantum_eq1_result(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.mul([
    @symcore.add([@symcore.mul([@symcore.int(2), a]), @symcore.int(1)]),
    quantum_kdelta(b, @symcore.int(0)),
  ])
}

///|
fn quantum_eq2_result(a : @symcore.Expr, c : @symcore.Expr) -> @symcore.Expr {
  @symcore.mul([
    @symcore.function(
      "sqrt",
      [@symcore.add([@symcore.mul([@symcore.int(2), a]), @symcore.int(1)])],
    ),
    quantum_kdelta(c, @symcore.int(0)),
  ])
}

///|
fn quantum_eq1_term(
  a : @symcore.Expr,
  b : @symcore.Expr,
  dalpha : Int,
  coeff : Int,
) -> @symcore.Expr {
  quantum_scale_expr(
    coeff,
    @symcore.function(
      "CG",
      [a, quantum_expr_from_doubled_int(dalpha), b, @symcore.int(0), a, quantum_expr_from_doubled_int(dalpha)],
    ),
  )
}

///|
fn quantum_eq2_term(
  a : @symcore.Expr,
  c : @symcore.Expr,
  dalpha : Int,
  scalar_coeff : Int,
) -> @symcore.Expr {
  let da = match quantum_doubled_int_number(a) {
    Some(value) => value
    None => 0
  }
  let actual_coeff = scalar_coeff * quantum_phase_sign(da, dalpha)
  quantum_scale_expr(
    actual_coeff,
    @symcore.function(
      "CG",
      [a, quantum_expr_from_doubled_int(dalpha), a, quantum_neg(quantum_expr_from_doubled_int(dalpha)), c, @symcore.int(0)],
    ),
  )
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
fn quantum_cg_simp_add(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let eq1_groups : Array[QuantumEq1Group] = Array::new()
      let eq2_groups : Array[QuantumEq2Group] = Array::new()
      let others : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match quantum_parse_eq1_add_term(arg) {
          Some((coeff, a, b, dalpha)) =>
            match quantum_find_eq1_group(eq1_groups, a, b) {
              Some(idx) => quantum_add_group_coeff(eq1_groups[idx].coeffs, dalpha, coeff)
              None => {
                let coeffs : Map[Int, Int] = {}
                quantum_add_group_coeff(coeffs, dalpha, coeff)
                eq1_groups.push(QuantumEq1Group::{ a, b, coeffs })
              }
            }
          None =>
            match quantum_parse_eq2_add_term(arg) {
              Some((coeff, a, c, dalpha)) =>
                match quantum_find_eq2_group(eq2_groups, a, c) {
                  Some(idx) => quantum_add_group_coeff(eq2_groups[idx].coeffs, dalpha, coeff)
                  None => {
                    let coeffs : Map[Int, Int] = {}
                    quantum_add_group_coeff(coeffs, dalpha, coeff)
                    eq2_groups.push(QuantumEq2Group::{ a, c, coeffs })
                  }
                }
              None => others.push(arg)
            }
        }
      }

      let out : Array[@symcore.Expr] = Array::new()
      for item in others {
        out.push(item)
      }

      for group in eq1_groups {
        match quantum_doubled_int_number(group.a) {
          Some(da) =>
            match quantum_common_signed_coeff(group.coeffs, da) {
              Some(common) => {
                out.push(quantum_scale_expr(common, quantum_eq1_result(group.a, group.b)))
                let mut alpha = -da
                while alpha <= da {
                  let residual = match group.coeffs.get(alpha) {
                    Some(coeff) => coeff - common
                    None => 0
                  }
                  if residual != 0 {
                    out.push(quantum_eq1_term(group.a, group.b, alpha, residual))
                  }
                  alpha = alpha + 2
                }
              }
              None => {
                for alpha, coeff in group.coeffs {
                  if coeff != 0 {
                    out.push(quantum_eq1_term(group.a, group.b, alpha, coeff))
                  }
                }
              }
            }
          None =>
            for alpha, coeff in group.coeffs {
              if coeff != 0 {
                out.push(quantum_eq1_term(group.a, group.b, alpha, coeff))
              }
            }
        }
      }

      for group in eq2_groups {
        match quantum_doubled_int_number(group.a) {
          Some(da) =>
            match quantum_common_signed_coeff(group.coeffs, da) {
              Some(common) => {
                out.push(quantum_scale_expr(common, quantum_eq2_result(group.a, group.c)))
                let mut alpha = -da
                while alpha <= da {
                  let residual = match group.coeffs.get(alpha) {
                    Some(coeff) => coeff - common
                    None => 0
                  }
                  if residual != 0 {
                    out.push(quantum_eq2_term(group.a, group.c, alpha, residual))
                  }
                  alpha = alpha + 2
                }
              }
              None => {
                for alpha, coeff in group.coeffs {
                  if coeff != 0 {
                    out.push(quantum_eq2_term(group.a, group.c, alpha, coeff))
                  }
                }
              }
            }
          None =>
            for alpha, coeff in group.coeffs {
              if coeff != 0 {
                out.push(quantum_eq2_term(group.a, group.c, alpha, coeff))
              }
            }
        }
      }

      @symcore.add(out)
    }
    _ => expr
  }
}

///|
pub fn cg_simp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => quantum_cg_simp_add(@symcore.add(args.map(cg_simp)))
    @symcore.Expr::Mul(args) => @symcore.mul(args.map(cg_simp))
    @symcore.Expr::Pow(base, exp) => @symcore.pow(cg_simp(base), cg_simp(exp))
    @symcore.Expr::Function("Sum", _) => quantum_cg_simp_sum(expr)
    _ => expr
  }
}
