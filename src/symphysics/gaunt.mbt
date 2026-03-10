///|
/// Exact Gaunt coefficients built from Wigner 3j symbols.

///|
fn gaunt_require_integer(value : @symcore.Expr) -> Unit raise PhysicsError {
  guard expr_integer_value(value) != None else {
    raise PhysicsError::ValueError("expecting integer, got \{@symprint.to_string(value)}")
  }
}

///|
pub fn gaunt(
  l_1 : @symcore.Expr,
  l_2 : @symcore.Expr,
  l_3 : @symcore.Expr,
  m_1 : @symcore.Expr,
  m_2 : @symcore.Expr,
  m_3 : @symcore.Expr,
) -> @symcore.Expr raise PhysicsError {
  gaunt_require_integer(l_1)
  gaunt_require_integer(l_2)
  gaunt_require_integer(l_3)
  gaunt_require_integer(m_1)
  gaunt_require_integer(m_2)
  gaunt_require_integer(m_3)
  @symelem.sqrt(
    expr_div(
      ((@symcore.int(2) * l_1) + @symcore.int(1)) *
        ((@symcore.int(2) * l_2) + @symcore.int(1)) *
        ((@symcore.int(2) * l_3) + @symcore.int(1)),
      @symcore.int(4) * pi_expr(),
    ),
  ) *
    (try! wigner_3j(l_1, l_2, l_3, @symcore.int(0), @symcore.int(0), @symcore.int(0))) *
    (try! wigner_3j(l_1, l_2, l_3, m_1, m_2, m_3))
}
