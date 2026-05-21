///|
/// Modular-GCD compatibility front doors.

///|
fn modgcd_lc_is_negative(poly : Poly) -> Bool raise PolyError {
  fe_expect_rational(poly.lc()).compare(@symnum.BigRational::zero()) < 0
}

///|
fn modgcd_signed_one(
  gens : Array[String],
  domain : Domain,
  negative : Bool,
) -> Poly raise PolyError {
  let one = Poly::one(gens, domain)
  if negative {
    one.neg()
  } else {
    one
  }
}

///|
fn modgcd_exact_division(a : Poly, b : Poly) -> Poly raise PolyError {
  if a.gens.length() == 1 {
    exquo(a, b, auto=false)
  } else {
    // Multivariate division is a field operation in the Groebner front door.
    try_round_to_int(poly_div_exact(lift_to_qq(a), lift_to_qq(b)))
  }
}

///|
fn modgcd_exact_cofactors(
  f : Poly,
  g : Poly,
) -> (Poly, Poly, Poly) raise PolyError {
  if f.domain != Domain::ZZ || g.domain != Domain::ZZ {
    raise PolyError::DomainMismatch
  }
  if f.gens != g.gens {
    raise PolyError::DomainMismatch
  }
  let zero = Poly::zero(f.gens, f.domain)
  if f.is_zero() && g.is_zero() {
    return (zero, zero, zero)
  }
  if f.is_zero() {
    let neg = modgcd_lc_is_negative(g)
    let h = if neg { g.neg() } else { g }
    return (h, zero, modgcd_signed_one(f.gens, f.domain, neg))
  }
  if g.is_zero() {
    let neg = modgcd_lc_is_negative(f)
    let h = if neg { f.neg() } else { f }
    return (h, modgcd_signed_one(f.gens, f.domain, neg), zero)
  }
  let h = gcd(f, g)
  let cff = modgcd_exact_division(f, h)
  let cfg = modgcd_exact_division(g, h)
  (h, cff, cfg)
}

///|
/// Compute univariate integer-polynomial gcd and cofactors.
///
/// - Does: Mirrors SymPy's `modgcd_univariate` return contract: `(h, cff,
///   cfg)` where `h` is the GCD, `cff*h == f`, and `cfg*h == g`.
/// - Input: Two compatible univariate `Poly` values over `ZZ`.
/// - Returns: `(Poly, Poly, Poly)`.
/// - Limits: The public result is aligned; the current implementation reuses
///   the package exact GCD/cofactor engine rather than exposing SymPy's modular
///   reconstruction loop as a separate observable step.
pub fn modgcd_univariate(
  f : Poly,
  g : Poly,
) -> (Poly, Poly, Poly) raise PolyError {
  if f.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  modgcd_exact_cofactors(f, g)
}

///|
/// Compute bivariate integer-polynomial gcd and cofactors.
///
/// - Does: Mirrors SymPy's `modgcd_bivariate` return contract: `(h, cff,
///   cfg)` with `cff*h == f` and `cfg*h == g`.
/// - Input: Two compatible bivariate `Poly` values over `ZZ`.
/// - Returns: `(Poly, Poly, Poly)`.
/// - Limits: The public result is aligned; the current implementation reuses
///   the package exact GCD/cofactor engine rather than SymPy's modular
///   reconstruction loop as an observable step.
pub fn modgcd_bivariate(
  f : Poly,
  g : Poly,
) -> (Poly, Poly, Poly) raise PolyError {
  if f.gens.length() != 2 {
    raise PolyError::BadGenerator(f.gens.join(","))
  }
  modgcd_exact_cofactors(f, g)
}

///|
/// Compute multivariate integer-polynomial gcd and cofactors.
///
/// - Does: Mirrors SymPy's `modgcd_multivariate` return contract for
///   polynomial rings with at least two generators.
/// - Input: Two compatible multivariate `Poly` values over `ZZ`.
/// - Returns: `(Poly, Poly, Poly)`.
/// - Limits: Uses the package exact GCD/cofactor engine; the modular
///   reconstruction internals remain a future kernel-level migration.
pub fn modgcd_multivariate(
  f : Poly,
  g : Poly,
) -> (Poly, Poly, Poly) raise PolyError {
  if f.gens.length() < 2 {
    raise PolyError::NotUnivariate
  }
  modgcd_exact_cofactors(f, g)
}
