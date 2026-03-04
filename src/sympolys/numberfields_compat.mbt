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
  match expr_rational_constant(expr) {
    Some(q) => {
      // Match SymPy's primitive-content convention for rationals:
      // minpoly(a/b) = b*x - a.
      let a = q.numerator()
      let b = q.denominator()
      let bx = @symcore.number(@symnum.BigRational::from_bigint(b)) * x
      let a_expr = @symcore.number(@symnum.BigRational::from_bigint(a))
      PolyBuilder::new([gen], Domain::QQ).from_expr(bx - a_expr)
    }
    None =>
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
fn parse_radical_atom(expr : @symcore.Expr) -> RadicalAtom? {
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      match (base, exp) {
        (@symcore.Expr::Number(rad), @symcore.Expr::Number(e)) => {
          let num = e.numerator()
          let den = e.denominator()
          if num.equal_int(1) && den.compare(BigInt::from_int(1)) > 0 {
            let (reduced_rad, reduced_n) = reduce_radical_power(rad, den.to_int())
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
fn expr_rational_constant(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(q) => Some(q)
    @symcore.Expr::Add(args) => {
      let mut sum = @symnum.BigRational::zero()
      for arg in args {
        match expr_rational_constant(arg) {
          Some(c) => sum = sum.add_r(c)
          None => return None
        }
      }
      Some(sum)
    }
    @symcore.Expr::Mul(args) => {
      let mut prod = @symnum.BigRational::one()
      for arg in args {
        match expr_rational_constant(arg) {
          Some(c) => prod = prod.mul_r(c)
          None => return None
        }
      }
      Some(prod)
    }
    @symcore.Expr::Pow(base, exp) =>
      match (base, exp) {
        (@symcore.Expr::Number(rad), @symcore.Expr::Number(e)) => {
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
/// SymPy-style membership helper for `to_number_field(expr, theta)`.
///
/// Returns coefficients in falling powers of `theta` when `expr` is in
/// `Q(theta)`, matching `AlgebraicNumber(...).coeffs()` ordering.
pub fn to_number_field_coeffs(
  expr : @symcore.Expr,
  theta : @symcore.Expr,
) -> Array[@symnum.BigRational] raise PolyError {
  match field_isomorphism(expr, theta) {
    Some(coeffs) => coeffs
    None => raise PolyError::DomainMismatch
  }
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
/// `primitive_element(..., ex=True)` core capability: also return reps.
///
/// Each rep is in falling powers of the returned primitive element.
pub fn primitive_element_ex(
  generators : Array[@symcore.Expr],
) -> (@symcore.Expr, Array[Int], Array[Array[@symnum.BigRational]]) raise PolyError {
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
fn as_rational_constant(expr : @symcore.Expr) -> @symnum.BigRational? {
  expr_rational_constant(expr)
}

///|
fn nonconstant_affine(expr : @symcore.Expr) -> AffineRadical? {
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
  match (
    bigint_exact_nth_root_signed(value.numerator(), n),
    bigint_exact_nth_root_nonnegative(value.denominator(), n),
  ) {
    (Some(num), Some(den)) => {
      let q_res : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
        num,
        den,
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
    let ratio = rad.div_r(atoms[i])
    match rational_exact_nth_root(ratio, 2) {
      Some(scale) => return Some((i, scale))
      None => ()
    }
  }
  None
}

///|
fn mq_collect_atoms(
  expr : @symcore.Expr,
  atoms : Array[@symnum.BigRational],
) -> Bool {
  match expr {
    @symcore.Expr::Number(_) => true
    @symcore.Expr::Add(args) => {
      for arg in args {
        if !mq_collect_atoms(arg, atoms) {
          return false
        }
      }
      true
    }
    @symcore.Expr::Mul(args) => {
      for arg in args {
        if !mq_collect_atoms(arg, atoms) {
          return false
        }
      }
      true
    }
    @symcore.Expr::Pow(base, exp) =>
      match exp {
        @symcore.Expr::Number(e) =>
          match rational_to_int_if_integer(e) {
            Some(k) => if k >= 0 { mq_collect_atoms(base, atoms) } else { false }
            None =>
              if e.numerator().equal_int(1) && e.denominator().equal_int(2) {
                match base {
                  @symcore.Expr::Number(rad) => {
                    if rad.compare(@symnum.BigRational::zero()) < 0 {
                      return false
                    }
                    let (reduced, n) = reduce_radical_power(rad, 2)
                    if n == 1 {
                      true
                    } else if n == 2 {
                      match mq_find_equivalent_atom(atoms, reduced) {
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
  expr : @symcore.Expr,
  atoms : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  let dim = mq_dimension(atoms.length())
  match expr {
    @symcore.Expr::Number(q) => Some(mq_const(dim, q))
    @symcore.Expr::Add(args) => {
      let mut acc = mq_const(dim, @symnum.BigRational::zero())
      for arg in args {
        match mq_parse_expr(arg, atoms) {
          Some(v) => acc = mq_add(acc, v)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = mq_const(dim, @symnum.BigRational::one())
      for arg in args {
        match mq_parse_expr(arg, atoms) {
          Some(v) => acc = mq_mul(acc, v, atoms)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match exp {
        @symcore.Expr::Number(e) =>
          match rational_to_int_if_integer(e) {
            Some(k) =>
              match mq_parse_expr(base, atoms) {
                Some(v) => mq_pow_nonnegative(v, k, atoms)
                None => None
              }
            None =>
              if e.numerator().equal_int(1) && e.denominator().equal_int(2) {
                match base {
                  @symcore.Expr::Number(rad) => {
                    if rad.compare(@symnum.BigRational::zero()) < 0 {
                      return None
                    }
                    let (reduced, n) = reduce_radical_power(rad, 2)
                    if n == 1 {
                      Some(mq_const(dim, reduced))
                    } else if n == 2 {
                      match mq_find_equivalent_atom(atoms, reduced) {
                        Some((idx, scale)) => {
                          let out = mq_const(dim, @symnum.BigRational::zero())
                          out.set(1 << idx, scale)
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
  let matrix = Array::makei(rows, _ => Array::make(cols.length(), @symnum.BigRational::zero()))
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
      aug[row].set(j, aug[row][j].div_r(pv))
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
  a : @symcore.Expr,
  b : @symcore.Expr,
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
fn mq_degree(expr : @symcore.Expr) -> Int? {
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
/// Necessary degree-based filter mirroring SymPy's subfield pre-check shape.
pub fn is_isomorphism_possible(a : @symcore.Expr, b : @symcore.Expr) -> Bool {
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
/// Return coefficients of a polynomial in `b` representing `a` in `Q(b)`.
///
/// This subfield stage currently handles:
/// - rational constants (`[a]`)
/// - affine radical embeddings between `a + b*q**(1/n)` forms (`[k, c]`)
/// - low-degree multiquadratic embeddings (up to 3 independent square roots).
pub fn field_isomorphism(
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> Array[@symnum.BigRational]? {
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
fn affine_embedding_coeffs(
  aff_a : AffineRadical,
  aff_b : AffineRadical,
) -> Array[@symnum.BigRational]? {
  if aff_a.atom.n != aff_b.atom.n {
    return None
  }
  let ratio = aff_a.atom.rad.div_r(aff_b.atom.rad)
  let t = match rational_exact_nth_root(ratio, aff_a.atom.n) {
    Some(root) => root
    None => return None
  }
  let k = aff_a.scale.mul_r(t).div_r(aff_b.scale)
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
