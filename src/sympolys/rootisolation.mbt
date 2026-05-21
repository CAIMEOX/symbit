///|
/// Real-root isolation helpers for dense univariate polynomials.
///
/// Current Limits:
/// - These front doors are restricted to dense coefficient arrays over
///   rational-like domains.
/// - The API is intentionally low-level and works on dense coefficient
///   sequences rather than `Poly` output objects.
fn abs_rational(r : @symnum.BigRational) -> @symnum.BigRational {
  if r.compare(@symnum.BigRational::zero()) < 0 {
    r.neg()
  } else {
    r
  }
}

///|
fn pow_rational(base : @symnum.BigRational, exp : Int) -> @symnum.BigRational {
  let mut result = @symnum.BigRational::one()
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result.mul(b)
    }
    e = e / 2
    if e > 0 {
      b = b.mul(b)
    }
  }
  result
}

///|
fn reverse_coeffs(coeffs : Array[FieldElem]) -> Array[FieldElem] {
  let out : Array[FieldElem] = Array::new()
  let mut i = coeffs.length()
  while i > 0 {
    i = i - 1
    out.push(coeffs[i])
  }
  out
}

///|
fn dup_to_poly(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Poly raise PolyError {
  let f = dup_strip(coeffs)
  if f.is_empty() {
    raise PolyError::NonPolynomial
  }
  let asc = reverse_coeffs(f)
  from_dense(asc, ["x"], domain)
}

///|
fn poly_to_dup(poly : Poly) -> Array[FieldElem] raise PolyError {
  let deg = poly.degree(0)
  let asc = to_dense(poly, degree=deg)
  dup_reverse(asc)
}

///|
/// Compute a Cauchy upper bound for root magnitudes.
///
/// - Does: Returns an upper bound on the absolute value of every root of the
///   dense polynomial.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: A `FieldElem`.
/// - Limits: Raises `PolyError::BadExponent` for constant input.
pub fn dup_cauchy_upper_bound(
  coeffs : Array[FieldElem],
  _domain : Domain,
) -> FieldElem raise PolyError {
  let f = dup_strip(coeffs)
  if f.length() < 2 {
    raise PolyError::BadExponent
  }
  let lc = fe_expect_rational(f[0])
  if lc.is_zero() {
    raise PolyError::DivisionByZero
  }
  let mut max_ratio = @symnum.BigRational::zero()
  for i in 1..<f.length() {
    let ai = abs_rational(fe_expect_rational(f[i]))
    let ratio = poly_rational_div(ai, abs_rational(lc))
    if ratio.compare(max_ratio) > 0 {
      max_ratio = ratio
    }
  }
  let one = @symnum.BigRational::one()
  fe_from_rational(one.add(max_ratio), Domain::QQ)
}

///|
/// Compute a Cauchy lower bound for non-zero root magnitudes.
///
/// - Does: Returns a lower bound on the absolute value of every non-zero root.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: A `FieldElem`.
/// - Limits: Raises `PolyError::BadExponent` for constant input.
pub fn dup_cauchy_lower_bound(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let g = dup_strip(reverse_coeffs(coeffs))
  if g.length() < 2 {
    raise PolyError::BadExponent
  }
  let upper = dup_cauchy_upper_bound(g, domain)
  let upper_rat = fe_expect_rational(upper)
  let inv = upper_rat.reciprocal() catch {
    _ => raise PolyError::DivisionByZero
  }
  fe_from_rational(inv, Domain::QQ)
}

///|
/// Return a squared Mignotte separation bound.
///
/// - Does: Computes a lower bound on the squared distance between distinct
///   roots.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: A `FieldElem`.
/// - Limits: Raises `PolyError::BadExponent` for degree `< 2`.
pub fn dup_mignotte_sep_bound_squared(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let f = dup_strip(coeffs)
  let n = dup_degree(f)
  if n < 2 {
    raise PolyError::BadExponent
  }
  let asc : Array[FieldElem] = Array::new()
  let mut i = f.length()
  while i > 0 {
    i = i - 1
    asc.push(f[i])
  }
  let poly = from_dense(asc, ["x"], domain)
  let disc = discriminant(poly)
  let disc_rat = abs_rational(fe_expect_rational(disc))
  let l2sq_fe = dup_l2_norm_squared(f, domain)
  let l2sq = fe_expect_rational(l2sq_fe)
  let n_rat = @symnum.BigRational::from_int(n)
  let num = @symnum.BigRational::from_int(3).mul(disc_rat)
  let denom = pow_rational(n_rat, n + 1).mul(pow_rational(l2sq, n - 1))
  if denom.is_zero() {
    raise PolyError::DivisionByZero
  }
  let bound = poly_rational_div(num, denom)
  fe_from_rational(bound, Domain::QQ)
}

///|
/// Build the dense Sturm sequence.
///
/// - Does: Converts the dense polynomial into `Poly`, builds its Sturm
///   sequence, and converts every step back to dense form.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: `Array[Array[FieldElem]]`.
/// - Limits: Raises `PolyError::NonPolynomial` for empty input.
pub fn dup_sturm(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let f = dup_strip(coeffs)
  if f.is_empty() {
    raise PolyError::NonPolynomial
  }
  if f.length() == 1 {
    return [[fe_from_int(1, domain)]]
  }
  let poly = dup_to_poly(f, domain)
  let seq = sturm_sequence(poly)
  let out : Array[Array[FieldElem]] = Array::new()
  for p in seq {
    out.push(poly_to_dup(p))
  }
  out
}

///|
fn rat_sub(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational {
  a.add_r(b.neg_r())
}

///|
fn rat_sign(r : @symnum.BigRational) -> Int {
  r.compare(@symnum.BigRational::zero())
}

///|
fn rat_mediant(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational raise PolyError {
  let num = a.numerator().add(b.numerator())
  let den = a.denominator().add(b.denominator())
  @symnum.BigRational::new(num, den) catch {
    _ => raise PolyError::DivisionByZero
  }
}

///|
fn rat_mid(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational raise PolyError {
  if a.is_integral() && b.is_integral() {
    let ai = a.numerator().to_int()
    let bi = b.numerator().to_int()
    if bi - ai > 1 {
      let mid = (ai + bi) / 2
      return @symnum.BigRational::from_int(mid)
    }
  }
  let half = poly_rational_from_ints(1, 2)
  let sum = a.add_r(b)
  sum.mul_r(half)
}

///|
fn interval_small(a : @symnum.BigRational, b : @symnum.BigRational) -> Bool {
  if a.is_integral() && b.is_integral() {
    let ai = a.numerator().to_int()
    let bi = b.numerator().to_int()
    bi - ai <= 1
  } else {
    let width = rat_sub(b, a)
    width.compare(@symnum.BigRational::from_int(1)) <= 0
  }
}

///|
fn eval_dup_rational(
  coeffs : Array[FieldElem],
  x : @symnum.BigRational,
) -> @symnum.BigRational raise PolyError {
  let mut acc = @symnum.BigRational::zero()
  for c in coeffs {
    let coeff = fe_expect_rational(c)
    acc = acc.mul_r(x).add_r(coeff)
  }
  acc
}

///|
fn sturm_variations(
  seq : Array[Array[FieldElem]],
  x : @symnum.BigRational,
) -> Int raise PolyError {
  let mut prev_sign = 0
  let mut variations = 0
  for poly in seq {
    let val = eval_dup_rational(poly, x)
    let s = rat_sign(val)
    if s == 0 {
      continue
    }
    if prev_sign != 0 && s != prev_sign {
      variations = variations + 1
    }
    prev_sign = s
  }
  variations
}

///|
fn isolate_sturm(
  f : Array[FieldElem],
  seq : Array[Array[FieldElem]],
  a : @symnum.BigRational,
  b : @symnum.BigRational,
  intervals : Array[(@symnum.BigRational, @symnum.BigRational)],
  include_left : Bool,
  include_right : Bool,
) -> Unit raise PolyError {
  let var_a = sturm_variations(seq, a)
  let var_b = sturm_variations(seq, b)
  let mut count = var_a - var_b
  let fa = eval_dup_rational(f, a)
  let fb = eval_dup_rational(f, b)
  if include_left && rat_sign(fa) == 0 {
    intervals.push((a, a))
  }
  if rat_sign(fb) == 0 {
    if include_right {
      intervals.push((b, b))
    }
    count = count - 1
  }
  if count <= 0 {
    return
  }
  if count == 1 && interval_small(a, b) {
    intervals.push((a, b))
    return
  }
  let mid = rat_mid(a, b)
  if mid.compare(a) == 0 || mid.compare(b) == 0 {
    intervals.push((a, b))
    return
  }
  let fm = eval_dup_rational(f, mid)
  if rat_sign(fm) == 0 {
    intervals.push((mid, mid))
  }
  isolate_sturm(f, seq, a, mid, intervals, include_left, false)
  isolate_sturm(f, seq, mid, b, intervals, false, include_right)
}

///|
fn ceil_pos_rational(r : @symnum.BigRational) -> Int {
  let num = r.numerator()
  let den = r.denominator()
  let div = num.div(den)
  let rem = num.mod(den)
  if rem.is_zero() {
    div.to_int()
  } else {
    div.add(BigInt::from_int(1)).to_int()
  }
}

///|
/// Refine a real-root isolating interval.
///
/// - Does: Narrows one isolating interval with mediants until a stopping
///   condition is reached.
/// - Input: Dense coefficient array, interval endpoints, coefficient `Domain`,
///   and optional refinement controls.
/// - Returns: `(@symnum.BigRational, @symnum.BigRational)`.
/// - Limits: Empty input raises `PolyError::NonPolynomial`; non-isolating input
///   may be returned unchanged.
pub fn dup_refine_real_root(
  coeffs : Array[FieldElem],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain : Domain,
  steps? : Int,
  eps? : @symnum.BigRational,
  disjoint? : @symnum.BigRational,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  let f = dup_strip(coeffs)
  if f.is_empty() {
    raise PolyError::NonPolynomial
  }
  if s.compare(t) == 0 {
    return (s, t)
  }
  let mut a = s
  let mut b = t
  if a.compare(b) > 0 {
    let tmp = a
    a = b
    b = tmp
  }
  let mut fa = eval_dup_rational(f, a)
  let mut fb = eval_dup_rational(f, b)
  let mut sa = rat_sign(fa)
  let mut sb = rat_sign(fb)
  if sa == 0 {
    return (a, a)
  }
  if sb == 0 {
    return (b, b)
  }
  let seq = dup_sturm(f, domain)
  let mut count = sturm_variations(seq, a) - sturm_variations(seq, b)
  if count <= 0 {
    return (a, b)
  }
  match disjoint {
    Some(d) => if d.compare(a) <= 0 || d.compare(b) >= 0 { return (a, b) }
    None => ()
  }
  let mut iter = 0
  let max_iter = match steps {
    Some(n) => n
    None =>
      match (eps, disjoint) {
        (Some(_), _) => 256
        (None, Some(_)) => 256
        (None, None) => 1
      }
  }
  while iter < max_iter {
    match eps {
      Some(e) =>
        if steps is None {
          let width = rat_sub(b, a)
          if width.compare(e) <= 0 {
            break
          }
        }
      None => ()
    }
    let m = rat_mediant(a, b)
    let fm = eval_dup_rational(f, m)
    let sm = rat_sign(fm)
    if sm == 0 {
      return (m, m)
    }
    if sa * sm < 0 {
      b = m
      fb = fm
      sb = sm
      count = sturm_variations(seq, a) - sturm_variations(seq, b)
    } else if sa * sm > 0 {
      a = m
      fa = fm
      sa = sm
      count = sturm_variations(seq, a) - sturm_variations(seq, b)
    } else {
      let left = sturm_variations(seq, a) - sturm_variations(seq, m)
      if left > 0 {
        b = m
        fb = fm
        sb = sm
      } else {
        a = m
        fa = fm
        sa = sm
      }
      count = sturm_variations(seq, a) - sturm_variations(seq, b)
    }
    if steps is None && eps is None && disjoint is None {
      if count <= 1 && interval_small(a, b) {
        break
      }
    }
    match disjoint {
      Some(d) => if d.compare(a) <= 0 || d.compare(b) >= 0 { break }
      None => ()
    }
    iter = iter + 1
  }
  (a, b)
}

///|
/// Perform one interval-refinement step for a real root.
///
/// - Does: Narrows the supplied isolating interval by one refinement step.
/// - Input: Dense coefficient array, interval endpoints, and coefficient
///   `Domain`.
/// - Returns: The refined interval.
/// - Limits: This typed front door accepts intervals directly rather than
///   SymPy's internal Mobius-transform tuple.
pub fn dup_step_refine_real_root(
  coeffs : Array[FieldElem],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain : Domain,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  dup_refine_real_root(coeffs, s, t, domain, steps=1)
}

///|
fn dup_refine_real_root_with_options(
  coeffs : Array[FieldElem],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain : Domain,
  steps : Int?,
  eps : @symnum.BigRational?,
  disjoint : @symnum.BigRational?,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  match (steps, eps, disjoint) {
    (None, None, None) => dup_refine_real_root(coeffs, s, t, domain)
    (Some(k), None, None) => dup_refine_real_root(coeffs, s, t, domain, steps=k)
    (None, Some(e), None) => dup_refine_real_root(coeffs, s, t, domain, eps=e)
    (None, None, Some(d)) =>
      dup_refine_real_root(coeffs, s, t, domain, disjoint=d)
    (Some(k), Some(e), None) =>
      dup_refine_real_root(coeffs, s, t, domain, steps=k, eps=e)
    (Some(k), None, Some(d)) =>
      dup_refine_real_root(coeffs, s, t, domain, steps=k, disjoint=d)
    (None, Some(e), Some(d)) =>
      dup_refine_real_root(coeffs, s, t, domain, eps=e, disjoint=d)
    (Some(k), Some(e), Some(d)) =>
      dup_refine_real_root(coeffs, s, t, domain, steps=k, eps=e, disjoint=d)
  }
}

///|
/// Refine an inner real-root interval.
///
/// - Does: Refines an isolating interval using the same interval algorithm as
///   `dup_refine_real_root`.
/// - Input: Dense coefficient array, interval endpoints, coefficient `Domain`,
///   and optional refinement controls.
/// - Returns: The refined interval.
/// - Limits: Mobius-transform input/output is not represented; callers pass
///   intervals directly.
pub fn dup_inner_refine_real_root(
  coeffs : Array[FieldElem],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain : Domain,
  steps? : Int,
  eps? : @symnum.BigRational,
  disjoint? : @symnum.BigRational,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  dup_refine_real_root_with_options(coeffs, s, t, domain, steps, eps, disjoint)
}

///|
/// Refine an outer real-root interval.
///
/// - Does: Refines an isolating interval after the outer interval has already
///   been chosen by the caller.
/// - Input: Dense coefficient array, interval endpoints, coefficient `Domain`,
///   and optional refinement controls.
/// - Returns: The refined interval.
/// - Limits: Uses the package's direct interval representation rather than
///   exposing internal Mobius transforms.
pub fn dup_outer_refine_real_root(
  coeffs : Array[FieldElem],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain : Domain,
  steps? : Int,
  eps? : @symnum.BigRational,
  disjoint? : @symnum.BigRational,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  dup_refine_real_root_with_options(coeffs, s, t, domain, steps, eps, disjoint)
}

///|
/// Isolate real roots of a square-free dense polynomial.
///
/// - Does: Uses Sturm subdivision inside a global Cauchy bound to produce
///   isolating intervals.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: `Array[(@symnum.BigRational, @symnum.BigRational)]`.
/// - Limits: Constant input returns `[]`.
pub fn dup_isolate_real_roots_sqf(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[(@symnum.BigRational, @symnum.BigRational)] raise PolyError {
  let f = dup_strip(coeffs)
  if f.is_empty() || f.length() == 1 {
    return []
  }
  let bound_fe = dup_cauchy_upper_bound(f, domain)
  let bound_rat = abs_rational(fe_expect_rational(bound_fe))
  let mut bound_int = ceil_pos_rational(bound_rat)
  if bound_int < 0 {
    bound_int = 0
  }
  let a = @symnum.BigRational::from_int(-bound_int)
  let b = @symnum.BigRational::from_int(bound_int)
  let intervals : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  let seq = dup_sturm(f, domain)
  isolate_sturm(f, seq, a, b, intervals, true, true)
  intervals.sort_by((left, right) => {
    let (a1, b1) = left
    let (a2, b2) = right
    let cmp = a1.compare(a2)
    if cmp != 0 {
      cmp
    } else {
      b1.compare(b2)
    }
  })
  intervals
}

///|
fn root_interval_positive(
  interval : (@symnum.BigRational, @symnum.BigRational),
) -> Bool {
  let (a, b) = interval
  b.compare(@symnum.BigRational::zero()) > 0 && !(a.is_zero() && b.is_zero())
}

///|
fn root_interval_negative(
  interval : (@symnum.BigRational, @symnum.BigRational),
) -> Bool {
  let (a, b) = interval
  a.compare(@symnum.BigRational::zero()) < 0 && !(a.is_zero() && b.is_zero())
}

///|
/// Isolate square-free real roots without postprocessing multiplicities.
///
/// - Does: Exposes the internal real-root isolation front door over the current
///   Sturm-subdivision implementation.
/// - Input: Dense coefficient array and coefficient `Domain`.
/// - Returns: Isolating intervals for all real roots.
/// - Limits: Returns intervals rather than SymPy's internal Mobius data.
pub fn dup_inner_isolate_real_roots(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[(@symnum.BigRational, @symnum.BigRational)] raise PolyError {
  dup_isolate_real_roots_sqf(coeffs, domain)
}

///|
/// Isolate positive real roots of a square-free polynomial.
///
/// - Does: Filters the real isolating intervals to positive roots.
/// - Input: Dense coefficient array and coefficient `Domain`.
/// - Returns: Positive-root intervals.
/// - Limits: Optional interval bounds and Mobius output from SymPy's Python API
///   are not represented.
pub fn dup_inner_isolate_positive_roots(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[(@symnum.BigRational, @symnum.BigRational)] raise PolyError {
  dup_isolate_real_roots_sqf(coeffs, domain).filter(root_interval_positive)
}

///|
/// Isolate negative real roots of a square-free polynomial.
///
/// - Does: Filters the real isolating intervals to negative roots.
/// - Input: Dense coefficient array and coefficient `Domain`.
/// - Returns: Negative-root intervals.
/// - Limits: Optional interval bounds and Mobius output from SymPy's Python API
///   are not represented.
pub fn dup_inner_isolate_negative_roots(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[(@symnum.BigRational, @symnum.BigRational)] raise PolyError {
  dup_isolate_real_roots_sqf(coeffs, domain).filter(root_interval_negative)
}

///|
/// Compute the positive-root upper bound.
///
/// - Does: Exposes the root upper-bound helper under the compatibility name
///   used by callers.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: A `FieldElem`.
/// - Limits: Inherits the same front-door errors as `dup_cauchy_upper_bound`.
pub fn dup_root_upper_bound(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  dup_cauchy_upper_bound(coeffs, domain)
}

///|
/// Compute the positive-root lower bound.
///
/// - Does: Exposes the root lower-bound helper under the compatibility name
///   used by callers.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: A `FieldElem`.
/// - Limits: Inherits the same front-door errors as `dup_cauchy_lower_bound`.
pub fn dup_root_lower_bound(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  dup_cauchy_lower_bound(coeffs, domain)
}

///|
/// Isolate real roots together with multiplicities.
///
/// - Does: Splits the dense polynomial into square-free factors, isolates each
///   factor’s real roots, and attaches multiplicities.
/// - Input: Dense coefficient array and one coefficient `Domain`.
/// - Returns: `Array[((@symnum.BigRational, @symnum.BigRational), Int)]`.
/// - Limits: Constant input returns `[]`.
pub fn dup_isolate_real_roots(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[((@symnum.BigRational, @symnum.BigRational), Int)] raise PolyError {
  let f = dup_strip(coeffs)
  if f.is_empty() || f.length() == 1 {
    return []
  }
  let poly = dup_to_poly(f, domain)
  let (_, parts) = poly.sqf_list()
  let out : Array[((@symnum.BigRational, @symnum.BigRational), Int)] = Array::new()
  for entry in parts {
    let (factor, mult) = entry
    let dense = poly_to_dup(factor)
    let intervals = dup_isolate_real_roots_sqf(dense, domain)
    for iv in intervals {
      out.push((iv, mult))
    }
  }
  out.sort_by((lhs, rhs) => {
    let ((a1, b1), _) = lhs
    let ((a2, b2), _) = rhs
    let cmp = a1.compare(a2)
    if cmp != 0 {
      cmp
    } else {
      b1.compare(b2)
    }
  })
  out
}

///|
/// Isolate real roots for a list of dense polynomials.
///
/// - Does: Applies `dup_isolate_real_roots` to each polynomial in order and
///   records the source polynomial index.
/// - Input: Dense coefficient arrays and coefficient `Domain`.
/// - Returns: Triples `(interval, polynomial_index, multiplicity)`.
/// - Limits: The Python API disjoins and groups shared roots across input
///   polynomials; this typed front door keeps source indices explicit instead
///   of returning Python dictionaries.
pub fn dup_isolate_real_roots_list(
  polys : Array[Array[FieldElem]],
  domain : Domain,
) -> Array[((@symnum.BigRational, @symnum.BigRational), Int, Int)] raise PolyError {
  let out : Array[((@symnum.BigRational, @symnum.BigRational), Int, Int)] = []
  for i in 0..<polys.length() {
    let roots = dup_isolate_real_roots(polys[i], domain)
    for entry in roots {
      let (interval, mult) = entry
      out.push((interval, i, mult))
    }
  }
  out.sort_by((lhs, rhs) => {
    let ((a1, b1), i1, _) = lhs
    let ((a2, b2), i2, _) = rhs
    let cmp = a1.compare(a2)
    if cmp != 0 {
      cmp
    } else {
      let cmp_b = b1.compare(b2)
      if cmp_b != 0 {
        cmp_b
      } else {
        i1.compare(i2)
      }
    }
  })
  out
}

///|
/// Count distinct real roots in an interval.
///
/// - Does: Counts isolated real roots whose intervals intersect the supplied
///   bounds.
/// - Input: Dense coefficient array, coefficient `Domain`, and optional lower
///   and upper bounds.
/// - Returns: An `Int`.
/// - Limits: Multiplicities are ignored; this counts distinct real roots only.
pub fn dup_count_real_roots(
  coeffs : Array[FieldElem],
  domain : Domain,
  inf? : @symnum.BigRational,
  sup? : @symnum.BigRational,
) -> Int raise PolyError {
  let roots = dup_isolate_real_roots(coeffs, domain)
  let mut total = 0
  for entry in roots {
    let ((a, b), _) = entry
    let include_lower = match inf {
      Some(v) => b.compare(v) >= 0
      None => true
    }
    let include_upper = match sup {
      Some(v) => a.compare(v) <= 0
      None => true
    }
    if include_lower && include_upper {
      total = total + 1
    }
  }
  total
}
