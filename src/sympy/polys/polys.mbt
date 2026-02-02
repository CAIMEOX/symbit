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
pub fn poly_expr(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  @sympy.poly_expr(expr, gens~, domain~, modulus~)
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

///|
pub fn symmetrize(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  formal? : Bool = false,
  symbols? : Array[String] = [],
) -> String raise {
  @sympy.symmetrize(expr, gens~, formal~, symbols~)
}

///|
pub fn horner(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  wrt? : String = "",
) -> String raise {
  @sympy.horner(expr, gens~, wrt~)
}

///|
pub fn dup_integrate(
  coeffs : Array[@symnum.BigRational],
  m : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_integrate(coeffs, m, domain~)
}

///|
pub fn dmp_integrate(
  data : @sympy.DenseData,
  m : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_integrate(data, m, u, domain~)
}

///|
pub fn dmp_integrate_in(
  data : @sympy.DenseData,
  m : Int,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_integrate_in(data, m, j, u, domain~)
}

///|
pub fn dup_diff(
  coeffs : Array[@symnum.BigRational],
  m : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_diff(coeffs, m, domain~)
}

///|
pub fn dmp_diff(
  data : @sympy.DenseData,
  m : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_diff(data, m, u, domain~)
}

///|
pub fn dmp_diff_in(
  data : @sympy.DenseData,
  m : Int,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_diff_in(data, m, j, u, domain~)
}

///|
pub fn dup_eval(
  coeffs : Array[@symnum.BigRational],
  a : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_eval(coeffs, a, domain~)
}

///|
pub fn dmp_eval(
  data : @sympy.DenseData,
  a : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_eval(data, a, u, domain~)
}

///|
pub fn dmp_eval_in(
  data : @sympy.DenseData,
  a : @symnum.BigRational,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_eval_in(data, a, j, u, domain~)
}

///|
pub fn dup_monic(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_monic(coeffs, domain~)
}

///|
pub fn dmp_ground_monic(
  data : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_ground_monic(data, u, domain~)
}

///|
pub fn gf_strip(f : Array[Int]) -> String raise {
  @sympy.gf_strip(f)
}

///|
pub fn gf_trunc(f : Array[Int], p : Int) -> String raise {
  @sympy.gf_trunc(f, p)
}

///|
pub fn gf_add(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  @sympy.gf_add(f, g, p)
}

///|
pub fn gf_sub(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  @sympy.gf_sub(f, g, p)
}

///|
pub fn gf_mul(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  @sympy.gf_mul(f, g, p)
}

///|
pub fn gf_div(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  @sympy.gf_div(f, g, p)
}

///|
pub fn gf_gcd(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  @sympy.gf_gcd(f, g, p)
}

///|
pub fn roots_linear(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  @sympy.roots_linear(expr, gens~)
}

///|
pub fn roots_quadratic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  @sympy.roots_quadratic(expr, gens~)
}

///|
pub fn roots_cubic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  @sympy.roots_cubic(expr, gens~)
}

///|
pub fn roots_quartic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  @sympy.roots_quartic(expr, gens~)
}

///|
pub fn rootof(
  expr : @symcore.Expr,
  index : Int,
  radicals? : Bool = true,
) -> String raise {
  @sympy.rootof(expr, index, radicals~)
}

///|
pub fn dup_cauchy_upper_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  @sympy.dup_cauchy_upper_bound(coeffs, domain~)
}

///|
pub fn dup_cauchy_lower_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  @sympy.dup_cauchy_lower_bound(coeffs, domain~)
}

///|
pub fn dup_mignotte_sep_bound_squared(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  @sympy.dup_mignotte_sep_bound_squared(coeffs, domain~)
}

///|
pub fn dup_sturm(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  @sympy.dup_sturm(coeffs, domain~)
}

///|
pub fn dup_refine_real_root(
  coeffs : Array[@symnum.BigRational],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain? : String = "QQ",
  steps? : Int,
  eps? : @symnum.BigRational,
  disjoint? : @symnum.BigRational,
) -> String raise {
  match (steps, eps, disjoint) {
    (None, None, None) =>
      @sympy.dup_refine_real_root(coeffs, s, t, domain=domain)
    (Some(k), None, None) =>
      @sympy.dup_refine_real_root(coeffs, s, t, domain=domain, steps=k)
    (None, Some(e), None) =>
      @sympy.dup_refine_real_root(coeffs, s, t, domain=domain, eps=e)
    (None, None, Some(d)) =>
      @sympy.dup_refine_real_root(coeffs, s, t, domain=domain, disjoint=d)
    (Some(k), Some(e), None) =>
      @sympy.dup_refine_real_root(
        coeffs,
        s,
        t,
        domain=domain,
        steps=k,
        eps=e,
      )
    (Some(k), None, Some(d)) =>
      @sympy.dup_refine_real_root(
        coeffs,
        s,
        t,
        domain=domain,
        steps=k,
        disjoint=d,
      )
    (None, Some(e), Some(d)) =>
      @sympy.dup_refine_real_root(
        coeffs,
        s,
        t,
        domain=domain,
        eps=e,
        disjoint=d,
      )
    (Some(k), Some(e), Some(d)) =>
      @sympy.dup_refine_real_root(
        coeffs,
        s,
        t,
        domain=domain,
        steps=k,
        eps=e,
        disjoint=d,
      )
  }
}

///|
pub fn dup_isolate_real_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  @sympy.dup_isolate_real_roots_sqf(coeffs, domain~)
}

///|
pub fn res_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  @sympy.res_qq_zz(p, q, x~)
}

///|
pub fn res_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  @sympy.res_q_qq_zz(p, q, x~)
}

///|
pub fn res_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  @sympy.res_z_qq_zz(p, q, x~)
}

///|
pub fn subresultants_rem_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  @sympy.subresultants_rem_qq_zz(p, q, x~)
}
///|
pub fn viete(
  expr : @symcore.Expr,
  roots? : Array[String] = [],
  gen? : String = "",
) -> String raise {
  @sympy.viete(expr, roots~, gen~)
}

///|
pub fn dup_add_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_add_term(f, c, k, domain~)
}

///|
pub fn dup_sub_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_sub_term(f, c, k, domain~)
}

///|
pub fn dup_mul_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_mul_term(f, c, k, domain~)
}

///|
pub fn dup_add_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_add_ground(f, c, domain~)
}

///|
pub fn dup_sub_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_sub_ground(f, c, domain~)
}

///|
pub fn dup_mul_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_mul_ground(f, c, domain~)
}

///|
pub fn dup_quo_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_quo_ground(f, c, domain~)
}

///|
pub fn dup_exquo_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_exquo_ground(f, c, domain~)
}

///|
pub fn dup_lshift(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_lshift(f, n, domain~)
}

///|
pub fn dup_rshift(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_rshift(f, n, domain~)
}

///|
pub fn dup_neg(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_neg(f, domain~)
}

///|
pub fn dup_abs(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_abs(f, domain~)
}

///|
pub fn dup_add(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_add(f, g, domain~)
}

///|
pub fn dup_sub(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_sub(f, g, domain~)
}

///|
pub fn dup_mul(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_mul(f, g, domain~)
}

///|
pub fn dup_sqr(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_sqr(f, domain~)
}

///|
pub fn dup_pow(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_pow(f, n, domain~)
}

///|
pub fn dup_rr_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_rr_div(f, g, domain~)
}

///|
pub fn dup_ff_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  @sympy.dup_ff_div(f, g, domain~)
}

///|
pub fn dup_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_div(f, g, domain~)
}

///|
pub fn dup_rem(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_rem(f, g, domain~)
}

///|
pub fn dup_quo(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_quo(f, g, domain~)
}

///|
pub fn dup_exquo(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_exquo(f, g, domain~)
}

///|
pub fn dmp_add_term(
  f : @sympy.DenseData,
  c : @sympy.DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_add_term(f, c, k, u, domain~)
}

///|
pub fn dmp_sub_term(
  f : @sympy.DenseData,
  c : @sympy.DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_sub_term(f, c, k, u, domain~)
}

///|
pub fn dmp_mul_term(
  f : @sympy.DenseData,
  c : @sympy.DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_mul_term(f, c, k, u, domain~)
}

///|
pub fn dmp_add_ground(
  f : @sympy.DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_add_ground(f, c, u, domain~)
}

///|
pub fn dmp_sub_ground(
  f : @sympy.DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_sub_ground(f, c, u, domain~)
}

///|
pub fn dmp_mul_ground(
  f : @sympy.DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_mul_ground(f, c, u, domain~)
}

///|
pub fn dmp_quo_ground(
  f : @sympy.DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_quo_ground(f, c, u, domain~)
}

///|
pub fn dmp_exquo_ground(
  f : @sympy.DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_exquo_ground(f, c, u, domain~)
}

///|
pub fn dmp_neg(
  f : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_neg(f, u, domain~)
}

///|
pub fn dmp_abs(
  f : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_abs(f, u, domain~)
}

///|
pub fn dmp_add(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_add(f, g, u, domain~)
}

///|
pub fn dmp_sub(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_sub(f, g, u, domain~)
}

///|
pub fn dmp_mul(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_mul(f, g, u, domain~)
}

///|
pub fn dmp_sqr(
  f : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_sqr(f, u, domain~)
}

///|
pub fn dmp_pow(
  f : @sympy.DenseData,
  n : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_pow(f, n, u, domain~)
}

///|
pub fn dmp_add_mul(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  h : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_add_mul(f, g, h, u, domain~)
}

///|
pub fn dmp_sub_mul(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  h : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_sub_mul(f, g, h, u, domain~)
}

///|
pub fn dmp_pdiv(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_pdiv(f, g, u, domain~)
}

///|
pub fn dmp_prem(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_prem(f, g, u, domain~)
}

///|
pub fn dmp_pquo(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_pquo(f, g, u, domain~)
}

///|
pub fn dmp_pexquo(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_pexquo(f, g, u, domain~)
}

///|
pub fn dmp_rr_div(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_rr_div(f, g, u, domain~)
}

///|
pub fn dmp_ff_div(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_ff_div(f, g, u, domain~)
}

///|
pub fn dmp_div(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_div(f, g, u, domain~)
}

///|
pub fn dmp_rem(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_rem(f, g, u, domain~)
}

///|
pub fn dmp_quo(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_quo(f, g, u, domain~)
}

///|
pub fn dmp_exquo(
  f : @sympy.DenseData,
  g : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_exquo(f, g, u, domain~)
}

///|
pub fn dup_max_norm(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_max_norm(f, domain~)
}

///|
pub fn dmp_max_norm(
  f : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_max_norm(f, u, domain~)
}

///|
pub fn dup_l1_norm(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_l1_norm(f, domain~)
}

///|
pub fn dmp_l1_norm(
  f : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_l1_norm(f, u, domain~)
}

///|
pub fn dup_l2_norm_squared(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_l2_norm_squared(f, domain~)
}

///|
pub fn dmp_l2_norm_squared(
  f : @sympy.DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_l2_norm_squared(f, u, domain~)
}

///|
pub fn dup_expand(
  polys : Array[Array[@symnum.BigRational]],
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dup_expand(polys, domain~)
}

///|
pub fn dmp_expand(
  polys : Array[@sympy.DenseData],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  @sympy.dmp_expand(polys, u, domain~)
}
