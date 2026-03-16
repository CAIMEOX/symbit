///|
pub type EigenValueMult = (Expr, Int)

///|
pub type EigenVectData = (Expr, Int, Array[Array[Expr]])

///|
fn matrix_add_diag_scalar(
  matrix : Matrix,
  scalar : Expr,
) -> Matrix raise MatrixError {
  if !matrix.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "diagonal scalar shift requires a square matrix",
    )
  }
  let data = clone_expr_rows(matrix.data)
  for i in 0..<matrix.rows {
    data[i][i] = expr_add(data[i][i], scalar)
  }
  { rows: matrix.rows, cols: matrix.cols, data }
}

///|
fn polynomial_const(expr : Expr) -> Map[Int, Expr] {
  let out : Map[Int, Expr] = {}
  if !expr_is_zero(expr) {
    out[0] = expr
  }
  out
}

///|
fn polynomial_merge(
  lhs : Map[Int, Expr],
  rhs : Map[Int, Expr],
) -> Map[Int, Expr] {
  let out : Map[Int, Expr] = {}
  for degree, coeff in lhs {
    if !expr_is_zero(coeff) {
      out[degree] = coeff
    }
  }
  for degree, coeff in rhs {
    match out.get(degree) {
      Some(prev) => {
        let merged = expr_add(prev, coeff)
        if expr_is_zero(merged) {
          ignore(out.remove(degree))
        } else {
          out[degree] = merged
        }
      }
      None => if !expr_is_zero(coeff) { out[degree] = coeff }
    }
  }
  out
}

///|
fn polynomial_mul(lhs : Map[Int, Expr], rhs : Map[Int, Expr]) -> Map[Int, Expr] {
  let out : Map[Int, Expr] = {}
  for left_degree, left_coeff in lhs {
    for right_degree, right_coeff in rhs {
      let degree = left_degree + right_degree
      let coeff = expr_mul(left_coeff, right_coeff)
      if expr_is_zero(coeff) {
        continue
      }
      match out.get(degree) {
        Some(prev) => out[degree] = expr_add(prev, coeff)
        None => out[degree] = coeff
      }
    }
  }
  let cleaned : Map[Int, Expr] = {}
  for degree, coeff in out {
    if !expr_is_zero(coeff) {
      cleaned[degree] = coeff
    }
  }
  cleaned
}

///|
fn polynomial_terms(expr : Expr, indeterminate : Expr) -> Map[Int, Expr]? {
  if expr_eq(expr, indeterminate) {
    let out : Map[Int, Expr] = {}
    out[1] = expr_one()
    return Some(out)
  }
  match expr {
    @symcore.Expr::Add(args) => {
      let mut acc : Map[Int, Expr] = {}
      for arg in args {
        match polynomial_terms(arg, indeterminate) {
          Some(poly) => acc = polynomial_merge(acc, poly)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = polynomial_const(expr_one())
      for arg in args {
        match polynomial_terms(arg, indeterminate) {
          Some(poly) => acc = polynomial_mul(acc, poly)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, @symcore.Expr::Number(exp)) if exp.is_integral() &&
      exp.numerator().to_int() >= 0 => {
      let power = exp.numerator().to_int()
      let base_poly = match polynomial_terms(base, indeterminate) {
        Some(poly) => poly
        None => return None
      }
      let mut acc = polynomial_const(expr_one())
      for _ in 0..<power {
        acc = polynomial_mul(acc, base_poly)
      }
      Some(acc)
    }
    _ => Some(polynomial_const(expr))
  }
}

///|
fn polynomial_to_expr(poly : Map[Int, Expr], indeterminate : Expr) -> Expr {
  if poly.is_empty() {
    return expr_zero()
  }
  let mut max_degree = 0
  for degree, _ in poly {
    if degree > max_degree {
      max_degree = degree
    }
  }
  let mut out = expr_zero()
  for degree in 0..<=max_degree {
    let actual_degree = max_degree - degree
    match poly.get(actual_degree) {
      Some(coeff) => {
        let term = match actual_degree {
          0 => coeff
          1 =>
            if expr_eq(coeff, expr_one()) {
              indeterminate
            } else {
              expr_mul(coeff, indeterminate)
            }
          _ => {
            let power = @symcore.pow(indeterminate, @symcore.int(actual_degree))
            if expr_eq(coeff, expr_one()) {
              power
            } else {
              expr_mul(coeff, power)
            }
          }
        }
        out = expr_add(out, term)
      }
      None => ()
    }
  }
  out
}

///|
fn normalize_charpoly_expr(expr : Expr, indeterminate : Expr) -> Expr {
  match polynomial_terms(expr, indeterminate) {
    Some(poly) => polynomial_to_expr(poly, indeterminate)
    None => expr
  }
}

///|
fn eigen_pack_diagonal(diagonal : Array[Expr]) -> Array[EigenValueMult] {
  let counts : Map[String, (Expr, Int)] = {}
  let order : Array[String] = []
  for value in diagonal {
    let key = @symprint.to_string(value)
    match counts.get(key) {
      Some((expr, mult)) => counts[key] = (expr, mult + 1)
      None => {
        counts[key] = (value, 1)
        order.push(key)
      }
    }
  }
  let out : Array[EigenValueMult] = []
  for key in order {
    match counts.get(key) {
      Some(item) => out.push(item)
      None => ()
    }
  }
  out
}

///|
pub fn Matrix::charpoly_expr(
  self : Matrix,
  x? : Expr = @symcore.symbol("lambda"),
) -> Expr raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError("charpoly requires a square matrix")
  }
  let shifted = matrix_add_diag_scalar(self.scalar_mul(expr_neg(expr_one())), x)
  normalize_charpoly_expr(@symsimplify.numer_expand(shifted.det()), x)
}

///|
pub fn Matrix::charpoly(
  self : Matrix,
  x? : Expr = @symcore.symbol("lambda"),
) -> Expr raise MatrixError {
  self.charpoly_expr(x~)
}

///|
pub fn Matrix::eigenvals(
  self : Matrix,
) -> Array[EigenValueMult] raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "eigenvals requires a square matrix",
    )
  }
  if self.rows == 0 {
    return []
  }
  if self.rows == 1 {
    return [(self.data[0][0], 1)]
  }
  if self.is_diagonal() || self.is_upper() || self.is_lower() {
    return eigen_pack_diagonal(self.diagonal())
  }
  if self.rows == 2 {
    let tr = self.trace()
    let det = self.det()
    let disc = expr_sub(expr_mul(tr, tr), expr_mul(@symcore.int(4), det))
    let sqrt_disc = expr_simplify(@symcore.function("sqrt", [disc]))
    let half = try! @symcore.rational_from_ints(1, 2)
    let r1 = expr_simplify(expr_mul(half, expr_sub(tr, sqrt_disc)))
    let r2 = expr_simplify(expr_mul(half, expr_add(tr, sqrt_disc)))
    if expr_eq(r1, r2) {
      return [(r1, 2)]
    }
    return [(r1, 1), (r2, 1)]
  }
  raise MatrixError::ValueError(
    "eigenvals currently supports diagonal/triangular matrices and general 2x2 matrices",
  )
}

///|
pub fn Matrix::eigenvects(
  self : Matrix,
) -> Array[EigenVectData] raise MatrixError {
  let values = self.eigenvals()
  let out : Array[EigenVectData] = []
  for item in values {
    let (value, mult) = item
    let shifted = matrix_add_diag_scalar(self, expr_neg(value))
    let basis = shifted.nullspace()
    out.push((value, mult, basis))
  }
  out
}

///|
pub fn Matrix::is_diagonalizable(self : Matrix) -> Bool {
  if !self.is_square() {
    return false
  }
  if self.is_diagonal() {
    return true
  }
  let eigs = self.eigenvects() catch { _ => return false }
  let mut basis_count = 0
  for item in eigs {
    let (_, _, basis) = item
    basis_count += basis.length()
  }
  basis_count == self.rows
}

///|
pub fn Matrix::diagonalize(self : Matrix) -> (Matrix, Matrix) raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "diagonalize requires a square matrix",
    )
  }
  let eigs = self.eigenvects()
  let columns : Array[Array[Expr]] = []
  let diag_values : Array[Expr] = []
  for item in eigs {
    let (value, _, basis) = item
    for vec in basis {
      columns.push(vec)
      diag_values.push(value)
    }
  }
  if columns.length() != self.rows {
    raise MatrixError::ValueError("matrix is not diagonalizable")
  }
  let pdata0 = zeros(self.rows, cols=Some(self.rows))
  let pdata = clone_expr_rows(pdata0.data)
  for j in 0..<self.rows {
    for i in 0..<self.rows {
      pdata[i][j] = columns[j][i]
    }
  }
  let p = Matrix::{ rows: self.rows, cols: self.rows, data: pdata }
  let d = diag(diag_values)
  (p, d)
}
