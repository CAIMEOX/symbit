///|
/// Full resultant over one eliminated generator. The result is a polynomial in
/// the remaining generators (or a constant when no generators remain).
pub fn Poly::resultant_poly(
  self : Poly,
  other : Poly,
  gen_index : Int,
) -> Poly raise PolyError {
  if self.domain.not_equal(other.domain) || self.gens.not_equal(other.gens) {
    raise PolyError::DomainMismatch
  }
  if gen_index < 0 || gen_index >= self.gens.length() {
    raise PolyError::BadGenerator("\{gen_index}".to_string())
  }
  let poly = resultant_elim_poly(self, other, gen_index)
  poly.with_order(self.order)
}

///|
/// Scalar resultant compatibility helper. This matches the old behavior and
/// raises DomainMismatch when elimination yields a non-constant polynomial.
pub fn Poly::resultant(
  self : Poly,
  other : Poly,
  gen_index : Int,
) -> @symnum.BigRational raise PolyError {
  let res_poly = self.resultant_poly(other, gen_index)
  poly_const_rational(res_poly)
}

///|
/// Resultant wrapper mirroring SymPy: resultant(f, g, x, gens?, domain?, modulus?, order?).
/// Returns a symbolic expression, so multivariate elimination is represented.
pub fn resultant_expr(
  f_expr : @symcore.Expr,
  g_expr : @symcore.Expr,
  var_name : String,
  gens? : Array[String],
  domain? : Domain,
  modulus? : Int,
  extension? : Array[String],
  gf_degree? : Int,
  order? : TermOrder,
) -> @symcore.Expr raise PolyError {
  let (f, g, resolved_gens) = build_resultant_inputs(
    f_expr,
    g_expr,
    var_name,
    gens~,
    domain~,
    modulus~,
    extension~,
    gf_degree~,
    order~,
  )
  match find_index(resolved_gens, var_name) {
    Some(i) => f.resultant_poly(g, i).to_expr()
    None => raise PolyError::BadGenerator(var_name)
  }
}

///|
/// Scalar compatibility wrapper for callers that require a rational resultant.
pub fn resultant_expr_scalar(
  f_expr : @symcore.Expr,
  g_expr : @symcore.Expr,
  var_name : String,
  gens? : Array[String],
  domain? : Domain,
  modulus? : Int,
  extension? : Array[String],
  gf_degree? : Int,
  order? : TermOrder,
) -> @symnum.BigRational raise PolyError {
  let (f, g, resolved_gens) = build_resultant_inputs(
    f_expr,
    g_expr,
    var_name,
    gens~,
    domain~,
    modulus~,
    extension~,
    gf_degree~,
    order~,
  )
  match find_index(resolved_gens, var_name) {
    Some(i) => f.resultant(g, i)
    None => raise PolyError::BadGenerator(var_name)
  }
}

///|
fn build_resultant_inputs(
  f_expr : @symcore.Expr,
  g_expr : @symcore.Expr,
  var_name : String,
  gens~ : Array[String]?,
  domain~ : Domain?,
  modulus~ : Int?,
  extension~ : Array[String]?,
  gf_degree~ : Int?,
  order~ : TermOrder?,
) -> (Poly, Poly, Array[String]) raise PolyError {
  let resolved_gens = match gens {
    Some(g) =>
      if !array_contains_str(g, var_name) {
        let arr = g.copy()
        arr.push(var_name)
        arr.sort()
        arr
      } else {
        g
      }
    None => {
      let list = infer_gens_union([f_expr, g_expr])
      if array_contains_str(list, var_name) {
        list
      } else {
        let arr = list
        arr.push(var_name)
        arr.sort()
        arr
      }
    }
  }
  let resolved_domain = resolve_domain(
    domain~,
    modulus~,
    extension~,
    gf_degree~,
    gaussian=None,
    expr=None,
  )
  let ord = match order {
    Some(o) => o
    None => TermOrder::Lex
  }
  let mod_opt = match resolved_domain {
    Domain::GF(p) => Some(p)
    _ => None
  }
  let f = match mod_opt {
    Some(m) =>
      Poly::from_expr_defaults(
        f_expr,
        gens=resolved_gens,
        domain=resolved_domain,
        modulus=m,
        order=ord,
      )
    None =>
      Poly::from_expr_defaults(
        f_expr,
        gens=resolved_gens,
        domain=resolved_domain,
        order=ord,
      )
  }
  let g = match mod_opt {
    Some(m) =>
      Poly::from_expr_defaults(
        g_expr,
        gens=resolved_gens,
        domain=resolved_domain,
        modulus=m,
        order=ord,
      )
    None =>
      Poly::from_expr_defaults(
        g_expr,
        gens=resolved_gens,
        domain=resolved_domain,
        order=ord,
      )
  }
  match find_index(resolved_gens, var_name) {
    Some(_) => (f, g, resolved_gens)
    None => raise PolyError::BadGenerator(var_name)
  }
}

///|
fn find_index(arr : Array[String], target : String) -> Int? {
  for i in 0..<arr.length() {
    if arr[i] == target {
      return Some(i)
    }
  }
  None
}

///|
fn array_contains_str(arr : Array[String], target : String) -> Bool {
  match find_index(arr, target) {
    Some(_) => true
    None => false
  }
}

///|
fn pow_big_rational(
  base : @symnum.BigRational,
  exp : Int,
) -> @symnum.BigRational raise PolyError {
  if exp < 0 {
    raise PolyError::BadExponent
  }
  let mut acc = @symnum.BigRational::one()
  let mut e = exp
  let mut b = base
  while e > 0 {
    if e % 2 == 1 {
      acc = acc.mul_r(b)
    }
    e = e / 2
    if e > 0 {
      b = b.mul_r(b)
    }
  }
  acc
}

///|
fn resultant_univar(a : Poly, b : Poly) -> @symnum.BigRational raise PolyError {
  check_univar_compat(a, b)
  if a.is_zero() || b.is_zero() {
    return @symnum.BigRational::zero()
  }
  let mut p = if a.domain is Domain::QQ { a } else { lift_to_qq(a) }
  let mut q = if b.domain is Domain::QQ { b } else { lift_to_qq(b) }
  let mut res = @symnum.BigRational::one()
  while true {
    let (deg_p, _) = match leading_data_univar(p) {
      Some(v) => v
      None => raise PolyError::DivisionByZero
    }
    let (deg_q, lc_q_fe) = match leading_data_univar(q) {
      Some(v) => v
      None => raise PolyError::DivisionByZero
    }
    let lc_q = fe_expect_rational(lc_q_fe)
    if deg_q == 0 {
      return res.mul_r(pow_big_rational(lc_q, deg_p))
    }
    let (_, r) = divmod_univar_rat(p, q)
    if r.is_zero() {
      // Common factor detected -> resultant is zero.
      return @symnum.BigRational::zero()
    }
    let (deg_r, _) = match leading_data_univar(r) {
      Some(v) => v
      None => raise PolyError::DivisionByZero
    }
    res = res.mul_r(pow_big_rational(lc_q, deg_p - deg_r))
    if deg_p * deg_q % 2 == 1 {
      res = res.neg_r()
    }
    p = q
    q = r
  }
  raise PolyError::DivisionByZero
}

///|
fn resultant_elim_poly(
  a : Poly,
  b : Poly,
  gen_index : Int,
) -> Poly raise PolyError {
  if a.gens.length() <= gen_index || b.gens.length() <= gen_index {
    raise PolyError::BadGenerator("\{gen_index}".to_string())
  }
  let use_qq_lift = a.domain is Domain::ZZ
  let work_a = if use_qq_lift { lift_to_qq(a) } else { a }
  let work_b = if use_qq_lift { lift_to_qq(b) } else { b }
  let out_gens = remove_gen(work_a.gens, gen_index)
  let out_domain = work_a.domain
  if work_a.is_zero() || work_b.is_zero() {
    let zero = Poly::zero(out_gens, out_domain)
    if use_qq_lift {
      return try_round_to_int(zero) catch { _ => zero }
    }
    return zero
  }
  if work_a.gens.length() == 1 {
    let rat = resultant_univar(work_a, work_b)
    let coeff = fe_from_rational(rat, out_domain)
    let const_poly = poly_from_const_coeff(coeff, out_gens, out_domain)
    if use_qq_lift {
      return try_round_to_int(const_poly) catch { _ => const_poly }
    }
    return const_poly
  }
  let fa = trim_poly_coeffs(poly_to_univar_coeffs(work_a, gen_index))
  let fb = trim_poly_coeffs(poly_to_univar_coeffs(work_b, gen_index))
  if fa.is_empty() || fb.is_empty() {
    let zero = Poly::zero(out_gens, out_domain)
    if use_qq_lift {
      return try_round_to_int(zero) catch { _ => zero }
    }
    return zero
  }
  let deg_a = fa.length() - 1
  let deg_b = fb.length() - 1
  if deg_a == 0 && deg_b == 0 {
    let one = Poly::one(out_gens, out_domain)
    if use_qq_lift {
      return try_round_to_int(one) catch { _ => one }
    }
    return one
  }
  if deg_a == 0 {
    let pow = fa[0].pow(deg_b)
    if use_qq_lift {
      return try_round_to_int(pow) catch { _ => pow }
    }
    return pow
  }
  if deg_b == 0 {
    let pow = fb[0].pow(deg_a)
    if use_qq_lift {
      return try_round_to_int(pow) catch { _ => pow }
    }
    return pow
  }
  let mat = sylvester_matrix(fa, fb, out_gens, out_domain)
  let det = det_poly_bareiss(mat, out_gens, out_domain)
  if use_qq_lift {
    try_round_to_int(det) catch { _ => det }
  } else {
    det
  }
}

///|
fn trim_poly_coeffs(coeffs : Array[Poly]) -> Array[Poly] {
  let mut end = coeffs.length()
  while end > 0 && coeffs[end - 1].is_zero() {
    end = end - 1
  }
  if end == coeffs.length() {
    return coeffs
  }
  let out : Array[Poly] = Array::new()
  for i in 0..<end {
    out.push(coeffs[i])
  }
  out
}

///|
fn poly_from_const_coeff(
  coeff : FieldElem,
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  if fe_is_zero(coeff) {
    return Poly::zero(gens, domain)
  }
  let mono = monomial_one(gens.length())
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  add_term(coeffs, mono, coeff, domain)
  Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
}

///|
fn poly_const_rational(poly : Poly) -> @symnum.BigRational raise PolyError {
  if poly.is_zero() {
    return @symnum.BigRational::zero()
  }
  let mut value : @symnum.BigRational? = None
  for m, c in poly.coeffs {
    if !m.exps.all(e => e == 0) {
      raise PolyError::DomainMismatch
    }
    value = match value {
      None => Some(fe_expect_rational(c))
      Some(v) => Some(v.add_r(fe_expect_rational(c)))
    }
  }
  match value {
    Some(v) => v
    None => @symnum.BigRational::zero()
  }
}

///|
fn sylvester_matrix(
  f_coeffs_asc : Array[Poly],
  g_coeffs_asc : Array[Poly],
  gens : Array[String],
  domain : Domain,
) -> Array[Array[Poly]] {
  let m = f_coeffs_asc.length() - 1
  let n = g_coeffs_asc.length() - 1
  let size = m + n
  let zero = Poly::zero(gens, domain)
  let mat : Array[Array[Poly]] = Array::new()
  for _ in 0..<size {
    mat.push(Array::make(size, zero))
  }
  for i in 0..<n {
    for j in 0..<=m {
      mat[i].set(i + j, f_coeffs_asc[m - j])
    }
  }
  for i in 0..<m {
    for j in 0..<=n {
      mat[n + i].set(i + j, g_coeffs_asc[n - j])
    }
  }
  mat
}

///|
fn det_poly_bareiss(
  mat : Array[Array[Poly]],
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  let n = mat.length()
  if n == 0 {
    return Poly::one(gens, domain)
  }
  if n == 1 {
    return mat[0][0]
  }
  let a : Array[Array[Poly]] = Array::new()
  for i in 0..<n {
    let row : Array[Poly] = Array::new()
    for j in 0..<n {
      row.push(mat[i][j])
    }
    a.push(row)
  }
  let mut det_sign = 1
  let mut pivot_prev = Poly::one(gens, domain)
  for k in 0..<(n - 1) {
    if a[k][k].is_zero() {
      let mut swap_row : Int? = None
      for r in (k + 1)..<n {
        if !a[r][k].is_zero() {
          swap_row = Some(r)
          break
        }
      }
      match swap_row {
        None => return Poly::zero(gens, domain)
        Some(r) => {
          let tmp = a[k]
          a.set(k, a[r])
          a.set(r, tmp)
          det_sign = -det_sign
        }
      }
    }
    let pivot = a[k][k]
    for i in (k + 1)..<n {
      for j in (k + 1)..<n {
        let num = a[i][j].mul(pivot).sub(a[i][k].mul(a[k][j]))
        if k == 0 {
          a[i].set(j, num)
        } else {
          a[i].set(j, poly_div_exact(num, pivot_prev))
        }
      }
      a[i].set(k, Poly::zero(gens, domain))
    }
    pivot_prev = pivot
  }
  let mut det = a[n - 1][n - 1]
  if det_sign < 0 {
    det = det.neg()
  }
  det
}
