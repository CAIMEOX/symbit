///|
/// Gamma and related special functions.

///|
pub fn gamma(expr : Expr) -> Expr {
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
pub fn lowergamma(a : Expr, z : Expr) -> Expr {
  @symcore.function("lowergamma", [a, z])
}

///|
pub fn uppergamma(a : Expr, z : Expr) -> Expr {
  @symcore.function("uppergamma", [a, z])
}

///|
pub fn polygamma(n : Expr, z : Expr) -> Expr {
  @symcore.function("polygamma", [n, z])
}

///|
pub fn loggamma(expr : Expr) -> Expr {
  @symcore.function("loggamma", [expr])
}

///|
pub fn digamma(expr : Expr) -> Expr {
  @symcore.function("digamma", [expr])
}

///|
pub fn trigamma(expr : Expr) -> Expr {
  @symcore.function("trigamma", [expr])
}

///|
pub fn multigamma(a : Expr, p : Expr) -> Expr {
  @symcore.function("multigamma", [a, p])
}
