///|
pub fn gcd(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.gcd(p, q, gens~, domain~, modulus~)
}

///|
pub fn resultant(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.resultant(p, q, x~, gens~, domain~, modulus~)
}

///|
pub fn groebner(
  exprs : Array[@symcore.Expr],
  order? : String = "lex",
) -> String raise {
  @sympy.groebner(exprs, order~)
}

///|
pub fn div(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.div(p, q, gens~, domain~, modulus~)
}

///|
pub fn monic(expr : @symcore.Expr, modulus? : Int = 0) -> String raise {
  @sympy.monic(expr, modulus~)
}

///|
pub fn factor_list(expr : @symcore.Expr, modulus? : Int = 0) -> String raise {
  @sympy.factor_list(expr, modulus~)
}

///|
pub fn sqf_list(expr : @symcore.Expr, modulus? : Int = 0) -> String raise {
  @sympy.sqf_list(expr, modulus~)
}

///|
pub fn sqf_part(expr : @symcore.Expr) -> String raise {
  @sympy.sqf_part(expr)
}
