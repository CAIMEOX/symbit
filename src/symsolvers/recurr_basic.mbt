///|
/// Initial-condition container accepted by [`rsolve`](#rsolve).
///
/// `List` uses the conventional `n = 0, 1, ...` ordering while `Dict` lets you
/// pass named values such as `"0"` or the printed recurrence target.
pub enum RsolveInit {
  List(Array[Expr])
  Dict(Map[String, Expr])
}

///|
/// Build list-based initial data for [`rsolve`](#rsolve).
pub fn rsolve_init_list(values : Array[Expr]) -> RsolveInit {
  RsolveInit::List(values)
}

///|
/// Build dictionary-based initial data for [`rsolve`](#rsolve).
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
fn solver_recurrence_raw_add(args : Array[Expr]) -> Expr {
  let flat : Array[Expr] = []
  for arg in args {
    match arg {
      Expr::Add(inner) =>
        for item in inner {
          if expr_is_zeroish(item) != Some(true) {
            flat.push(item)
          }
        }
      _ => if expr_is_zeroish(arg) != Some(true) { flat.push(arg) }
    }
  }
  if flat.is_empty() {
    return @symcore.int(0)
  }
  if flat.length() == 1 {
    flat[0]
  } else {
    @symcore.raw_add(flat)
  }
}

///|
fn solver_recurrence_depends_on(expr : Expr, n : Expr) -> Bool {
  @symcore.free_symbols(expr).any(sym => @symcore.compare_expr(sym, n) == 0)
}

///|
fn solver_recurrence_compare_terms(lhs : Expr, rhs : Expr, n : Expr) -> Int {
  let lhs_dep = solver_recurrence_depends_on(lhs, n)
  let rhs_dep = solver_recurrence_depends_on(rhs, n)
  if lhs_dep != rhs_dep {
    if lhs_dep {
      -1
    } else {
      1
    }
  } else if lhs_dep {
    let lhs_deg = solver_recurrence_degree(lhs, n)
    let rhs_deg = solver_recurrence_degree(rhs, n)
    match (lhs_deg, rhs_deg) {
      (Some(ld), Some(rd)) if ld != rd => ld - rd
      _ => @symcore.compare_expr(lhs, rhs)
    }
  } else {
    @symcore.compare_expr(lhs, rhs)
  }
}

///|
fn solver_recurrence_order_solution(expr : Expr, n : Expr) -> Expr {
  match expr {
    Expr::Add(args) => {
      let ordered = args.copy()
      ordered.sort_by((lhs, rhs) => solver_recurrence_compare_terms(lhs, rhs, n))
      @symcore.raw_add(ordered)
    }
    _ => expr
  }
}

///|
fn solver_recurrence_rationalize_term(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) =>
      solver_recurrence_raw_add(args.map(solver_recurrence_rationalize_term))
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = []
      for arg in args {
        let normalized = solver_recurrence_rationalize_term(arg)
        match @symcore.exact_numeric_expr_num_den(normalized) {
          Some((num, den)) => {
            let value : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
              num, den,
            )
            match value {
              Ok(rat) => coeff = coeff.mul_r(rat)
              Err(_) => rest.push(normalized)
            }
          }
          None => rest.push(normalized)
        }
      }
      if coeff.is_zero() {
        @symcore.int(0)
      } else {
        let factors : Array[Expr] = []
        if !coeff.is_one() || rest.is_empty() {
          factors.push(Expr::Number(coeff))
        }
        for factor in rest {
          factors.push(factor)
        }
        canonical_expr(@symcore.mul(factors))
      }
    }
    _ => expr
  }
}

///|
fn solver_recurrence_normalize_output(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) =>
      solver_recurrence_raw_add(args.map(solver_recurrence_normalize_output))
    Expr::Mul(args) => {
      let normalized_args = args.map(solver_recurrence_normalize_output)
      for i in 0..<normalized_args.length() {
        match normalized_args[i] {
          Expr::Add(inner) => {
            let distributed : Array[Expr] = []
            for term in inner {
              let factors : Array[Expr] = []
              for j in 0..<normalized_args.length() {
                factors.push(if i == j { term } else { normalized_args[j] })
              }
              distributed.push(
                solver_recurrence_normalize_output(
                  canonical_expr(@symcore.mul(factors)),
                ),
              )
            }
            return solver_recurrence_raw_add(distributed)
          }
          _ => ()
        }
      }
      solver_recurrence_rationalize_term(
        canonical_expr(@symcore.mul(normalized_args)),
      )
    }
    _ => solver_recurrence_rationalize_term(expr)
  }
}

///|
fn solver_recurrence_expand_basis_term(coeff : Expr, basis : Expr) -> Expr {
  let coeff = canonical_expr(coeff)
  match coeff {
    Expr::Add(args) =>
      solver_recurrence_raw_add(
        args.map(arg => {
          solver_recurrence_normalize_output(
            @symsimplify.fraction_expand(
              canonical_expr(@symcore.mul([arg, basis])),
            ),
          )
        }),
      )
    _ =>
      solver_recurrence_normalize_output(
        @symsimplify.fraction_expand(
          canonical_expr(@symcore.mul([coeff, basis])),
        ),
      )
  }
}

///|
fn solver_recurrence_particular_solution(
  values : Map[String, Expr],
  n : Expr,
  degree : Int,
) -> Expr {
  let terms : Array[Expr] = []
  for i in 1..<=(degree + 1) {
    let value = values.get("A\{i}").unwrap_or(@symcore.int(0))
    if expr_is_zeroish(value) != Some(true) {
      terms.push(
        solver_recurrence_expand_basis_term(value, n ^ @symcore.int(i)),
      )
    }
  }
  solver_recurrence_raw_add(terms)
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
  Some(
    canonical_expr(@symcore.mul([solver_recurrence_constant(shift), ratio ^ n])),
  )
}

///|
/// Solve a first-order polynomial-difference recurrence when a polynomial
/// particular solution is available.
///
/// The function returns `None` when the current heuristic cannot build the
/// solution family.
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
  for i in 1..<=(degree + 1) {
    let coeff = Expr::Symbol("A\{i}")
    coeff_symbols.push(coeff)
    particular = canonical_expr(
      @symcore.add([particular, @symcore.mul([coeff, n ^ @symcore.int(i)])]),
    )
  }
  let equations : Array[Expr] = []
  for sample in 0..<=degree {
    let current = solver_subst_single(particular, name, @symcore.int(sample))
    let shifted = solver_subst_single(
      particular,
      name,
      @symcore.int(sample + 1),
    )
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
  let particular_solution = solver_recurrence_particular_solution(
    values, n, degree,
  )
  Some(
    solver_recurrence_order_solution(
      solver_recurrence_normalize_output(
        solver_recurrence_raw_add([
          particular_solution,
          solver_recurrence_constant(shift),
        ]),
      ),
      n,
    ),
  )
}

///|
/// Solve a recurrence through the rational-solution heuristic layer.
///
/// This currently delegates to [`rsolve_poly`](#rsolve_poly) first and falls
/// back to constant-ratio solutions for simple first-order recurrences.
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
/// Solve a recurrence through the hypergeometric-solution heuristic layer.
///
/// The current implementation is a thin wrapper over the rational solver.
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
    Some((coeffs, constant)) =>
      Some(
        (coeffs, canonical_expr(@symcore.mul([@symcore.int(-1), constant])), n),
      )
    None => None
  }
}

///|
fn solver_initial_value(init : RsolveInit, y : Expr) -> (Expr, Expr)? {
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
  let constant_part = canonical_expr(@symcore.subst(base, zero_env))
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
      canonical_expr(
        @symcore.add([value, @symcore.mul([@symcore.int(-1), constant_part])]),
      ),
      coeff_part ^ @symcore.int(-1),
    ]),
  )
  let solution_env : Map[String, Expr] = {}
  solution_env["C0"] = c0_value
  solver_recurrence_order_solution(
    solver_recurrence_normalize_output(
      @symsimplify.fraction_expand(
        canonical_expr(@symcore.subst(solution, solution_env)),
      ),
    ),
    n,
  )
}

///|
/// Solve a supported linear recurrence for an undefined sequence.
///
/// `f` is the recurrence equation, `y` is the applied undefined sequence such
/// as `y(n)`, and `init` optionally pins the free constant using one initial
/// value.
pub fn rsolve(
  f : Expr,
  y : Expr,
  init? : RsolveInit? = None,
) -> Expr? raise SolverError {
  let (coeffs, rhs, n) = match
    solver_recurrence_coeffs_from_expr(solver_normalize_equation(f), y) {
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
