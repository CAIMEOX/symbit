///|
fn wild_property_resolver(
  property : @symcore.WildProperty,
  expr : @symcore.Expr,
) -> Bool? {
  match property {
    @symcore.WildProperty::Integer => tri_to_bool_option(is_integer(expr))
    @symcore.WildProperty::Rational => tri_to_bool_option(is_rational(expr))
    @symcore.WildProperty::Real => tri_to_bool_option(is_real(expr))
    @symcore.WildProperty::Positive => tri_to_bool_option(is_positive(expr))
    @symcore.WildProperty::Negative =>
      tri_to_bool_option(is_positive(@symcore.mul([@symcore.int(-1), expr])))
    @symcore.WildProperty::Finite => None
    @symcore.WildProperty::Nonzero => tri_to_bool_option(is_nonzero(expr))
  }
}

///|
fn init {
  @symcore.set_wild_property_resolver(wild_property_resolver)
}
