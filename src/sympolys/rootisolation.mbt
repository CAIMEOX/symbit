///|
/// Root isolation helpers (subset): Cauchy and Mignotte bounds.
fn abs_rational(r : @symnum.BigRational) -> @symnum.BigRational {
  if r.compare(@symnum.BigRational::zero()) < 0 {
    r.neg()
  } else {
    r
  }
}

///|
fn pow_rational(
  base : @symnum.BigRational,
  exp : Int,
) -> @symnum.BigRational {
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
fn dup_to_poly(coeffs : Array[FieldElem], domain : Domain) -> Poly raise PolyError {
  let f = dup_strip(coeffs)
  if f.is_empty() {
    raise PolyError::NotImplemented("dup_to_poly empty")
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
pub fn dup_cauchy_upper_bound(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let f = dup_strip(coeffs)
  if f.length() < 2 {
    raise PolyError::NotImplemented("cauchy-upper")
  }
  let lc = fe_expect_rational(f[0])
  if lc.is_zero() {
    raise PolyError::DivisionByZero
  }
  let mut max_ratio = @symnum.BigRational::zero()
  for i in 1..<f.length() {
    let ai = abs_rational(fe_expect_rational(f[i]))
    let ratio = try ai.div_r(abs_rational(lc)) catch {
      _ => raise PolyError::NotImplemented("cauchy-upper-div")
    }
    if ratio.compare(max_ratio) > 0 {
      max_ratio = ratio
    }
  }
  let one = @symnum.BigRational::one()
  fe_from_rational(one.add(max_ratio), Domain::QQ)
}

///|
pub fn dup_cauchy_lower_bound(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let g = dup_strip(reverse_coeffs(coeffs))
  if g.length() < 2 {
    raise PolyError::NotImplemented("cauchy-lower")
  }
  let upper = dup_cauchy_upper_bound(g, domain)
  let upper_rat = fe_expect_rational(upper)
  let inv = try upper_rat.reciprocal() catch {
    _ => raise PolyError::NotImplemented("cauchy-lower-div")
  }
  fe_from_rational(inv, Domain::QQ)
}

///|
pub fn dup_mignotte_sep_bound_squared(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let f = dup_strip(coeffs)
  let n = dup_degree(f)
  if n < 2 {
    raise PolyError::NotImplemented("mignotte-sep")
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
  let denom = pow_rational(n_rat, n + 1).mul(
    pow_rational(l2sq, n - 1),
  )
  let bound = try num.div_r(denom) catch {
    _ => raise PolyError::NotImplemented("mignotte-div")
  }
  fe_from_rational(bound, Domain::QQ)
}

///|
pub fn dup_sturm(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let f = dup_strip(coeffs)
  if f.is_empty() {
    raise PolyError::NotImplemented("dup_sturm empty")
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
  try @symnum.BigRational::new(num, den) catch {
    _ => raise PolyError::NotImplemented("mediant")
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
  let two = @symnum.BigRational::from_int(2)
  let sum = a.add_r(b)
  try sum.div_r(two) catch {
    _ => raise PolyError::NotImplemented("midpoint")
  }
}

///|
fn interval_small(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> Bool {
  if a.is_integral() && b.is_integral() {
    let ai = a.numerator().to_int()
    let bi = b.numerator().to_int()
    (bi - ai) <= 1
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
) -> Unit raise PolyError {
  let var_a = sturm_variations(seq, a)
  let var_b = sturm_variations(seq, b)
  let count = var_a - var_b
  if count <= 0 {
    return
  }
  if count == 1 {
    let fb = eval_dup_rational(f, b)
    if rat_sign(fb) == 0 {
      intervals.push((b, b))
      return
    }
    if interval_small(a, b) {
      intervals.push((a, b))
      return
    }
  }
  let mid = rat_mid(a, b)
  if mid.compare(a) == 0 || mid.compare(b) == 0 {
    intervals.push((a, b))
    return
  }
  isolate_sturm(f, seq, a, mid, intervals)
  isolate_sturm(f, seq, mid, b, intervals)
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
    raise PolyError::NotImplemented("refine empty")
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
  let sa = rat_sign(fa)
  let sb = rat_sign(fb)
  if sa == 0 {
    return (a, a)
  }
  if sb == 0 {
    return (b, b)
  }
  if sa == sb {
    raise PolyError::NotImplemented("refine interval")
  }
  match disjoint {
    Some(d) =>
      if d.compare(a) <= 0 || d.compare(b) >= 0 {
        return (a, b)
      }
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
    } else {
      a = m
      fa = fm
    }
    match disjoint {
      Some(d) =>
        if d.compare(a) <= 0 || d.compare(b) >= 0 {
          break
        }
      None => ()
    }
    iter = iter + 1
  }
  (a, b)
}

///|
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
  let fa = eval_dup_rational(f, a)
  if rat_sign(fa) == 0 {
    intervals.push((a, a))
  }
  let seq = dup_sturm(f, domain)
  isolate_sturm(f, seq, a, b, intervals)
  intervals
}
