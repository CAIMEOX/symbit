///|
fn wild_property_resolver(
  property : @symcore.WildProperty,
  expr : @symcore.Expr,
) -> Bool? {
  match property {
    Symbol =>
      Some(
        match @symcore.expr_form(expr) {
          Symbol(_) | Dummy(_, _) | Wild(_, _, _) => true
          _ => false
        },
      )
    Integer => tri_to_bool_option(is_integer(expr))
    Rational => tri_to_bool_option(is_rational(expr))
    Real => tri_to_bool_option(is_real(expr))
    Positive => tri_to_bool_option(is_positive(expr))
    Negative =>
      tri_to_bool_option(is_positive(@symcore.mul([@symcore.int(-1), expr])))
    Finite =>
      if @symcore.is_number_atom(expr) {
        Some(@symcore.is_finite_number_atom(expr))
      } else {
        tri_to_bool_option(ask(q_finite(expr)) catch { _ => return None })
      }
    Nonzero => tri_to_bool_option(is_nonzero(expr))
  }
}

///|
fn init {
  @symcore.set_wild_property_resolver(wild_property_resolver)
}
