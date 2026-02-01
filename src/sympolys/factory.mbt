///|
pub struct PolyBuilder {
  gens : Array[String]
  domain : Domain
  order : TermOrder
}

///|
pub fn PolyBuilder::new(gens : Array[String], domain : Domain) -> PolyBuilder {
  PolyBuilder::{ gens, domain, order: TermOrder::Lex }
}

///|
pub fn PolyBuilder::order(self : PolyBuilder, order : TermOrder) -> PolyBuilder {
  PolyBuilder::{ gens: self.gens, domain: self.domain, order }
}

///|
pub fn PolyBuilder::from_expr(
  self : PolyBuilder,
  expr : @symcore.Expr,
) -> Poly raise PolyError {
  Poly::from_expr(expr, self.gens, self.domain).with_order(self.order)
}

///|
/// SymPy-style convenience wrapper that infers generators and domain.
pub fn Poly::from_expr_defaults(
  expr : @symcore.Expr,
  gens? : Array[String],
  domain? : Domain,
  modulus? : Int,
  gaussian? : Bool,
  extension? : Array[String],
  order? : TermOrder,
) -> Poly raise PolyError {
  let resolved_gens = match gens {
    Some(g) => g
    None => infer_gens(expr)
  }
  let resolved_domain = resolve_domain(
    domain~,
    modulus~,
    gaussian~,
    extension~,
    gf_degree=None,
    expr=Some(expr),
  )
  let resolved_order = match order {
    Some(o) => o
    None => TermOrder::Lex
  }
  Poly::from_expr(expr, resolved_gens, resolved_domain).with_order(
    resolved_order,
  )
}

///|
fn infer_gens(expr : @symcore.Expr) -> Array[String] {
  let seen : Map[String, Bool] = Map::new()
  collect_symbols(expr, seen)
  let names : Array[String] = Array::new()
  for name, _ in seen {
    names.push(name)
  }
  names.sort()
  names
}

///|
fn collect_symbols(expr : @symcore.Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => seen.set(name, true)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for child in args {
        collect_symbols(child, seen)
      }
    @symcore.Expr::Pow(base, exp) => {
      collect_symbols(base, seen)
      collect_symbols(exp, seen)
    }
    @symcore.Expr::Function(_, args) =>
      for child in args {
        collect_symbols(child, seen)
      }
    _ => ()
  }
}

///|
fn infer_domain(expr : @symcore.Expr) -> Domain {
  if has_fractional_coeff(expr) {
    Domain::QQ
  } else {
    Domain::ZZ
  }
}

///|
fn resolve_domain(
  domain~ : Domain?,
  modulus~ : Int?,
  gaussian~ : Bool?,
  extension~ : Array[String]?,
  gf_degree~ : Int?,
  expr~ : @symcore.Expr?,
) -> Domain raise PolyError {
  // SymPy-style precedence:
  // 1) explicit domain wins (with modulus consistency checks)
  // 2) gaussian=True upgrades ZZ/QQ -> CC
  // 3) modulus selects GF(p); gf_degree lifts to GF(p^k)
  // 4) extension builds algebraic extension over inferred/base domain

  // Decide base domain, first handling finite-field extension requests.
  let mut base : Domain = match gf_degree {
    Some(k) =>
      match (domain, modulus) {
        (Some(Domain::GFExt(p, k0, poly)), Some(m)) =>
          if p == m && k0 == k {
            Domain::GFExt(p, k, poly)
          } else {
            raise PolyError::BadModulus
          }
        (Some(Domain::GFExt(p, k0, poly)), None) =>
          if k0 == k {
            Domain::GFExt(p, k0, poly)
          } else {
            raise PolyError::BadModulus
          }
        (Some(Domain::GF(p)), Some(m)) =>
          if p == m {
            Domain::GFExt(p, k, gfext_default_poly(k))
          } else {
            raise PolyError::BadModulus
          }
        (Some(Domain::GF(p)), None) =>
          Domain::GFExt(p, k, gfext_default_poly(k))
        (None, Some(m)) =>
          if m <= 1 {
            raise PolyError::BadModulus
          } else {
            Domain::GFExt(m, k, gfext_default_poly(k))
          }
        (Some(_), Some(_)) | (Some(_), None) =>
          raise PolyError::NotImplemented("gf-degree-non-gf")
        (None, None) => raise PolyError::BadModulus
      }
    None =>
      match (domain, modulus) {
        (Some(Domain::GFExt(p, k, poly)), Some(m)) =>
          if p == m {
            Domain::GFExt(p, k, poly)
          } else {
            raise PolyError::BadModulus
          }
        (Some(Domain::GFExt(p, k, poly)), None) => Domain::GFExt(p, k, poly)
        (Some(Domain::GF(p)), Some(m)) =>
          if p == m {
            Domain::GF(p)
          } else {
            raise PolyError::BadModulus
          }
        (Some(Domain::GF(p)), None) => Domain::GF(p)
        (None, Some(m)) =>
          if m <= 1 {
            raise PolyError::BadModulus
          } else {
            Domain::GF(m)
          }
        (Some(_), Some(_)) => raise PolyError::BadModulus
        (Some(d), None) => d
        (None, None) =>
          match expr {
            Some(e) => infer_domain(e)
            None => Domain::QQ
          }
      }
  }

  // gaussian flag upgrades integer/rational domains to Gaussian complex
  match gaussian {
    Some(true) =>
      base = match base {
        Domain::ZZ | Domain::QQ => Domain::CC
        _ => base
      }
    _ => ()
  }

  // algebraic extension
  match extension {
    Some(exts) if !exts.is_empty() => {
      let rels = match expr {
        Some(e) => [e]
        None => Array::new()
      }
      Domain::AlgExt(base, exts, rels)
    }
    _ => base
  }
}

///|
fn gfext_default_poly(k : Int) -> Array[Int] {
  let coeffs : Array[Int] = Array::make(k + 1, 0)
  coeffs.set(0, 1)
  coeffs.set(k, 1)
  coeffs
}

///|
fn has_fractional_coeff(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => !n.is_integral()
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => has_fractional_coeff(child))
    @symcore.Expr::Pow(base, exp) =>
      has_fractional_coeff(base) || has_fractional_coeff(exp)
    @symcore.Expr::Function(_, args) =>
      args.any(child => has_fractional_coeff(child))
    _ => false
  }
}
