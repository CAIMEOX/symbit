///|
pub type EigenValueMult = (Expr, Int)

///|
pub type EigenVectData = (Expr, Int, Array[Array[Expr]])

///|
type JordanChain = (Expr, Array[Array[Expr]])

///|
fn vector_matrix_from_array(items : Array[Expr]) -> Matrix raise MatrixError {
  let rows : Array[Array[Expr]] = []
  for item in items {
    rows.push([item])
  }
  matrix(rows)
}

///|
fn matrix_from_columns(
  columns : Array[Array[Expr]],
) -> Matrix raise MatrixError {
  if columns.is_empty() {
    return zeros(0, cols=Some(0))
  }
  let rows = columns[0].length()
  let data = Array::makei(rows, fn(_) {
    Array::make(columns.length(), @symcore.int(0))
  })
  for j in 0..<columns.length() {
    if columns[j].length() != rows {
      raise MatrixError::ShapeError("matrix columns must have equal height")
    }
    for i in 0..<rows {
      data[i][j] = columns[j][i]
    }
  }
  matrix(data)
}

///|
fn vector_extends_basis(
  basis : Array[Array[Expr]],
  candidate : Array[Expr],
) -> Bool raise MatrixError {
  if basis.is_empty() {
    return !candidate.all(expr_is_zero)
  }
  let old_rank = matrix_from_columns(basis).rank()
  let extended : Array[Array[Expr]] = []
  for vec in basis {
    extended.push(vec)
  }
  extended.push(candidate)
  let new_rank = matrix_from_columns(extended).rank()
  new_rank > old_rank
}

///|
fn solve_singular_particular(
  lhs : Matrix,
  rhs : Array[Expr],
) -> Array[Expr] raise MatrixError {
  let rhs_matrix = vector_matrix_from_array(rhs)
  let (reduced_lhs, reduced_rhs) = lhs.rref_rhs(rhs_matrix)
  let solution = Array::make(lhs.cols, @symcore.int(0))
  for i in 0..<reduced_lhs.rows {
    let mut pivot : Int? = None
    for j in 0..<reduced_lhs.cols {
      if !expr_is_zero(reduced_lhs.data[i][j]) {
        pivot = Some(j)
        break
      }
    }
    match pivot {
      Some(col) => solution[col] = reduced_rhs.data[i][0]
      None =>
        if !expr_is_zero(reduced_rhs.data[i][0]) {
          raise MatrixError::ValueError(
            "singular linear system is inconsistent",
          )
        }
    }
  }
  solution
}

///|
fn jordan_chains_for_eigenvalue(
  matrix : Matrix,
  value : Expr,
  mult : Int,
  basis : Array[Array[Expr]],
) -> Array[Array[Array[Expr]]] raise MatrixError {
  if mult == basis.length() {
    let out : Array[Array[Array[Expr]]] = []
    for vec in basis {
      out.push([vec])
    }
    return out
  }
  let shifted = matrix_add_diag_scalar(matrix, expr_neg(value))
  let chains : Array[Array[Array[Expr]]] = []
  let used_vectors : Array[Array[Expr]] = []
  for vec in basis {
    chains.push([vec])
    used_vectors.push(vec)
  }
  let mut remaining = mult - basis.length()
  while remaining > 0 {
    let mut extended_any = false
    for idx in 0..<chains.length() {
      if remaining == 0 {
        break
      }
      let chain = chains[idx]
      let tail = chain[chain.length() - 1]
      let candidate = solve_singular_particular(shifted, tail) catch {
        _ => continue
      }
      if !vector_extends_basis(used_vectors, candidate) {
        continue
      }
      chains[idx].push(candidate)
      used_vectors.push(candidate)
      remaining -= 1
      extended_any = true
    }
    if !extended_any {
      raise MatrixError::ValueError(
        "failed to construct full generalized eigenvector chains",
      )
    }
  }
  chains
}

///|
fn jordan_chain_data(matrix : Matrix) -> Array[JordanChain] raise MatrixError {
  let out : Array[JordanChain] = []
  for item in matrix.eigenvects() {
    let (value, mult, basis) = item
    let chains = jordan_chains_for_eigenvalue(matrix, value, mult, basis)
    for chain in chains {
      out.push((value, chain))
    }
  }
  out
}

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
    out[1] = @symcore.int(1)
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
      let mut acc = polynomial_const(@symcore.int(1))
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
      let mut acc = polynomial_const(@symcore.int(1))
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
    return @symcore.int(0)
  }
  let mut max_degree = 0
  for degree, _ in poly {
    if degree > max_degree {
      max_degree = degree
    }
  }
  let mut out = @symcore.int(0)
  for degree in 0..<=max_degree {
    let actual_degree = max_degree - degree
    match poly.get(actual_degree) {
      Some(coeff) => {
        let term = match actual_degree {
          0 => coeff
          1 =>
            if expr_eq(coeff, @symcore.int(1)) {
              indeterminate
            } else {
              expr_mul(coeff, indeterminate)
            }
          _ => {
            let power = @symcore.pow(indeterminate, @symcore.int(actual_degree))
            if expr_eq(coeff, @symcore.int(1)) {
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
fn eigen_pack_values(values : Array[Expr]) -> Array[EigenValueMult] {
  let counts : Map[String, (Expr, Int)] = {}
  let order : Array[String] = []
  for value in values {
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
fn matrix_charpoly_roots(matrix : Matrix) -> Array[Expr] raise MatrixError {
  let lam_name = "_lambda"
  let poly = @sympolys.Poly::from_expr_defaults(
    matrix.charpoly_expr(x=@symcore.Expr::Symbol(lam_name)),
    gens=[lam_name],
  ) catch {
    _ =>
      raise MatrixError::ValueError(
        "charpoly could not be converted into a polynomial over a supported exact domain",
      )
  }
  @sympolys.roots(poly).map(expr_simplify) catch {
    _ =>
      raise MatrixError::ValueError(
        "eigen root extraction is not available for this characteristic polynomial",
      )
  }
}

///|
fn expr_rows_clone(rows : Array[Array[Expr]]) -> Array[Array[Expr]] {
  let out : Array[Array[Expr]] = []
  for row in rows {
    let copied : Array[Expr] = []
    for item in row {
      copied.push(item)
    }
    out.push(copied)
  }
  out
}

///|
fn matrix_exact_charpoly_expr(
  matrix : Matrix,
  x : Expr,
) -> Expr raise MatrixError {
  match matrix_exact_integer_data(matrix.to_list()) {
    Some(data) => return exact_integer_charpoly_expr(data, x)
    None => ()
  }
  let dm = (@sympolys.DomainMatrix::from_Matrix(
    matrix.to_list(),
    fmt="dense",
  ) catch {
    _ =>
      raise MatrixError::ValueError(
        "matrix entries are not supported by the exact DomainMatrix charpoly path",
      )
  })
  let coeffs = dm.charpoly_base() catch {
    _ =>
      raise MatrixError::ValueError(
        "exact DomainMatrix charpoly is not available for this matrix",
      )
  }
  let domain = dm.domain
  let degree = coeffs.length() - 1
  let terms : Array[Expr] = Array::new()
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    let coeff_expr = (@sympolys.DomainScalar::new(coeff, domain) catch {
      _ =>
        raise MatrixError::ValueError(
          "exact DomainMatrix charpoly coefficient could not be converted back to an expression",
        )
    }).to_sympy()
    if coeff_expr == @symcore.int(0) {
      continue
    }
    let exp = degree - i
    let term = match exp {
      0 => coeff_expr
      1 =>
        if coeff_expr == @symcore.int(1) {
          x
        } else {
          expr_mul(coeff_expr, x)
        }
      _ => {
        let x_pow = @symcore.pow(x, @symcore.int(exp))
        if coeff_expr == @symcore.int(1) {
          x_pow
        } else {
          expr_mul(coeff_expr, x_pow)
        }
      }
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
fn matrix_try_exact_charpoly_expr(
  matrix : Matrix,
  x : Expr,
) -> Expr? raise MatrixError {
  let exact : Result[Expr, MatrixError] = try? matrix_exact_charpoly_expr(
    matrix,
    x,
  )
  match exact {
    Ok(value) => Some(value)
    Err(MatrixError::ValueError(_)) => None
    Err(err) => raise err
  }
}

///|
fn matrix_exact_eigenvects(
  matrix : Matrix,
) -> Array[EigenVectData] raise MatrixError {
  let dm = @sympolys.DomainMatrix::from_Matrix(
    matrix.to_list(),
    fmt="dense",
    field=true,
  ) catch {
    _ =>
      raise MatrixError::ValueError(
        "matrix entries are not supported by the exact DomainMatrix eigensolver",
      )
  }
  let (rational, algebraic) = @sympolys.dom_eigenvects(dm, l="_lambda") catch {
    _ =>
      raise MatrixError::ValueError(
        "exact DomainMatrix eigen decomposition is not available for this matrix",
      )
  }
  let out : Array[EigenVectData] = []
  for item in rational {
    let eigenvalue = (@sympolys.DomainScalar::new(item.1, item.0) catch {
      _ =>
        raise MatrixError::ValueError(
          "exact rational eigenvalue could not be converted back to an expression",
        )
    }).to_sympy()
    let basis_rows = item.3.to_Matrix() catch {
      _ =>
        raise MatrixError::ValueError(
          "exact rational eigenbasis could not be converted back to expression rows",
        )
    }
    out.push((expr_simplify(eigenvalue), item.2, expr_rows_clone(basis_rows)))
  }
  for item in algebraic {
    let gen = if item.1.gens.is_empty() { "_lambda" } else { item.1.gens[0] }
    let basis_rows = item.3.to_Matrix() catch {
      _ =>
        raise MatrixError::ValueError(
          "exact algebraic eigenbasis could not be converted back to expression rows",
        )
    }
    let roots = @sympolys.roots(item.1) catch {
      _ =>
        raise MatrixError::ValueError(
          "algebraic eigenvalue expansion is not available for this matrix",
        )
    }
    for root in roots {
      let env : Map[String, Expr] = {}
      let eigenvalue = expr_simplify(root)
      env[gen] = eigenvalue
      let basis : Array[Array[Expr]] = []
      for row in basis_rows {
        let copied : Array[Expr] = []
        for item in row {
          copied.push(expr_simplify(@symcore.subst(item, env)))
        }
        basis.push(copied)
      }
      out.push((eigenvalue, item.2, basis))
    }
  }
  out
}

///|
pub fn Matrix::charpoly_expr(
  self : Matrix,
  x? : Expr = @symcore.Expr::Symbol("lambda"),
) -> Expr raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError("charpoly requires a square matrix")
  }
  if !matrix_has_floating_leaf(self.data) {
    match matrix_try_exact_charpoly_expr(self, x) {
      Some(charpoly) => return charpoly
      None => ()
    }
  }
  let shifted = matrix_add_diag_scalar(
    self.scalar_mul(expr_neg(@symcore.int(1))),
    x,
  )
  normalize_charpoly_expr(@symsimplify.numer_expand(shifted.det()), x)
}

///|
pub fn Matrix::charpoly(
  self : Matrix,
  x? : Expr = @symcore.Expr::Symbol("lambda"),
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
    let half = @symcore.rational_from_ints(1, 2) catch {
      _ =>
        expr_mul(
          @symcore.int(1),
          @symcore.pow(@symcore.int(2), @symcore.int(-1)),
        )
    }
    let r1 = expr_simplify(expr_mul(half, expr_sub(tr, sqrt_disc)))
    let r2 = expr_simplify(expr_mul(half, expr_add(tr, sqrt_disc)))
    if expr_eq(r1, r2) {
      return [(r1, 2)]
    }
    return [(r1, 1), (r2, 1)]
  }
  let exact = matrix_exact_eigenvects(self) catch { _ => [] }
  if !exact.is_empty() {
    let out : Array[EigenValueMult] = []
    for item in exact {
      out.push((item.0, item.1))
    }
    return out
  }
  eigen_pack_values(matrix_charpoly_roots(self))
}

///|
pub fn Matrix::eigenvects(
  self : Matrix,
) -> Array[EigenVectData] raise MatrixError {
  if self.rows > 2 &&
    !(self.is_diagonal() || self.is_upper() || self.is_lower()) {
    let exact = matrix_exact_eigenvects(self) catch { _ => [] }
    if !exact.is_empty() {
      return exact
    }
  }
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
pub fn Matrix::jordan_cells(self : Matrix) -> Array[Matrix] raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "jordan_cells requires a square matrix",
    )
  }
  if self.rows == 0 {
    return []
  }
  if self.is_diagonal() {
    let out : Array[Matrix] = []
    for value in self.diagonal() {
      out.push(jordan_cell(value, 1))
    }
    return out
  }
  let out : Array[Matrix] = []
  for item in jordan_chain_data(self) {
    let (value, chain) = item
    out.push(jordan_cell(value, chain.length()))
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
pub fn Matrix::diagonalize(
  self : Matrix,
  reals_only? : Bool = false,
) -> (Matrix, Matrix) raise MatrixError {
  ignore(reals_only)
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

///|
pub fn Matrix::jordan_form(
  self : Matrix,
  calc_transform? : Bool = true,
) -> (Matrix, Matrix) raise MatrixError {
  if !self.is_square() {
    raise MatrixError::NonSquareMatrixError(
      "jordan_form requires a square matrix",
    )
  }
  let chains = jordan_chain_data(self)
  let jordan_blocks : Array[Matrix] = []
  let columns : Array[Array[Expr]] = []
  for item in chains {
    let (value, chain) = item
    jordan_blocks.push(jordan_cell(value, chain.length()))
    for vec in chain {
      columns.push(vec)
    }
  }
  if columns.length() != self.rows {
    raise MatrixError::ValueError("failed to assemble full Jordan basis")
  }
  let j = if jordan_blocks.length() == 1 {
    jordan_blocks[0]
  } else {
    block_diag(jordan_blocks)
  }
  if !calc_transform {
    return (eye(self.rows), j)
  }
  let p = matrix_from_columns(columns)
  (p, j)
}
