///|
/// Common error variants raised by the public solver front-ends.
///
/// These errors mirror the high-level categories users need to handle at the
/// API boundary: malformed input, unsupported algorithms, nonlinear systems in
/// linear-only entrypoints, shape mismatches, and LP feasibility failures.
pub(all) suberror SolverError {
  ValueError(String)
  NotImplementedError(String)
  NonlinearError(String)
  ShapeError(String)
  InfeasibleLPError(String)
  UnboundedLPError(String)
} derive(Show, Eq)

///|
/// Tagged input accepted by [`linsolve`](#linsolve).
///
/// Use `Equations` when you already have symbolic linear equations, or
/// `AugmentedMatrix` when the system is stored in matrix form.
pub enum LinsolveInput {
  Equations(Array[Expr])
  AugmentedMatrix(Matrix)
}

///|
/// Wrap an array of equations for [`linsolve`](#linsolve).
pub fn linsolve_equations_input(equations : Array[Expr]) -> LinsolveInput {
  LinsolveInput::Equations(equations)
}

///|
/// Wrap an augmented matrix for [`linsolve`](#linsolve).
///
/// The matrix must have one more column than the number of solved symbols.
pub fn linsolve_augmented_matrix_input(matrix : Matrix) -> LinsolveInput {
  LinsolveInput::AugmentedMatrix(matrix)
}

///|
fn symbol_name(symbol : Expr) -> String raise SolverError {
  match symbol {
    Expr::Symbol(name) => name
    _ => raise SolverError::ValueError("expected Symbol in solver API")
  }
}

///|
fn symbol_names(symbols : Array[Expr]) -> Array[String] raise SolverError {
  let out : Array[String] = []
  for symbol in symbols {
    let name = symbol_name(symbol)
    if out.contains(name) {
      raise SolverError::ValueError("duplicate symbol " + name)
    }
    out.push(name)
  }
  out
}

///|
fn wrap_poly_error(prefix : String, err : @sympolys.PolyError) -> SolverError {
  SolverError::ValueError(prefix + ": " + err.to_string())
}

///|
fn wrap_linear_eq_poly_error(err : @sympolys.PolyError) -> SolverError {
  match err {
    @sympolys.PolyError::NonPolynomial =>
      SolverError::NonlinearError("linear_eq_to_matrix: " + err.to_string())
    _ => wrap_poly_error("linear_eq_to_matrix", err)
  }
}

///|
fn wrap_matrix_error(
  prefix : String,
  err : @symmatrices.MatrixError,
) -> SolverError {
  SolverError::ValueError(prefix + ": " + err.to_string())
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
    raise SolverError::ShapeError(
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
      @symsets.finite_set([Expr::Tuple(items)])
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
  let normalized = @sympolys.domain_normal_expr(@sympolys.Domain::EX, expr) catch {
    _ => expr
  }
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
    raise SolverError::ShapeError(
      "linsolve matrix dimensions must match the number of symbols",
    )
  }
  if rhs.cols != 1 || lhs.rows != rhs.rows {
    raise SolverError::ShapeError(
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

  let pivot_set : Map[Int, Bool] = {}
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

  let solution : Map[String, Expr] = {}
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
    raise SolverError::ShapeError(
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
              @symcore.RelOp::Eq => cmp == 0
              @symcore.RelOp::Ne => cmp != 0
              @symcore.RelOp::Lt => cmp < 0
              @symcore.RelOp::Le => cmp <= 0
              @symcore.RelOp::Gt => cmp > 0
              @symcore.RelOp::Ge => cmp >= 0
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
/// Convert a linear equation system into `(A, b)` matrix form.
///
/// The returned pair represents `A * x = b`. Nonlinear terms raise
/// `SolverError::NonlinearError`; malformed inputs such as an empty symbol list
/// or Boolean relations raise `SolverError::ValueError`.
pub fn linear_eq_to_matrix(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> (Matrix, Matrix) raise SolverError {
  if symbols.is_empty() {
    raise SolverError::ValueError(
      "linear_eq_to_matrix expects at least one symbol",
    )
  }
  if equations.any(expr => expr is Expr::Boolean(_)) {
    raise SolverError::ValueError(
      "linear_eq_to_matrix expects equations, not Boolean",
    )
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
/// Solve a linear system and return a finite set of tuple solutions.
///
/// This solves a linear system into a set of tuple solutions. A unique solution
/// is returned as `FiniteSet((...))`, free variables are left symbolic in the
/// tuple, and an inconsistent system returns `EmptySet`.
pub fn linsolve(
  system : LinsolveInput,
  symbols : Array[Expr],
) -> Set raise SolverError {
  let names = symbol_names(symbols)
  let equations = match system {
    LinsolveInput::Equations(items) => items
    LinsolveInput::AugmentedMatrix(matrix) =>
      equations_from_augmented_matrix(matrix, symbols)
  }
  let linear_try : Result[Map[String, Expr]?, @sympolys.PolyError] = try? @sympolys._linsolve(
    equations, names,
  )
  let solution = match linear_try {
    Ok(solution) => solution
    Err(@sympolys.PolyError::DomainMismatch) => {
      let (lhs, rhs) = match system {
        LinsolveInput::Equations(_) => linear_eq_to_matrix(equations, symbols)
        LinsolveInput::AugmentedMatrix(matrix) =>
          split_augmented_matrix(matrix, symbols)
      }
      symbolic_linsolve_from_matrices(lhs, rhs, symbols, names)
    }
    Err(err) => raise wrap_poly_error("linsolve", err)
  }
  tuple_solution_set(solution, symbols, names)
}

///|
/// Solve an augmented matrix by linear elimination.
///
/// The input matrix is interpreted as `[A | b]`. The result is `None` for an
/// inconsistent system and `Some(map)` otherwise, with keys taken from the
/// supplied symbols.
pub fn solve_linear_system(
  system : Matrix,
  symbols : Array[Expr],
) -> Map[String, Expr]? raise SolverError {
  let names = symbol_names(symbols)
  let equations = equations_from_augmented_matrix(system, symbols)
  let linear_try : Result[Map[String, Expr]?, @sympolys.PolyError] = try? @sympolys._linsolve(
    equations, names,
  )
  match linear_try {
    Ok(solution) => solution
    Err(@sympolys.PolyError::DomainMismatch) => {
      let (lhs, rhs) = split_augmented_matrix(system, symbols)
      symbolic_linsolve_from_matrices(lhs, rhs, symbols, names)
    }
    Err(err) => raise wrap_poly_error("solve_linear_system", err)
  }
}

///|
/// Solve a square augmented matrix via the matrix package LU-based solver.
///
/// This entrypoint requires a square coefficient matrix. It is useful when you
/// want a direct linear algebra solve rather than symbolic elimination.
pub fn solve_linear_system_LU(
  system : Matrix,
  symbols : Array[Expr],
) -> Map[String, Expr]? raise SolverError {
  let names = symbol_names(symbols)
  let (lhs, rhs) = split_augmented_matrix(system, symbols)
  if lhs.rows != lhs.cols {
    raise SolverError::ShapeError(
      "solve_linear_system_LU requires a square coefficient matrix",
    )
  }
  let solved = lhs.solve(rhs) catch {
    err => raise wrap_matrix_error("solve_linear_system_LU", err)
  }
  let out : Map[String, Expr] = {}
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
/// `algorithm` is accepted for API compatibility and is currently ignored.
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
pub fn inv_quick(matrix : Matrix) -> Matrix raise SolverError {
  matrix.inv() catch {
    err => raise wrap_matrix_error("inv_quick", err)
  }
}

///|
/// Check whether substituting `sol` for `symbol` makes `f` vanish.
///
/// The result is `Some(true)` for a verified solution, `Some(false)` for a
/// verified non-solution, and `None` when the residual cannot be decided
/// exactly.
pub fn checksol(f : Expr, symbol : Expr, sol : Expr) -> Bool? raise SolverError {
  let name = symbol_name(symbol)
  let env : Map[String, Expr] = {}
  env[name] = sol
  check_zero_expr(@symcore.subst(f, env))
}
