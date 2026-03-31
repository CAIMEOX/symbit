///|
pub enum RsolveInit {
  List(Array[Expr])
  Dict(Map[String, Expr])
}

///|
pub fn rsolve_init_list(values : Array[Expr]) -> RsolveInit {
  RsolveInit::List(values)
}

///|
pub fn rsolve_init_dict(values : Map[String, Expr]) -> RsolveInit {
  RsolveInit::Dict(values)
}

///|
fn solver_shift_expr(symbol : Expr, step : Int) -> Expr {
  if step == 0 {
    symbol
  } else {
    canonical_expr(@symcore.add([symbol, @symcore.int(step)]))
  }
}

///|
fn solver_recurrence_constant(shift : Int) -> Expr {
  Expr::Symbol("C\{shift}")
}

///|
fn solver_recurrence_degree(expr : Expr, n : Expr) -> Int? {
  let name = symbol_name(n) catch { _ => return None }
  let poly = @sympolys.Poly::from_expr_defaults(expr, gens=[name]) catch {
    _ => return None
  }
  if poly.is_zero() {
    Some(0)
  } else {
    Some(poly.degree(0))
  }
}

///|
fn solver_subst_single(expr : Expr, name : String, value : Expr) -> Expr {
  let env : Map[String, Expr] = {}
  env[name] = value
  canonical_expr(@symcore.subst(expr, env))
}

///|
fn solver_recurrence_constant_solution(
  coeffs : Array[Expr],
  f : Expr,
  n : Expr,
  shift : Int,
) -> Expr? {
  guard coeffs.length() == 2 else { return None }
  guard expr_is_zeroish(f) == Some(true) else { return None }
  let ratio = canonical_expr(
    @symcore.mul([@symcore.int(-1), coeffs[0], coeffs[1] ^ @symcore.int(-1)]),
  )
  Some(canonical_expr(@symcore.mul([solver_recurrence_constant(shift), ratio ^ n])))
}

///|
pub fn rsolve_poly(
  coeffs : Array[Expr],
  f : Expr,
  n : Expr,
  shift? : Int = 0,
) -> Expr? raise SolverError {
  guard coeffs.length() == 2 else { return None }
  let name = symbol_name(n)
  let c0 = canonical_expr(coeffs[0])
  let c1 = canonical_expr(coeffs[1])
  if @symcore.compare_expr(c0, @symcore.int(-1)) != 0 ||
    @symcore.compare_expr(c1, @symcore.int(1)) != 0 {
    return solver_recurrence_constant_solution(coeffs, f, n, shift)
  }
  let degree = match solver_recurrence_degree(f, n) {
    Some(value) => value
    None => return None
  }
  let coeff_symbols : Array[Expr] = []
  let mut particular = @symcore.int(0)
  for i in 1..=(degree + 1) {
    let coeff = Expr::Symbol("A\{i}")
    coeff_symbols.push(coeff)
    particular = canonical_expr(
      @symcore.add([
        particular,
        @symcore.mul([coeff, n ^ @symcore.int(i)]),
      ]),
    )
  }
  let equations : Array[Expr] = []
  for sample in 0..=degree {
    let current = solver_subst_single(particular, name, @symcore.int(sample))
    let shifted = solver_subst_single(particular, name, @symcore.int(sample + 1))
    let rhs = solver_subst_single(f, name, @symcore.int(sample))
    equations.push(
      canonical_expr(
        @symcore.add([
          shifted,
          @symcore.mul([@symcore.int(-1), current]),
          @symcore.mul([@symcore.int(-1), rhs]),
        ]),
      ),
    )
  }
  let (lhs, rhs) = linear_eq_to_matrix(equations, coeff_symbols)
  let augmented = lhs.row_join(rhs) catch {
    err => raise wrap_matrix_error("rsolve_poly", err)
  }
  let values = match solve_linear_system(augmented, coeff_symbols) {
    Some(map) => map
    None => return None
  }
  let particular_solution = @symsimplify.numer_expand(
    canonical_expr(@symcore.subst(particular, values)),
  )
  Some(
    @symsimplify.numer_expand(
      canonical_expr(@symcore.add([solver_recurrence_constant(shift), particular_solution])),
    ),
  )
}

///|
pub fn rsolve_ratio(
  coeffs : Array[Expr],
  f : Expr,
  n : Expr,
) -> Expr? raise SolverError {
  match rsolve_poly(coeffs, f, n) {
    Some(value) => Some(value)
    None => solver_recurrence_constant_solution(coeffs, f, n, 0)
  }
}

///|
pub fn rsolve_hyper(
  coeffs : Array[Expr],
  f : Expr,
  n : Expr,
) -> Expr? raise SolverError {
  match rsolve_ratio(coeffs, f, n) {
    Some(value) => Some(value)
    None => None
  }
}

///|
fn solver_recurrence_coeffs_from_expr(
  expr : Expr,
  y : Expr,
) -> (Array[Expr], Expr, Expr)? {
  let (name, args) = match @symcore.undefined_application_parts(y) {
    Some(parts) => parts
    None => return None
  }
  guard args.length() == 1 else { return None }
  let n = args[0]
  let yn = @symcore.applied_undefined_function(name, [n])
  let yn1 = @symcore.applied_undefined_function(name, [solver_shift_expr(n, 1)])
  match solver_extract_linear_targets(expr, [yn, yn1]) {
    Some((coeffs, constant)) => Some((coeffs, canonical_expr(@symcore.mul([@symcore.int(-1), constant])), n))
    None => None
  }
}

///|
fn solver_initial_value(
  init : RsolveInit,
  y : Expr,
) -> (Expr, Expr)? {
  match init {
    RsolveInit::List(values) =>
      if values.is_empty() {
        None
      } else {
        Some((@symcore.int(0), values[0]))
      }
    RsolveInit::Dict(values) => {
      let y0 = @symprint.to_string(y)
      match values.get("0") {
        Some(v) => Some((@symcore.int(0), v))
        None =>
          match values.get(y0) {
            Some(v) => Some((@symcore.int(0), v))
            None => None
          }
      }
    }
  }
}

///|
fn solver_apply_recurrence_init(
  solution : Expr,
  n : Expr,
  init : RsolveInit,
  y : Expr,
) -> Expr {
  let (at, value) = match solver_initial_value(init, y) {
    Some(data) => data
    None => return solution
  }
  let nname = match n {
    Expr::Symbol(name) => name
    _ => return solution
  }
  let base = solver_subst_single(solution, nname, at)
  let zero_env : Map[String, Expr] = {}
  zero_env["C0"] = @symcore.int(0)
  let constant_part = canonical_expr(
    @symcore.subst(base, zero_env),
  )
  let one_env : Map[String, Expr] = {}
  one_env["C0"] = @symcore.int(1)
  let coeff_part = canonical_expr(
    @symcore.add([
      @symcore.subst(base, one_env),
      @symcore.mul([@symcore.int(-1), constant_part]),
    ]),
  )
  if expr_is_zeroish(coeff_part) == Some(true) {
    return solution
  }
  let c0_value = canonical_expr(
    @symcore.mul([
      canonical_expr(@symcore.add([value, @symcore.mul([@symcore.int(-1), constant_part])])),
      coeff_part ^ @symcore.int(-1),
    ]),
  )
  let solution_env : Map[String, Expr] = {}
  solution_env["C0"] = c0_value
  @symsimplify.numer_expand(canonical_expr(@symcore.subst(solution, solution_env)))
}

///|
pub fn rsolve(
  f : Expr,
  y : Expr,
  init? : RsolveInit? = None,
) -> Expr? raise SolverError {
  let (coeffs, rhs, n) = match solver_recurrence_coeffs_from_expr(solver_normalize_equation(f), y) {
    Some(value) => value
    None => return None
  }
  let solution = match rsolve_hyper(coeffs, rhs, n) {
    Some(value) => value
    None => return None
  }
  match init {
    Some(data) => Some(solver_apply_recurrence_init(solution, n, data, y))
    None => Some(solution)
  }
}
