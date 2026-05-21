///|
/// SymPy-style polynomial tool front doors over `Poly`.
///
/// Current Limits:
/// - These functions operate on already-built `Poly` values rather than doing
///   SymPy's dynamic expression/generator inference.
/// - Uppercase Python names such as `LC`, `LM`, and `LT` are exposed as
///   lowercase `lc`, `lm`, and `lt`, because MoonBit value identifiers must
///   start with lowercase.
/// - The deep division and pseudo-division paths are univariate-centered.

///|
/// Return the lexicographic monomial order.
///
/// - Does: Mirrors SymPy's `lex` order singleton with a MoonBit function.
/// - Input: No arguments.
/// - Returns: `TermOrder::Lex`.
/// - Limits: MoonBit does not expose lowercase value singletons in the same way
///   Python modules do, so this is a nullary function.
pub fn lex() -> TermOrder {
  TermOrder::Lex
}

///|
/// Return the graded lexicographic monomial order.
///
/// - Does: Mirrors SymPy's `grlex` order singleton with a MoonBit function.
/// - Input: No arguments.
/// - Returns: `TermOrder::Grlex`.
/// - Limits: See `lex`.
pub fn grlex() -> TermOrder {
  TermOrder::Grlex
}

///|
/// Return the graded reverse lexicographic monomial order.
///
/// - Does: Mirrors SymPy's `grevlex` order singleton with a MoonBit function.
/// - Input: No arguments.
/// - Returns: `TermOrder::Grevlex`.
/// - Limits: See `lex`.
pub fn grevlex() -> TermOrder {
  TermOrder::Grevlex
}

///|
/// Return the inverse lexicographic monomial order.
///
/// - Does: Mirrors SymPy's `ilex` order singleton with a MoonBit function.
/// - Input: No arguments.
/// - Returns: `TermOrder::Ilex`.
/// - Limits: See `lex`.
pub fn ilex() -> TermOrder {
  TermOrder::Ilex
}

///|
/// Return the inverse graded lexicographic monomial order.
///
/// - Does: Mirrors SymPy's `igrlex` order singleton with a MoonBit function.
/// - Input: No arguments.
/// - Returns: `TermOrder::Igrlex`.
/// - Limits: See `lex`.
pub fn igrlex() -> TermOrder {
  TermOrder::Igrlex
}

///|
/// Return the inverse graded reverse lexicographic monomial order.
///
/// - Does: Mirrors SymPy's `igrevlex` order singleton with a MoonBit function.
/// - Input: No arguments.
/// - Returns: `TermOrder::Igrevlex`.
/// - Limits: See `lex`.
pub fn igrevlex() -> TermOrder {
  TermOrder::Igrevlex
}

///|
/// Build one polynomial from an expression.
///
/// - Does: Converts an expression through the package's SymPy-style option
///   resolver.
/// - Input: One `Expr` plus optional generators/domain/order controls.
/// - Returns: A `Poly`.
/// - Limits: Returns only the polynomial, not SymPy's `(poly, options)` pair.
pub fn poly_from_expr(
  expr : Expr,
  gens? : Array[String],
  domain? : Domain,
  modulus? : Int,
  gaussian? : Bool,
  extension? : Array[String],
  order? : TermOrder,
) -> Poly raise PolyError {
  poly_from_expr_options(
    expr,
    gens~,
    domain~,
    modulus~,
    gaussian~,
    extension~,
    order~,
  )
}

///|
fn poly_from_expr_options(
  expr : Expr,
  gens~ : Array[String]?,
  domain~ : Domain?,
  modulus~ : Int?,
  gaussian~ : Bool?,
  extension~ : Array[String]?,
  order~ : TermOrder?,
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
/// Build several polynomials with shared generators and domain.
///
/// - Does: Infers common generators/domain, then converts every expression.
/// - Input: An `Array[Expr]` plus optional generator/domain controls.
/// - Returns: `Array[Poly]`.
/// - Limits: Returns only the polynomial array, not SymPy's options object.
pub fn parallel_poly_from_expr(
  exprs : Array[Expr],
  gens? : Array[String],
  domain? : Domain,
  modulus? : Int,
  gaussian? : Bool,
  extension? : Array[String],
  order? : TermOrder,
) -> Array[Poly] raise PolyError {
  let resolved_gens = match gens {
    Some(g) => g
    None => infer_gens_union(exprs)
  }
  let combined = if exprs.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(exprs)
  }
  let resolved_domain = resolve_domain(
    domain~,
    modulus~,
    gaussian~,
    extension~,
    gf_degree=None,
    expr=Some(combined),
  )
  let out : Array[Poly] = []
  for expr in exprs {
    out.push(
      Poly::from_expr(expr, resolved_gens, resolved_domain).with_order(
        match order {
          Some(o) => o
          None => TermOrder::Lex
        },
      ),
    )
  }
  out
}

///|
/// Efficiently transform an expression into a polynomial.
///
/// - Does: Provides the public `poly` spelling as an alias for
///   `poly_from_expr`.
/// - Input: One `Expr` plus optional polynomial construction controls.
/// - Returns: A `Poly`.
/// - Limits: Does not implement SymPy's internal non-expanding recursive
///   optimization separately from the package converter.
pub fn poly(
  expr : Expr,
  gens? : Array[String],
  domain? : Domain,
  modulus? : Int,
  gaussian? : Bool,
  extension? : Array[String],
  order? : TermOrder,
) -> Poly raise PolyError {
  poly_from_expr_options(
    expr,
    gens~,
    domain~,
    modulus~,
    gaussian~,
    extension~,
    order~,
  )
}

///|
fn div_inputs(f : Poly, g : Poly, auto : Bool) -> (Poly, Poly) raise PolyError {
  if f.domain.not_equal(g.domain) || f.gens.not_equal(g.gens) {
    raise PolyError::DomainMismatch
  }
  if auto {
    match f.domain {
      Domain::ZZ => (lift_to_qq(f), lift_to_qq(g))
      _ => (f, g)
    }
  } else {
    (f, g)
  }
}

///|
fn poly_to_field_view(poly : Poly, auto : Bool) -> Poly raise PolyError {
  if auto && !domain_is_field_pred(poly.domain) {
    Poly::{
      coeffs: poly.coeffs,
      gens: poly.gens,
      domain: domain_get_field(poly.domain),
      order: poly.order,
    }
  } else {
    poly
  }
}

///|
fn gcdex_inputs(
  f : Poly,
  g : Poly,
  auto : Bool,
) -> (Poly, Poly) raise PolyError {
  check_univar_compat(f, g)
  let ff = poly_to_field_view(f, auto)
  let gg = poly_to_field_view(g, auto)
  if !domain_is_field_pred(ff.domain) {
    raise PolyError::DomainNotField
  }
  (ff, gg)
}

///|
fn poly_from_dup_desc(
  coeffs : Array[FieldElem],
  template : Poly,
) -> Poly raise PolyError {
  poly_from_dense_desc(coeffs, template.gens[0], template.domain).with_order(
    template.order,
  )
}

///|
fn dup_one(domain : Domain) -> Array[FieldElem] raise PolyError {
  [fe_from_int(1, domain)]
}

///|
fn dup_is_one(coeffs : Array[FieldElem]) -> Bool {
  coeffs.length() == 1 && fe_is_one(coeffs[0])
}

///|
fn monomial_as_expr(poly : Poly, mono : Monomial) -> Expr raise PolyError {
  poly_from_term(
    mono,
    fe_from_int(1, poly.domain),
    poly.gens,
    poly.domain,
    poly.order,
  ).to_expr()
}

///|
fn term_as_expr(
  poly : Poly,
  mono : Monomial,
  coeff : FieldElem,
) -> Expr raise PolyError {
  poly_from_term(mono, coeff, poly.gens, poly.domain, poly.order).to_expr()
}

///|
/// Return the degree in one generator.
///
/// - Does: Computes the largest exponent of `gen_index`.
/// - Input: One `Poly` and an optional generator index.
/// - Returns: An `Int`.
/// - Limits: Zero input returns `-1`, the dense-polynomial sentinel used in
///   this package for SymPy's negative infinity.
pub fn degree(poly : Poly, gen_index? : Int = 0) -> Int {
  if poly.is_zero() {
    -1
  } else {
    poly.degree(gen_index)
  }
}

///|
/// Return degrees in all generators.
///
/// - Does: Computes `degree(poly, gen_index=i)` for each generator.
/// - Input: One `Poly`.
/// - Returns: `Array[Int]`.
/// - Limits: Zero input returns `-1` for each generator, matching this
///   package's finite sentinel for SymPy's negative infinity.
pub fn degree_list(poly : Poly) -> Array[Int] {
  Array::makei(poly.gens.length(), i => degree(poly, gen_index=i))
}

///|
/// Return the total degree.
///
/// - Does: Computes the largest sum of exponents in any term.
/// - Input: One `Poly`.
/// - Returns: An `Int`.
/// - Limits: Zero and constant inputs return `0`.
pub fn total_degree(poly : Poly) -> Int {
  poly.total_degree()
}

///|
/// Return the leading coefficient.
///
/// - Does: Mirrors SymPy `LC` using a lowercase MoonBit-compatible name.
/// - Input: One `Poly` and an optional monomial order.
/// - Returns: A `FieldElem`.
/// - Limits: Zero input returns the additive zero of the coefficient domain.
pub fn lc(poly : Poly, order? : TermOrder) -> FieldElem raise PolyError {
  match order {
    Some(ord) => poly.lc(order=ord)
    None => poly.lc()
  }
}

///|
/// Return the leading monomial as an expression.
///
/// - Does: Mirrors SymPy `LM` using a lowercase MoonBit-compatible name.
/// - Input: One `Poly` and an optional monomial order.
/// - Returns: An `Expr`.
/// - Limits: Zero input returns `1`, matching SymPy's leading monomial
///   convention for the zero polynomial.
pub fn lm(poly : Poly, order? : TermOrder) -> Expr raise PolyError {
  let mono = match order {
    Some(ord) => poly.lm(order=ord)
    None => poly.lm()
  }
  match mono {
    Some(mono) => monomial_as_expr(poly, mono)
    None => @symcore.int(1)
  }
}

///|
/// Return the leading term as an expression.
///
/// - Does: Mirrors SymPy `LT` using a lowercase MoonBit-compatible name.
/// - Input: One `Poly` and an optional monomial order.
/// - Returns: An `Expr`.
/// - Limits: Zero input returns `0`.
pub fn lt(poly : Poly, order? : TermOrder) -> Expr raise PolyError {
  let term = match order {
    Some(ord) => poly.lt(order=ord)
    None => poly.lt()
  }
  match term {
    Some((mono, coeff)) => term_as_expr(poly, mono, coeff)
    None => @symcore.int(0)
  }
}

///|
/// Compute polynomial division.
///
/// - Does: Returns quotient and remainder for `f / g`.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: `(Poly, Poly)`.
/// - Limits: The default `auto=true` lifts `ZZ` input to `QQ`, matching
///   SymPy's common expression front door; `auto=false` uses the stored domain.
pub fn div(
  f : Poly,
  g : Poly,
  auto? : Bool = true,
) -> (Poly, Poly) raise PolyError {
  let (ff, gg) = div_inputs(f, g, auto)
  ff.divmod_univar(gg)
}

///|
/// Compute the polynomial remainder.
///
/// - Does: Returns the second component of `div`.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: A `Poly`.
/// - Limits: Inherits `div` limits.
pub fn rem(f : Poly, g : Poly, auto? : Bool = true) -> Poly raise PolyError {
  let (_, r) = div(f, g, auto~)
  r
}

///|
/// Compute the polynomial quotient.
///
/// - Does: Returns the first component of `div`.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: A `Poly`.
/// - Limits: Inherits `div` limits.
pub fn quo(f : Poly, g : Poly, auto? : Bool = true) -> Poly raise PolyError {
  let (q, _) = div(f, g, auto~)
  q
}

///|
/// Compute an exact polynomial quotient.
///
/// - Does: Divides `f` by `g` and requires zero remainder.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: A quotient `Poly`.
/// - Limits: Raises `PolyError::ExactQuotientFailed` when division is not
///   exact.
pub fn exquo(f : Poly, g : Poly, auto? : Bool = true) -> Poly raise PolyError {
  let (q, r) = div(f, g, auto~)
  if r.is_zero() {
    q
  } else {
    raise PolyError::ExactQuotientFailed
  }
}

///|
/// Compute polynomial pseudo-division.
///
/// - Does: Returns the pseudo-quotient and pseudo-remainder.
/// - Input: Two compatible univariate `Poly` values.
/// - Returns: `(Poly, Poly)`.
/// - Limits: For field domains this falls back to ordinary division.
pub fn pdiv(f : Poly, g : Poly) -> (Poly, Poly) raise PolyError {
  match f.domain {
    Domain::ZZ => {
      let (q, r, _) = f.pseudo_div_univar_int(g)
      (q, r)
    }
    _ => f.divmod_univar(g)
  }
}

///|
/// Compute the polynomial pseudo-remainder.
///
/// - Does: Returns the second component of `pdiv`.
/// - Input: Two compatible univariate `Poly` values.
/// - Returns: A `Poly`.
/// - Limits: Inherits `pdiv` limits.
pub fn prem(f : Poly, g : Poly) -> Poly raise PolyError {
  let (_, r) = pdiv(f, g)
  r
}

///|
/// Compute the polynomial pseudo-quotient.
///
/// - Does: Returns the first component of `pdiv`.
/// - Input: Two compatible univariate `Poly` values.
/// - Returns: A `Poly`.
/// - Limits: Unlike `pexquo`, a non-zero pseudo-remainder is allowed.
pub fn pquo(f : Poly, g : Poly) -> Poly raise PolyError {
  let (q, _) = pdiv(f, g)
  q
}

///|
/// Compute an exact polynomial pseudo-quotient.
///
/// - Does: Returns the pseudo-quotient only if the pseudo-remainder is zero.
/// - Input: Two compatible univariate `Poly` values.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError::ExactQuotientFailed` when pseudo-division is
///   not exact.
pub fn pexquo(f : Poly, g : Poly) -> Poly raise PolyError {
  let (q, r) = pdiv(f, g)
  if r.is_zero() {
    q
  } else {
    raise PolyError::ExactQuotientFailed
  }
}

///|
/// Return extended Euclidean intermediate steps.
///
/// - Does: Enumerates `(s, t, r)` steps satisfying `s*f + t*g = r`.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: `Array[(Poly, Poly, Poly)]`.
/// - Limits: SymPy exposes this as a generator; MoonBit returns the realized
///   sequence. With `auto=true`, ring domains are viewed in their field.
pub fn gcdex_steps(
  f : Poly,
  g : Poly,
  auto? : Bool = true,
) -> Array[(Poly, Poly, Poly)] raise PolyError {
  let (ff, gg) = gcdex_inputs(f, g, auto)
  let domain = ff.domain
  let mut s1 = dup_one(domain)
  let mut s2 : Array[FieldElem] = []
  let mut t1 : Array[FieldElem] = []
  let mut t2 = dup_one(domain)
  let mut r1 = poly_to_dense_desc(ff)
  let mut r2 = poly_to_dense_desc(gg)
  if dup_degree(r1) < dup_degree(r2) {
    let tmp_s = s1
    s1 = t1
    t1 = tmp_s
    let tmp_s2 = s2
    s2 = t2
    t2 = tmp_s2
    let tmp_r = r1
    r1 = r2
    r2 = tmp_r
  }
  let steps : Array[(Poly, Poly, Poly)] = []
  let max_steps = ({
      let df = dup_degree(r1)
      let dg = dup_degree(r2)
      if df > dg {
        df
      } else {
        dg
      }
    }) +
    1
  for _ in 0..<max_steps {
    if r2.is_empty() {
      break
    }
    steps.push(
      (
        poly_from_dup_desc(s2, ff),
        poly_from_dup_desc(t2, ff),
        poly_from_dup_desc(r2, ff),
      ),
    )
    let (q, rem) = dup_div(r1, r2, domain)
    if rem.is_empty() {
      break
    }
    r1 = r2
    r2 = rem
    let next_s = dup_sub_mul(s1, q, s2, domain)
    let next_t = dup_sub_mul(t1, q, t2, domain)
    s1 = s2
    s2 = next_s
    t1 = t2
    t2 = next_t
  }
  steps
}

///|
/// Run the half extended Euclidean algorithm.
///
/// - Does: Returns `(s, h)` such that `h = gcd(f, g)` and
///   `s*f = h (mod g)`.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: `(Poly, Poly)`.
/// - Limits: Requires a field after optional `auto` conversion.
pub fn half_gcdex(
  f : Poly,
  g : Poly,
  auto? : Bool = true,
) -> (Poly, Poly) raise PolyError {
  let (ff, gg) = gcdex_inputs(f, g, auto)
  let domain = ff.domain
  let mut f_desc = poly_to_dense_desc(ff)
  let mut g_desc = poly_to_dense_desc(gg)
  let mut a = dup_one(domain)
  let mut b : Array[FieldElem] = []
  while !g_desc.is_empty() {
    let (q, r) = dup_div(f_desc, g_desc, domain)
    f_desc = g_desc
    g_desc = r
    let next = dup_sub_mul(a, q, b, domain)
    a = b
    b = next
  }
  let lc = dup_LC(f_desc)
  let s = dup_exquo_ground(a, lc, domain)
  let h = dup_monic(f_desc, domain)
  (poly_from_dup_desc(s, ff), poly_from_dup_desc(h, ff))
}

///|
/// Run the extended Euclidean algorithm.
///
/// - Does: Returns `(s, t, h)` such that `s*f + t*g = h`.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: `(Poly, Poly, Poly)`.
/// - Limits: Requires a field after optional `auto` conversion.
pub fn gcdex(
  f : Poly,
  g : Poly,
  auto? : Bool = true,
) -> (Poly, Poly, Poly) raise PolyError {
  let (ff, gg) = gcdex_inputs(f, g, auto)
  let (s, h) = half_gcdex(ff, gg, auto=false)
  let t = if gg.is_zero() {
    Poly::zero(gg.gens, gg.domain).with_order(gg.order)
  } else {
    let h_desc = poly_to_dense_desc(h)
    let s_desc = poly_to_dense_desc(s)
    let f_desc = poly_to_dense_desc(ff)
    let g_desc = poly_to_dense_desc(gg)
    let diff = dup_sub_mul(h_desc, s_desc, f_desc, ff.domain)
    poly_from_dup_desc(dup_quo(diff, g_desc, ff.domain), ff)
  }
  (s, t, h)
}

///|
/// Invert a polynomial modulo another polynomial.
///
/// - Does: Computes `f**(-1) mod g` when `gcd(f, g) == 1`.
/// - Input: Two compatible univariate `Poly` values and optional `auto`.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError::ExactQuotientFailed` for zero divisors because
///   this package does not expose a separate `NotInvertible` error.
pub fn invert(f : Poly, g : Poly, auto? : Bool = true) -> Poly raise PolyError {
  let (ff, gg) = gcdex_inputs(f, g, auto)
  let (s, h) = half_gcdex(ff, gg, auto=false)
  let h_desc = poly_to_dense_desc(h)
  if dup_is_one(h_desc) {
    let s_desc = poly_to_dense_desc(s)
    let g_desc = poly_to_dense_desc(gg)
    poly_from_dup_desc(dup_rem(s_desc, g_desc, ff.domain), ff)
  } else {
    raise PolyError::ExactQuotientFailed
  }
}

///|
/// Compute the greatest common divisor.
///
/// - Does: Dispatches to univariate or multivariate gcd.
/// - Input: Two compatible `Poly` values.
/// - Returns: A normalized gcd `Poly`.
/// - Limits: Inherits the current domain and multivariate limits of the
///   underlying `Poly` methods.
pub fn gcd(f : Poly, g : Poly) -> Poly raise PolyError {
  if f.gens.length() == 1 {
    f.gcd_univar(g)
  } else {
    f.gcd_multivar(g)
  }
}

///|
/// Compute the least common multiple.
///
/// - Does: Computes `f*g/gcd(f, g)` and normalizes the result when possible.
/// - Input: Two compatible univariate `Poly` values.
/// - Returns: A `Poly`.
/// - Limits: Currently uses the same univariate-centered path as `lcm_list`.
pub fn lcm(f : Poly, g : Poly) -> Poly raise PolyError {
  lcm_list([f, g])
}

///|
/// Compute gcd and cofactors.
///
/// - Does: Returns `(h, cff, cfg)` where `h = gcd(f, g)`,
///   `cff = exquo(f, h)`, and `cfg = exquo(g, h)`.
/// - Input: Two compatible `Poly` values.
/// - Returns: `(Poly, Poly, Poly)`.
/// - Limits: Raises when exact cofactor division is unsupported.
pub fn cofactors(f : Poly, g : Poly) -> (Poly, Poly, Poly) raise PolyError {
  let h = gcd(f, g)
  let cff = exquo(f, h)
  let cfg = exquo(g, h)
  (h, cff, cfg)
}

///|
/// Compute polynomial GCD and cofactors through the heuristic-GCD front door.
///
/// - Does: Returns `(h, cff, cfg)` where `h = gcd(f, g)` and the cofactors
///   multiply back to the inputs.
/// - Input: Two compatible `Poly` values.
/// - Returns: `(Poly, Poly, Poly)`.
/// - Limits: Uses the deterministic package GCD/cofactor path rather than a
///   probabilistic heuristic path, so heuristic failure is not modeled.
pub fn heugcd(f : Poly, g : Poly) -> (Poly, Poly, Poly) raise PolyError {
  cofactors(f, g)
}

///|
/// Return coefficient content.
///
/// - Does: Computes the gcd of coefficients as an exact rational scalar.
/// - Input: One `Poly`.
/// - Returns: An `@symnum.BigRational`.
/// - Limits: Some non-rational coefficient domains conservatively return `1`.
pub fn content(poly : Poly) -> @symnum.BigRational raise PolyError {
  poly.content()
}

///|
/// Return content and primitive part.
///
/// - Does: Splits a polynomial into scalar coefficient content and primitive
///   polynomial part.
/// - Input: One `Poly`.
/// - Returns: `(@symnum.BigRational, Poly)`.
/// - Limits: Domains without a clear rational content notion may return
///   content `1` and the input unchanged.
pub fn primitive(poly : Poly) -> (@symnum.BigRational, Poly) raise PolyError {
  (poly.content(), poly.primitive_part())
}

///|
/// Normalize the leading coefficient to one.
///
/// - Does: Divides all coefficients by the leading coefficient.
/// - Input: One `Poly` and optional `auto`.
/// - Returns: A monic `Poly`.
/// - Limits: The default `auto=true` lifts `ZZ` input to `QQ`; domains without
///   invertible leading coefficients raise `PolyError::DomainNotField`.
pub fn monic(poly : Poly, auto? : Bool = true) -> Poly raise PolyError {
  if auto {
    match poly.domain {
      Domain::ZZ => make_monic(lift_to_qq(poly))
      _ => make_monic(poly)
    }
  } else {
    make_monic(poly)
  }
}

///|
fn symmetric_mod_int(value : Int, modulus : Int) -> Int raise PolyError {
  let p = if modulus < 0 { -modulus } else { modulus }
  if p == 0 {
    raise PolyError::BadModulus
  }
  let mut r = value % p
  if r < 0 {
    r += p
  }
  if r > p / 2 {
    r - p
  } else {
    r
  }
}

///|
fn trunc_coeff(
  coeff : FieldElem,
  modulus : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  let rat = fe_expect_rational(coeff)
  if !rat.is_integral() {
    raise PolyError::CoefficientNotInteger
  }
  fe_from_int(symmetric_mod_int(rat.numerator().to_int(), modulus), domain)
}

///|
/// Reduce coefficients modulo an integer.
///
/// - Does: Maps every coefficient into SymPy's symmetric residue interval for
///   `modulus`.
/// - Input: One `Poly` and a non-zero integer modulus.
/// - Returns: A `Poly` over the same generators and domain.
/// - Limits: Coefficients must be rational integers representable as `Int`.
pub fn trunc(poly : Poly, modulus : Int) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for mono, coeff in poly.coeffs {
    add_term(
      coeffs,
      mono,
      trunc_coeff(coeff, modulus, poly.domain),
      poly.domain,
    )
  }
  Poly::{ coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
}

///|
/// Factor a polynomial.
///
/// - Does: Returns irreducible factors with multiplicities.
/// - Input: One `Poly` plus optional factorization controls.
/// - Returns: `Array[(Poly, Int)]`.
/// - Limits: Inherits `Poly::factor` limits.
pub fn factor(
  poly : Poly,
  modulus? : Int,
  extension? : Array[String],
  seed? : Int,
  gens? : Array[String],
) -> Array[(Poly, Int)] raise PolyError {
  match (modulus, extension, seed, gens) {
    (None, None, None, None) => poly.factor()
    (Some(m), None, None, None) => poly.factor(modulus=m)
    (None, Some(e), None, None) => poly.factor(extension=e)
    (None, None, Some(s), None) => poly.factor(seed=s)
    (None, None, None, Some(g)) => poly.factor(gens=g)
    (Some(m), Some(e), None, None) => poly.factor(modulus=m, extension=e)
    (Some(m), None, Some(s), None) => poly.factor(modulus=m, seed=s)
    (Some(m), None, None, Some(g)) => poly.factor(modulus=m, gens=g)
    (None, Some(e), Some(s), None) => poly.factor(extension=e, seed=s)
    (None, Some(e), None, Some(g)) => poly.factor(extension=e, gens=g)
    (None, None, Some(s), Some(g)) => poly.factor(seed=s, gens=g)
    (Some(m), Some(e), Some(s), None) =>
      poly.factor(modulus=m, extension=e, seed=s)
    (Some(m), Some(e), None, Some(g)) =>
      poly.factor(modulus=m, extension=e, gens=g)
    (Some(m), None, Some(s), Some(g)) => poly.factor(modulus=m, seed=s, gens=g)
    (None, Some(e), Some(s), Some(g)) =>
      poly.factor(extension=e, seed=s, gens=g)
    (Some(m), Some(e), Some(s), Some(g)) =>
      poly.factor(modulus=m, extension=e, seed=s, gens=g)
  }
}

///|
/// Return content and factor list.
///
/// - Does: Separates scalar content and normalized factors.
/// - Input: One `Poly`.
/// - Returns: `(@symnum.BigRational, Array[(Poly, Int)])`.
/// - Limits: Inherits `Poly::factor_list` limits.
pub fn factor_list(
  poly : Poly,
) -> (@symnum.BigRational, Array[(Poly, Int)]) raise PolyError {
  poly.factor_list()
}

///|
/// Return content and square-free factors.
///
/// - Does: Splits a polynomial into square-free factors and multiplicities.
/// - Input: One `Poly`.
/// - Returns: `(@symnum.BigRational, Array[(Poly, Int)])`.
/// - Limits: Inherits `Poly::sqf_list` limits.
pub fn sqf_list(
  poly : Poly,
) -> (@symnum.BigRational, Array[(Poly, Int)]) raise PolyError {
  poly.sqf_list()
}

///|
/// Return the square-free part.
///
/// - Does: Multiplies distinct square-free factors.
/// - Input: One `Poly`.
/// - Returns: A `Poly`.
/// - Limits: Inherits `Poly::sqf_part` limits.
pub fn sqf_part(poly : Poly) -> Poly raise PolyError {
  poly.sqf_part()
}

///|
/// Return the square-free factorization as a polynomial.
///
/// - Does: Reconstructs `content * product(factor**multiplicity)` from
///   `sqf_list`, mirroring SymPy's expression-level `sqf` result.
/// - Input: One `Poly`.
/// - Returns: A `Poly`.
/// - Limits: The result remains a `Poly`; callers can use `to_expr` for an
///   expression-level view.
pub fn sqf(poly : Poly) -> Poly raise PolyError {
  let (coeff, factors) = sqf_list(poly)
  let mut out = Poly::one(poly.gens, poly.domain).scale_coeff(
    fe_from_rational(coeff, poly.domain),
  )
  for pair in factors {
    let (factor_poly, mult) = pair
    out = out.mul(factor_poly.pow(mult))
  }
  out
}

///|
fn linear_shift_poly(template : Poly, amount : Int) -> Poly raise PolyError {
  let x = Expr::Symbol(template.gens[0])
  PolyBuilder::new(template.gens, template.domain).from_expr(
    x + @symcore.int(amount),
  )
}

///|
fn poly_shift_int(poly : Poly, amount : Int) -> Poly raise PolyError {
  compose(poly, linear_shift_poly(poly, amount))
}

///|
/// Compute greatest factorial factorization factors.
///
/// - Does: Ports SymPy's recursive `dup_gff_list` algorithm using `Poly`
///   gcd, shift, multiplication, and exact quotient operations.
/// - Input: One non-zero univariate `Poly`.
/// - Returns: `Array[(Poly, Int)]` of greatest factorial factors.
/// - Limits: Multivariate input raises `PolyError::NotUnivariate`; non-monic
///   integer input is first viewed over `QQ`, matching SymPy's monic dense
///   precondition.
pub fn gff_list(poly : Poly) -> Array[(Poly, Int)] raise PolyError {
  ensure_univar(poly)
  if poly.is_zero() {
    raise PolyError::BadExponent
  }
  let f = monic(poly)
  if f.degree(0) == 0 {
    return []
  }
  let mut g = gcd(f, poly_shift_int(f, 1))
  let factors = gff_list(g)
  let out : Array[(Poly, Int)] = []
  for pair in factors {
    let (h, k) = pair
    g = g.mul(poly_shift_int(h, -k))
    out.push((h, k + 1))
  }
  let rest = exquo(f, g, auto=false)
  if rest.degree(0) == 0 {
    out
  } else {
    let result : Array[(Poly, Int)] = [(rest, 1)]
    for pair in out {
      result.push(pair)
    }
    result
  }
}

///|
/// Compute symbolic greatest factorial factorization.
///
/// - Does: Keeps SymPy's current public behavior for `gff`, which deliberately
///   raises because symbolic falling factorial output is not implemented.
/// - Input: One `Poly`.
/// - Returns: Nothing on success; this front door always raises.
/// - Limits: Raises `PolyError::BadGenerator("symbolic falling factorial")`.
pub fn gff(_poly : Poly) -> Poly raise PolyError {
  raise PolyError::BadGenerator("symbolic falling factorial")
}

///|
/// Compute a Sturm sequence.
///
/// - Does: Returns the univariate Sturm chain.
/// - Input: One univariate `Poly`.
/// - Returns: `Array[Poly]`.
/// - Limits: Inherits `sturm_sequence` limits.
pub fn sturm(poly : Poly) -> Array[Poly] raise PolyError {
  sturm_sequence(poly)
}

///|
/// Compute a Groebner basis.
///
/// - Does: Runs the package Buchberger front door.
/// - Input: A non-empty `Array[Poly]` and optional monomial order.
/// - Returns: `Array[Poly]`.
/// - Limits: Inherits `Poly::groebner` limits.
pub fn groebner(
  polys : Array[Poly],
  order? : TermOrder,
) -> Array[Poly] raise PolyError {
  match order {
    Some(ord) => Poly::groebner(polys, order=ord)
    None => Poly::groebner(polys)
  }
}

///|
/// Compute a resultant.
///
/// - Does: Eliminates one variable between two compatible polynomials.
/// - Input: Two `Poly` values and optional variable index.
/// - Returns: An exact rational scalar.
/// - Limits: Multivariate resultants that produce polynomial coefficients are
///   available through `Poly::resultant_poly`.
pub fn resultant(
  f : Poly,
  g : Poly,
  var_index? : Int = 0,
) -> @symnum.BigRational raise PolyError {
  f.resultant(g, var_index)
}

///|
fn filter_root_intervals(
  items : Array[((@symnum.BigRational, @symnum.BigRational), Int)],
  inf : @symnum.BigRational?,
  sup : @symnum.BigRational?,
) -> Array[((@symnum.BigRational, @symnum.BigRational), Int)] {
  let out : Array[((@symnum.BigRational, @symnum.BigRational), Int)] = []
  for item in items {
    let ((a, b), _) = item
    let include_lower = match inf {
      Some(v) => b.compare(v) >= 0
      None => true
    }
    let include_upper = match sup {
      Some(v) => a.compare(v) <= 0
      None => true
    }
    if include_lower && include_upper {
      out.push(item)
    }
  }
  out
}

///|
fn maybe_refine_interval(
  dense : Array[FieldElem],
  domain : Domain,
  interval : (@symnum.BigRational, @symnum.BigRational),
  eps : @symnum.BigRational?,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  match eps {
    Some(e) =>
      dup_refine_real_root(dense, interval.0, interval.1, domain, eps=e)
    None => interval
  }
}

///|
/// Isolate real roots.
///
/// - Does: Computes rational isolating intervals with multiplicities.
/// - Input: One univariate `Poly` and optional bounds/refinement settings.
/// - Returns: `Array[((BigRational, BigRational), Int)]`.
/// - Limits: Complex-rectangle counting and list-of-polynomials mode are not
///   part of this MoonBit front door.
pub fn intervals(
  poly : Poly,
  eps? : @symnum.BigRational,
  inf? : @symnum.BigRational,
  sup? : @symnum.BigRational,
  sqf? : Bool = false,
) -> Array[((@symnum.BigRational, @symnum.BigRational), Int)] raise PolyError {
  ensure_univar(poly)
  let dense = poly_to_dense_desc(poly)
  let raw = if sqf {
    dup_isolate_real_roots_sqf(dense, poly.domain).map(iv => (iv, 1))
  } else {
    dup_isolate_real_roots(dense, poly.domain)
  }
  let bounded = filter_root_intervals(raw, inf, sup)
  let out : Array[((@symnum.BigRational, @symnum.BigRational), Int)] = []
  for item in bounded {
    let (iv, mult) = item
    out.push((maybe_refine_interval(dense, poly.domain, iv, eps), mult))
  }
  out
}

///|
/// Refine one isolating interval.
///
/// - Does: Narrows the rational interval containing one real root.
/// - Input: One univariate `Poly`, interval endpoints, and optional controls.
/// - Returns: `(BigRational, BigRational)`.
/// - Limits: The interval is assumed to isolate a real root.
pub fn refine_root(
  poly : Poly,
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  eps? : @symnum.BigRational,
  steps? : Int,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  ensure_univar(poly)
  let dense = poly_to_dense_desc(poly)
  match (steps, eps) {
    (None, None) => dup_refine_real_root(dense, s, t, poly.domain)
    (Some(step_count), None) =>
      dup_refine_real_root(dense, s, t, poly.domain, steps=step_count)
    (None, Some(epsilon)) =>
      dup_refine_real_root(dense, s, t, poly.domain, eps=epsilon)
    (Some(step_count), Some(epsilon)) =>
      dup_refine_real_root(
        dense,
        s,
        t,
        poly.domain,
        steps=step_count,
        eps=epsilon,
      )
  }
}

///|
/// Count distinct real roots in a rational interval.
///
/// - Does: Counts roots whose isolating intervals intersect `[inf, sup]`.
/// - Input: One univariate `Poly` and optional rational bounds.
/// - Returns: An `Int`.
/// - Limits: Complex rectangle counting is not implemented.
pub fn count_roots(
  poly : Poly,
  inf? : @symnum.BigRational,
  sup? : @symnum.BigRational,
) -> Int raise PolyError {
  ensure_univar(poly)
  let dense = poly_to_dense_desc(poly)
  match (inf, sup) {
    (None, None) => dup_count_real_roots(dense, poly.domain)
    (Some(lo), None) => dup_count_real_roots(dense, poly.domain, inf=lo)
    (None, Some(hi)) => dup_count_real_roots(dense, poly.domain, sup=hi)
    (Some(lo), Some(hi)) =>
      dup_count_real_roots(dense, poly.domain, inf=lo, sup=hi)
  }
}

///|
/// Return all roots with multiplicity.
///
/// - Does: Forwards to the symbolic `roots` front door.
/// - Input: One univariate `Poly` and optional radical formula toggle.
/// - Returns: `Array[Expr]`.
/// - Limits: `multiple=false` is not modeled because MoonBit does not return
///   Python-style union values from one function.
pub fn all_roots(
  poly : Poly,
  radicals? : Bool = true,
) -> Array[Expr] raise PolyError {
  let out = roots(poly, radicals~)
  out.sort_by(@symcore.compare_expr)
  out
}

///|
/// Return real roots with multiplicity.
///
/// - Does: Factors the polynomial, solves low-degree real factors exactly, and
///   represents higher-degree real roots with `CRootOf` placeholders.
/// - Input: One univariate `Poly` and optional radical formula toggle.
/// - Returns: `Array[Expr]`.
/// - Limits: Algebraic filtering is interval-count based; complex `CRootOf`
///   roots are not materialized.
pub fn real_roots(
  poly : Poly,
  radicals? : Bool = true,
) -> Array[Expr] raise PolyError {
  ignore(radicals)
  ensure_univar(poly)
  let out : Array[Expr] = []
  let (_, factors) = poly.factor_list()
  for pair in factors {
    let (factor_poly, mult) = pair
    let deg = factor_poly.degree(0)
    let factor_roots = if deg == 1 {
      roots_linear(factor_poly)
    } else if deg == 2 && count_roots(factor_poly) > 0 {
      roots_quadratic(factor_poly)
    } else if deg > 2 {
      let n = count_roots(factor_poly)
      let roots : Array[Expr] = []
      for i in 0..<n {
        roots.push(rootof_expr(factor_poly, i))
      }
      roots
    } else {
      []
    }
    append_roots(out, factor_roots, mult)
  }
  out.sort_by(@symcore.compare_expr)
  out
}

///|
/// Numerically approximate roots.
///
/// - Does: Applies the package `evalf` path to symbolic `all_roots` output.
/// - Input: One univariate `Poly`, decimal-digit hint `n`, and compatibility
///   controls accepted for API shape.
/// - Returns: `Array[Expr]` containing float expressions when `evalf` can
///   evaluate the symbolic root.
/// - Limits: This is not yet a Durand-Kerner/mpmath equivalent; unresolved
///   `CRootOf` placeholders remain symbolic.
pub fn nroots(
  poly : Poly,
  n? : Int = 15,
  maxsteps? : Int = 50,
  cleanup? : Bool = true,
) -> Array[Expr] raise PolyError {
  ignore(maxsteps)
  ignore(cleanup)
  let prec = if n <= 0 { 53 } else { n * 4 }
  all_roots(poly).map(root => @symcore.evalf(root, prec~))
}

///|
/// Construct a polynomial whose roots are n-th powers of input roots.
///
/// - Does: Mirrors SymPy's resultant construction
///   `resultant(f(x), x**n - t, x)` and renames `t` back to the input
///   generator.
/// - Input: One univariate `Poly` and positive integer `n`.
/// - Returns: A univariate `Poly`.
/// - Limits: Uses a synthetic temporary generator and requires resultant
///   support over the input domain.
pub fn nth_power_roots_poly(poly : Poly, n : Int) -> Poly raise PolyError {
  ensure_univar(poly)
  if n < 1 {
    raise PolyError::BadExponent
  }
  let x_name = poly.gens[0]
  let mut t_name = "_t"
  while poly.gens.any(g => g == t_name) {
    t_name = "_" + t_name
  }
  let x = Expr::Symbol(x_name)
  let t = Expr::Symbol(t_name)
  let gens = [x_name, t_name]
  let f = Poly::from_expr_defaults(poly.to_expr(), gens~, domain=poly.domain)
  let q = Poly::from_expr_defaults(
    (x ^ @symcore.int(n)) - t,
    gens~,
    domain=poly.domain,
  )
  let res = f.resultant_poly(q, 0)
  let expr = expr_replace_symbol(res.to_expr(), t_name, x_name)
  Poly::from_expr_defaults(expr, gens=poly.gens, domain=poly.domain).with_order(
    poly.order,
  )
}

///|
/// Check whether a Groebner basis defines a zero-dimensional ideal.
///
/// - Does: Computes a Groebner basis and verifies that every generator has a
///   pure-power leading monomial in the basis.
/// - Input: A polynomial system and optional monomial order.
/// - Returns: `Bool`.
/// - Limits: Assumes the package's reduced Groebner output and supported
///   monomial orders.
pub fn is_zero_dimensional(
  polys : Array[Poly],
  order? : TermOrder,
) -> Bool raise PolyError {
  if polys.is_empty() {
    return false
  }
  let basis = match order {
    Some(ord) => groebner(polys, order=ord)
    None => groebner(polys)
  }
  let n = basis[0].gens.length()
  for i in 0..<n {
    let mut found = false
    for p in basis {
      let mono = match p.lm() {
        Some(m) => m
        None => continue
      }
      let mut pure = mono.exps[i] > 0
      for j in 0..<n {
        if j != i && mono.exps[j] != 0 {
          pure = false
          break
        }
      }
      if pure {
        found = true
        break
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
/// Compute roots found directly in the ground domain.
///
/// - Does: Factors the polynomial and returns roots of linear factors with
///   multiplicities.
/// - Input: One univariate `Poly`.
/// - Returns: `Array[(Expr, Int)]`.
/// - Limits: Non-linear factors are ignored; this mirrors the useful ground
///   factorization path without exposing a Python dict.
pub fn ground_roots(poly : Poly) -> Array[(Expr, Int)] raise PolyError {
  ensure_univar(poly)
  let out : Array[(Expr, Int)] = []
  let (_, factors) = poly.factor_list()
  for pair in factors {
    let (factor_poly, mult) = pair
    if factor_poly.degree(0) == 1 {
      let rs = roots_linear(factor_poly)
      if !rs.is_empty() {
        out.push((rs[0], mult))
      }
    }
  }
  out.sort_by((lhs, rhs) => @symcore.compare_expr(lhs.0, rhs.0))
  out
}
