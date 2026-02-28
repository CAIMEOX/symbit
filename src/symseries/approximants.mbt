///|
/// Padé approximants (numeric coefficients, general center x0).

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
fn poly_from_expr_coeffs(
  coeffs : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr {
  poly_to_expr(coeffs, x, coeffs.length())
}

///|
fn expr_to_rational(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn rationals_from_expr_coeffs(
  coeffs : Array[@symcore.Expr],
) -> Array[@symnum.BigRational]? {
  let out : Array[@symnum.BigRational] = Array::new()
  for coeff in coeffs {
    match expr_to_rational(coeff) {
      Some(v) => out.push(v)
      None => return None
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
  if b.is_zero() {
    None
  } else {
    Some(a.div_r(b))
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
fn solve_linear_expr(
  mat_in : Array[Array[@symcore.Expr]],
  rhs_in : Array[@symcore.Expr],
) -> Array[@symcore.Expr]? {
  let n = rhs_in.length()
  let mat : Array[Array[@symcore.Expr]] = Array::new()
  for row in mat_in {
    let new_row : Array[@symcore.Expr] = Array::new()
    for v in row {
      new_row.push(v)
    }
    mat.push(new_row)
  }
  let rhs : Array[@symcore.Expr] = Array::new()
  for v in rhs_in {
    rhs.push(v)
  }
  let mut i = 0
  while i < n {
    let mut pivot = i
    while pivot < n && is_zero_expr(mat[pivot][i]) {
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
    let inv_pivot = match expr_inv(pivot_val) {
      Some(v) => v
      None => return None
    }
    let mut j = i + 1
    while j < n {
      if !is_zero_expr(mat[j][i]) {
        let factor = expr_mul(mat[j][i], inv_pivot)
        let mut k = i
        while k < n {
          mat[j][k] = expr_sub(mat[j][k], expr_mul(factor, mat[i][k]))
          k += 1
        }
        rhs[j] = expr_sub(rhs[j], expr_mul(factor, rhs[i]))
      }
      j += 1
    }
    i += 1
  }
  let sol : Array[@symcore.Expr] = Array::new()
  for _ in 0..<n {
    sol.push(zero_expr())
  }
  let mut r = n - 1
  while true {
    let mut acc = rhs[r]
    let mut c = r + 1
    while c < n {
      acc = expr_sub(acc, expr_mul(mat[r][c], sol[c]))
      c += 1
    }
    let inv = match expr_inv(mat[r][r]) {
      Some(v) => v
      None => return None
    }
    sol[r] = expr_mul(acc, inv)
    if r == 0 {
      break
    }
    r -= 1
  }
  Some(sol)
}

///|
fn pade_from_expr_coeffs(
  coeffs : Array[@symcore.Expr],
  m : Int,
  n : Int,
) -> (Array[@symcore.Expr], Array[@symcore.Expr])? {
  if n == 0 {
    let p : Array[@symcore.Expr] = Array::new()
    for i in 0..<=m {
      p.push(coeffs[i])
    }
    return Some((p, [one_expr()]))
  }
  let mat : Array[Array[@symcore.Expr]] = Array::new()
  let rhs : Array[@symcore.Expr] = Array::new()
  for k in 1..<=n {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 1..<=n {
      row.push(coeffs[m + k - j])
    }
    mat.push(row)
    rhs.push(expr_neg(coeffs[m + k]))
  }
  let q_tail = match solve_linear_expr(mat, rhs) {
    Some(v) => v
    None => return None
  }
  let q : Array[@symcore.Expr] = [one_expr()]
  for v in q_tail {
    q.push(v)
  }
  let p : Array[@symcore.Expr] = Array::new()
  for k in 0..<=m {
    let mut acc = zero_expr()
    let max_j = if k < n { k } else { n }
    for j in 0..<=max_j {
      let qj = q[j]
      acc = expr_add(acc, expr_mul(coeffs[k - j], qj))
    }
    p.push(acc)
  }
  Some((p, q))
}

///|
fn pade_numeric_best(
  coeffs : Array[@symnum.BigRational],
  m : Int,
  n : Int,
) -> (Array[@symnum.BigRational], Array[@symnum.BigRational]) {
  letrec solve = (dn : Int) => {
    let dm = m + (n - dn)
    match pade_from_coeffs(coeffs, dm, dn) {
      Some(v) => v
      None =>
        if dn == 0 {
          ([coeffs[0]], [@symnum.BigRational::one()])
        } else {
          solve(dn - 1)
        }
    }
  }
  solve(n)
}

///|
fn pade_expr_best(
  coeffs : Array[@symcore.Expr],
  m : Int,
  n : Int,
) -> (Array[@symcore.Expr], Array[@symcore.Expr]) {
  letrec solve = (dn : Int) => {
    let dm = m + (n - dn)
    match pade_from_expr_coeffs(coeffs, dm, dn) {
      Some(v) => v
      None =>
        if dn == 0 {
          ([coeffs[0]], [one_expr()])
        } else {
          solve(dn - 1)
        }
    }
  }
  solve(n)
}

///|
fn pade_inv_factorial_expr(n : Int) -> @symcore.Expr {
  let den = factorial_bigint(n)
  @symcore.number(safe_rational(BigInt::from_int(1), den))
}

///|
fn coeffs_via_derivatives(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x_name : String,
  x0 : @symcore.Expr,
  count : Int,
) -> Array[@symcore.Expr] {
  let coeffs : Array[@symcore.Expr] = Array::new()
  let mut current = expr
  for k in 0..<count {
    let env : Map[String, @symcore.Expr] = {}
    env[x_name] = x0
    let value = @symcore.subst(current, env)
    coeffs.push(expr_mul(value, pade_inv_factorial_expr(k)))
    current = @symcalculus.diff(current, x)
  }
  coeffs
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
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("pade variable must be a Symbol")
  }
  let around_zero = match x0 {
    @symcore.Expr::Number(n0v) => n0v.is_zero()
    _ => false
  }
  let work_x = if around_zero { x } else { @symcore.symbol("__pade_t") }
  let work_expr = if around_zero {
    expr
  } else {
    let env : Map[String, @symcore.Expr] = {}
    env[var_name] = @symcore.add([x0, work_x])
    @symcore.subst(expr, env)
  }
  let work_name = match work_x {
    @symcore.Expr::Symbol(name) => name
    _ => "__pade_t"
  }
  let order = m + n0 + 1
  let ser = series(work_expr, x=work_x, x0=@symcore.int(0), n=order)
  let poly_expr = strip_order_expr(ser)
  let coeffs_expr = match poly_from_expr(poly_expr, work_x) {
    Some(poly) => {
      let out : Array[@symcore.Expr] = Array::new()
      for i in 0..<order {
        if i < poly.length() {
          out.push(poly[i])
        } else {
          out.push(zero_expr())
        }
      }
      out
    }
    None => coeffs_via_derivatives(work_expr, work_x, work_name, @symcore.int(0), order)
  }
  let (num_expr, den_expr) = match rationals_from_expr_coeffs(coeffs_expr) {
    Some(coeffs_num) => {
      let (p_coeffs, q_coeffs) = pade_numeric_best(coeffs_num, m, n0)
      (poly_from_rationals(p_coeffs, work_x), poly_from_rationals(q_coeffs, work_x))
    }
    None => {
      let (p_coeffs, q_coeffs) = pade_expr_best(coeffs_expr, m, n0)
      (poly_from_expr_coeffs(p_coeffs, work_x), poly_from_expr_coeffs(q_coeffs, work_x))
    }
  }
  let approx_work = if den_expr == one_expr() {
    num_expr
  } else {
    @symcore.mul([num_expr, @symcore.pow(den_expr, @symcore.int(-1))])
  }
  if around_zero {
    approx_work
  } else {
    let back : Map[String, @symcore.Expr] = {}
    back["__pade_t"] = @symcore.add([x, expr_neg(x0)])
    @symcore.subst(approx_work, back)
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
