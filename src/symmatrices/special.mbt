///|
/// Special dense matrix constructors and calculus-derived helpers.
///
/// Current Limits:
/// - These front doors return dense matrices or symbolic expressions directly.
/// - More specialized structured-matrix families are not modeled separately in this package.
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
  let mut acc = @symcore.int(0)
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
/// Build a Jordan block.
///
/// - Does: Creates an `n x n` dense matrix with `eigenval` on the diagonal and ones on the superdiagonal.
/// - Input: One eigenvalue expression and a non-negative block size.
/// - Returns: A dense `Matrix`.
/// - Limits: Raises `MatrixError::ShapeError` when `n` is negative.
pub fn jordan_cell(eigenval : Expr, n : Int) -> Matrix raise MatrixError {
  if n < 0 {
    raise MatrixError::ShapeError("jordan_cell size must be non-negative")
  }
  let out = zeros(n, cols=Some(n))
  let data = clone_expr_rows(out.data)
  for i in 0..<n {
    data[i][i] = eigenval
    if i + 1 < n {
      data[i][i + 1] = @symcore.int(1)
    }
  }
  { rows: n, cols: n, data }
}

///|
/// Build the right-handed rotation matrix around the first axis.
///
/// - Does: Returns the symbolic `3 x 3` rotation matrix using `sin(theta)` and `cos(theta)`.
/// - Input: One angle expression `theta`.
/// - Returns: A dense `Matrix`.
/// - Limits: Propagates any matrix-construction error from the underlying dense front door.
pub fn rot_axis1(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
    [@symcore.int(0), c, s],
    [@symcore.int(0), expr_neg(s), c],
  ])
}

///|
/// Build the right-handed rotation matrix around the second axis.
///
/// - Does: Returns the symbolic `3 x 3` rotation matrix using `sin(theta)` and `cos(theta)`.
/// - Input: One angle expression `theta`.
/// - Returns: A dense `Matrix`.
/// - Limits: Propagates any matrix-construction error from the underlying dense front door.
pub fn rot_axis2(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, @symcore.int(0), expr_neg(s)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
    [s, @symcore.int(0), c],
  ])
}

///|
/// Build the right-handed rotation matrix around the third axis.
///
/// - Does: Returns the symbolic `3 x 3` rotation matrix using `sin(theta)` and `cos(theta)`.
/// - Input: One angle expression `theta`.
/// - Returns: A dense `Matrix`.
/// - Limits: Propagates any matrix-construction error from the underlying dense front door.
pub fn rot_axis3(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, s, @symcore.int(0)],
    [expr_neg(s), c, @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  ])
}

///|
/// Build the counter-clockwise rotation matrix around the first axis.
///
/// - Does: Returns the symbolic `3 x 3` matrix with the opposite sign convention from `rot_axis1`.
/// - Input: One angle expression `theta`.
/// - Returns: A dense `Matrix`.
/// - Limits: Propagates any matrix-construction error from the underlying dense front door.
pub fn rot_ccw_axis1(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
    [@symcore.int(0), c, expr_neg(s)],
    [@symcore.int(0), s, c],
  ])
}

///|
/// Build the counter-clockwise rotation matrix around the second axis.
///
/// - Does: Returns the symbolic `3 x 3` matrix with the opposite sign convention from `rot_axis2`.
/// - Input: One angle expression `theta`.
/// - Returns: A dense `Matrix`.
/// - Limits: Propagates any matrix-construction error from the underlying dense front door.
pub fn rot_ccw_axis2(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, @symcore.int(0), s],
    [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
    [expr_neg(s), @symcore.int(0), c],
  ])
}

///|
/// Build the counter-clockwise rotation matrix around the third axis.
///
/// - Does: Returns the symbolic `3 x 3` matrix with the opposite sign convention from `rot_axis3`.
/// - Input: One angle expression `theta`.
/// - Returns: A dense `Matrix`.
/// - Limits: Propagates any matrix-construction error from the underlying dense front door.
pub fn rot_ccw_axis3(theta : Expr) -> Matrix raise MatrixError {
  let c = trig_function("cos", theta)
  let s = trig_function("sin", theta)
  matrix([
    [c, expr_neg(s), @symcore.int(0)],
    [s, c, @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  ])
}

///|
/// Orthogonalize or orthonormalize a list of vectors.
///
/// - Does: Runs Gram-Schmidt on row or column vectors and optionally normalizes the resulting basis.
/// - Input: `Array[Matrix]` where each matrix must be a row or column vector, plus optional `orthonormal`.
/// - Returns: `Array[Matrix]` in column-vector form.
/// - Limits: Raises `MatrixError::ShapeError` when an input is not a vector and `MatrixError::SingularMatrixError` when the vectors are linearly dependent.
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
      current = vector_scale(current, expr_div(@symcore.int(1), norm))
    }
    basis.push(current)
  }
  basis
}

///|
/// Build a Hessian matrix, optionally augmented with constraint gradients.
///
/// - Does: Places first derivatives of constraints around the border and second derivatives of `f` in the lower-right block.
/// - Input: One scalar expression `f`, a variable list, and an optional constraint list.
/// - Returns: A dense `Matrix`.
/// - Limits: Constraint handling follows the bordered-Hessian layout only; it does not solve optimization problems by itself.
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
/// Compute the Wronskian determinant.
///
/// - Does: Builds the derivative tower of the given functions and returns the determinant of the resulting matrix.
/// - Input: An array of expressions and a differentiation variable.
/// - Returns: One symbolic `Expr`.
/// - Limits: Raises any matrix or differentiation errors from the underlying dense and calculus front doors.
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
/// Compute the Casoratian determinant of sequences.
///
/// - Does: Substitutes consecutive values into the sequences, builds the resulting matrix, and returns its determinant.
/// - Input: An array of sequence expressions, a symbolic index `n`, and optional `zero` to choose between zero-based and shifted evaluation.
/// - Returns: One symbolic `Expr`.
/// - Limits: Raises `MatrixError::ValueError` when `n` is not a symbol.
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
