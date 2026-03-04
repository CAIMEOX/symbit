///|
/// Minimal polynomial for a supported algebraic expression over `QQ`.
///
/// Currently implemented for:
/// - rational constants `q`
/// - radical constants `q**(1/n)` with integer `n > 1`.
pub fn minimal_polynomial(
  expr : @symcore.Expr,
  gen? : String = "x",
) -> Poly raise PolyError {
  let x = @symcore.symbol(gen)
  match expr {
    @symcore.Expr::Number(q) => {
      // Match SymPy's primitive-content convention for rational constants:
      // minpoly(a/b) = b*x - a.
      let a = q.numerator()
      let b = q.denominator()
      let bx = @symcore.number(@symnum.BigRational::from_bigint(b)) * x
      let a_expr = @symcore.number(@symnum.BigRational::from_bigint(a))
      PolyBuilder::new([gen], Domain::QQ).from_expr(bx - a_expr)
    }
    @symcore.Expr::Pow(base, exp) =>
      match (base, exp) {
        (@symcore.Expr::Number(rad), @symcore.Expr::Number(e)) => {
          let num = e.numerator()
          let den = e.denominator()
          if num.equal_int(1) && den.compare(BigInt::from_int(1)) > 0 {
            let n = den.to_int()
            PolyBuilder::new([gen], Domain::QQ).from_expr(
              (x ^ @symcore.int(n)) - @symcore.number(rad),
            )
          } else {
            raise PolyError::NonPolynomial
          }
        }
        _ => raise PolyError::NonPolynomial
      }
    _ => raise PolyError::NonPolynomial
  }
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
/// Return a primitive element candidate from a list of algebraic generators.
///
/// This initial migration keeps SymPy's signature intent but uses the first
/// generator as the primitive element witness.
pub fn primitive_element(
  generators : Array[@symcore.Expr],
) -> (@symcore.Expr, Array[Int]) raise PolyError {
  if generators.is_empty() {
    raise PolyError::NonPolynomial
  }
  let coeffs : Array[Int] = Array::make(generators.length(), 0)
  coeffs.set(0, 1)
  (generators[0], coeffs)
}

///|
/// A conservative field-isomorphism predicate for migrated algebraic domains.
pub fn field_isomorphic(a : Domain, b : Domain) -> Bool {
  a.equal(b)
}
