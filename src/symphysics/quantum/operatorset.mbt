///|
/// Mappings between operator families and their associated eigenstates.
///
/// SymPy exposes this through `operators_to_state` and `state_to_operators`.
/// MoonBit does not have Python classes, so the API works directly on
/// expressions and explicit arrays of operator expressions.

///|
fn quantum_default_ket() -> @symcore.Expr {
  ket([@symcore.symbol("psi")]).as_expr()
}

///|
fn quantum_default_operator() -> @symcore.Expr {
  operator([@symcore.symbol("O")]).as_expr()
}

///|
fn operatorset_half() -> @symcore.Expr {
  try! @symcore.rational_from_ints(1, 2)
}

///|
pub fn operators_to_state(operator_expr : @symcore.Expr) -> @symcore.Expr? {
  match cartesian_operator_to_state(operator_expr) {
    Some(state) => Some(state)
    None =>
      match operator_expr {
        @symcore.Expr::Function("Operator", _) => Some(quantum_default_ket())
        @symcore.Expr::Symbol(name) if name == "Jx" =>
          Some(jx_ket(operatorset_half(), operatorset_half()).as_expr())
        @symcore.Expr::Symbol(name) if name == "Jy" =>
          Some(jy_ket(operatorset_half(), operatorset_half()).as_expr())
        @symcore.Expr::Symbol(name) if name == "Jz" =>
          Some(jz_ket(operatorset_half(), operatorset_half()).as_expr())
        _ => None
      }
  }
}

///|
pub fn operators_to_state_many(
  operator_exprs : Array[@symcore.Expr],
) -> @symcore.Expr? {
  if operator_exprs.length() == 1 {
    return operators_to_state(operator_exprs[0])
  }
  let names = operator_exprs.map(expr => @symprint.to_string(expr))
  names.sort()
  if names == ["J2", "Jx"] {
    return Some(jx_ket(operatorset_half(), operatorset_half()).as_expr())
  }
  if names == ["J2", "Jy"] {
    return Some(jy_ket(operatorset_half(), operatorset_half()).as_expr())
  }
  if names == ["J2", "Jz"] {
    return Some(jz_ket(operatorset_half(), operatorset_half()).as_expr())
  }
  let has_x = names.contains("XOp(X)") ||
    names.contains("XOp()") ||
    names.contains("X")
  let has_y = names.contains("YOp(Y)") ||
    names.contains("YOp()") ||
    names.contains("Y")
  let has_z = names.contains("ZOp(Z)") ||
    names.contains("ZOp()") ||
    names.contains("Z")
  if has_x && has_y && has_z {
    Some(position_ket_3d())
  } else {
    None
  }
}

///|
pub fn state_to_operators(state_expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match cartesian_state_to_operator(state_expr) {
    Some(ops) => Some(ops)
    None =>
      match state_expr {
        @symcore.Expr::Function("Ket", _) | @symcore.Expr::Function("Bra", _) =>
          Some([quantum_default_operator()])
        @symcore.Expr::Function("JxKet", _)
        | @symcore.Expr::Function("JxBra", _) => Some([j2(), jx()])
        @symcore.Expr::Function("JyKet", _)
        | @symcore.Expr::Function("JyBra", _) => Some([j2(), jy()])
        @symcore.Expr::Function("JzKet", _)
        | @symcore.Expr::Function("JzBra", _) => Some([j2(), jz()])
        _ => None
      }
  }
}
