///|
pub fn gcd(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.sympy_polys_gcd_str(p, q, gens~, domain~, modulus~)
}

///|
pub fn resultant(
  p : String,
  q : String,
  var_name? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.sympy_polys_resultant_str(p, q, var_name~, gens~, domain~, modulus~)
}

///|
pub fn groebner_list(
  exprs : Array[String],
  gens? : Array[String] = [],
  order? : String = "",
  domain? : String = "",
  modulus? : Int = 0,
) -> Array[String] raise {
  @sympy.sympy_polys_groebner_list(exprs, gens~, order~, domain~, modulus~)
}

///|
pub fn div_pair_str(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.sympy_polys_div_pair_str(p, q, gens~, domain~, modulus~)
}

///|
pub fn monic_expr_str(expr : String, modulus? : Int = 0) -> String raise {
  @sympy.sympy_monic_expr_str(expr, modulus~)
}

///|
pub fn factor_list_str(expr : String, modulus? : Int = 0) -> String raise {
  @sympy.sympy_factor_list_str(expr, modulus~)
}

///|
pub fn sqf_list_str(expr : String, modulus? : Int = 0) -> String raise {
  @sympy.sympy_sqf_list_str(expr, modulus~)
}

///|
pub fn groebner_str(
  exprs : Array[String],
  ord? : String = "lex",
) -> String raise {
  @sympy.sympy_groebner_str(exprs, order=ord)
}

///|
pub fn sort_factor_repr(repr_str : String) -> String raise {
  @sympy.sympy_sort_factor_repr(repr_str)
}

///|
pub fn sqf_part_str(expr : String) -> String raise {
  @sympy.sympy_sqf_part_str(expr)
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  @sympy.sympy_expr_equal(lhs, rhs)
}

///|
pub fn normalize_spaces(s : String) -> String {
  @sympy.remove_spaces(s)
}

///|
pub fn sympy_normalize(expr_str : String) -> String raise {
  @sympy.sympy_normalize(expr_str)
}

///|
pub fn canonical_cmp(s : String) -> String {
  @sympy.canonical_cmp(s)
}

///|
pub fn poly_degree_list(
  expr : String,
  gens? : Array[String] = [],
) -> Array[Int] raise {
  @sympy.sympy_poly_degree_list(expr, gens=gens)
}

///|
pub fn poly_lc(expr : String, gens? : Array[String] = []) -> String raise {
  @sympy.sympy_poly_lc(expr, gens=gens)
}

///|
pub fn poly_tc(expr : String, gens? : Array[String] = []) -> String raise {
  @sympy.sympy_poly_tc(expr, gens=gens)
}
