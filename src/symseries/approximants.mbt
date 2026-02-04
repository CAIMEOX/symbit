///|
/// Padé approximants (limited to numeric coefficients, x0=0).

///|
fn strip_order_expr(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, _) if name == "O" => @symcore.int(0)
    @symcore.Expr::Add(args) => {
      let kept : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Function(name, _) if name == "O" => ()
          _ => kept.push(arg)
        }
      }
      if kept.is_empty() {
        @symcore.int(0)
      } else if kept.length() == 1 {
        kept[0]
      } else {
        @symcore.add(kept)
      }
    }
    _ => expr
  }
}

///|
fn poly_from_rationals(
  coeffs : Array[@symnum.BigRational],
  x : @symcore.Expr,
) -> @symcore.Expr {
  let expr_coeffs : Array[@symcore.Expr] = Array::new()
  for c in coeffs {
    expr_coeffs.push(@symcore.number(c))
  }
  poly_to_expr(expr_coeffs, x, expr_coeffs.length())
}

///|
fn expr_to_rational(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn rationals_from_poly(
  poly : Array[@symcore.Expr],
  count : Int,
) -> Array[@symnum.BigRational]? {
  let out : Array[@symnum.BigRational] = Array::new()
  for i in 0..<count {
    if i < poly.length() {
      match expr_to_rational(poly[i]) {
        Some(v) => out.push(v)
        None => return None
      }
    } else {
      out.push(@symnum.BigRational::zero())
    }
  }
  Some(out)
}

///|
fn br_add(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational {
  a.add_r(b)
}

///|
fn br_sub(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational {
  a.add_r(b.neg_r())
}

///|
fn br_mul(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational {
  a.mul_r(b)
}

///|
fn br_div(
  a : @symnum.BigRational,
  b : @symnum.BigRational,
) -> @symnum.BigRational? {
  try a.div_r(b) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn solve_linear(
  mat_in : Array[Array[@symnum.BigRational]],
  rhs_in : Array[@symnum.BigRational],
) -> Array[@symnum.BigRational]? {
  let n = rhs_in.length()
  let mat : Array[Array[@symnum.BigRational]] = Array::new()
  for row in mat_in {
    let new_row : Array[@symnum.BigRational] = Array::new()
    for v in row {
      new_row.push(v)
    }
    mat.push(new_row)
  }
  let rhs : Array[@symnum.BigRational] = Array::new()
  for v in rhs_in {
    rhs.push(v)
  }
  let mut i = 0
  while i < n {
    let mut pivot = i
    while pivot < n && mat[pivot][i].is_zero() {
      pivot += 1
    }
    if pivot == n {
      return None
    }
    if pivot != i {
      let tmp_row = mat[i]
      mat[i] = mat[pivot]
      mat[pivot] = tmp_row
      let tmp_rhs = rhs[i]
      rhs[i] = rhs[pivot]
      rhs[pivot] = tmp_rhs
    }
    let pivot_val = mat[i][i]
    let mut j = i + 1
    while j < n {
      if !mat[j][i].is_zero() {
        let factor = match br_div(mat[j][i], pivot_val) {
          Some(v) => v
          None => return None
        }
        let mut k = i
        while k < n {
          mat[j][k] = br_sub(mat[j][k], br_mul(factor, mat[i][k]))
          k += 1
        }
        rhs[j] = br_sub(rhs[j], br_mul(factor, rhs[i]))
      }
      j += 1
    }
    i += 1
  }
  let sol : Array[@symnum.BigRational] = Array::new()
  for _ in 0..<n {
    sol.push(@symnum.BigRational::zero())
  }
  let mut r = n - 1
  while true {
    let mut acc = rhs[r]
    let mut c = r + 1
    while c < n {
      acc = br_sub(acc, br_mul(mat[r][c], sol[c]))
      c += 1
    }
    let val = match br_div(acc, mat[r][r]) {
      Some(v) => v
      None => return None
    }
    sol[r] = val
    if r == 0 {
      break
    }
    r -= 1
  }
  Some(sol)
}

///|
fn pade_from_coeffs(
  coeffs : Array[@symnum.BigRational],
  m : Int,
  n : Int,
) -> (Array[@symnum.BigRational], Array[@symnum.BigRational])? {
  if n == 0 {
    let p : Array[@symnum.BigRational] = Array::new()
    for i in 0..<=m {
      p.push(coeffs[i])
    }
    return Some((p, [@symnum.BigRational::one()]))
  }
  let mat : Array[Array[@symnum.BigRational]] = Array::new()
  let rhs : Array[@symnum.BigRational] = Array::new()
  for k in 1..<=n {
    let row : Array[@symnum.BigRational] = Array::new()
    for j in 1..<=n {
      row.push(coeffs[m + k - j])
    }
    mat.push(row)
    rhs.push(coeffs[m + k].neg_r())
  }
  let q_tail = match solve_linear(mat, rhs) {
    Some(v) => v
    None => return None
  }
  let q : Array[@symnum.BigRational] = Array::new()
  q.push(@symnum.BigRational::one())
  for v in q_tail {
    q.push(v)
  }
  let p : Array[@symnum.BigRational] = Array::new()
  for k in 0..<=m {
    let mut acc = @symnum.BigRational::zero()
    let max_j = if k < n { k } else { n }
    for j in 0..<=max_j {
      let qj = if j == 0 { @symnum.BigRational::one() } else { q[j] }
      acc = br_add(acc, br_mul(coeffs[k - j], qj))
    }
    p.push(acc)
  }
  Some((p, q))
}

///|
pub fn pade_approximant(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0? : @symcore.Expr = @symcore.int(0),
  m? : Int = 6,
  n? : Int = -1,
) -> @symcore.Expr raise {
  let n0 = if n < 0 { m } else { n }
  if m < 0 || n0 < 0 {
    fail("pade m and n must be non-negative")
  }
  match x {
    @symcore.Expr::Symbol(_) => ()
    _ => fail("pade variable must be a Symbol")
  }
  match x0 {
    @symcore.Expr::Number(n0v) if n0v.is_zero() => ()
    _ => fail("pade only supports x0 = 0 in this stage")
  }
  let order = m + n0 + 1
  let ser = series(expr, x~, x0~, n=order)
  let poly_expr = strip_order_expr(ser)
  let poly = match poly_from_expr(poly_expr, x) {
    Some(p) => p
    None => fail("pade requires a polynomial series")
  }
  let coeffs = match rationals_from_poly(poly, order) {
    Some(v) => v
    None => fail("pade requires numeric coefficients")
  }
  let (p_coeffs, q_coeffs) = match pade_from_coeffs(coeffs, m, n0) {
    Some(v) => v
    None => fail("pade solve failed")
  }
  let num_expr = poly_from_rationals(p_coeffs, x)
  let den_expr = poly_from_rationals(q_coeffs, x)
  if q_coeffs.length() == 1 {
    num_expr
  } else {
    @symcore.mul([num_expr, @symcore.pow(den_expr, @symcore.int(-1))])
  }
}

///|
pub fn approximants(
  coeffs : Array[@symcore.Expr],
  x? : @symcore.Expr = @symcore.symbol("x"),
  simplify? : Bool = false,
) -> Array[@symcore.Expr] raise {
  let _ = simplify
  let mut l : Array[@symcore.Expr] = Array::new()
  for v in coeffs {
    l.push(v)
  }
  let mut p1 : Array[@symcore.Expr] = [one_expr()]
  let mut q1 : Array[@symcore.Expr] = [zero_expr()]
  let mut p2 : Array[@symcore.Expr] = [zero_expr()]
  let mut q2 : Array[@symcore.Expr] = [one_expr()]
  let out : Array[@symcore.Expr] = Array::new()
  while !l.is_empty() {
    let mut b = 0
    while b < l.length() && is_zero_expr(l[b]) {
      b += 1
      if b == l.length() {
        return out
      }
    }
    let inv_lb = match expr_inv(l[b]) {
      Some(v) => v
      None => fail("approximants division by zero")
    }
    let mseq : Array[@symcore.Expr] = Array::new()
    mseq.push(inv_lb)
    let mut k = b + 1
    while k < l.length() {
      let mut s = zero_expr()
      let mut j = b
      while j < k {
        let idx = b - j - 1
        let mi = mseq[mseq.length() + idx]
        let term = expr_mul(l[j + 1], mi)
        s = expr_sub(s, term)
        j += 1
      }
      mseq.push(expr_mul(s, inv_lb))
      k += 1
    }
    l = mseq
    let a = l[0]
    l[0] = zero_expr()
    let p_len = if p2.length() > b + p1.length() {
      p2.length()
    } else {
      b + p1.length()
    }
    let q_len = if q2.length() > b + q1.length() {
      q2.length()
    } else {
      b + q1.length()
    }
    let p : Array[@symcore.Expr] = Array::new()
    let q : Array[@symcore.Expr] = Array::new()
    for _ in 0..<p_len {
      p.push(zero_expr())
    }
    for _ in 0..<q_len {
      q.push(zero_expr())
    }
    for i in 0..<p2.length() {
      p[i] = expr_mul(a, p2[i])
    }
    for i in b..<(b + p1.length()) {
      p[i] = expr_add(p[i], p1[i - b])
    }
    for i in 0..<q2.length() {
      q[i] = expr_mul(a, q2[i])
    }
    for i in b..<(b + q1.length()) {
      q[i] = expr_add(q[i], q1[i - b])
    }
    let p_trim = poly_trim(p)
    let q_trim = poly_trim(q)
    p1 = p2
    q1 = q2
    p2 = p_trim
    q2 = q_trim
    let num_expr = poly_to_expr(p2, x, p2.length())
    let den_expr = poly_to_expr(q2, x, q2.length())
    let approx = if q2.is_empty() {
      num_expr
    } else {
      @symcore.mul([num_expr, @symcore.pow(den_expr, @symcore.int(-1))])
    }
    out.push(approx)
  }
  out
}
