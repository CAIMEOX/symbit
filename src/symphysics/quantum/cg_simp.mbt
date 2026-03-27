///|
/// Simplification rules for `CG(...)` sums aligned with the implemented
/// `sympy.physics.quantum.cg` sum identities.

///|
fn quantum_tuple3(expr : Expr) -> (Expr, Expr, Expr)? {
  match @symcore.tuple_items(expr) {
    Some([a, b, c]) => Some((a, b, c))
    _ => None
  }
}

///|
fn quantum_neg(expr : Expr) -> Expr {
  @symcore.mul([int(-1), expr])
}

///|
fn quantum_kdelta(a : Expr, b : Expr) -> Expr {
  if a == b {
    int(1)
  } else {
    match (a, b) {
      (Expr::Number(lhs), Expr::Number(rhs)) =>
        if lhs == rhs {
          int(1)
        } else {
          int(0)
        }
      _ => @symcore.function("KroneckerDelta", [a, b])
    }
  }
}

///|
fn quantum_cg_args(expr : Expr) -> Array[Expr]? {
  match @symcore.application_args(expr) {
    Some(args) if @symcore.application_has_name(expr, "CG", arity=6) =>
      Some(args)
    _ => None
  }
}

///|
priv struct QuantumEq1Group {
  a : Expr
  b : Expr
  coeffs : Map[Int, Int]
}

///|
priv struct QuantumEq2Group {
  a : Expr
  c : Expr
  coeffs : Map[Int, Int]
}

///|
priv struct QuantumEq9SquareGroup {
  j1 : Expr
  m1 : Expr
  j2 : Expr
  m2 : Expr
  dj1 : Int
  dj2 : Int
  coeffs : Map[Int, Int]
}

///|
priv struct QuantumEq9CrossGroup {
  j1 : Expr
  m1 : Expr
  m1p : Expr
  j2 : Expr
  m2 : Expr
  m2p : Expr
  dj1 : Int
  dj2 : Int
  coeffs : Map[Int, Int]
}

///|
fn quantum_expr_from_doubled_int(value : Int) -> Expr {
  if value % 2 == 0 {
    int(value / 2)
  } else {
    @symcore.rational_from_ints(value, 2) catch {
      _ => int(value) * (int(2) ^ int(-1))
    }
  }
}

///|
fn quantum_doubled_int_number(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) =>
      if n.denominator().equal_int(1) {
        Some((n.numerator() * @bigint.BigInt::from_int(2)).to_int())
      } else if n.denominator().equal_int(2) {
        Some(n.numerator().to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
fn quantum_split_integer_coeff(expr : Expr) -> (Int, Expr)? {
  match expr {
    Expr::Number(n) if n.is_integral() => Some((n.numerator().to_int(), int(1)))
    Expr::Mul(factors) => {
      let mut coeff = 1
      let rest : Array[Expr] = Array::new()
      for factor in factors {
        match factor {
          Expr::Number(n) if n.is_integral() =>
            coeff = coeff * n.numerator().to_int()
          _ => rest.push(factor)
        }
      }
      let core = if rest.is_empty() {
        int(1)
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
  if exp % 2 == 0 {
    1
  } else {
    -1
  }
}

///|
fn quantum_state_key(dj : Int, dm : Int) -> Int {
  (dj + 128) * 512 + (dm + 128)
}

///|
fn quantum_state_key_dj(key : Int) -> Int {
  key / 512 - 128
}

///|
fn quantum_state_key_dm(key : Int) -> Int {
  key % 512 - 128
}

///|
fn quantum_add_group_coeff(
  coeffs : Map[Int, Int],
  alpha : Int,
  coeff : Int,
) -> Unit {
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
fn quantum_common_signed_coeff_states(
  coeffs : Map[Int, Int],
  states : Array[Int],
) -> Int? {
  let mut common : Int? = None
  for state in states {
    match coeffs.get(state) {
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
  }
  common
}

///|
fn quantum_scale_expr(coeff : Int, expr : Expr) -> Expr {
  if coeff == 1 {
    expr
  } else {
    @symcore.mul([int(coeff), expr])
  }
}

///|
fn quantum_find_eq1_group(
  groups : Array[QuantumEq1Group],
  a : Expr,
  b : Expr,
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
  a : Expr,
  c : Expr,
) -> Int? {
  for i in 0..<groups.length() {
    if groups[i].a == a && groups[i].c == c {
      return Some(i)
    }
  }
  None
}

///|
fn quantum_find_eq9_square_group(
  groups : Array[QuantumEq9SquareGroup],
  j1 : Expr,
  m1 : Expr,
  j2 : Expr,
  m2 : Expr,
) -> Int? {
  for i in 0..<groups.length() {
    if groups[i].j1 == j1 &&
      groups[i].m1 == m1 &&
      groups[i].j2 == j2 &&
      groups[i].m2 == m2 {
      return Some(i)
    }
  }
  None
}

///|
fn quantum_find_eq9_cross_group(
  groups : Array[QuantumEq9CrossGroup],
  j1 : Expr,
  m1 : Expr,
  m1p : Expr,
  j2 : Expr,
  m2 : Expr,
  m2p : Expr,
) -> Int? {
  for i in 0..<groups.length() {
    if groups[i].j1 == j1 &&
      groups[i].m1 == m1 &&
      groups[i].m1p == m1p &&
      groups[i].j2 == j2 &&
      groups[i].m2 == m2 &&
      groups[i].m2p == m2p {
      return Some(i)
    }
  }
  None
}

///|
fn quantum_parse_eq1_add_term(expr : Expr) -> (Int, Expr, Expr, Int)? {
  match quantum_split_integer_coeff(expr) {
    Some((coeff, core)) =>
      match quantum_cg_args(core) {
        Some(args) =>
          match
            (
              quantum_doubled_int_number(args[0]),
              quantum_doubled_int_number(args[1]),
            ) {
            (Some(da), Some(dalpha)) =>
              if args[3] == int(0) &&
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
fn quantum_parse_eq2_add_term(expr : Expr) -> (Int, Expr, Expr, Int)? {
  match quantum_split_integer_coeff(expr) {
    Some((coeff, core)) =>
      match quantum_cg_args(core) {
        Some(args) =>
          match
            (
              quantum_doubled_int_number(args[0]),
              quantum_doubled_int_number(args[1]),
            ) {
            (Some(da), Some(dalpha)) =>
              if args[0] == args[2] &&
                args[3] == quantum_neg(args[1]) &&
                args[5] == int(0) &&
                dalpha >= -da &&
                dalpha <= da {
                Some(
                  (
                    coeff * quantum_phase_sign(da, dalpha),
                    args[0],
                    args[4],
                    dalpha,
                  ),
                )
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
fn quantum_parse_eq9_square_add_term(
  expr : Expr,
) -> (Int, Expr, Expr, Expr, Expr, Int, Int, Int, Int)? {
  match quantum_split_integer_coeff(expr) {
    Some((coeff, core)) =>
      match core {
        Expr::Pow(base, exp) if exp == int(2) =>
          match quantum_cg_args(base) {
            Some(args) =>
              match
                (
                  quantum_doubled_int_number(args[0]),
                  quantum_doubled_int_number(args[2]),
                  quantum_doubled_int_number(args[4]),
                  quantum_doubled_int_number(args[5]),
                ) {
                (Some(dj1), Some(dj2), Some(dj3), Some(dm3)) =>
                  Some(
                    (
                      coeff,
                      args[0],
                      args[1],
                      args[2],
                      args[3],
                      dj1,
                      dj2,
                      dj3,
                      dm3,
                    ),
                  )
                _ => None
              }
            None => None
          }
        _ => None
      }
    None => None
  }
}

///|
fn quantum_parse_eq9_cross_add_term(
  expr : Expr,
) -> (Int, Expr, Expr, Expr, Expr, Expr, Expr, Int, Int, Int, Int)? {
  match quantum_split_integer_coeff(expr) {
    Some((coeff, core)) =>
      match core {
        Expr::Mul(args) if args.length() == 2 =>
          match (quantum_cg_args(args[0]), quantum_cg_args(args[1])) {
            (Some(a1), Some(a2)) =>
              match
                (
                  quantum_doubled_int_number(a1[0]),
                  quantum_doubled_int_number(a1[2]),
                  quantum_doubled_int_number(a1[4]),
                  quantum_doubled_int_number(a1[5]),
                ) {
                (Some(dj1), Some(dj2), Some(dj3), Some(dm3)) =>
                  if a1[0] == a2[0] &&
                    a1[2] == a2[2] &&
                    a1[4] == a2[4] &&
                    a1[5] == a2[5] {
                    Some(
                      (
                        coeff,
                        a1[0],
                        a1[1],
                        a2[1],
                        a1[2],
                        a1[3],
                        a2[3],
                        dj1,
                        dj2,
                        dj3,
                        dm3,
                      ),
                    )
                  } else {
                    None
                  }
                _ => None
              }
            _ => None
          }
        _ => None
      }
    None => None
  }
}

///|
fn quantum_eq1_result(a : Expr, b : Expr) -> Expr {
  @symcore.mul([
    @symcore.add([@symcore.mul([int(2), a]), int(1)]),
    quantum_kdelta(b, int(0)),
  ])
}

///|
fn quantum_eq2_result(a : Expr, c : Expr) -> Expr {
  @symcore.mul([
    @symcore.function("sqrt", [
      @symcore.add([@symcore.mul([int(2), a]), int(1)]),
    ]),
    quantum_kdelta(c, int(0)),
  ])
}

///|
fn quantum_eq1_term(a : Expr, b : Expr, dalpha : Int, coeff : Int) -> Expr {
  quantum_scale_expr(
    coeff,
    @symcore.function("CG", [
      a,
      quantum_expr_from_doubled_int(dalpha),
      b,
      int(0),
      a,
      quantum_expr_from_doubled_int(dalpha),
    ]),
  )
}

///|
fn quantum_eq2_term(
  a : Expr,
  c : Expr,
  dalpha : Int,
  scalar_coeff : Int,
) -> Expr {
  let da = match quantum_doubled_int_number(a) {
    Some(value) => value
    None => 0
  }
  let actual_coeff = scalar_coeff * quantum_phase_sign(da, dalpha)
  quantum_scale_expr(
    actual_coeff,
    @symcore.function("CG", [
      a,
      quantum_expr_from_doubled_int(dalpha),
      a,
      quantum_neg(quantum_expr_from_doubled_int(dalpha)),
      c,
      int(0),
    ]),
  )
}

///|
fn quantum_expected_eq9_states(
  dj1 : Int,
  dj2 : Int,
  m1 : Expr,
  m2 : Expr,
) -> Array[Int] {
  let states : Array[Int] = Array::new()
  match (quantum_doubled_int_number(m1), quantum_doubled_int_number(m2)) {
    (Some(dm1), Some(dm2)) => {
      let dm = dm1 + dm2
      let mut dj = (dj1 - dj2).abs()
      while dj <= dj1 + dj2 {
        if dj >= dm.abs() {
          states.push(quantum_state_key(dj, dm))
        }
        dj = dj + 2
      }
    }
    _ => {
      let mut dj = (dj1 - dj2).abs()
      while dj <= dj1 + dj2 {
        let mut dm = -dj
        while dm <= dj {
          states.push(quantum_state_key(dj, dm))
          dm = dm + 2
        }
        dj = dj + 2
      }
    }
  }
  states
}

///|
fn quantum_eq9_square_term(
  j1 : Expr,
  m1 : Expr,
  j2 : Expr,
  m2 : Expr,
  key : Int,
  coeff : Int,
) -> Expr {
  let j3 = quantum_expr_from_doubled_int(quantum_state_key_dj(key))
  let m3 = quantum_expr_from_doubled_int(quantum_state_key_dm(key))
  quantum_scale_expr(
    coeff,
    @symcore.function("CG", [j1, m1, j2, m2, j3, m3]) ^ int(2),
  )
}

///|
fn quantum_eq9_cross_term(
  j1 : Expr,
  m1 : Expr,
  m1p : Expr,
  j2 : Expr,
  m2 : Expr,
  m2p : Expr,
  key : Int,
  coeff : Int,
) -> Expr {
  let j3 = quantum_expr_from_doubled_int(quantum_state_key_dj(key))
  let m3 = quantum_expr_from_doubled_int(quantum_state_key_dm(key))
  quantum_scale_expr(
    coeff,
    @symcore.mul([
      @symcore.function("CG", [j1, m1, j2, m2, j3, m3]),
      @symcore.function("CG", [j1, m1p, j2, m2p, j3, m3]),
    ]),
  )
}

///|
fn quantum_parse_sum_871_1(expr : Expr) -> Expr? {
  match @symcore.application_args(expr) {
    Some([body, limit]) if @symcore.application_has_name(expr, "Sum", arity=2) =>
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
            zero == int(0) &&
            lower == quantum_neg(a) &&
            upper == a {
            Some(
              @symcore.mul([
                @symcore.add([@symcore.mul([int(2), a]), int(1)]),
                quantum_kdelta(b, int(0)),
              ]),
            )
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
fn quantum_parse_sum_871_2(expr : Expr) -> Expr? {
  match @symcore.application_args(expr) {
    Some([body, limit]) if @symcore.application_has_name(expr, "Sum", arity=2) =>
      match quantum_tuple3(limit) {
        Some((alpha, lower, upper)) =>
          match body {
            Expr::Mul(factors) => {
              let mut phase_exp : Expr? = None
              let mut a_val : Expr? = None
              let mut c_val : Expr? = None
              for factor in factors {
                match factor {
                  Expr::Pow(base, exp) if base == int(-1) =>
                    phase_exp = Some(exp)
                  _ =>
                    match quantum_cg_args(factor) {
                      Some(args) =>
                        if args[1] == alpha &&
                          args[0] == args[2] &&
                          args[3] == quantum_neg(alpha) &&
                          args[5] == int(0) {
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
                    Some(
                      @symcore.mul([
                        @symcore.function("sqrt", [
                          @symcore.add([@symcore.mul([int(2), a]), int(1)]),
                        ]),
                        quantum_kdelta(c, int(0)),
                      ]),
                    )
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
fn quantum_parse_sum_872_4(expr : Expr) -> Expr? {
  match @symcore.application_args(expr) {
    Some([body, limit1, limit2]) if @symcore.application_has_name(
        expr,
        "Sum",
        arity=3,
      ) =>
      match (quantum_tuple3(limit1), quantum_tuple3(limit2)) {
        (Some((alpha, lower_a, upper_a)), Some((beta, lower_b, upper_b))) =>
          match body {
            Expr::Pow(base, exp) if exp == int(2) =>
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
                    Some(int(1))
                  } else {
                    None
                  }
                }
                None => None
              }
            Expr::Mul(args) if args.length() == 2 =>
              match (quantum_cg_args(args[0]), quantum_cg_args(args[1])) {
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
                    Some(
                      @symcore.mul([
                        quantum_kdelta(args1[4], args2[4]),
                        quantum_kdelta(args1[5], args2[5]),
                      ]),
                    )
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
fn quantum_cg_simp_sum(expr : Expr) -> Expr {
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
fn quantum_cg_simp_add(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
      let eq1_groups : Array[QuantumEq1Group] = Array::new()
      let eq2_groups : Array[QuantumEq2Group] = Array::new()
      let eq9_square_groups : Array[QuantumEq9SquareGroup] = Array::new()
      let eq9_cross_groups : Array[QuantumEq9CrossGroup] = Array::new()
      let others : Array[Expr] = Array::new()
      for arg in args {
        match quantum_parse_eq1_add_term(arg) {
          Some((coeff, a, b, dalpha)) =>
            match quantum_find_eq1_group(eq1_groups, a, b) {
              Some(idx) =>
                quantum_add_group_coeff(eq1_groups[idx].coeffs, dalpha, coeff)
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
                  Some(idx) =>
                    quantum_add_group_coeff(
                      eq2_groups[idx].coeffs,
                      dalpha,
                      coeff,
                    )
                  None => {
                    let coeffs : Map[Int, Int] = {}
                    quantum_add_group_coeff(coeffs, dalpha, coeff)
                    eq2_groups.push(QuantumEq2Group::{ a, c, coeffs })
                  }
                }
              None =>
                match quantum_parse_eq9_square_add_term(arg) {
                  Some((coeff, j1, m1, j2, m2, dj1, dj2, dj3, dm3)) => {
                    let state = quantum_state_key(dj3, dm3)
                    match
                      quantum_find_eq9_square_group(
                        eq9_square_groups, j1, m1, j2, m2,
                      ) {
                      Some(idx) =>
                        quantum_add_group_coeff(
                          eq9_square_groups[idx].coeffs,
                          state,
                          coeff,
                        )
                      None => {
                        let coeffs : Map[Int, Int] = {}
                        quantum_add_group_coeff(coeffs, state, coeff)
                        eq9_square_groups.push(QuantumEq9SquareGroup::{
                          j1,
                          m1,
                          j2,
                          m2,
                          dj1,
                          dj2,
                          coeffs,
                        })
                      }
                    }
                  }
                  None =>
                    match quantum_parse_eq9_cross_add_term(arg) {
                      Some(
                        (coeff, j1, m1, m1p, j2, m2, m2p, dj1, dj2, dj3, dm3)
                      ) => {
                        let state = quantum_state_key(dj3, dm3)
                        match
                          quantum_find_eq9_cross_group(
                            eq9_cross_groups, j1, m1, m1p, j2, m2, m2p,
                          ) {
                          Some(idx) =>
                            quantum_add_group_coeff(
                              eq9_cross_groups[idx].coeffs,
                              state,
                              coeff,
                            )
                          None => {
                            let coeffs : Map[Int, Int] = {}
                            quantum_add_group_coeff(coeffs, state, coeff)
                            eq9_cross_groups.push(QuantumEq9CrossGroup::{
                              j1,
                              m1,
                              m1p,
                              j2,
                              m2,
                              m2p,
                              dj1,
                              dj2,
                              coeffs,
                            })
                          }
                        }
                      }
                      None => others.push(arg)
                    }
                }
            }
        }
      }

      let out : Array[Expr] = Array::new()
      for item in others {
        out.push(item)
      }

      for group in eq1_groups {
        match quantum_doubled_int_number(group.a) {
          Some(da) =>
            match quantum_common_signed_coeff(group.coeffs, da) {
              Some(common) => {
                out.push(
                  quantum_scale_expr(
                    common,
                    quantum_eq1_result(group.a, group.b),
                  ),
                )
                let mut alpha = -da
                while alpha <= da {
                  let residual = match group.coeffs.get(alpha) {
                    Some(coeff) => coeff - common
                    None => 0
                  }
                  if residual != 0 {
                    out.push(
                      quantum_eq1_term(group.a, group.b, alpha, residual),
                    )
                  }
                  alpha = alpha + 2
                }
              }
              None =>
                for alpha, coeff in group.coeffs {
                  if coeff != 0 {
                    out.push(quantum_eq1_term(group.a, group.b, alpha, coeff))
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
                out.push(
                  quantum_scale_expr(
                    common,
                    quantum_eq2_result(group.a, group.c),
                  ),
                )
                let mut alpha = -da
                while alpha <= da {
                  let residual = match group.coeffs.get(alpha) {
                    Some(coeff) => coeff - common
                    None => 0
                  }
                  if residual != 0 {
                    out.push(
                      quantum_eq2_term(group.a, group.c, alpha, residual),
                    )
                  }
                  alpha = alpha + 2
                }
              }
              None =>
                for alpha, coeff in group.coeffs {
                  if coeff != 0 {
                    out.push(quantum_eq2_term(group.a, group.c, alpha, coeff))
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

      for group in eq9_square_groups {
        let states = quantum_expected_eq9_states(
          group.dj1,
          group.dj2,
          group.m1,
          group.m2,
        )
        match quantum_common_signed_coeff_states(group.coeffs, states) {
          Some(common) => {
            out.push(int(common))
            for state in states {
              let residual = match group.coeffs.get(state) {
                Some(coeff) => coeff - common
                None => 0
              }
              if residual != 0 {
                out.push(
                  quantum_eq9_square_term(
                    group.j1,
                    group.m1,
                    group.j2,
                    group.m2,
                    state,
                    residual,
                  ),
                )
              }
            }
            for state, coeff in group.coeffs {
              if states.contains(state) || coeff == 0 {
                ()
              } else {
                out.push(
                  quantum_eq9_square_term(
                    group.j1,
                    group.m1,
                    group.j2,
                    group.m2,
                    state,
                    coeff,
                  ),
                )
              }
            }
          }
          None =>
            for state, coeff in group.coeffs {
              if coeff != 0 {
                out.push(
                  quantum_eq9_square_term(
                    group.j1,
                    group.m1,
                    group.j2,
                    group.m2,
                    state,
                    coeff,
                  ),
                )
              }
            }
        }
      }

      for group in eq9_cross_groups {
        let states = quantum_expected_eq9_states(
          group.dj1,
          group.dj2,
          group.m1,
          group.m2,
        )
        let delta = @symcore.mul([
          quantum_kdelta(group.m1, group.m1p),
          quantum_kdelta(group.m2, group.m2p),
        ])
        match quantum_common_signed_coeff_states(group.coeffs, states) {
          Some(common) => {
            out.push(quantum_scale_expr(common, delta))
            for state in states {
              let residual = match group.coeffs.get(state) {
                Some(coeff) => coeff - common
                None => 0
              }
              if residual != 0 {
                out.push(
                  quantum_eq9_cross_term(
                    group.j1,
                    group.m1,
                    group.m1p,
                    group.j2,
                    group.m2,
                    group.m2p,
                    state,
                    residual,
                  ),
                )
              }
            }
            for state, coeff in group.coeffs {
              if states.contains(state) || coeff == 0 {
                ()
              } else {
                out.push(
                  quantum_eq9_cross_term(
                    group.j1,
                    group.m1,
                    group.m1p,
                    group.j2,
                    group.m2,
                    group.m2p,
                    state,
                    coeff,
                  ),
                )
              }
            }
          }
          None =>
            for state, coeff in group.coeffs {
              if coeff != 0 {
                out.push(
                  quantum_eq9_cross_term(
                    group.j1,
                    group.m1,
                    group.m1p,
                    group.j2,
                    group.m2,
                    group.m2p,
                    state,
                    coeff,
                  ),
                )
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
pub fn cg_simp(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => quantum_cg_simp_add(@symcore.add(args.map(cg_simp)))
    Expr::Mul(args) => @symcore.mul(args.map(cg_simp))
    Expr::Pow(base, exp) => @symcore.pow(cg_simp(base), cg_simp(exp))
    _ if @symcore.application_has_name(expr, "Sum") => quantum_cg_simp_sum(expr)
    _ => expr
  }
}
