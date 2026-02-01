///|
pub fn gcd(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.gcd(p, q, gens~, domain~, modulus~)
}

///|
pub fn resultant(
  p : String,
  q : String,
  x? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.resultant(p, q, x~, gens~, domain~, modulus~)
}

///|
pub fn groebner(exprs : Array[String], order? : String = "lex") -> String raise {
  @sympy.groebner(exprs, order~)
}

///|
pub fn div(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.div(p, q, gens~, domain~, modulus~)
}

///|
pub fn monic(expr : String, modulus? : Int = 0) -> String raise {
  @sympy.monic(expr, modulus~)
}

///|
pub fn factor_list(expr : String, modulus? : Int = 0) -> String raise {
  @sympy.factor_list(expr, modulus~)
}

///|
pub fn sqf_list(expr : String, modulus? : Int = 0) -> String raise {
  @sympy.sqf_list(expr, modulus~)
}

///|
pub fn sqf_part(expr : String) -> String raise {
  @sympy.sqf_part(expr)
}
