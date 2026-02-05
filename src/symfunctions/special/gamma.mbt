///|
/// Gamma and related special functions.

///|
pub fn gamma(expr : @symcore.Expr) -> @symcore.Expr {
  match int_value(expr) {
    Some(bi) => {
      let n = bi.to_int()
      if n > 0 {
        return expr_from_bigint(factorial_bigint(n - 1))
      }
      @symcore.function("gamma", [expr])
    }
    None => @symcore.function("gamma", [expr])
  }
}

///|
pub fn lowergamma(a : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("lowergamma", [a, z])
}

///|
pub fn uppergamma(a : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("uppergamma", [a, z])
}

///|
pub fn polygamma(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("polygamma", [n, z])
}

///|
pub fn loggamma(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("loggamma", [expr])
}

///|
pub fn digamma(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("digamma", [expr])
}

///|
pub fn trigamma(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("trigamma", [expr])
}

///|
pub fn multigamma(a : @symcore.Expr, p : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("multigamma", [a, p])
}
