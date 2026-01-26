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
  order? : TermOrder,
) -> Poly raise PolyError {
  let resolved_gens = match gens {
    Some(g) => g
    None => infer_gens(expr)
  }
  let resolved_domain = match (domain, modulus) {
    (Some(Domain::GF(p)), Some(m)) =>
      if p == m {
        Domain::GF(m)
      } else {
        raise PolyError::BadModulus
      }
    (Some(Domain::GF(p)), None) => Domain::GF(p)
    (Some(_), Some(_)) => raise PolyError::BadModulus
    (Some(d), None) => d
    (None, Some(m)) => {
      if m <= 1 {
        raise PolyError::BadModulus
      }
      Domain::GF(m)
    }
    (None, None) => infer_domain(expr)
  }
  let resolved_order = match order {
    Some(o) => o
    None => TermOrder::Lex
  }
  Poly::from_expr(expr, resolved_gens, resolved_domain)
    .with_order(resolved_order)
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
    @symcore.Expr::Symbol(name) => {
      seen.set(name, true)
    }
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
