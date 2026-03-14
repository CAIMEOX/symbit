///|
/// Additional `Vector` methods aligned with SymPy's vector surface.

///|
pub fn Vector::truediv(
  self : Vector,
  scalar : @symcore.Expr,
) -> Vector raise VectorError {
  if expr_is_zero(scalar) {
    raise VectorError::ValueError("division by zero")
  }
  self.scale(simplify_expr(scalar ^ neg_one_expr()))
}

///|
pub fn Vector::magnitude(self : Vector) -> @symcore.Expr raise VectorError {
  if self.is_zero() {
    return zero_expr()
  }
  let anchor = frame_registry_get(self.args[0].0)
  simplify_expr(@symelem.sqrt(components_norm_sq(self.components_in(anchor))))
}

///|
pub fn Vector::angle_between(
  self : Vector,
  other : Vector,
) -> @symcore.Expr raise VectorError {
  let lhs_mag = self.magnitude()
  let rhs_mag = other.magnitude()
  if expr_is_zero(lhs_mag) || expr_is_zero(rhs_mag) {
    raise VectorError::ValueError("angle is undefined for zero vectors")
  }
  let cosine = simplify_expr(
    self.dot(other) * ((lhs_mag * rhs_mag) ^ neg_one_expr()),
  )
  if expr_is_zero(cosine) {
    return simplify_expr(
      @symcore.symbol("pi") * (try! @symcore.rational_from_ints(1, 2)),
    )
  }
  if expr_eq(cosine, one_expr()) {
    return zero_expr()
  }
  if expr_eq(cosine, neg_one_expr()) {
    return @symcore.symbol("pi")
  }
  simplify_expr(@symelem.acos(cosine))
}

///|
pub fn Vector::doit(self : Vector) -> Vector {
  self.simplify()
}
