///|
/// B-spline functions.

///|
pub fn bspline_basis(
  d : Expr,
  knots : Expr,
  n : Expr,
  x : Expr,
) -> Expr {
  @symcore.function("bspline_basis", [d, knots, n, x])
}

///|
pub fn bspline_basis_set(
  d : Expr,
  knots : Expr,
  x : Expr,
) -> Expr {
  @symcore.function("bspline_basis_set", [d, knots, x])
}

///|
pub fn interpolating_spline(
  d : Expr,
  x : Expr,
  knots : Expr,
  values : Expr,
) -> Expr {
  @symcore.function("interpolating_spline", [d, x, knots, values])
}
