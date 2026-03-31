///|
pub(all) suberror SolverError {
  ValueError(String)
  ShapeError(String)
  InfeasibleLPError(String)
  UnboundedLPError(String)
} derive(Show, Eq)

///|
pub enum LinsolveInput {
  Equations(Array[Expr])
  AugmentedMatrix(Matrix)
}

///|
pub fn linsolve_equations_input(equations : Array[Expr]) -> LinsolveInput {
  LinsolveInput::Equations(equations)
}

///|
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
pub fn linear_eq_to_matrix(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> (Matrix, Matrix) raise SolverError {
  let names = symbol_names(symbols)
  let (coeffs, const_terms) = @sympolys._linear_eq_to_dict(equations, names) catch {
    err => raise wrap_poly_error("linear_eq_to_matrix", err)
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
  let solution = @sympolys._linsolve(equations, names) catch {
    err => raise wrap_poly_error("linsolve", err)
  }
  tuple_solution_set(solution, symbols, names)
}

///|
pub fn solve_linear_system(
  system : Matrix,
  symbols : Array[Expr],
) -> Map[String, Expr]? raise SolverError {
  let names = symbol_names(symbols)
  let equations = equations_from_augmented_matrix(system, symbols)
  @sympolys._linsolve(equations, names) catch {
    err => raise wrap_poly_error("solve_linear_system", err)
  }
}

///|
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
pub fn inv_quick(matrix : Matrix) -> Matrix raise SolverError {
  matrix.inv() catch {
    err => raise wrap_matrix_error("inv_quick", err)
  }
}

///|
pub fn checksol(f : Expr, symbol : Expr, sol : Expr) -> Bool? raise SolverError {
  let name = symbol_name(symbol)
  let env : Map[String, Expr] = {}
  env[name] = sol
  check_zero_expr(@symcore.subst(f, env))
}
