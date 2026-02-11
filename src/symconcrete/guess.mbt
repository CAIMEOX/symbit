///|
/// Guessing helpers for sequences.

///|
fn to_rational(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn from_rational(r : @symnum.BigRational) -> @symcore.Expr {
  @symcore.number(r)
}

///|
pub fn find_simple_recurrence_vector(
  seq : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  if seq.length() < 2 {
    return [@symcore.int(0)]
  }
  let data : Array[@symnum.BigRational] = Array::new()
  for v in seq {
    match to_rational(v) {
      Some(r) => data.push(r)
      None => return [@symcore.int(0)]
    }
  }
  let coeffs = berlekamp_massey(data)
  let out : Array[@symcore.Expr] = Array::new()
  for c in coeffs {
    out.push(from_rational(c))
  }
  out
}

///|
pub fn find_simple_recurrence(
  seq : Array[@symcore.Expr],
  a? : @symcore.Expr = @symcore.symbol("a"),
  n? : @symcore.Expr = @symcore.symbol("n"),
) -> @symcore.Expr? {
  let coeffs = find_simple_recurrence_vector(seq)
  if coeffs.length() <= 1 {
    return None
  }
  let name = match symbol_name(a) {
    Some(s) => s
    None => "a"
  }
  let terms : Array[@symcore.Expr] = Array::new()
  let len = coeffs.length()
  for i in 0..<len {
    let coeff = coeffs[len - 1 - i]
    let arg = if i == 0 { n } else { expr_add(n, @symcore.int(i)) }
    let fn_call = @symcore.function(name, [arg])
    terms.push(expr_mul(coeff, fn_call))
  }
  Some(@symcore.add(terms))
}

///|
pub fn find_simple_recurrence_vector_expr(
  seq : Array[@symcore.Expr],
) -> Array[@symcore.Expr]? {
  let coeffs = find_simple_recurrence_vector(seq)
  if coeffs.length() <= 1 {
    None
  } else {
    Some(coeffs)
  }
}

///|
pub fn rinterp(
  data : Array[@symcore.Expr],
  degnum : Int,
  x? : @symcore.Expr = @symcore.symbol("x"),
) -> @symcore.Expr? {
  if data.is_empty() {
    return None
  }
  let values : Array[@symnum.BigRational] = Array::new()
  let mut all_rational = true
  for v in data {
    match to_rational(v) {
      Some(r) => values.push(r)
      None => {
        all_rational = false
        break
      }
    }
  }
  if !all_rational {
    if degnum >= data.length() - 1 {
      return Some(lagrange_poly(data, x))
    }
    return None
  }
  let m = values.length()
  let degden = m - degnum - 1
  if degden < 0 {
    return None
  }
  let n_unknowns = degnum + 1 + degden
  if n_unknowns != m {
    return None
  }
  let mat : Array[Array[@symnum.BigRational]] = Array::new()
  let rhs : Array[@symnum.BigRational] = Array::new()
  for i in 0..<m {
    let x = @symnum.BigRational::from_int(i)
    let row : Array[@symnum.BigRational] = Array::new()
    // p coefficients
    let mut pow = @symnum.BigRational::one()
    for _ in 0..<=degnum {
      row.push(pow)
      pow = pow.mul_r(x)
    }
    // q coefficients (excluding q0)
    let mut qpow = x
    for _ in 1..<=degden {
      row.push(values[i].neg().mul_r(qpow))
      qpow = qpow.mul_r(x)
    }
    mat.push(row)
    rhs.push(values[i])
  }
  let sol = match solve_linear_system(mat, rhs) {
    Some(s) => s
    None => return None
  }
  let p_coeffs : Array[@symnum.BigRational] = Array::new()
  let q_coeffs : Array[@symnum.BigRational] = Array::new()
  for i in 0..<=degnum {
    p_coeffs.push(sol[i])
  }
  q_coeffs.push(@symnum.BigRational::one())
  for i in 0..<degden {
    q_coeffs.push(sol[degnum + 1 + i])
  }
  let num_expr = poly_from_rational(p_coeffs, x)
  let den_expr = poly_from_rational(q_coeffs, x)
  let inv = match expr_inv(den_expr) {
    Some(v) => v
    None => @symcore.pow(den_expr, @symcore.int(-1))
  }
  Some(expr_mul(num_expr, inv))
}

///|
pub fn guess_generating_function_rational(
  seq : Array[@symcore.Expr],
  x? : @symcore.Expr = @symcore.symbol("x"),
) -> @symcore.Expr? {
  if seq.length() < 2 {
    return None
  }
  match bm_coeffs(seq) {
    Some(coeffs) if coeffs.length() > 1 => {
      let l = coeffs.length() - 1
      let values = unwrap_rationals(seq)
      let p_coeffs : Array[@symnum.BigRational] = Array::new()
      for i in 0..<l {
        let mut acc = values[i]
        let mut j = 1
        while j <= i {
          acc = acc.add_r(coeffs[j].mul_r(values[i - j]))
          j = j + 1
        }
        p_coeffs.push(acc)
      }
      let q_coeffs : Array[@symnum.BigRational] = Array::new()
      for i in 0..<=l {
        q_coeffs.push(coeffs[i])
      }
      let num_expr = poly_from_rational(p_coeffs, x)
      let den_expr = poly_from_rational(q_coeffs, x)
      let inv = match expr_inv(den_expr) {
        Some(v) => v
        None => @symcore.pow(den_expr, @symcore.int(-1))
      }
      Some(expr_mul(num_expr, inv))
    }
    _ => {
      let m = seq.length()
      let mut deg = 0
      while deg < m {
        let degden = m - deg - 1
        if degden >= 0 {
          match rinterp(seq, deg, x~) {
            Some(expr) => return Some(expr)
            None => ()
          }
        }
        deg = deg + 1
      }
      None
    }
  }
}

///|
pub fn guess_generating_function(
  seq : Array[@symcore.Expr],
  x? : @symcore.Expr = @symcore.symbol("x"),
) -> @symcore.Expr? {
  guess_generating_function_rational(seq, x~)
}

///|
pub fn guess(
  seq : Array[@symcore.Expr],
  all? : Bool = false,
  evaluate? : Bool = true,
  niter? : Int = 2,
  variables? : Array[@symcore.Expr] = [],
) -> @symcore.Expr? {
  let _ = niter
  let _ = variables
  let rec = find_simple_recurrence(seq)
  let gf = guess_generating_function_rational(seq)
  if all {
    match (rec, gf) {
      (Some(r), Some(g)) => Some(@symcore.function("Tuple", [r, g]))
      (Some(r), None) => Some(@symcore.function("Tuple", [r]))
      (None, Some(g)) => Some(@symcore.function("Tuple", [g]))
      _ => None
    }
  } else if evaluate {
    match rec {
      Some(r) => Some(r)
      None => gf
    }
  } else {
    rec
  }
}

///|
pub fn rationalize(x : @symcore.Expr, maxcoeff? : Int = 10000) -> @symcore.Expr {
  let _ = maxcoeff
  match x {
    @symcore.Expr::Number(_) => x
    _ => x
  }
}

///|
fn berlekamp_massey(
  seq : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational] {
  let n = seq.length()
  let c : Array[@symnum.BigRational] = [@symnum.BigRational::one()]
  let b : Array[@symnum.BigRational] = [@symnum.BigRational::one()]
  let mut l = 0
  let mut m = 1
  let mut bb = @symnum.BigRational::one()
  for i in 0..<n {
    let mut d = seq[i]
    let mut j = 1
    while j <= l {
      d = d.add_r(c[j].mul_r(seq[i - j]))
      j = j + 1
    }
    if d.is_zero() {
      m = m + 1
      continue
    }
    let t : Array[@symnum.BigRational] = Array::new()
    for v in c {
      t.push(v)
    }
    let coef = try! d.div_r(bb)
    let need = b.length() + m
    while c.length() < need {
      c.push(@symnum.BigRational::zero())
    }
    for k in 0..<b.length() {
      let idx = k + m
      c[idx] = c[idx].add_r(coef.mul_r(b[k]).neg())
    }
    if 2 * l <= i {
      l = i + 1 - l
      b.clear()
      for v in t {
        b.push(v)
      }
      bb = d
      m = 1
    } else {
      m = m + 1
    }
  }
  c
}

///|
fn unwrap_rationals(seq : Array[@symcore.Expr]) -> Array[@symnum.BigRational] {
  let out : Array[@symnum.BigRational] = Array::new()
  for v in seq {
    match to_rational(v) {
      Some(r) => out.push(r)
      None => out.push(@symnum.BigRational::zero())
    }
  }
  out
}

///|
fn bm_coeffs(seq : Array[@symcore.Expr]) -> Array[@symnum.BigRational]? {
  let values : Array[@symnum.BigRational] = Array::new()
  for v in seq {
    match to_rational(v) {
      Some(r) => values.push(r)
      None => return None
    }
  }
  Some(berlekamp_massey(values))
}

///|
fn solve_linear_system(
  mat : Array[Array[@symnum.BigRational]],
  rhs : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  let n = mat.length()
  if n == 0 {
    return None
  }
  let mut i = 0
  while i < n {
    let mut pivot = i
    while pivot < n && mat[pivot][i].is_zero() {
      pivot = pivot + 1
    }
    if pivot == n {
      return None
    }
    if pivot != i {
      let tmp = mat[i]
      mat[i] = mat[pivot]
      mat[pivot] = tmp
      let t2 = rhs[i]
      rhs[i] = rhs[pivot]
      rhs[pivot] = t2
    }
    let pivot_val = mat[i][i]
    let inv = try! pivot_val.reciprocal()
    let mut j = i
    while j < n {
      mat[i][j] = mat[i][j].mul_r(inv)
      j = j + 1
    }
    rhs[i] = rhs[i].mul_r(inv)
    let mut r = 0
    while r < n {
      if r != i {
        let factor = mat[r][i]
        if !factor.is_zero() {
          let mut c = i
          while c < n {
            mat[r][c] = mat[r][c].add_r(factor.mul_r(mat[i][c]).neg())
            c = c + 1
          }
          rhs[r] = rhs[r].add_r(factor.mul_r(rhs[i]).neg())
        }
      }
      r = r + 1
    }
    i = i + 1
  }
  Some(rhs)
}

///|
fn poly_from_rational(
  coeffs : Array[@symnum.BigRational],
  x : @symcore.Expr,
) -> @symcore.Expr {
  let terms : Array[@symcore.Expr] = Array::new()
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if coeff.is_zero() {
      continue
    }
    let base = @symcore.number(coeff)
    let term = if i == 0 {
      base
    } else {
      expr_mul(base, @symcore.pow(x, @symcore.int(i)))
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(terms)
  }
}

///|
fn lagrange_poly(
  data : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr {
  let m = data.length()
  let terms : Array[@symcore.Expr] = Array::new()
  for i in 0..<m {
    let mut term = data[i]
    for j in 0..<m {
      if i == j {
        continue
      }
      let num = expr_sub(x, @symcore.int(j))
      let inv = try! @symcore.rational_from_ints(1, i - j)
      term = expr_mul(term, expr_mul(num, inv))
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(terms)
  }
}
