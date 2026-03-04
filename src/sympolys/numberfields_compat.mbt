///|
priv struct RadicalAtom {
  rad : @symnum.BigRational
  n : Int
}

///|
priv struct AffineRadical {
  shift : @symnum.BigRational
  scale : @symnum.BigRational
  atom : RadicalAtom
}

///|
/// Minimal polynomial for a supported algebraic expression over `QQ`.
///
/// This stage supports:
/// - rational constants `q`
/// - radicals `q**(1/n)` with integer `n > 1`
/// - affine transforms `a + b*q**(1/n)` with rational `a, b`.
pub fn minimal_polynomial(
  expr : @symcore.Expr,
  gen? : String = "x",
) -> Poly raise PolyError {
  let x = @symcore.symbol(gen)
  match expr {
    @symcore.Expr::Number(q) => {
      // Match SymPy's primitive-content convention for rationals:
      // minpoly(a/b) = b*x - a.
      let a = q.numerator()
      let b = q.denominator()
      let bx = @symcore.number(@symnum.BigRational::from_bigint(b)) * x
      let a_expr = @symcore.number(@symnum.BigRational::from_bigint(a))
      PolyBuilder::new([gen], Domain::QQ).from_expr(bx - a_expr)
    }
    _ =>
      match parse_affine_radical(expr) {
        Some(aff) => {
          let shift_expr = if aff.shift.is_zero() {
            x
          } else {
            x - @symcore.number(aff.shift)
          }
          let lhs = shift_expr ^ @symcore.int(aff.atom.n)
          let scale_pow = rat_pow_nonnegative(aff.scale, aff.atom.n)
          let rhs = @symcore.number(scale_pow.mul_r(aff.atom.rad))
          let raw = PolyBuilder::new([gen], Domain::QQ).from_expr(lhs - rhs)
          normalize_minpoly_qq(raw)
        }
        None => raise PolyError::NonPolynomial
      }
  }
}

///|
fn parse_affine_radical(expr : @symcore.Expr) -> AffineRadical? {
  match expr {
    @symcore.Expr::Add(args) => {
      let mut shift = @symnum.BigRational::zero()
      let mut term : (@symnum.BigRational, RadicalAtom)? = None
      for arg in args {
        match arg {
          @symcore.Expr::Number(c) => shift = shift.add_r(c)
          _ =>
            match parse_linear_radical(arg) {
              Some(parsed) =>
                if term is None {
                  term = Some(parsed)
                } else {
                  return None
                }
              None => return None
            }
        }
      }
      match term {
        Some((scale, atom)) => Some(AffineRadical::{ shift, scale, atom })
        None => None
      }
    }
    _ =>
      match parse_linear_radical(expr) {
        Some((scale, atom)) => Some(
          AffineRadical::{
            shift: @symnum.BigRational::zero(),
            scale,
            atom,
          },
        )
        None => None
      }
  }
}

///|
fn parse_linear_radical(
  expr : @symcore.Expr,
) -> (@symnum.BigRational, RadicalAtom)? {
  match parse_radical_atom(expr) {
    Some(atom) => Some((@symnum.BigRational::one(), atom))
    None =>
      match expr {
        @symcore.Expr::Mul(args) => {
          let mut coeff = @symnum.BigRational::one()
          let mut atom : RadicalAtom? = None
          for arg in args {
            match arg {
              @symcore.Expr::Number(c) => coeff = coeff.mul_r(c)
              _ =>
                match parse_radical_atom(arg) {
                  Some(parsed) =>
                    if atom is None {
                      atom = Some(parsed)
                    } else {
                      return None
                    }
                  None => return None
                }
            }
          }
          match atom {
            Some(parsed) => Some((coeff, parsed))
            None => None
          }
        }
        _ => None
      }
  }
}

///|
fn parse_radical_atom(expr : @symcore.Expr) -> RadicalAtom? {
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      match (base, exp) {
        (@symcore.Expr::Number(rad), @symcore.Expr::Number(e)) => {
          let num = e.numerator()
          let den = e.denominator()
          if num.equal_int(1) && den.compare(BigInt::from_int(1)) > 0 {
            Some(RadicalAtom::{ rad, n: den.to_int() })
          } else {
            None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn rat_pow_nonnegative(
  base : @symnum.BigRational,
  n : Int,
) -> @symnum.BigRational {
  let mut result = @symnum.BigRational::one()
  let mut i = 0
  while i < n {
    result = result.mul_r(base)
    i = i + 1
  }
  result
}

///|
fn normalize_minpoly_qq(poly : Poly) -> Poly raise PolyError {
  if poly.domain.not_equal(Domain::QQ) {
    return poly
  }
  let mut lcm_den = BigInt::from_int(1)
  for _, c in poly.coeffs {
    let q = fe_expect_rational(c)
    let den = q.denominator()
    let g = @symnum.gcd_bigint(lcm_den, den)
    lcm_den = lcm_den.mul(den.div(g))
  }
  let mut normalized = if lcm_den.equal_int(1) {
    poly
  } else {
    poly.scale_coeff(FieldElem::QQ(@symnum.BigRational::from_bigint(lcm_den)))
  }
  normalized = normalized.primitive_part()
  let lc = normalized.lc()
  if fe_is_negative(lc) {
    normalized = normalized.scale_coeff(fe_from_int(-1, Domain::QQ))
  }
  normalized
}

///|
/// Alias of `minimal_polynomial` for SymPy-compatible naming.
pub fn minpoly(expr : @symcore.Expr, gen? : String = "x") -> Poly raise PolyError {
  minimal_polynomial(expr, gen~)
}

///|
/// Construct a one-generator algebraic field extension `QQ(a)`, where `a`
/// satisfies the computed minimal polynomial.
pub fn to_number_field(
  expr : @symcore.Expr,
  gen? : String = "a",
) -> Domain raise PolyError {
  let mp = minimal_polynomial(expr, gen~)
  build_alg_extension(alg_ext_spec(Domain::QQ, gen, mp))
}

///|
/// Return a primitive-element candidate from a list of algebraic generators.
///
/// We currently use the linear combination `sum(generators)` with all-ones
/// integer coefficients, matching SymPy's common choice on many radical inputs.
pub fn primitive_element(
  generators : Array[@symcore.Expr],
) -> (@symcore.Expr, Array[Int]) raise PolyError {
  if generators.is_empty() {
    raise PolyError::NonPolynomial
  }
  let mut prim = generators[0]
  let coeffs : Array[Int] = Array::make(generators.length(), 1)
  for i in 1..<generators.length() {
    prim = prim + generators[i]
  }
  (prim, coeffs)
}

///|
fn algext_relation_coeffs(domain : Domain) -> Array[@symnum.BigRational]? {
  match domain {
    Domain::AlgExt(base, gens, rels) => {
      if base.not_equal(Domain::QQ) || gens.length() != 1 || rels.length() != 1 {
        return None
      }
      let poly_res : Result[Poly, PolyError] = try? PolyBuilder::new(gens, base).from_expr(
        rels[0],
      )
      match poly_res {
        Err(_) => None
        Ok(poly) => {
          let norm_res : Result[Poly, PolyError] = try? normalize_minpoly_qq(poly)
          match norm_res {
            Err(_) => None
            Ok(norm) => poly_to_dense_qq(norm)
          }
        }
      }
    }
    _ => None
  }
}

///|
fn poly_to_dense_qq(poly : Poly) -> Array[@symnum.BigRational]? {
  if poly.gens.length() != 1 || poly.domain.not_equal(Domain::QQ) {
    return None
  }
  let degree = poly.degree(0)
  if degree < 0 {
    return None
  }
  let dense = Array::make(degree + 1, @symnum.BigRational::zero())
  for monomial, coeff in poly.coeffs {
    if monomial.exps.length() != 1 {
      return None
    }
    let exp = monomial.exps[0]
    if exp < 0 || exp > degree {
      return None
    }
    let q_res : Result[@symnum.BigRational, PolyError] = try? fe_expect_rational(
      coeff,
    )
    match q_res {
      Ok(q) => dense.set(degree - exp, q)
      Err(_) => return None
    }
  }
  Some(dense)
}

///|
/// A conservative field-isomorphism predicate for migrated algebraic domains.
///
/// For `QQ` one-generator algebraic extensions this compares defining
/// relations up to generator renaming (coefficient vectors).
pub fn field_isomorphic(a : Domain, b : Domain) -> Bool {
  if a.equal(b) {
    return true
  }
  match (algext_relation_coeffs(a), algext_relation_coeffs(b)) {
    (Some(lhs), Some(rhs)) => lhs.equal(rhs)
    _ => false
  }
}
