///|
/// B-spline functions.

///|
pub fn bspline_basis(
  d : @symcore.Expr,
  knots : @symcore.Expr,
  n : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("bspline_basis", [d, knots, n, x])
}

///|
pub fn bspline_basis_set(
  d : @symcore.Expr,
  knots : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("bspline_basis_set", [d, knots, x])
}

///|
pub fn interpolating_spline(
  d : @symcore.Expr,
  x : @symcore.Expr,
  knots : @symcore.Expr,
  values : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("interpolating_spline", [d, x, knots, values])
}
