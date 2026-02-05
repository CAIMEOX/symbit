///|
/// Integer limits specialization.

///|
pub(all) struct ExprWithIntLimits {
  expr : @symcore.Expr
  limits : Array[LimitSpec]
}

///|
fn ExprWithIntLimits::as_limits(self : ExprWithIntLimits) -> ExprWithLimits {
  ExprWithLimits::{ expr: self.expr, limits: self.limits }
}

///|
pub fn ExprWithIntLimits::to_expr(
  self : ExprWithIntLimits,
  func_name : String,
) -> @symcore.Expr {
  self.as_limits().to_expr(func_name)
}

///|
pub fn ExprWithIntLimits::variables(self : ExprWithIntLimits) -> Array[@symcore.Expr] {
  self.as_limits().variables()
}

///|
pub fn ExprWithIntLimits::bound_symbol_names(
  self : ExprWithIntLimits,
) -> Array[String] {
  self.as_limits().bound_symbol_names()
}

///|
pub fn ExprWithIntLimits::free_symbols(
  self : ExprWithIntLimits,
) -> Array[String] {
  self.as_limits().free_symbols()
}

///|
pub fn ExprWithIntLimits::has_finite_limits(self : ExprWithIntLimits) -> Bool {
  self.as_limits().has_finite_limits()
}

///|
pub fn ExprWithIntLimits::has_infinite_limits(self : ExprWithIntLimits) -> Bool {
  self.as_limits().has_infinite_limits()
}
