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

///|
pub fn gcd_list(
  polys : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.gcd_list(polys, gens~, domain~, modulus~)
}

///|
pub fn lcm_list(
  polys : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.lcm_list(polys, gens~, domain~, modulus~)
}

///|
pub fn terms_gcd(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.terms_gcd(expr, gens~, domain~, modulus~)
}

///|
pub fn cancel(
  p : @symcore.Expr,
  q : @symcore.Expr,
) -> String raise {
  @sympy.cancel(p, q)
}

///|
pub fn reduced(
  f : @symcore.Expr,
  divisors : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.reduced(f, divisors, gens~, domain~, modulus~)
}

///|
pub fn compose(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.compose(f, g, gens~, domain~, modulus~)
}

///|
pub fn decompose(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.decompose(f, gens~, domain~, modulus~)
}

///|
pub fn sturm(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.sturm(f, gens~, domain~, modulus~)
}

///|
pub fn discriminant(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.discriminant(f, gens~, domain~, modulus~)
}

///|
pub fn subresultants(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.subresultants(p, q, gens~, domain~, modulus~)
}

///|
pub fn interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  x? : String = "x",
) -> String raise {
  @sympy.interpolate(points, x~)
}

///|
pub fn rational_interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  x? : String = "x",
) -> String raise {
  @sympy.rational_interpolate(points, deg_num, x~)
}
