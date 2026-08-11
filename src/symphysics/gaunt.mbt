///|
/// Exact Gaunt coefficients built from Wigner 3j symbols.

///|
fn gaunt_require_integer(value : Expr) -> Unit raise PhysicsError {
  guard expr_integer_value(value) != None else {
    raise ValueError("expecting integer, got \{@symprint.pretty_string(value)}")
  }
}

///|
pub fn gaunt(
  l_1 : Expr,
  l_2 : Expr,
  l_3 : Expr,
  m_1 : Expr,
  m_2 : Expr,
  m_3 : Expr,
) -> Expr raise PhysicsError {
  gaunt_require_integer(l_1)
  gaunt_require_integer(l_2)
  gaunt_require_integer(l_3)
  gaunt_require_integer(m_1)
  gaunt_require_integer(m_2)
  gaunt_require_integer(m_3)
  @symelem.sqrt(
    expr_div(
      (int(2) * l_1 + int(1)) *
      (int(2) * l_2 + int(1)) *
      (int(2) * l_3 + int(1)),
      int(4) * pi_expr(),
    ),
  ) *
  wigner_3j(l_1, l_2, l_3, int(0), int(0), int(0)) *
  wigner_3j(l_1, l_2, l_3, m_1, m_2, m_3)
}
