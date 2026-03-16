///|
fn normalize_vector_matrix(vec : Matrix) -> Matrix raise MatrixError {
  if vec.cols == 1 {
    return vec
  }
  if vec.rows == 1 {
    return vec.transpose()
  }
  raise MatrixError::ShapeError("expected a row or column vector")
}

///|
fn vector_dot(lhs : Matrix, rhs : Matrix) -> Expr raise MatrixError {
  let left = normalize_vector_matrix(lhs)
  let right = normalize_vector_matrix(rhs)
  if left.rows != right.rows {
    raise MatrixError::ShapeError("vector dimensions must agree")
  }
  let mut acc = expr_zero()
  for i in 0..<left.rows {
    acc = expr_add(acc, expr_mul(left.data[i][0], right.data[i][0]))
  }
  acc
}

///|
fn vector_sub(lhs : Matrix, rhs : Matrix) -> Matrix raise MatrixError {
  let left = normalize_vector_matrix(lhs)
  let right = normalize_vector_matrix(rhs)
  if left.rows != right.rows {
    raise MatrixError::ShapeError("vector dimensions must agree")
  }
  let out : Array[Array[Expr]] = []
  for i in 0..<left.rows {
    out.push([expr_sub(left.data[i][0], right.data[i][0])])
  }
  matrix(out)
}

///|
fn vector_scale(vec : Matrix, scalar : Expr) -> Matrix raise MatrixError {
  normalize_vector_matrix(vec).scalar_mul(scalar)
}

///|
fn trig_function(name : String, theta : Expr) -> Expr {
  expr_simplify(@symcore.function(name, [theta]))
}

///|
pub fn jordan_cell(eigenval : Expr, n : Int) -> Matrix raise MatrixError {
  if n < 0 {
    raise MatrixError::ShapeError("jordan_cell size must be non-negative")
  }
  let out = zeros(n, cols=Some(n))
  let data = clone_expr_rows(out.data)
  for i in 0..<n {
    data[i][i] = eigenval
    if i + 1 < n {
      data[i][i + 1] = expr_one()
    }
  }
  { rows: n, cols: n, data }
}

///|
pub fn rot_axis1(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [expr_one(), expr_zero(), expr_zero()],
    [expr_zero(), c, s],
    [expr_zero(), expr_neg(s), c],
  ])
}

///|
pub fn rot_axis2(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, expr_zero(), expr_neg(s)],
    [expr_zero(), expr_one(), expr_zero()],
    [s, expr_zero(), c],
  ])
}

///|
pub fn rot_axis3(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, s, expr_zero()],
    [expr_neg(s), c, expr_zero()],
    [expr_zero(), expr_zero(), expr_one()],
  ])
}

///|
pub fn rot_ccw_axis1(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [expr_one(), expr_zero(), expr_zero()],
    [expr_zero(), c, expr_neg(s)],
    [expr_zero(), s, c],
  ])
}

///|
pub fn rot_ccw_axis2(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, expr_zero(), s],
    [expr_zero(), expr_one(), expr_zero()],
    [expr_neg(s), expr_zero(), c],
  ])
}

///|
pub fn rot_ccw_axis3(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, expr_neg(s), expr_zero()],
    [s, c, expr_zero()],
    [expr_zero(), expr_zero(), expr_one()],
  ])
}

///|
pub fn gram_schmidt(
  vectors : Array[Matrix],
  orthonormal? : Bool = false,
) -> Array[Matrix] raise MatrixError {
  let basis : Array[Matrix] = []
  for vec in vectors {
    let mut current = normalize_vector_matrix(vec)
    for prev in basis {
      let coeff = expr_div(vector_dot(prev, current), vector_dot(prev, prev))
      current = vector_sub(current, vector_scale(prev, coeff))
    }
    if current.is_zero_matrix() {
      raise MatrixError::SingularMatrixError(
        "gram_schmidt found linearly dependent vectors",
      )
    }
    if orthonormal {
      let norm = expr_simplify(
        @symcore.function("sqrt", [vector_dot(current, current)]),
      )
      current = vector_scale(current, expr_div(expr_one(), norm))
    }
    basis.push(current)
  }
  basis
}

///|
pub fn hessian(
  f : Expr,
  varlist : Array[Expr],
  constraints? : Array[Expr] = [],
) -> Matrix raise MatrixError {
  let n = constraints.length() + varlist.length()
  let out = zeros(n, cols=Some(n))
  let data = clone_expr_rows(out.data)
  for i in 0..<constraints.length() {
    for j in 0..<varlist.length() {
      let deriv = @symcalculus.diff(constraints[i], varlist[j])
      data[i][constraints.length() + j] = deriv
      data[constraints.length() + j][i] = deriv
    }
  }
  for i in 0..<varlist.length() {
    for j in 0..<varlist.length() {
      data[constraints.length() + i][constraints.length() + j] = @symcalculus.diff(
        @symcalculus.diff(f, varlist[i]),
        varlist[j],
      )
    }
  }
  { rows: n, cols: n, data }
}

///|
pub fn wronskian(functions : Array[Expr], wrt : Expr) -> Expr raise MatrixError {
  let rows = functions.length()
  let mut current = functions.map(fn(item) { item })
  let data : Array[Array[Expr]] = []
  for _ in 0..<rows {
    let row : Array[Expr] = []
    for value in current {
      row.push(value)
    }
    data.push(row)
    let next : Array[Expr] = []
    for value in current {
      next.push(@symcalculus.diff(value, wrt))
    }
    current = next
  }
  matrix(data).det()
}

///|
pub fn casoratian(
  seqs : Array[Expr],
  n : Expr,
  zero? : Bool = true,
) -> Expr raise MatrixError {
  let rows = seqs.length()
  let data : Array[Array[Expr]] = []
  let name = match n {
    @symcore.Expr::Symbol(sym) => sym
    _ => raise MatrixError::ValueError("casoratian variable must be a Symbol")
  }
  for i in 0..<rows {
    let row : Array[Expr] = []
    for seq in seqs {
      let env : Map[String, Expr] = {}
      env[name] = if zero {
        @symcore.int(i)
      } else {
        expr_add(n, @symcore.int(i))
      }
      row.push(@symcore.subst(seq, env))
    }
    data.push(row)
  }
  matrix(data).det()
}
