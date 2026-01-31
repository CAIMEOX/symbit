///|
/// Resultant placeholder; keeps API visible while algorithms are built.
pub fn Poly::resultant(
  self : Poly,
  other : Poly,
  gen_index : Int,
) -> @symnum.BigRational raise PolyError {
  if self.domain.not_equal(other.domain) || self.gens.not_equal(other.gens) {
    raise PolyError::DomainMismatch
  }
  if gen_index < 0 || gen_index >= self.gens.length() {
    raise PolyError::BadGenerator("\{gen_index}".to_string())
  }
  if gen_index != 0 {
    return resultant_elim(self, other, gen_index)
  }
  resultant_univar(self, other)
}

///|
/// Resultant wrapper mirroring SymPy: resultant(f, g, x, gens?, domain?, modulus?, order?).
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
) -> @symnum.BigRational raise PolyError {
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
    Some(i) => f.resultant(g, i)
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
fn resultant_elim(
  a : Poly,
  b : Poly,
  gen_index : Int,
) -> @symnum.BigRational raise PolyError {
  if a.gens.length() <= gen_index || b.gens.length() <= gen_index {
    raise PolyError::BadGenerator("\{gen_index}".to_string())
  }
  let basis = Poly::groebner([a, b], order=TermOrder::Lex)
  for p in basis {
    let mut depends = false
    for m, _ in p.coeffs {
      if m.exps[gen_index] != 0 {
        depends = true
        break
      }
    }
    if !depends {
      // If elimination yields a constant, return it; otherwise not a pure resultant.
      if p.gens.length() == 1 ||
        (p.coeffs.length() == 1 && p.degree(gen_index) == 0) {
        match p.leading_term() {
          Some((_, c)) => return fe_expect_rational(c)
          None => continue
        }
      }
    }
  }
  raise PolyError::NotImplemented("resultant-elimination")
}
