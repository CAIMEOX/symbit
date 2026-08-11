///|
/// Polynomial front doors for generator/domain inference and builder-style
/// construction.
///
/// Current Limits:
/// - Generator inference only sees free symbol names in the input expression.
/// - Domain inference is intentionally conservative and may require explicit
///   overrides for mixed or extension-heavy inputs.

///|
/// Configurable builder for repeated polynomial construction.
///
/// - Does: Stores generators, coefficient domain, and term order for later
///   `Expr -> Poly` conversions.
/// - Input: Builder configuration fields managed through public constructors.
/// - Returns: A `PolyBuilder`.
/// - Limits: The builder does not infer settings on its own; use
///   `Poly::from_expr_defaults` when inference is desired.
pub struct PolyBuilder {
  gens : Array[String]
  domain : Domain
  order : TermOrder
}

///|
/// Create a polynomial builder with default `Lex` order.
///
/// - Does: Builds a reusable `PolyBuilder`.
/// - Input: An ordered generator array and a coefficient `Domain`.
/// - Returns: A `PolyBuilder`.
/// - Limits: The initial term order is always `TermOrder::Lex`.
pub fn PolyBuilder::new(gens : Array[String], domain : Domain) -> PolyBuilder {
  { gens, domain, order: Lex }
}

///|
/// Rebind a builder to a different term order.
///
/// - Does: Keeps generators and domain unchanged while swapping the stored
///   monomial order.
/// - Input: One `PolyBuilder` and one `TermOrder`.
/// - Returns: A `PolyBuilder`.
/// - Limits: This only changes how future conversions order terms.
pub fn PolyBuilder::order(self : PolyBuilder, order : TermOrder) -> PolyBuilder {
  { gens: self.gens, domain: self.domain, order }
}

///|
/// Parse one expression with the builder configuration.
///
/// - Does: Converts an `Expr` into a `Poly` using stored generators, domain,
///   and term order.
/// - Input: One `Expr`.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError` when the expression is not polynomial over the
///   configured generators or cannot be represented in the configured domain.
pub fn PolyBuilder::from_expr(
  self : PolyBuilder,
  expr : Expr,
) -> Poly raise PolyError {
  Poly::from_expr(expr, self.gens, self.domain).with_order(self.order)
}

///|
/// Build a polynomial with inferred generators/domain and optional overrides.
///
/// - Does: Converts one expression into a polynomial while inferring generators
///   and coefficient domain unless explicit options override them.
/// - Input: One `Expr` plus optional `gens`, `domain`, `modulus`, `gaussian`,
///   `extension`, and `order`.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError` when the resolved options are inconsistent or
///   the expression is not polynomial in the resolved generators.
///
/// ```mbt check
/// test "sympolys from_expr_defaults infers gens and QQ domain" {
///   let x = @symcore.Expr::Symbol("x")
///   let y = @symcore.Expr::Symbol("y")
///   let poly = Poly::from_expr_defaults(x * y + @symcore.rational_from_ints(1, 2))
///   debug_inspect(poly.gens, content="[\"x\", \"y\"]")
///   match poly.domain {
///     QQ => ()
///     _ => fail("expected QQ domain")
///   }
///   inspect(poly, content="x*y + 1/2")
/// }
/// ```
pub fn Poly::from_expr_defaults(
  expr : Expr,
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
    None => Lex
  }
  Poly::from_expr(expr, resolved_gens, resolved_domain).with_order(
    resolved_order,
  )
}

///|
fn infer_gens(expr : Expr) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  collect_symbols(expr, seen)
  let names : Array[String] = Array::new()
  for name, _ in seen {
    names.push(name)
  }
  names.sort()
  names
}

///|
fn collect_symbols(expr : Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    Symbol(name) => seen.set(name, true)
    Add(args) | Mul(args) =>
      for child in args {
        collect_symbols(child, seen)
      }
    Pow(base, exp) => {
      collect_symbols(base, seen)
      collect_symbols(exp, seen)
    }
    _ =>
      for child in @symcore.args(expr) {
        collect_symbols(child, seen)
      }
  }
}

///|
fn infer_domain(expr : Expr) -> Domain {
  if has_complex_float_coeff(expr) {
    CC
  } else if has_float_coeff(expr) {
    RR
  } else if has_fractional_coeff(expr) {
    QQ
  } else {
    ZZ
  }
}

///|
fn has_complex_float_coeff(expr : Expr) -> Bool {
  match expr {
    ComplexFloat(z) => !@symnum.is_zero(z.to_mpc().imag)
    Add(args) | Mul(args) => args.any(child => has_complex_float_coeff(child))
    Pow(base, exp) =>
      has_complex_float_coeff(base) || has_complex_float_coeff(exp)
    _ => @symcore.args(expr).any(child => has_complex_float_coeff(child))
  }
}

///|
fn has_float_coeff(expr : Expr) -> Bool {
  match expr {
    Float(_) | ComplexFloat(_) => true
    Add(args) | Mul(args) => args.any(child => has_float_coeff(child))
    Pow(base, exp) => has_float_coeff(base) || has_float_coeff(exp)
    _ => @symcore.args(expr).any(child => has_float_coeff(child))
  }
}

///|
fn resolve_domain(
  domain~ : Domain?,
  modulus~ : Int?,
  gaussian~ : Bool?,
  extension~ : Array[String]?,
  gf_degree~ : Int?,
  expr~ : Expr?,
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
        (Some(GFExt(p, k0, poly)), Some(m)) =>
          if p == m && k0 == k {
            GFExt(p, k, poly)
          } else {
            raise BadModulus
          }
        (Some(GFExt(p, k0, poly)), None) =>
          if k0 == k {
            GFExt(p, k0, poly)
          } else {
            raise BadModulus
          }
        (Some(GF(p)), Some(m)) =>
          if p == m {
            GFExt(p, k, gfext_default_poly(k))
          } else {
            raise BadModulus
          }
        (Some(GF(p)), None) => GFExt(p, k, gfext_default_poly(k))
        (None, Some(m)) =>
          if m <= 1 {
            raise BadModulus
          } else {
            GFExt(m, k, gfext_default_poly(k))
          }
        (Some(_), Some(_)) | (Some(_), None) => raise BadModulus
        (None, None) => raise BadModulus
      }
    None =>
      match (domain, modulus) {
        (Some(GFExt(p, k, poly)), Some(m)) =>
          if p == m {
            GFExt(p, k, poly)
          } else {
            raise BadModulus
          }
        (Some(GFExt(p, k, poly)), None) => GFExt(p, k, poly)
        (Some(GF(p)), Some(m)) => if p == m { GF(p) } else { raise BadModulus }
        (Some(GF(p)), None) => GF(p)
        (None, Some(m)) => if m <= 1 { raise BadModulus } else { GF(m) }
        (Some(_), Some(_)) => raise BadModulus
        (Some(d), None) => d
        (None, None) =>
          match expr {
            Some(e) => infer_domain(e)
            None => QQ
          }
      }
  }

  // gaussian flag upgrades integer/rational domains to Gaussian complex
  match gaussian {
    Some(true) =>
      base = match base {
        ZZ | QQ => CC
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
      AlgExt(base, exts, rels)
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
fn has_fractional_coeff(expr : Expr) -> Bool {
  match expr {
    Number(n) => !n.is_integral()
    Float(_) | ComplexFloat(_) => false
    Add(args) | Mul(args) => args.any(child => has_fractional_coeff(child))
    Pow(base, exp) => has_fractional_coeff(base) || has_fractional_coeff(exp)
    _ => @symcore.args(expr).any(child => has_fractional_coeff(child))
  }
}
