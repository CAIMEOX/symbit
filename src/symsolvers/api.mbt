///|
/// Public front-door types and helpers for solver APIs.
///
/// Current Limits:
/// - this file documents the high-level entry points, not every algorithmic
///   branch used underneath them.
/// - ODE/PDE and deep `solveset` behavior still depends on package areas that
///   are not fully feature-complete yet.

///|
/// Common error variants raised by the public solver front-ends.
///
/// - Does: Groups the main user-visible solver failure categories.
/// - Input: Raised by public solver APIs when validation or solving fails.
/// - Returns: A `SolverError` variant carrying a message string.
/// - Limits: This is a high-level boundary error model; low-level algorithm
///   details are intentionally collapsed into a smaller set of variants.
pub(all) suberror SolverError {
  ValueError(String)
  NotImplementedError(String)
  NonlinearError(String)
  ShapeError(String)
  InfeasibleLPError(String)
  UnboundedLPError(String)
} derive(Debug, Eq)

///|
pub impl Show for SolverError with fn output(self, logger : &Logger) -> Unit {
  match self {
    ValueError(msg) => logger.write_string("ValueError(\{msg})")
    NotImplementedError(msg) =>
      logger.write_string("NotImplementedError(\{msg})")
    NonlinearError(msg) => logger.write_string("NonlinearError(\{msg})")
    ShapeError(msg) => logger.write_string("ShapeError(\{msg})")
    InfeasibleLPError(msg) => logger.write_string("InfeasibleLPError(\{msg})")
    UnboundedLPError(msg) => logger.write_string("UnboundedLPError(\{msg})")
  }
}

///|
/// Tagged input accepted by `linsolve`.
///
/// - Does: Distinguishes symbolic-equation input from augmented-matrix input.
/// - Input: `Equations(Array[Expr])` or `AugmentedMatrix(Matrix)`.
/// - Returns: A `LinsolveInput` wrapper for the public front door.
/// - Limits: `AugmentedMatrix` must still satisfy the shape constraints checked
///   by `linsolve`.
pub enum LinsolveInput {
  Equations(Array[Expr])
  AugmentedMatrix(Matrix)
}

///|
/// Wrap an array of equations for `linsolve`.
///
/// - Does: Marks a symbolic linear system as equation-based input.
/// - Input: `Array[Expr]`.
/// - Returns: `LinsolveInput::Equations`.
/// - Limits: This helper performs no linearity or symbol validation by itself.
pub fn linsolve_equations_input(equations : Array[Expr]) -> LinsolveInput {
  Equations(equations)
}

///|
/// Wrap an augmented matrix for `linsolve`.
///
/// - Does: Marks a matrix as augmented linear-system input.
/// - Input: A `Matrix` interpreted later as `[A | b]`.
/// - Returns: `LinsolveInput::AugmentedMatrix`.
/// - Limits: The matrix must have one more column than the number of solved
///   symbols when it reaches `linsolve`.
pub fn linsolve_augmented_matrix_input(matrix : Matrix) -> LinsolveInput {
  AugmentedMatrix(matrix)
}

///|
fn symbol_name(symbol : Expr) -> String raise SolverError {
  match symbol {
    Symbol(name) => name
    _ => raise ValueError("expected Symbol in solver API")
  }
}

///|
fn symbol_names(symbols : Array[Expr]) -> Array[String] raise SolverError {
  let out : Array[String] = []
  for symbol in symbols {
    let name = symbol_name(symbol)
    if out.contains(name) {
      raise ValueError("duplicate symbol " + name)
    }
    out.push(name)
  }
  out
}

///|
fn wrap_poly_error(prefix : String, err : @sympolys.PolyError) -> SolverError {
  ValueError(prefix + ": " + Show::to_string(err))
}

///|
fn wrap_linear_eq_poly_error(err : @sympolys.PolyError) -> SolverError {
  match err {
    NonPolynomial =>
      NonlinearError("linear_eq_to_matrix: " + Show::to_string(err))
    _ => wrap_poly_error("linear_eq_to_matrix", err)
  }
}

///|
fn wrap_matrix_error(
  prefix : String,
  err : @symmatrices.MatrixError,
) -> SolverError {
  ValueError(prefix + ": " + Show::to_string(err))
}

///|
fn coeff_term(coeff : Expr, symbol : Expr) -> Expr {
  if @symcore.is_zero(coeff) {
    @symcore.int(0)
  } else {
    @symcore.mul([coeff, symbol])
  }
}

///|
fn add_terms(terms : Array[Expr]) -> Expr {
  let kept : Array[Expr] = []
  for term in terms {
    if !@symcore.is_zero(term) {
      kept.push(term)
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

///|
fn equations_from_augmented_matrix(
  system : Matrix,
  symbols : Array[Expr],
) -> Array[Expr] raise SolverError {
  if system.cols != symbols.length() + 1 {
    raise ShapeError(
      "augmented matrix must have one more column than the number of symbols",
    )
  }
  let rows = system.to_list()
  let eqs : Array[Expr] = []
  for row in rows {
    let terms : Array[Expr] = []
    for i in 0..<symbols.length() {
      terms.push(coeff_term(row[i], symbols[i]))
    }
    terms.push(@symcore.mul([@symcore.int(-1), row[symbols.length()]]))
    eqs.push(add_terms(terms))
  }
  eqs
}

///|
fn tuple_solution_set(
  solution : Map[String, Expr]?,
  symbols : Array[Expr],
  names : Array[String],
) -> Set {
  match solution {
    None => @symsets.empty_set()
    Some(values) => {
      let items : Array[Expr] = []
      for i in 0..<names.length() {
        let fallback = symbols[i]
        items.push(values.get(names[i]).unwrap_or(fallback))
      }
      @symsets.finite_set([Tuple(items)])
    }
  }
}

///|
fn expr_zeroish(expr : Expr) -> Bool {
  if @symcore.is_zero(expr) {
    return true
  }
  match check_zero_expr(expr) {
    Some(true) => return true
    Some(false) => ()
    None => ()
  }
  let simplified = @symsimplify.simplify(expr)
  @symcore.is_zero(simplified) ||
  @symcore.compare_expr(simplified, @symcore.int(0)) == 0 ||
  check_zero_expr(simplified) == Some(true)
}

///|
fn expr_canonicalish(expr : Expr) -> Expr {
  let normalized = @sympolys.domain_normal_expr(EX, expr) catch { _ => expr }
  @symsimplify.simplify(normalized)
}

///|
fn symbolic_linsolve_from_matrices(
  lhs : Matrix,
  rhs : Matrix,
  symbols : Array[Expr],
  names : Array[String],
) -> Map[String, Expr]? raise SolverError {
  if lhs.rows == 0 && lhs.cols == 0 && rhs.rows == 0 {
    return None
  }
  if lhs.cols != symbols.length() || names.length() != symbols.length() {
    raise ShapeError(
      "linsolve matrix dimensions must match the number of symbols",
    )
  }
  if rhs.cols != 1 || lhs.rows != rhs.rows {
    raise ShapeError(
      "linsolve fallback expects rhs as a single matching column",
    )
  }
  let augmented = lhs.row_join(rhs) catch {
    err => raise wrap_matrix_error("linsolve", err)
  }
  let (reduced, pivots) = augmented.rref()
  for i in 0..<lhs.rows {
    let mut all_zero = true
    for j in 0..<lhs.cols {
      let value = reduced.getitem(i, j) catch {
        err => raise wrap_matrix_error("linsolve", err)
      }
      if !expr_zeroish(value) {
        all_zero = false
        break
      }
    }
    if all_zero {
      let rhs_value = reduced.getitem(i, lhs.cols) catch {
        err => raise wrap_matrix_error("linsolve", err)
      }
      if !expr_zeroish(rhs_value) {
        return None
      }
    }
  }

  let pivot_set : Map[Int, Bool] = Map([])
  for pivot in pivots {
    if pivot < lhs.cols {
      pivot_set[pivot] = true
    }
  }
  let free_cols : Array[Int] = []
  for j in 0..<lhs.cols {
    if !pivot_set.contains(j) {
      free_cols.push(j)
    }
  }

  let solution : Map[String, Expr] = Map([])
  for free_col in free_cols {
    solution[names[free_col]] = symbols[free_col]
  }
  for i in 0..<pivots.length() {
    let pivot_col = pivots[i]
    if pivot_col >= lhs.cols {
      continue
    }
    let terms : Array[Expr] = []
    let rhs_value = reduced.getitem(i, lhs.cols) catch {
      err => raise wrap_matrix_error("linsolve", err)
    }
    if !expr_zeroish(rhs_value) {
      terms.push(rhs_value)
    }
    for free_col in free_cols {
      let coeff = reduced.getitem(i, free_col) catch {
        err => raise wrap_matrix_error("linsolve", err)
      }
      if !expr_zeroish(coeff) {
        terms.push(@symcore.mul([@symcore.int(-1), coeff, symbols[free_col]]))
      }
    }
    let value = if terms.is_empty() {
      @symcore.int(0)
    } else if terms.length() == 1 {
      terms[0]
    } else {
      @symsimplify.simplify(@symcore.add(terms))
    }
    solution[names[pivot_col]] = expr_canonicalish(value)
  }
  for i in 0..<names.length() {
    if solution.get(names[i]) is None {
      solution[names[i]] = @symcore.int(0)
    }
  }
  Some(solution)
}

///|
fn split_augmented_matrix(
  system : Matrix,
  symbols : Array[Expr],
) -> (Matrix, Matrix) raise SolverError {
  if system.cols != symbols.length() + 1 {
    raise ShapeError(
      "augmented matrix must have one more column than the number of symbols",
    )
  }
  let lhs_rows : Array[Array[Expr]] = []
  let rhs_rows : Array[Array[Expr]] = []
  for row in system.to_list() {
    let lhs_row : Array[Expr] = []
    for i in 0..<symbols.length() {
      lhs_row.push(row[i])
    }
    lhs_rows.push(lhs_row)
    rhs_rows.push([row[symbols.length()]])
  }
  let lhs = @symmatrices.matrix(lhs_rows) catch {
    err => raise wrap_matrix_error("failed to build coefficient matrix", err)
  }
  let rhs = @symmatrices.matrix(rhs_rows) catch {
    err => raise wrap_matrix_error("failed to build rhs matrix", err)
  }
  (lhs, rhs)
}

///|
fn exact_compare(lhs : Expr, rhs : Expr) -> Int? {
  match
    (@symcore.exact_number_num_den(lhs), @symcore.exact_number_num_den(rhs)) {
    (Some((ln, ld)), Some((rn, rd))) => Some((ln * rd).compare(rn * ld))
    _ => None
  }
}

///|
fn check_zero_expr(expr : Expr) -> Bool? {
  if @symcore.is_zero(expr) {
    return Some(true)
  }
  match @symcore.bool_value(expr) {
    Some(value) => return Some(value)
    None => ()
  }
  match @symcore.relational_parts(expr) {
    Some((op, lhs, rhs)) =>
      return match exact_compare(lhs, rhs) {
        Some(cmp) =>
          Some(
            match op {
              Eq => cmp == 0
              Ne => cmp != 0
              Lt => cmp < 0
              Le => cmp <= 0
              Gt => cmp > 0
              Ge => cmp >= 0
            },
          )
        None => None
      }
    None => ()
  }
  let evaled = @symcore.evalf(expr, prec=80)
  if @symcore.is_zero(evaled) {
    return Some(true)
  }
  @symcore.bool_value(evaled)
}

///|
/// Convert a symbolic linear system into matrix form.
///
/// - Does: Rewrites equations into the pair `(A, b)` for `A * x = b`.
/// - Input: `Array[Expr]` equations and the solved `Array[Expr]` symbols.
/// - Returns: `(Matrix, Matrix)` where the right-hand side is a single-column
///   matrix.
/// - Limits: Nonlinear terms raise `SolverError::NonlinearError`; malformed
///   inputs such as an empty symbol list or Boolean equations raise
///   `SolverError::ValueError`.
pub fn linear_eq_to_matrix(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> (Matrix, Matrix) raise SolverError {
  if symbols.is_empty() {
    raise ValueError("linear_eq_to_matrix expects at least one symbol")
  }
  if equations.any(expr => expr is Boolean(_)) {
    raise ValueError("linear_eq_to_matrix expects equations, not Boolean")
  }
  let names = symbol_names(symbols)
  let (coeffs, const_terms) = @sympolys._linear_eq_to_dict(equations, names) catch {
    err => raise wrap_linear_eq_poly_error(err)
  }
  let lhs_rows : Array[Array[Expr]] = []
  let rhs_rows : Array[Array[Expr]] = []
  for i in 0..<coeffs.length() {
    let row : Array[Expr] = []
    for name in names {
      row.push(coeffs[i].get(name).unwrap_or(@symcore.int(0)))
    }
    lhs_rows.push(row)
    rhs_rows.push([@symcore.mul([@symcore.int(-1), const_terms[i]])])
  }
  let lhs = @symmatrices.matrix(lhs_rows) catch {
    err => raise wrap_matrix_error("failed to build coefficient matrix", err)
  }
  let rhs = @symmatrices.matrix(rhs_rows) catch {
    err => raise wrap_matrix_error("failed to build rhs matrix", err)
  }
  (lhs, rhs)
}

///|
/// Solve a linear system and return set-shaped solutions.
///
/// - Does: Solves a linear system presented as equations or an augmented matrix.
/// - Input: A `LinsolveInput` and the solved symbol list.
/// - Returns: A `Set`, typically `FiniteSet((...))` for solved tuples or
///   `EmptySet` for inconsistency.
/// - Limits: Free variables are left symbolic in the returned tuple; this front
///   door is for linear systems only.
pub fn linsolve(
  system : LinsolveInput,
  symbols : Array[Expr],
) -> Set raise SolverError {
  let names = symbol_names(symbols)
  let equations = match system {
    Equations(items) => items
    AugmentedMatrix(matrix) => equations_from_augmented_matrix(matrix, symbols)
  }
  let solution = @sympolys._linsolve(equations, names) catch {
    DomainMismatch => {
      let (lhs, rhs) = match system {
        Equations(_) => linear_eq_to_matrix(equations, symbols)
        AugmentedMatrix(matrix) => split_augmented_matrix(matrix, symbols)
      }
      symbolic_linsolve_from_matrices(lhs, rhs, symbols, names)
    }
    err => raise wrap_poly_error("linsolve", err)
  }
  tuple_solution_set(solution, symbols, names)
}

///|
/// Solve an augmented matrix by linear elimination.
///
/// - Does: Solves `[A | b]` into a symbol-to-expression map.
/// - Input: An augmented `Matrix` and the solved symbol list.
/// - Returns: `None` for inconsistency and `Some(Map[String, Expr])` otherwise.
/// - Limits: This front door assumes linear input and reports shape or domain
///   issues through `SolverError`.
pub fn solve_linear_system(
  system : Matrix,
  symbols : Array[Expr],
) -> Map[String, Expr]? raise SolverError {
  let names = symbol_names(symbols)
  let equations = equations_from_augmented_matrix(system, symbols)
  @sympolys._linsolve(equations, names) catch {
    DomainMismatch => {
      let (lhs, rhs) = split_augmented_matrix(system, symbols)
      symbolic_linsolve_from_matrices(lhs, rhs, symbols, names)
    }
    err => raise wrap_poly_error("solve_linear_system", err)
  }
}

///|
/// Solve a square augmented matrix through LU decomposition.
///
/// - Does: Uses the matrix backend LU solver for a direct linear solve.
/// - Input: An augmented `Matrix` and the solved symbol list.
/// - Returns: `Some(Map[String, Expr])` on success.
/// - Limits: Requires a square coefficient matrix and raises
///   `SolverError::ShapeError` otherwise.
pub fn solve_linear_system_LU(
  system : Matrix,
  symbols : Array[Expr],
) -> Map[String, Expr]? raise SolverError {
  let names = symbol_names(symbols)
  let (lhs, rhs) = split_augmented_matrix(system, symbols)
  if lhs.rows != lhs.cols {
    raise ShapeError(
      "solve_linear_system_LU requires a square coefficient matrix",
    )
  }
  let solved = lhs.solve(rhs) catch {
    err => raise wrap_matrix_error("solve_linear_system_LU", err)
  }
  let out : Map[String, Expr] = Map([])
  for i in 0..<names.length() {
    out[names[i]] = solved.getitem(i, 0) catch {
      err => raise wrap_matrix_error("solve_linear_system_LU", err)
    }
  }
  Some(out)
}

///|
/// Compute a determinant through the matrix backend.
///
/// - Does: Delegates determinant computation to `symmatrices`.
/// - Input: A `Matrix` and an optional `algorithm` string.
/// - Returns: An `Expr` determinant.
/// - Limits: `algorithm` is accepted for front-door compatibility and is
///   currently ignored.
pub fn det_quick(
  matrix : Matrix,
  algorithm? : String? = None,
) -> Expr raise SolverError {
  ignore(algorithm)
  matrix.det() catch {
    err => raise wrap_matrix_error("det_quick", err)
  }
}

///|
/// Compute the inverse of a matrix through the matrix backend.
///
/// - Does: Delegates matrix inversion to `symmatrices`.
/// - Input: A `Matrix`.
/// - Returns: A `Matrix`.
/// - Limits: Singular or malformed matrices surface as `SolverError`.
pub fn inv_quick(matrix : Matrix) -> Matrix raise SolverError {
  matrix.inv() catch {
    err => raise wrap_matrix_error("inv_quick", err)
  }
}

///|
/// Check whether a substitution makes an expression vanish.
///
/// - Does: Substitutes `sol` for `symbol` and tests whether the residual is
///   zero.
/// - Input: The target expression, the solved symbol, and the proposed value.
/// - Returns: `Some(true)`, `Some(false)`, or `None` when exact decisiveness is
///   not available.
/// - Limits: This front door only checks one symbol replacement at a time.
pub fn checksol(f : Expr, symbol : Expr, sol : Expr) -> Bool? raise SolverError {
  let name = symbol_name(symbol)
  let env : Map[String, Expr] = Map([])
  env[name] = sol
  check_zero_expr(@symcore.subst(f, env))
}
