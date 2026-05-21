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
/// Number-field compatibility front doors.
///
/// Current Limits:
/// - the public minimal-polynomial and field-isomorphism surface currently
///   targets rational constants, radicals, affine radical forms, and the
///   supported multiquadratic families implemented here.
/// - unsupported algebraic expressions still raise conservative front-door
///   errors instead of fabricating approximate answers.

///|
/// Test whether a rational value is acceptable as a rational coefficient.
///
/// - Does: Reports whether the provided exact rational is rational-valued.
/// - Input: A `BigRational`.
/// - Returns: Always `true` for this MoonBit exact-rational front door.
/// - Limits: Python object-type acceptance is not modeled.
pub fn is_rat(_c : @symnum.BigRational) -> Bool {
  true
}

///|
/// Test whether a rational value is integral.
///
/// - Does: Checks whether the denominator is one.
/// - Input: A `BigRational`.
/// - Returns: `true` for integral rationals.
/// - Limits: Python object-type acceptance is not modeled.
pub fn is_int(c : @symnum.BigRational) -> Bool {
  c.is_integral()
}

///|
/// Return numerator and denominator of an exact rational.
///
/// - Does: Extracts the normalized numerator and denominator.
/// - Input: A `BigRational`.
/// - Returns: `(numerator, denominator)` as `BigInt` values.
/// - Limits: The input must already be an exact rational.
pub fn get_num_denom(c : @symnum.BigRational) -> (BigInt, BigInt) {
  (c.numerator(), c.denominator())
}

///|
/// Transform integer coefficients into a column domain matrix.
///
/// - Does: Mirrors SymPy `numberfields.modules.to_col` by treating a flat
///   coefficient list as a `ZZ` column vector.
/// - Input: `Array[Int]` coefficients.
/// - Returns: A `DomainMatrix` with shape `(len(coeffs), 1)` over `Domain::ZZ`.
/// - Limits: The MoonBit front door accepts integer literals only; callers that
///   already have `FieldElem` rows should use `domain_matrix_from_dense`.
pub fn to_col(coeffs : Array[Int]) -> DomainMatrix raise PolyError {
  let rows : Array[Array[Int]] = []
  for coeff in coeffs {
    rows.push([coeff])
  }
  domain_matrix_from_ints(rows, Domain::ZZ)
}

///|
/// Test whether a domain matrix is square maximal-rank Hermite normal form.
///
/// - Does: Mirrors SymPy `numberfields.modules.is_sq_maxrank_HNF`.
/// - Input: A `DomainMatrix`.
/// - Returns: `true` when the matrix is over `ZZ`, square, upper triangular,
///   has positive diagonal entries, and each strict upper entry in column `j`
///   satisfies `0 <= a_ij < a_ii`.
/// - Limits: This only checks the special square maximal-rank HNF predicate;
///   it does not compute a Hermite normal form.
pub fn is_sq_maxrank_HNF(dm : DomainMatrix) -> Bool raise PolyError {
  if dm.domain != Domain::ZZ || !dm.is_square() || !dm.is_upper() {
    return false
  }
  let n = dm.rows
  let zero = @symnum.BigRational::zero()
  for i in 0..<n {
    let d = fe_expect_rational(dm.getitem(i, i).element)
    if d.compare(zero) <= 0 {
      return false
    }
    for j in (i + 1)..<n {
      let value = fe_expect_rational(dm.getitem(i, j).element)
      if value.compare(zero) < 0 || value.compare(d) >= 0 {
        return false
      }
    }
  }
  true
}

///|
/// Extend a subspace basis to a full-space basis.
///
/// - Does: Mirrors SymPy `numberfields.utilities.supplement_a_subspace` by
///   computing an invertible matrix whose first columns equal the input basis.
/// - Input: An `n x r` `DomainMatrix` over a field, with rank `r`.
/// - Returns: An invertible `n x n` `DomainMatrix`.
/// - Limits: Raises when the domain is not a field, when the input columns are
///   not independent, or when exact inversion is unsupported by the matrix
///   layer.
pub fn supplement_a_subspace(m : DomainMatrix) -> DomainMatrix raise PolyError {
  let n = m.rows
  let r = m.cols
  let augmented = m.hstack(DomainMatrix::eye(n, m.domain))
  let (reduced, pivots) = augmented.rref()
  if pivots.length() < r {
    raise PolyError::DomainMismatch
  }
  for i in 0..<r {
    if pivots[i] != i {
      raise PolyError::DomainMismatch
    }
  }
  let row_indices : Array[Int] = []
  for i in 0..<n {
    row_indices.push(i)
  }
  let col_indices : Array[Int] = []
  for j in r..<(r + n) {
    col_indices.push(j)
  }
  reduced.extract(row_indices, col_indices).inv()
}

///|
/// Build elementary-symmetric placeholder symbols.
///
/// - Does: Mirrors SymPy `galois_resolvents.s_vars`, producing `s1, s2, ...`.
/// - Input: A non-negative count `n`.
/// - Returns: `Array[Expr]` of symbols named `s1` through `sn`.
/// - Limits: Non-positive `n` returns an empty array; this does not attach
///   polynomial-ring metadata to the symbols.
pub fn s_vars(n : Int) -> Array[Expr] {
  let out : Array[Expr] = []
  for i in 0..<n {
    out.push(Expr::Symbol("s\{i + 1}"))
  }
  out
}

///|
/// Extract fundamental discriminant factors.
///
/// - Does: Writes `a = d*f^2` and returns prime-factor lists for `d` and `f`.
/// - Input: An integer congruent to `0` or `1` modulo `4`.
/// - Returns: `(D, F)` as sorted `(prime, exponent)` arrays.
/// - Limits: Raises `PolyError::DomainMismatch` when `a` is not `0` or `1`
///   modulo `4`.
pub fn extract_fundamental_discriminant(
  a : Int,
) -> (Array[(Int, Int)], Array[(Int, Int)]) raise PolyError {
  let residue = nf_pos_mod(a, 4)
  if residue != 0 && residue != 1 {
    raise PolyError::DomainMismatch
  }
  if a == 0 {
    return ([], [(0, 1)])
  }
  if a == 1 {
    return ([], [])
  }
  let factors = nf_factorint(a)
  let d : Array[(Int, Int)] = []
  let f : Array[(Int, Int)] = []
  let mut num_3_mod_4 = 0
  for item in factors {
    let p = item.0
    let e = item.1
    if e % 2 == 1 {
      nf_set_factor(d, p, 1)
      if nf_pos_mod(p, 4) == 3 {
        num_3_mod_4 += 1
      }
      if e >= 3 {
        nf_set_factor(f, p, (e - 1) / 2)
      }
    } else {
      nf_set_factor(f, p, e / 2)
    }
  }
  let even = nf_factor_get(d, 2) is Some(_)
  if even || num_3_mod_4 % 2 == 1 {
    let e2 = match nf_factor_get(f, 2) {
      Some(v) => v
      None => raise PolyError::DomainMismatch
    }
    if e2 == 1 {
      nf_delete_factor(f, 2)
    } else {
      nf_set_factor(f, 2, e2 - 1)
    }
    nf_set_factor(d, 2, if even { 3 } else { 2 })
  }
  nf_sort_factors(d)
  nf_sort_factors(f)
  (d, f)
}

///|
/// Generate a finite prefix of coefficient-search candidates.
///
/// - Does: Follows SymPy's bounded-coefficient search order.
/// - Input: List length `m`, positive initial absolute bound `r`, and prefix `count`.
/// - Returns: `count` coefficient vectors.
/// - Limits: SymPy returns an infinite generator; MoonBit exposes a finite
///   prefix front door. Non-positive bounds return an empty prefix.
pub fn coeff_search(m : Int, r : Int, count? : Int = 16) -> Array[Array[Int]] {
  if m <= 0 || r <= 0 || count <= 0 {
    return []
  }
  let r0 = r
  let mut radius = r
  let c = Array::make(m, radius)
  let out : Array[Array[Int]] = []
  while out.length() < count {
    if radius == r0 || c.contains(radius) || c.contains(-radius) {
      out.push(c.copy())
    }
    let mut j = m - 1
    while j >= 0 && c[j] == -radius {
      j -= 1
    }
    if j < 0 {
      radius += 1
      for i in 0..<m {
        c[i] = radius
      }
      continue
    }
    c[j] -= 1
    for i in (j + 1)..<m {
      c[i] = radius
    }
    let mut all_zero = true
    for value in c {
      if value != 0 {
        all_zero = false
        break
      }
    }
    if all_zero {
      radius += 1
      for i in 0..<m {
        c[i] = radius
      }
    }
  }
  out
}

///|
fn nf_factorint(a : Int) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let mut n = a
  if n < 0 {
    out.push((-1, 1))
    n = -n
  }
  let mut p = 2
  while p * p <= n {
    if n % p == 0 {
      let mut e = 0
      while n % p == 0 {
        n = n / p
        e += 1
      }
      out.push((p, e))
    }
    p = if p == 2 { 3 } else { p + 2 }
  }
  if n > 1 {
    out.push((n, 1))
  }
  out
}

///|
fn nf_factor_get(items : Array[(Int, Int)], p : Int) -> Int? {
  for item in items {
    let key = item.0
    let exp = item.1
    if key == p {
      return Some(exp)
    }
  }
  None
}

///|
fn nf_set_factor(items : Array[(Int, Int)], p : Int, e : Int) -> Unit {
  for i in 0..<items.length() {
    if items[i].0 == p {
      items[i] = (p, e)
      return
    }
  }
  items.push((p, e))
}

///|
fn nf_delete_factor(items : Array[(Int, Int)], p : Int) -> Unit {
  let out : Array[(Int, Int)] = []
  for item in items {
    if item.0 != p {
      out.push(item)
    }
  }
  items.clear()
  for item in out {
    items.push(item)
  }
}

///|
fn nf_sort_factors(items : Array[(Int, Int)]) -> Unit {
  items.sort_by((a, b) => a.0.compare(b.0))
}

///|
/// Compute a minimal polynomial over `QQ`.
///
/// - Does: Returns the minimal polynomial for one supported algebraic
///   expression.
/// - Input: An `Expr` and optional generator name.
/// - Returns: A univariate `Poly` over `QQ`.
/// - Limits: Raises `PolyError::NonPolynomial` when the expression is outside
///   the currently supported algebraic families.
pub fn minimal_polynomial(
  expr : Expr,
  gen? : String = "x",
) -> Poly raise PolyError {
  match expr_rational_constant(expr) {
    Some(q) => {
      // Match SymPy's primitive-content convention for rationals:
      // minpoly(a/b) = b*x - a.
      let x = Expr::Symbol(gen)
      let a = q.numerator()
      let b = q.denominator()
      let bx = @symcore.Expr::Number(@symnum.BigRational::from_bigint(b)) * x
      let a_expr = @symcore.Expr::Number(@symnum.BigRational::from_bigint(a))
      PolyBuilder::new([gen], Domain::QQ).from_expr(bx - a_expr)
    }
    None =>
      match parse_affine_radical(expr) {
        Some(aff) => {
          let x = Expr::Symbol(gen)
          let shift_expr = if aff.shift.is_zero() {
            x
          } else {
            x - @symcore.Expr::Number(aff.shift)
          }
          let lhs = shift_expr ^ int(aff.atom.n)
          let scale_pow = rat_pow_nonnegative(aff.scale, aff.atom.n)
          let rhs = @symcore.Expr::Number(scale_pow.mul_r(aff.atom.rad))
          let raw = PolyBuilder::new([gen], Domain::QQ).from_expr(lhs - rhs)
          normalize_minpoly_qq(raw)
        }
        None =>
          match mq_minpoly(expr, gen) {
            Some(poly) => poly
            None => raise PolyError::NonPolynomial
          }
      }
  }
}

///|
/// Minimal polynomial for multiquadratic expressions built from rational
/// combinations of square roots.
fn mq_minpoly(expr : Expr, gen : String) -> Poly? raise PolyError {
  let atoms : Array[@symnum.BigRational] = Array::new()
  if !mq_collect_atoms(expr, atoms) || atoms.is_empty() {
    return None
  }
  match mq_parse_expr(expr, atoms) {
    Some(alpha) => mq_minpoly_from_vector(alpha, atoms, gen)
    None => None
  }
}

///|
fn mq_minpoly_from_vector(
  alpha : Array[@symnum.BigRational],
  atoms : Array[@symnum.BigRational],
  gen : String,
) -> Poly? raise PolyError {
  let dim = mq_dimension(atoms.length())
  if alpha.length() != dim {
    return None
  }
  let powers : Array[Array[@symnum.BigRational]] = [
    mq_const(dim, @symnum.BigRational::one()),
  ]
  let mut current = mq_const(dim, @symnum.BigRational::one())
  for degree in 1..<=dim {
    current = mq_mul(current, alpha, atoms)
    let cols : Array[Array[@symnum.BigRational]] = Array::new()
    for i in 0..<degree {
      cols.push(powers[i])
    }
    match mq_solver_matrix(cols, dim) {
      Some(matrix) =>
        match mq_solve_linear(matrix, current) {
          Some(coeffs) => return Some(mq_relation_to_poly(coeffs, degree, gen))
          None => powers.push(current)
        }
      None => return None
    }
  }
  None
}

///|
fn mq_relation_to_poly(
  coeffs : Array[@symnum.BigRational],
  degree : Int,
  gen : String,
) -> Poly raise PolyError {
  let x = Expr::Symbol(gen)
  let terms : Array[Expr] = [x ^ int(degree)]
  for i in 0..<coeffs.length() {
    let c = coeffs[i]
    if c.is_zero() {
      continue
    }
    let coeff_expr = @symcore.Expr::Number(c.neg_r())
    let term = if i == 0 {
      coeff_expr
    } else if i == 1 {
      coeff_expr * x
    } else {
      coeff_expr * (x ^ int(i))
    }
    terms.push(term)
  }
  let raw = PolyBuilder::new([gen], Domain::QQ).from_expr(@symcore.add(terms))
  normalize_minpoly_qq(raw)
}

///|
fn parse_affine_radical(expr : Expr) -> AffineRadical? {
  match expr {
    Expr::Add(args) => {
      let mut shift = @symnum.BigRational::zero()
      let mut term : (@symnum.BigRational, RadicalAtom)? = None
      for arg in args {
        match expr_rational_constant(arg) {
          Some(c) => shift = shift.add_r(c)
          None =>
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
        Some((scale, atom)) =>
          Some(AffineRadical::{
            shift: @symnum.BigRational::zero(),
            scale,
            atom,
          })
        None => None
      }
  }
}

///|
fn parse_linear_radical(expr : Expr) -> (@symnum.BigRational, RadicalAtom)? {
  match parse_radical_atom(expr) {
    Some(atom) => Some((@symnum.BigRational::one(), atom))
    None =>
      match expr {
        Expr::Mul(args) => {
          let mut coeff = @symnum.BigRational::one()
          let mut atom : RadicalAtom? = None
          for arg in args {
            match expr_rational_constant(arg) {
              Some(c) => coeff = coeff.mul_r(c)
              None =>
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
fn parse_radical_atom(expr : Expr) -> RadicalAtom? {
  match expr {
    Expr::Pow(base, exp) =>
      match (base, exp) {
        (Expr::Number(rad), Expr::Number(e)) => {
          let num = e.numerator()
          let den = e.denominator()
          if num.equal_int(1) && den.compare(BigInt::from_int(1)) > 0 {
            let (reduced_rad, reduced_n) = reduce_radical_power(
              rad,
              den.to_int(),
            )
            if reduced_n > 1 {
              Some(RadicalAtom::{ rad: reduced_rad, n: reduced_n })
            } else {
              None
            }
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
fn reduce_radical_power(
  rad : @symnum.BigRational,
  n : Int,
) -> (@symnum.BigRational, Int) {
  if n <= 1 {
    return (rad, 1)
  }
  let mut base = rad
  let mut degree = n
  let mut changed = true
  while changed && degree > 1 {
    changed = false
    let mut d = degree
    while d >= 2 {
      if degree % d == 0 {
        match rational_exact_nth_root(base, d) {
          Some(root) => {
            base = root
            degree = degree / d
            changed = true
            break
          }
          None => ()
        }
      }
      d = d - 1
    }
  }
  (base, degree)
}

///|
fn expr_rational_constant(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(q) => Some(q)
    Expr::Add(args) => {
      let mut sum = @symnum.BigRational::zero()
      for arg in args {
        match expr_rational_constant(arg) {
          Some(c) => sum = sum.add_r(c)
          None => return None
        }
      }
      Some(sum)
    }
    Expr::Mul(args) => {
      let mut prod = @symnum.BigRational::one()
      for arg in args {
        match expr_rational_constant(arg) {
          Some(c) => prod = prod.mul_r(c)
          None => return None
        }
      }
      Some(prod)
    }
    Expr::Pow(base, exp) =>
      match (base, exp) {
        (Expr::Number(rad), Expr::Number(e)) => {
          let num = e.numerator()
          let den = e.denominator()
          if num.equal_int(1) && den.compare(BigInt::from_int(1)) > 0 {
            let (r, n) = reduce_radical_power(rad, den.to_int())
            if n == 1 {
              Some(r)
            } else {
              None
            }
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
/// Compatibility alias for `minimal_polynomial`.
///
/// - Does: Preserves the short public spelling.
/// - Input: An `Expr` and optional generator name.
/// - Returns: A `Poly`.
/// - Limits: Shares the same supported-expression limits as
///   `minimal_polynomial`.
pub fn minpoly(expr : Expr, gen? : String = "x") -> Poly raise PolyError {
  minimal_polynomial(expr, gen~)
}

///|
fn nf_rat(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => abort("numberfields rational helper expects nonzero denominator")
  }
}

///|
fn nf_rat_div_int(
  value : @symnum.BigRational,
  den : Int,
) -> @symnum.BigRational {
  value.div_r(@symnum.BigRational::from_int(den)) catch {
    _ =>
      abort("numberfields rational division helper expects nonzero denominator")
  }
}

///|
fn nf_rat_abs(value : @symnum.BigRational) -> @symnum.BigRational {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    value.neg_r()
  } else {
    value
  }
}

///|
fn nf_rat_mid(
  lo : @symnum.BigRational,
  hi : @symnum.BigRational,
) -> @symnum.BigRational {
  nf_rat_div_int(lo.add_r(hi), 2)
}

///|
fn nf_rat_width(
  lo : @symnum.BigRational,
  hi : @symnum.BigRational,
) -> @symnum.BigRational {
  hi.sub_r(lo)
}

///|
fn nf_pos_mod(value : Int, modulus : Int) -> Int {
  let mut out = value % modulus
  if out < 0 {
    out = out + modulus
  }
  out
}

///|
fn nf_radical_integer_interval(
  rad : @symnum.BigRational,
  n : Int,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  if n <= 0 {
    raise PolyError::BadExponent
  }
  if rad.compare(@symnum.BigRational::zero()) < 0 {
    raise PolyError::DomainMismatch
  }
  if rad.is_zero() {
    return (@symnum.BigRational::zero(), @symnum.BigRational::zero())
  }
  let mut hi = 1
  while rat_pow_nonnegative(@symnum.BigRational::from_int(hi), n).compare(rad) <=
        0 {
    hi = hi * 2
  }
  let mut lo = hi / 2
  while lo + 1 < hi {
    let mid = (lo + hi) / 2
    let cmp = rat_pow_nonnegative(@symnum.BigRational::from_int(mid), n).compare(
      rad,
    )
    if cmp <= 0 {
      lo = mid
    } else {
      hi = mid
    }
  }
  let lo_rat = @symnum.BigRational::from_int(lo)
  if rat_pow_nonnegative(lo_rat, n).compare(rad) == 0 {
    (lo_rat, lo_rat)
  } else {
    (lo_rat, @symnum.BigRational::from_int(hi))
  }
}

///|
fn nf_refine_radical_interval(
  rad : @symnum.BigRational,
  n : Int,
  lo0 : @symnum.BigRational,
  hi0 : @symnum.BigRational,
  eps : @symnum.BigRational,
) -> (@symnum.BigRational, @symnum.BigRational) {
  if eps.compare(@symnum.BigRational::zero()) <= 0 {
    return (lo0, hi0)
  }
  let mut lo = lo0
  let mut hi = hi0
  while nf_rat_width(lo, hi).compare(eps) > 0 {
    let mid = nf_rat_mid(lo, hi)
    let cmp = rat_pow_nonnegative(mid, n).compare(rad)
    if cmp == 0 {
      return (mid, mid)
    } else if cmp < 0 {
      lo = mid
    } else {
      hi = mid
    }
  }
  (lo, hi)
}

///|
fn nf_affine_radical_rough_interval(
  aff : AffineRadical,
  eps? : @symnum.BigRational,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  let (base_lo0, base_hi0) = nf_radical_integer_interval(
    aff.atom.rad,
    aff.atom.n,
  )
  let (base_lo, base_hi) = match eps {
    Some(e) => {
      let abs_scale = nf_rat_abs(aff.scale)
      if abs_scale.is_zero() {
        (base_lo0, base_hi0)
      } else {
        let base_eps = e.div_r(abs_scale) catch {
          _ => abort("numberfields affine radical helper expects nonzero scale")
        }
        nf_refine_radical_interval(
          aff.atom.rad,
          aff.atom.n,
          base_lo0,
          base_hi0,
          base_eps,
        )
      }
    }
    None => (base_lo0, base_hi0)
  }
  let lo = aff.shift.add_r(aff.scale.mul_r(base_lo))
  let hi = aff.shift.add_r(aff.scale.mul_r(base_hi))
  if lo.compare(hi) <= 0 {
    (lo, hi)
  } else {
    (hi, lo)
  }
}

///|
fn nf_interval_overlaps(
  lhs : (@symnum.BigRational, @symnum.BigRational),
  rhs : (@symnum.BigRational, @symnum.BigRational),
) -> Bool {
  lhs.0.compare(rhs.1) <= 0 && rhs.0.compare(lhs.1) <= 0
}

///|
fn nf_choose_interval(
  poly : Poly,
  rough : (@symnum.BigRational, @symnum.BigRational),
  eps? : @symnum.BigRational,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  let all = match eps {
    Some(e) => intervals(poly, eps=e)
    None => intervals(poly)
  }
  let matches : Array[(@symnum.BigRational, @symnum.BigRational)] = []
  for item in all {
    let (iv, _) = item
    if nf_interval_overlaps(iv, rough) {
      matches.push(iv)
    }
  }
  if matches.length() == 1 {
    matches[0]
  } else if all.length() == 1 {
    all[0].0
  } else {
    raise PolyError::NonPolynomial
  }
}

///|
/// Find a rational isolating interval for a supported real algebraic number.
///
/// - Does: Mirrors SymPy's `isolate` front door for rational constants and
///   affine radical expressions supported by `minimal_polynomial`.
/// - Input: An `Expr`, optional rational `eps`, and ignored compatibility
///   flag `fast`.
/// - Returns: A pair of exact rational endpoints.
/// - Limits: Complex algebraic numbers and general `AlgebraicNumber` objects
///   are not modeled; unsupported expressions raise `PolyError`.
pub fn isolate(
  expr : Expr,
  eps? : @symnum.BigRational,
  fast? : Bool = false,
) -> (@symnum.BigRational, @symnum.BigRational) raise PolyError {
  ignore(fast)
  match expr_rational_constant(expr) {
    Some(q) => return (q, q)
    None => ()
  }
  let poly = minimal_polynomial(expr)
  match parse_affine_radical(expr) {
    Some(aff) => {
      let rough = match eps {
        Some(e) => nf_affine_radical_rough_interval(aff, eps=e)
        None => nf_affine_radical_rough_interval(aff)
      }
      match eps {
        Some(e) => nf_choose_interval(poly, rough, eps=e)
        None => nf_choose_interval(poly, rough)
      }
    }
    None => {
      let roots = match eps {
        Some(e) => intervals(poly, eps=e)
        None => intervals(poly)
      }
      if roots.length() == 1 {
        roots[0].0
      } else {
        raise PolyError::NonPolynomial
      }
    }
  }
}

///|
/// Construct a one-generator algebraic field extension.
///
/// - Does: Builds the algebraic field `QQ(a)` from the minimal polynomial of
///   `expr`.
/// - Input: An `Expr` and optional generator name.
/// - Returns: A `Domain::AlgExt`.
/// - Limits: Raises `PolyError` when the minimal polynomial cannot be computed
///   by the current compatibility layer.
pub fn to_number_field(
  expr : Expr,
  gen? : String = "a",
) -> Domain raise PolyError {
  let mp = minimal_polynomial(expr, gen~)
  build_alg_extension(alg_ext_spec(Domain::QQ, gen, mp))
}

///|
/// Express one algebraic element in the basis of another.
///
/// - Does: Returns coefficients in falling powers of `theta` when `expr` lies
///   in `Q(theta)`.
/// - Input: Two algebraic `Expr` values.
/// - Returns: `Array[BigRational]`.
/// - Limits: Raises `PolyError::DomainMismatch` when no embedding is found by
///   the current compatibility layer.
pub fn to_number_field_coeffs(
  expr : Expr,
  theta : Expr,
) -> Array[@symnum.BigRational] raise PolyError {
  match field_isomorphism(expr, theta) {
    Some(coeffs) => coeffs
    None => raise PolyError::DomainMismatch
  }
}

///|
/// Return a primitive-element candidate.
///
/// - Does: Chooses one primitive-element candidate together with the integer
///   coefficients used to build it.
/// - Input: `Array[Expr]`.
/// - Returns: `(Expr, Array[Int])`.
/// - Limits: Raises `PolyError::NonPolynomial` for empty input and currently
///   uses the package's simple linear-combination strategy.
pub fn primitive_element(
  generators : Array[Expr],
) -> (Expr, Array[Int]) raise PolyError {
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
/// Return a primitive-element candidate together with representations.
///
/// - Does: Extends `primitive_element` by also returning each generator written
///   in the primitive-element basis.
/// - Input: `Array[Expr]`.
/// - Returns: `(Expr, Array[Int], Array[Array[BigRational]])`.
/// - Limits: Raises `PolyError` when one generator cannot be represented in the
///   chosen primitive-element basis.
pub fn primitive_element_ex(
  generators : Array[Expr],
) -> (Expr, Array[Int], Array[Array[@symnum.BigRational]]) raise PolyError {
  let (prim, coeffs) = primitive_element(generators)
  let reps : Array[Array[@symnum.BigRational]] = Array::new()
  for g in generators {
    match field_isomorphism(g, prim) {
      Some(rep) => reps.push(rep)
      None => raise PolyError::DomainMismatch
    }
  }
  (prim, coeffs, reps)
}

///|
/// Integral-basis descriptor returned by `round_two`.
///
/// - Does: Stores a rational basis matrix and the resulting field
///   discriminant.
/// - Input: Produced from a univariate defining polynomial.
/// - Returns: A `RoundTwoResult`.
/// - Limits: This is a typed MoonBit descriptor, not SymPy's module object.
pub struct RoundTwoResult {
  basis : Array[Array[@symnum.BigRational]]
  denom : @symnum.BigRational
  discriminant : FieldElem
}

///|
fn nf_basis_row_string(row : Array[@symnum.BigRational]) -> String {
  "[" + row.map(item => item.to_string()).join(", ") + "]"
}

///|
fn nf_basis_string(rows : Array[Array[@symnum.BigRational]]) -> String {
  "Submodule[" + rows.map(nf_basis_row_string).join(", ") + "]"
}

///|
pub impl Show for RoundTwoResult with output(
  self : RoundTwoResult,
  logger : &Logger,
) -> Unit {
  let basis_text = nf_basis_string(self.basis)
  let full_basis = if self.denom.is_one() {
    basis_text
  } else {
    "\{basis_text}/\{self.denom}"
  }
  logger.write_string("(\{full_basis}, \{self.discriminant})")
}

///|
fn nf_identity_basis(degree : Int) -> Array[Array[@symnum.BigRational]] {
  let rows : Array[Array[@symnum.BigRational]] = []
  for i in 0..<degree {
    let row : Array[@symnum.BigRational] = []
    for j in 0..<degree {
      row.push(@symnum.BigRational::from_int(if i == j { 1 } else { 0 }))
    }
    rows.push(row)
  }
  rows
}

///|
fn nf_fe_int(elem : FieldElem) -> Int raise PolyError {
  let q = fe_expect_rational(elem)
  if !q.denominator().equal_int(1) {
    raise PolyError::DomainMismatch
  }
  q.numerator().to_int()
}

///|
/// Compute a Round 2 integral-basis descriptor for a defining polynomial.
///
/// - Does: Follows SymPy's public `round_two` front door for monic univariate
///   integer polynomials, including the quadratic half-integral basis case.
/// - Input: One univariate `Poly` over `ZZ` or `QQ`.
/// - Returns: `RoundTwoResult`.
/// - Limits: Higher-degree output currently uses the power basis with the
///   polynomial discriminant; full maximal-order refinement is not implemented.
pub fn round_two(poly : Poly) -> RoundTwoResult raise PolyError {
  ensure_univar(poly)
  let degree = poly.degree(0)
  if degree <= 0 {
    raise PolyError::NonPolynomial
  }
  let disc0 = discriminant(poly)
  let mut basis = nf_identity_basis(degree)
  let mut denom = @symnum.BigRational::one()
  let mut disc = disc0
  if degree == 2 {
    let dense = to_dense(poly)
    let lead = nf_fe_int(dense[2])
    if lead != 1 {
      raise PolyError::DomainMismatch
    }
    let b = nf_fe_int(dense[1])
    let c = nf_fe_int(dense[0])
    if b == 0 {
      let radicand = -c
      if nf_pos_mod(radicand, 4) == 1 {
        basis = [
          [@symnum.BigRational::from_int(2), @symnum.BigRational::zero()],
          [@symnum.BigRational::one(), @symnum.BigRational::one()],
        ]
        denom = nf_rat(2, 1)
        disc = fe_from_int(radicand, poly.domain)
      }
    }
  }
  RoundTwoResult::{ basis, denom, discriminant: disc }
}

///|
/// Prime ideal descriptor for the `prime_decomp` front door.
///
/// - Does: Stores the rational prime, residue factor, ramification index, and
///   residue degree.
/// - Input: Produced by factoring the defining polynomial modulo `p`.
/// - Returns: A `PrimeIdeal`.
/// - Limits: This covers the polynomial-factorization front door, not the full
///   ideal-arithmetic object model.
pub struct PrimeIdeal {
  p : Int
  factor : Poly
  ramification : Int
  residue_degree : Int
  has_generator : Bool
}

///|
pub impl Show for PrimeIdeal with output(self : PrimeIdeal, logger : &Logger) -> Unit {
  if self.has_generator {
    logger.write_string("(\{self.p}, \{self.factor})")
  } else {
    logger.write_string("(\{self.p})")
  }
}

///|
/// Decompose a rational prime in a simple number field.
///
/// - Does: Factors the defining polynomial modulo `p`, matching SymPy's
///   factor-driven prime-decomposition front door for common inputs.
/// - Input: A rational prime `p` and a univariate defining polynomial `T`.
/// - Returns: `Array[PrimeIdeal]`.
/// - Limits: Does not construct full ideal modules or radical-splitting data.
pub fn prime_decomp(p : Int, poly : Poly) -> Array[PrimeIdeal] raise PolyError {
  if p <= 1 {
    raise PolyError::BadModulus
  }
  ensure_univar(poly)
  let defining_degree = poly.degree(0)
  if defining_degree <= 0 {
    raise PolyError::NonPolynomial
  }
  let gf_poly = map_to_gf(poly, p)
  let (_, factors) = gf_poly.factor_list()
  let ideals : Array[PrimeIdeal] = []
  for item in factors {
    let factor = item.0
    let ramification = item.1
    let factor_degree = factor.degree(0)
    if factor_degree <= 0 {
      continue
    }
    ideals.push(PrimeIdeal::{
      p,
      factor,
      ramification,
      residue_degree: factor_degree,
      has_generator: factor_degree < defining_degree || ramification > 1,
    })
  }
  if ideals.is_empty() {
    ideals.push(PrimeIdeal::{
      p,
      factor: gf_poly,
      ramification: 1,
      residue_degree: defining_degree,
      has_generator: false,
    })
  }
  ideals
}

///|
/// Compute the valuation of an integer at a prime ideal.
///
/// - Does: Counts the exponent of `prime.p` in an integer principal ideal.
/// - Input: An integer and one `PrimeIdeal` from `prime_decomp`.
/// - Returns: A nonnegative exponent.
/// - Limits: General ideal/module valuations are not modeled.
pub fn prime_valuation(n : Int, prime : PrimeIdeal) -> Int raise PolyError {
  if n == 0 {
    raise PolyError::DivisionByZero
  }
  let mut value = if n < 0 { -n } else { n }
  let mut count = 0
  while value % prime.p == 0 {
    count = count + prime.ramification
    value = value / prime.p
  }
  count
}

///|
fn as_rational_constant(expr : Expr) -> @symnum.BigRational? {
  expr_rational_constant(expr)
}

///|
fn nonconstant_affine(expr : Expr) -> AffineRadical? {
  match parse_affine_radical(expr) {
    Some(aff) =>
      if aff.scale.is_zero() || aff.atom.rad.is_zero() {
        None
      } else {
        Some(aff)
      }
    None => None
  }
}

///|
fn bigint_pow_nonnegative(base : BigInt, exp : Int) -> BigInt {
  let mut result = BigInt::from_int(1)
  let mut cur = base
  let mut k = exp
  while k > 0 {
    if k % 2 == 1 {
      result = result.mul(cur)
    }
    k = k / 2
    if k > 0 {
      cur = cur.mul(cur)
    }
  }
  result
}

///|
fn bigint_exact_nth_root_nonnegative(value : BigInt, n : Int) -> BigInt? {
  if n <= 0 {
    return None
  }
  let zero = BigInt::from_int(0)
  let one = BigInt::from_int(1)
  if value.op_lt(zero) {
    return None
  }
  if value.is_zero() {
    return Some(zero)
  }
  let mut lo = zero
  let mut hi = value.add(one)
  let two = BigInt::from_int(2)
  while lo.add(one).op_lt(hi) {
    let mid = lo.add(hi).div(two)
    let p = bigint_pow_nonnegative(mid, n)
    if p.equal(value) {
      return Some(mid)
    }
    if p.op_lt(value) {
      lo = mid
    } else {
      hi = mid
    }
  }
  None
}

///|
fn bigint_exact_nth_root_signed(value : BigInt, n : Int) -> BigInt? {
  let zero = BigInt::from_int(0)
  if value.op_lt(zero) {
    if n <= 0 || n % 2 == 0 {
      return None
    }
    match bigint_exact_nth_root_nonnegative(value.neg(), n) {
      Some(root) => Some(root.neg())
      None => None
    }
  } else {
    bigint_exact_nth_root_nonnegative(value, n)
  }
}

///|
fn rational_exact_nth_root(
  value : @symnum.BigRational,
  n : Int,
) -> @symnum.BigRational? {
  if n <= 0 {
    return None
  }
  match
    (
      bigint_exact_nth_root_signed(value.numerator(), n),
      bigint_exact_nth_root_nonnegative(value.denominator(), n),
    ) {
    (Some(num), Some(den)) => {
      let q_res : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
        num, den,
      )
      match q_res {
        Ok(q) => Some(q)
        Err(_) => None
      }
    }
    _ => None
  }
}

///|
fn rational_to_int_if_integer(value : @symnum.BigRational) -> Int? {
  if value.denominator().equal_int(1) {
    Some(value.numerator().to_int())
  } else {
    None
  }
}

///|
fn mq_dimension(atom_count : Int) -> Int {
  if atom_count <= 0 {
    1
  } else {
    1 << atom_count
  }
}

///|
fn mq_zero(dim : Int) -> Array[@symnum.BigRational] {
  Array::make(dim, @symnum.BigRational::zero())
}

///|
fn mq_const(dim : Int, c : @symnum.BigRational) -> Array[@symnum.BigRational] {
  let out = mq_zero(dim)
  out.set(0, c)
  out
}

///|
fn mq_add(
  lhs : Array[@symnum.BigRational],
  rhs : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational] {
  if lhs.length() != rhs.length() {
    return Array::new()
  }
  let out = mq_zero(lhs.length())
  for i in 0..<lhs.length() {
    out.set(i, lhs[i].add_r(rhs[i]))
  }
  out
}

///|
fn mq_mul(
  lhs : Array[@symnum.BigRational],
  rhs : Array[@symnum.BigRational],
  atoms : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational] {
  if lhs.length() != rhs.length() {
    return Array::new()
  }
  let dim = lhs.length()
  let out = mq_zero(dim)
  for i in 0..<dim {
    let li = lhs[i]
    if li.is_zero() {
      continue
    }
    for j in 0..<dim {
      let rj = rhs[j]
      if rj.is_zero() {
        continue
      }
      let mut factor = li.mul_r(rj)
      let mut shared = i & j
      let mut bit = 0
      while shared > 0 {
        if (shared & 1) == 1 {
          factor = factor.mul_r(atoms[bit])
        }
        shared = shared >> 1
        bit = bit + 1
      }
      let idx = i ^ j
      out.set(idx, out[idx].add_r(factor))
    }
  }
  out
}

///|
fn mq_pow_nonnegative(
  base : Array[@symnum.BigRational],
  exp : Int,
  atoms : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  if exp < 0 {
    return None
  }
  let dim = base.length()
  let mut result = mq_const(dim, @symnum.BigRational::one())
  let mut cur = base
  let mut k = exp
  while k > 0 {
    if k % 2 == 1 {
      result = mq_mul(result, cur, atoms)
    }
    k = k / 2
    if k > 0 {
      cur = mq_mul(cur, cur, atoms)
    }
  }
  Some(result)
}

///|
fn mq_find_equivalent_atom(
  atoms : Array[@symnum.BigRational],
  rad : @symnum.BigRational,
) -> (Int, @symnum.BigRational)? {
  for i in 0..<atoms.length() {
    let ratio = match
      (
        try? rad.div_r(atoms[i]) :
        Result[@symnum.BigRational, @symnum.RationalError]) {
      Ok(value) => value
      Err(_) => continue
    }
    match rational_exact_nth_root(ratio, 2) {
      Some(scale) => return Some((i, scale))
      None => ()
    }
  }
  None
}

///|
fn mq_find_atom_mask(
  atoms : Array[@symnum.BigRational],
  rad : @symnum.BigRational,
) -> (Int, @symnum.BigRational)? {
  match mq_find_equivalent_atom(atoms, rad) {
    Some((idx, scale)) => Some((1 << idx, scale))
    None => {
      if atoms.is_empty() {
        return None
      }
      let mut mask = 1
      let limit = 1 << atoms.length()
      while mask < limit {
        let mut prod = @symnum.BigRational::one()
        for i in 0..<atoms.length() {
          if ((mask >> i) & 1) == 1 {
            prod = prod.mul_r(atoms[i])
          }
        }
        let ratio = match
          (
            try? rad.div_r(prod) :
            Result[@symnum.BigRational, @symnum.RationalError]) {
          Ok(value) => value
          Err(_) => {
            mask = mask + 1
            continue
          }
        }
        match rational_exact_nth_root(ratio, 2) {
          Some(scale) => return Some((mask, scale))
          None => ()
        }
        mask = mask + 1
      }
      None
    }
  }
}

///|
fn mq_collect_atoms(expr : Expr, atoms : Array[@symnum.BigRational]) -> Bool {
  match expr {
    Expr::Number(_) => true
    Expr::Add(args) => {
      for arg in args {
        if !mq_collect_atoms(arg, atoms) {
          return false
        }
      }
      true
    }
    Expr::Mul(args) => {
      for arg in args {
        if !mq_collect_atoms(arg, atoms) {
          return false
        }
      }
      true
    }
    Expr::Pow(base, exp) =>
      match exp {
        Expr::Number(e) =>
          match rational_to_int_if_integer(e) {
            Some(k) =>
              if k >= 0 {
                mq_collect_atoms(base, atoms)
              } else {
                false
              }
            None =>
              if e.numerator().equal_int(1) && e.denominator().equal_int(2) {
                match base {
                  Expr::Number(rad) => {
                    if rad.compare(@symnum.BigRational::zero()) < 0 {
                      return false
                    }
                    let (reduced, n) = reduce_radical_power(rad, 2)
                    if n == 1 {
                      true
                    } else if n == 2 {
                      match mq_find_atom_mask(atoms, reduced) {
                        Some(_) => true
                        None => {
                          atoms.push(reduced)
                          true
                        }
                      }
                    } else {
                      false
                    }
                  }
                  _ => false
                }
              } else {
                false
              }
          }
        _ => false
      }
    _ => false
  }
}

///|
fn mq_parse_expr(
  expr : Expr,
  atoms : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  let dim = mq_dimension(atoms.length())
  match expr {
    Expr::Number(q) => Some(mq_const(dim, q))
    Expr::Add(args) => {
      let mut acc = mq_const(dim, @symnum.BigRational::zero())
      for arg in args {
        match mq_parse_expr(arg, atoms) {
          Some(v) => acc = mq_add(acc, v)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = mq_const(dim, @symnum.BigRational::one())
      for arg in args {
        match mq_parse_expr(arg, atoms) {
          Some(v) => acc = mq_mul(acc, v, atoms)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match exp {
        Expr::Number(e) =>
          match rational_to_int_if_integer(e) {
            Some(k) =>
              match mq_parse_expr(base, atoms) {
                Some(v) => mq_pow_nonnegative(v, k, atoms)
                None => None
              }
            None =>
              if e.numerator().equal_int(1) && e.denominator().equal_int(2) {
                match base {
                  Expr::Number(rad) => {
                    if rad.compare(@symnum.BigRational::zero()) < 0 {
                      return None
                    }
                    let (reduced, n) = reduce_radical_power(rad, 2)
                    if n == 1 {
                      Some(mq_const(dim, reduced))
                    } else if n == 2 {
                      match mq_find_atom_mask(atoms, reduced) {
                        Some((mask, scale)) => {
                          let out = mq_const(dim, @symnum.BigRational::zero())
                          out.set(mask, scale)
                          Some(out)
                        }
                        None => None
                      }
                    } else {
                      None
                    }
                  }
                  _ => None
                }
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
fn mq_solver_matrix(
  cols : Array[Array[@symnum.BigRational]],
  rows : Int,
) -> Array[Array[@symnum.BigRational]]? {
  for col in cols {
    if col.length() != rows {
      return None
    }
  }
  let matrix = Array::makei(rows, _ => {
    Array::make(cols.length(), @symnum.BigRational::zero())
  })
  for i in 0..<rows {
    for j in 0..<cols.length() {
      matrix[i].set(j, cols[j][i])
    }
  }
  Some(matrix)
}

///|
fn mq_solve_linear(
  matrix : Array[Array[@symnum.BigRational]],
  rhs : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  let rows = matrix.length()
  if rows != rhs.length() {
    return None
  }
  let cols = if rows == 0 { 0 } else { matrix[0].length() }
  for row in matrix {
    if row.length() != cols {
      return None
    }
  }
  let aug = Array::makei(rows, i => {
    let row = Array::make(cols + 1, @symnum.BigRational::zero())
    for j in 0..<cols {
      row.set(j, matrix[i][j])
    }
    row.set(cols, rhs[i])
    row
  })

  let pivot_cols : Array[Int] = Array::new()
  let mut row = 0
  let mut col = 0
  while row < rows && col < cols {
    let mut pivot = row
    while pivot < rows && aug[pivot][col].is_zero() {
      pivot = pivot + 1
    }
    if pivot == rows {
      col = col + 1
      continue
    }
    if pivot != row {
      let tmp = aug[row]
      aug.set(row, aug[pivot])
      aug.set(pivot, tmp)
    }
    let pv = aug[row][col]
    let mut j = col
    while j <= cols {
      aug[row].set(
        j,
        match
          (
            try? aug[row][j].div_r(pv) :
            Result[@symnum.BigRational, @symnum.RationalError]) {
          Ok(value) => value
          Err(_) => return None
        },
      )
      j = j + 1
    }
    let mut r = 0
    while r < rows {
      if r != row {
        let factor = aug[r][col]
        if !factor.is_zero() {
          let mut k = col
          while k <= cols {
            let sub = factor.mul_r(aug[row][k])
            aug[r].set(k, aug[r][k].add_r(sub.neg_r()))
            k = k + 1
          }
        }
      }
      r = r + 1
    }
    pivot_cols.push(col)
    row = row + 1
    col = col + 1
  }

  for i in 0..<rows {
    let mut all_zero = true
    for j in 0..<cols {
      if !aug[i][j].is_zero() {
        all_zero = false
        break
      }
    }
    if all_zero && !aug[i][cols].is_zero() {
      return None
    }
  }

  let sol = Array::make(cols, @symnum.BigRational::zero())
  for i in 0..<pivot_cols.length() {
    sol.set(pivot_cols[i], aug[i][cols])
  }
  Some(sol)
}

///|
fn mq_solve_with_columns(
  cols : Array[Array[@symnum.BigRational]],
  target : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  match mq_solver_matrix(cols, target.length()) {
    Some(matrix) => mq_solve_linear(matrix, target)
    None => None
  }
}

///|
fn mq_linear_combination(
  cols : Array[Array[@symnum.BigRational]],
  coeffs : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  if cols.length() != coeffs.length() {
    return None
  }
  if cols.is_empty() {
    return Some([])
  }
  let rows = cols[0].length()
  for col in cols {
    if col.length() != rows {
      return None
    }
  }
  let out = mq_const(rows, @symnum.BigRational::zero())
  for j in 0..<cols.length() {
    let cj = coeffs[j]
    if cj.is_zero() {
      continue
    }
    for i in 0..<rows {
      out.set(i, out[i].add_r(cols[j][i].mul_r(cj)))
    }
  }
  Some(out)
}

///|
fn mq_power_basis(
  value : Array[@symnum.BigRational],
  atoms : Array[@symnum.BigRational],
) -> Array[Array[@symnum.BigRational]] {
  let dim = value.length()
  let one = mq_const(dim, @symnum.BigRational::one())
  let powers : Array[Array[@symnum.BigRational]] = [one]
  let mut current = one
  let mut k = 1
  while k <= dim {
    current = mq_mul(current, value, atoms)
    match mq_solve_with_columns(powers, current) {
      Some(_) => break
      None => powers.push(current)
    }
    k = k + 1
  }
  powers
}

///|
fn mq_trim_to_falling(
  ascending : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational] {
  let trimmed = ascending.copy()
  while trimmed.length() > 1 {
    match trimmed.last() {
      Some(v) => if v.is_zero() { let _ = trimmed.pop() } else { break }
      None => break
    }
  }
  let n = trimmed.length()
  Array::makei(n, i => trimmed[n - 1 - i])
}

///|
fn field_isomorphism_multiquadratic(
  a : Expr,
  b : Expr,
) -> Array[@symnum.BigRational]? {
  let atoms : Array[@symnum.BigRational] = Array::new()
  if !mq_collect_atoms(a, atoms) || !mq_collect_atoms(b, atoms) {
    return None
  }
  if atoms.is_empty() || atoms.length() > 3 {
    // Keep the solver intentionally low-degree.
    return None
  }
  let av = match mq_parse_expr(a, atoms) {
    Some(v) => v
    None => return None
  }
  let bv = match mq_parse_expr(b, atoms) {
    Some(v) => v
    None => return None
  }
  let basis = mq_power_basis(bv, atoms)
  let ascending = match mq_solve_with_columns(basis, av) {
    Some(v) => v
    None => return None
  }
  match mq_linear_combination(basis, ascending) {
    Some(reconstructed) =>
      if reconstructed.equal(av) {
        Some(mq_trim_to_falling(ascending))
      } else {
        None
      }
    None => None
  }
}

///|
fn mq_degree(expr : Expr) -> Int? {
  let atoms : Array[@symnum.BigRational] = Array::new()
  if !mq_collect_atoms(expr, atoms) {
    return None
  }
  if atoms.is_empty() {
    return Some(1)
  }
  if atoms.length() > 3 {
    return None
  }
  match mq_parse_expr(expr, atoms) {
    Some(v) => Some(mq_power_basis(v, atoms).length())
    None => None
  }
}

///|
/// Conservative degree-based isomorphism pre-check.
///
/// - Does: Rejects field embeddings that are impossible by degree alone.
/// - Input: Two algebraic `Expr` values.
/// - Returns: A `Bool`.
/// - Limits: This is only a necessary filter; `true` does not prove an
///   embedding exists.
pub fn is_isomorphism_possible(a : Expr, b : Expr) -> Bool {
  let ma_res : Result[Poly, PolyError] = try? minimal_polynomial(a)
  let mb_res : Result[Poly, PolyError] = try? minimal_polynomial(b)
  match (ma_res, mb_res) {
    (Ok(ma), Ok(mb)) => {
      let n = ma.degree(0)
      let m = mb.degree(0)
      if n <= 0 || m <= 0 {
        false
      } else if n == 1 {
        // Q(a) = Q for rational constants, always embeddable into Q(b).
        true
      } else {
        m % n == 0
      }
    }
    _ =>
      match (mq_degree(a), mq_degree(b)) {
        (Some(n), Some(m)) =>
          if n <= 0 || m <= 0 {
            false
          } else if n == 1 {
            true
          } else {
            m % n == 0
          }
        _ => false
      }
  }
}

///|
/// Express one algebraic element inside another number field.
///
/// - Does: Returns coefficients of a polynomial in `b` representing `a` in
///   `Q(b)` when the embedding is found.
/// - Input: Two algebraic `Expr` values.
/// - Returns: `Array[BigRational]?`.
/// - Limits: Returns `None` when the current compatibility layer cannot prove
///   the embedding.
pub fn field_isomorphism(a : Expr, b : Expr) -> Array[@symnum.BigRational]? {
  match as_rational_constant(a) {
    Some(q) => return Some([q])
    None => ()
  }
  if a == b {
    return Some([@symnum.BigRational::one(), @symnum.BigRational::zero()])
  }
  match as_rational_constant(b) {
    Some(_) => return None
    None => ()
  }
  match (nonconstant_affine(a), nonconstant_affine(b)) {
    (Some(aff_a), Some(aff_b)) =>
      match affine_embedding_coeffs(aff_a, aff_b) {
        Some(coeffs) => return Some(coeffs)
        None => ()
      }
    _ => ()
  }
  field_isomorphism_multiquadratic(a, b)
}

///|
/// Construct a field embedding through the PSLQ-named front door.
///
/// - Does: Mirrors SymPy's `field_isomorphism_pslq` public entry point for the
///   exact radical families supported by this package.
/// - Input: Two algebraic `Expr` values.
/// - Returns: Coefficients of a polynomial in `b` representing `a`, or `None`.
/// - Limits: The current implementation reuses the exact
///   `field_isomorphism` compatibility layer; it does not run a numeric PSLQ
///   search for general algebraic numbers.
pub fn field_isomorphism_pslq(
  a : Expr,
  b : Expr,
) -> Array[@symnum.BigRational]? {
  field_isomorphism(a, b)
}

///|
/// Construct a field embedding through the factorization-named front door.
///
/// - Does: Mirrors SymPy's `field_isomorphism_factor` public entry point for
///   the exact radical families supported by this package.
/// - Input: Two algebraic `Expr` values.
/// - Returns: Coefficients of a polynomial in `b` representing `a`, or `None`.
/// - Limits: The current implementation reuses the exact
///   `field_isomorphism` compatibility layer; general linear-factor extraction
///   over algebraic extensions is not yet modeled.
pub fn field_isomorphism_factor(
  a : Expr,
  b : Expr,
) -> Array[@symnum.BigRational]? {
  field_isomorphism(a, b)
}

///|
fn affine_embedding_coeffs(
  aff_a : AffineRadical,
  aff_b : AffineRadical,
) -> Array[@symnum.BigRational]? {
  if aff_a.atom.n != aff_b.atom.n {
    return None
  }
  let ratio = match
    (
      try? aff_a.atom.rad.div_r(aff_b.atom.rad) :
      Result[@symnum.BigRational, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => return None
  }
  let t = match rational_exact_nth_root(ratio, aff_a.atom.n) {
    Some(root) => root
    None => return None
  }
  let k = match
    (
      try? aff_a.scale.mul_r(t).div_r(aff_b.scale) :
      Result[@symnum.BigRational, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => return None
  }
  let c = aff_a.shift.add_r(k.mul_r(aff_b.shift).neg_r())
  Some([k, c])
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
          let norm_res : Result[Poly, PolyError] = try? normalize_minpoly_qq(
            poly,
          )
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
/// Conservative field-isomorphism predicate for migrated algebraic domains.
///
/// - Does: Checks whether two migrated algebraic-domain descriptors should be
///   treated as the same number field.
/// - Input: Two `Domain` values.
/// - Returns: A `Bool`.
/// - Limits: This currently handles `QQ` one-generator algebraic extensions by
///   comparing normalized defining relations.
pub fn field_isomorphic(a : Domain, b : Domain) -> Bool {
  if a.equal(b) {
    return true
  }
  match (algext_relation_coeffs(a), algext_relation_coeffs(b)) {
    (Some(lhs), Some(rhs)) => lhs.equal(rhs)
    _ => false
  }
}
