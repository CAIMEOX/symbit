///|
/// Angular-momentum operators and Jz-basis eigenstates.
///
/// This first spin slice covers the uncoupled Jz basis: the global operators
/// `Jplus`, `Jminus`, `Jx`, `Jy`, `Jz`, `J2`, the eigenstates `JzKet` and
/// `JzBra`, exact ladder-operator action, and exact Jz-basis matrix
/// representations.

///|
fn spin_op_symbol(name : String) -> @symcore.Expr {
  @symcore.symbol(name)
}

///|
pub fn jplus() -> @symcore.Expr {
  spin_op_symbol("Jplus")
}

///|
pub fn jminus() -> @symcore.Expr {
  spin_op_symbol("Jminus")
}

///|
pub fn jx() -> @symcore.Expr {
  spin_op_symbol("Jx")
}

///|
pub fn jy() -> @symcore.Expr {
  spin_op_symbol("Jy")
}

///|
pub fn jz() -> @symcore.Expr {
  spin_op_symbol("Jz")
}

///|
pub fn j2() -> @symcore.Expr {
  spin_op_symbol("J2")
}

///|
pub struct JzState {
  j : @symcore.Expr
  m : @symcore.Expr
  is_bra : Bool
} derive(Eq)

///|
pub struct RotationExpr {
  alpha : @symcore.Expr
  beta : @symcore.Expr
  gamma : @symcore.Expr
} derive(Eq)

///|
pub struct WignerDExpr {
  j : @symcore.Expr
  m : @symcore.Expr
  mp : @symcore.Expr
  alpha : @symcore.Expr
  beta : @symcore.Expr
  gamma : @symcore.Expr
} derive(Eq)

///|
pub fn jz_ket(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  JzState::{ j, m, is_bra: false }
}

///|
pub fn jz_bra(j : @symcore.Expr, m : @symcore.Expr) -> JzState {
  JzState::{ j, m, is_bra: true }
}

///|
pub fn rotation(
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  gamma : @symcore.Expr,
) -> RotationExpr {
  RotationExpr::{ alpha, beta, gamma }
}

///|
pub fn rotation_d(
  j : @symcore.Expr,
  m : @symcore.Expr,
  mp : @symcore.Expr,
  beta : @symcore.Expr,
) -> WignerDExpr {
  WignerDExpr::{
    j,
    m,
    mp,
    alpha: @symcore.int(0),
    beta,
    gamma: @symcore.int(0),
  }
}

///|
pub fn rotation_D(
  j : @symcore.Expr,
  m : @symcore.Expr,
  mp : @symcore.Expr,
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  gamma : @symcore.Expr,
) -> WignerDExpr {
  WignerDExpr::{ j, m, mp, alpha, beta, gamma }
}

///|
pub fn JzState::as_expr(self : JzState) -> @symcore.Expr {
  if self.is_bra {
    @symcore.raw_function("JzBra", [self.j, self.m])
  } else {
    @symcore.raw_function("JzKet", [self.j, self.m])
  }
}

///|
pub fn RotationExpr::as_expr(self : RotationExpr) -> @symcore.Expr {
  @symcore.raw_function("Rotation", [self.alpha, self.beta, self.gamma])
}

///|
pub fn RotationExpr::to_string(self : RotationExpr) -> String {
  "R(\{@symprint.to_string(self.alpha)},\{@symprint.to_string(self.beta)},\{@symprint.to_string(self.gamma)})"
}

///|
pub fn RotationExpr::inverse(self : RotationExpr) -> RotationExpr {
  rotation(
    @symcore.int(-1) * self.gamma,
    @symcore.int(-1) * self.beta,
    @symcore.int(-1) * self.alpha,
  )
}

///|
pub fn WignerDExpr::as_expr(self : WignerDExpr) -> @symcore.Expr {
  @symcore.raw_function("WignerD", [
    self.j,
    self.m,
    self.mp,
    self.alpha,
    self.beta,
    self.gamma,
  ])
}

///|
pub fn WignerDExpr::to_string(self : WignerDExpr) -> String {
  if self.alpha == @symcore.int(0) && self.gamma == @symcore.int(0) {
    "d(\{@symprint.to_string(self.j)},\{@symprint.to_string(self.m)},\{@symprint.to_string(self.mp)},\{@symprint.to_string(self.beta)})"
  } else {
    "D(\{@symprint.to_string(self.j)},\{@symprint.to_string(self.m)},\{@symprint.to_string(self.mp)},\{@symprint.to_string(self.alpha)},\{@symprint.to_string(self.beta)},\{@symprint.to_string(self.gamma)})"
  }
}

///|
pub fn JzState::to_string(self : JzState) -> String {
  let contents = "\{@symprint.to_string(self.j)},\{@symprint.to_string(self.m)}"
  if self.is_bra {
    "<\{contents}|"
  } else {
    "|\{contents}>"
  }
}

///|
pub fn JzState::dual(self : JzState) -> JzState {
  JzState::{ j: self.j, m: self.m, is_bra: !self.is_bra }
}

///|
pub fn m_values(
  j : @symcore.Expr,
) -> (Int, Array[@symcore.Expr]) raise @symphysics.PhysicsError {
  let size_expr = @symcore.int(2) * j + @symcore.int(1)
  match size_expr {
    @symcore.Expr::Number(n) if n.is_integral() && n.numerator().to_int() > 0 => {
      let size = n.numerator().to_int()
      let values : Array[@symcore.Expr] = []
      for idx in 0..<size {
        values.push(j - @symcore.int(idx))
      }
      (size, values)
    }
    _ =>
      raise @symphysics.PhysicsError::ValueError(
        "Only integer or half-integer j values are supported for explicit spin bases",
      )
  }
}

///|
pub fn jz_state_from_expr(expr : @symcore.Expr) -> JzState? {
  match expr {
    @symcore.Expr::Function(name, args) if (name == "JzKet" || name == "JzBra") &&
      args.length() == 2 =>
      Some(JzState::{ j: args[0], m: args[1], is_bra: name == "JzBra" })
    _ => None
  }
}

///|
pub fn rotation_from_expr(expr : @symcore.Expr) -> RotationExpr? {
  match expr {
    @symcore.Expr::Function("Rotation", args) if args.length() == 3 =>
      Some(rotation(args[0], args[1], args[2]))
    _ => None
  }
}

///|
pub fn wigner_d_from_expr(expr : @symcore.Expr) -> WignerDExpr? {
  match expr {
    @symcore.Expr::Function("WignerD", args) if args.length() == 6 =>
      Some(rotation_D(args[0], args[1], args[2], args[3], args[4], args[5]))
    _ => None
  }
}

///|
fn spin_m_index(
  j : @symcore.Expr,
  value : @symcore.Expr,
) -> Int raise @symphysics.PhysicsError {
  let (_, values) = m_values(j)
  for idx in 0..<values.length() {
    if values[idx] == value {
      return idx
    }
  }
  raise @symphysics.PhysicsError::ValueError(
    "Invalid magnetic quantum number for the given j",
  )
}

///|
fn spin_wigner_d_value(
  item : WignerDExpr,
  evaluate? : Bool = false,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  if item.alpha == @symcore.int(0) &&
    item.beta == @symcore.int(0) &&
    item.gamma == @symcore.int(0) {
    if item.m == item.mp {
      return @symcore.int(1)
    } else {
      return @symcore.int(0)
    }
  }
  if !evaluate {
    return item.as_expr()
  }
  let matrix = try! @symphysics.wigner_d(
    item.j,
    item.alpha,
    item.beta,
    item.gamma,
  )
  let row = try! spin_m_index(item.j, item.mp)
  let col = try! spin_m_index(item.j, item.m)
  matrix.get(row, col)
}

///|
pub fn WignerDExpr::doit(
  self : WignerDExpr,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  try! spin_wigner_d_value(self, evaluate=true)
}

///|
fn spin_ladder_coeff(
  j : @symcore.Expr,
  m : @symcore.Expr,
  step : Int,
) -> @symcore.Expr {
  if step > 0 {
    @symcore.raw_function("sqrt", [
      j * (j + @symcore.int(1)) - m * (m + @symcore.int(1)),
    ])
  } else {
    @symcore.raw_function("sqrt", [
      j * (j + @symcore.int(1)) - m * (m - @symcore.int(1)),
    ])
  }
}

///|
pub fn spin_apply_operator_to_ket(
  op_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (rotation_from_expr(op_expr), jz_state_from_expr(ket_expr)) {
    (Some(op), Some(state)) if !state.is_bra => {
      let (_, mvals) = try! m_values(state.j)
      let terms : Array[@symcore.Expr] = []
      for mp in mvals {
        let coeff = try! spin_wigner_d_value(
          rotation_D(state.j, state.m, mp, op.alpha, op.beta, op.gamma),
          evaluate=true,
        )
        if coeff != @symcore.int(0) {
          terms.push(coeff * jz_ket(state.j, mp).as_expr())
        }
      }
      Some(quantum_add_from_args_preserve(terms))
    }
    _ =>
      match (op_expr, jz_state_from_expr(ket_expr)) {
        (@symcore.Expr::Symbol(name), Some(state)) if !state.is_bra => {
          let j = state.j
          let m = state.m
          match name {
            "Jz" => Some(hbar * m * ket_expr)
            "J2" =>
              Some(
                (hbar ^ @symcore.int(2)) * j * (j + @symcore.int(1)) * ket_expr,
              )
            "Jplus" =>
              if m == j {
                Some(@symcore.int(0))
              } else {
                Some(
                  hbar *
                  spin_ladder_coeff(j, m, 1) *
                  jz_ket(j, m + @symcore.int(1)).as_expr(),
                )
              }
            "Jminus" =>
              if m == @symcore.int(-1) * j {
                Some(@symcore.int(0))
              } else {
                Some(
                  hbar *
                  spin_ladder_coeff(j, m, -1) *
                  jz_ket(j, m - @symcore.int(1)).as_expr(),
                )
              }
            "Jx" =>
              Some(
                try! (@symcore.rational_from_ints(1, 2) *
                (
                  spin_apply_operator_to_ket(jplus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  ) +
                  spin_apply_operator_to_ket(jminus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  )
                )),
              )
            "Jy" =>
              Some(
                try! (@symcore.rational_from_ints(1, 2) *
                @symcore.int(-1) *
                @symcore.symbol("I") *
                (
                  spin_apply_operator_to_ket(jplus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  ) -
                  spin_apply_operator_to_ket(jminus(), ket_expr).unwrap_or(
                    @symcore.int(0),
                  )
                )),
              )
            _ => None
          }
        }
        _ => None
      }
  }
}

///|
fn spin_op_matrix_element(
  op_expr : @symcore.Expr,
  j : @symcore.Expr,
  m : @symcore.Expr,
  mp : @symcore.Expr,
) -> @symcore.Expr {
  match op_expr {
    @symcore.Expr::Symbol(name) =>
      match name {
        "Jz" => if m == mp { hbar * mp } else { @symcore.int(0) }
        "J2" =>
          if m == mp {
            (hbar ^ @symcore.int(2)) * j * (j + @symcore.int(1))
          } else {
            @symcore.int(0)
          }
        "Jplus" =>
          if m == mp + @symcore.int(1) {
            hbar * spin_ladder_coeff(j, mp, 1)
          } else {
            @symcore.int(0)
          }
        "Jminus" =>
          if m == mp - @symcore.int(1) {
            hbar * spin_ladder_coeff(j, mp, -1)
          } else {
            @symcore.int(0)
          }
        "Jx" =>
          try! (@symcore.rational_from_ints(1, 2) *
          (
            spin_op_matrix_element(jplus(), j, m, mp) +
            spin_op_matrix_element(jminus(), j, m, mp)
          ))
        "Jy" =>
          try! (@symcore.rational_from_ints(1, 2) *
          @symcore.int(-1) *
          @symcore.symbol("I") *
          (
            spin_op_matrix_element(jplus(), j, m, mp) -
            spin_op_matrix_element(jminus(), j, m, mp)
          ))
        _ => @symcore.int(0)
      }
    _ => @symcore.int(0)
  }
}

///|
pub fn represent_spin_jz_operator(
  op_expr : @symcore.Expr,
  j : @symcore.Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let (size, mvals) = m_values(j)
  let rows : Array[Array[@symcore.Expr]] = []
  for p in 0..<size {
    let row : Array[@symcore.Expr] = []
    for q in 0..<size {
      row.push(spin_op_matrix_element(op_expr, j, mvals[p], mvals[q]))
    }
    rows.push(row)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn represent_spin_jz_state(
  state_expr : @symcore.Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match jz_state_from_expr(state_expr) {
    Some(state) => {
      let (size, mvals) = m_values(state.j)
      if state.is_bra {
        let row = Array::make(size, @symcore.int(0))
        for idx in 0..<size {
          if mvals[idx] == state.m {
            row[idx] = @symcore.int(1)
          }
        }
        @symphysics.explicit_matrix_from_rows([row])
      } else {
        let rows : Array[Array[@symcore.Expr]] = []
        for idx in 0..<size {
          rows.push([
            if mvals[idx] == state.m {
              @symcore.int(1)
            } else {
              @symcore.int(0)
            },
          ])
        }
        @symphysics.explicit_matrix_from_rows(rows)
      }
    }
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "Expected a Jz basis spin state",
      )
  }
}

///|
pub fn represent_spin_rotation(
  expr : @symcore.Expr,
  j : @symcore.Expr,
  evaluate? : Bool = false,
) -> @symphysics.ExplicitMatrix? raise @symphysics.PhysicsError {
  match rotation_from_expr(expr) {
    Some(op) => {
      let (_, mvals) = try! m_values(j)
      let rows : Array[Array[@symcore.Expr]] = []
      for m in mvals {
        let row : Array[@symcore.Expr] = []
        for mp in mvals {
          row.push(
            try! spin_wigner_d_value(
              rotation_D(j, m, mp, op.alpha, op.beta, op.gamma),
              evaluate~,
            ),
          )
        }
        rows.push(row)
      }
      Some(try! @symphysics.explicit_matrix_from_rows(rows))
    }
    None => None
  }
}
