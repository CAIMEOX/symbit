///|
/// B-spline functions.
///
/// Current Limits:
/// - These front doors build symbolic spline applications.
/// - Knot validation, piecewise expansion, and interpolation solving are not
///   implemented here.

///|
/// Build a single B-spline basis expression.
///
/// - Does: Builds `bspline_basis(d, knots, n, x)`.
/// - Input: Degree, knot data, basis index, and evaluation variable/value.
/// - Returns: A symbolic B-spline basis expression.
/// - Limits: Does not validate knot shape or expand the piecewise spline.
pub fn bspline_basis(d : Expr, knots : Expr, n : Expr, x : Expr) -> Expr {
  @symcore.function("bspline_basis", [d, knots, n, x])
}

///|
/// Build a B-spline basis-set expression.
///
/// - Does: Builds `bspline_basis_set(d, knots, x)`.
/// - Input: Degree, knot data, and evaluation variable/value.
/// - Returns: A symbolic B-spline basis-set expression.
/// - Limits: Does not enumerate or simplify the basis functions.
pub fn bspline_basis_set(d : Expr, knots : Expr, x : Expr) -> Expr {
  @symcore.function("bspline_basis_set", [d, knots, x])
}

///|
/// Build an interpolating-spline expression.
///
/// - Does: Builds `interpolating_spline(d, x, knots, values)`.
/// - Input: Degree, variable, knot data, and sample values.
/// - Returns: A symbolic interpolating-spline expression.
/// - Limits: Does not solve interpolation coefficients or validate ranks.
pub fn interpolating_spline(
  d : Expr,
  x : Expr,
  knots : Expr,
  values : Expr,
) -> Expr {
  @symcore.function("interpolating_spline", [d, x, knots, values])
}
