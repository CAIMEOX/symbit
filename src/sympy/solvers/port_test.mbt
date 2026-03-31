///|
fn x() -> @symcore.Expr {
  @symcore.Expr::Symbol("x")
}

///|
fn y() -> @symcore.Expr {
  @symcore.Expr::Symbol("y")
}

///|
fn sin(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("sin", [expr])
}

///|
fn cos(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("cos", [expr])
}

///|
fn sqrt(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("sqrt", [expr])
}

///|
fn f(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("f", [expr])
}

///|
fn g(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("g", [expr])
}

///|
fn u(xv : @symcore.Expr, yv : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("u", [xv, yv])
}

///|
fn xfun(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("X", [expr])
}

///|
fn yfun(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("Y", [expr])
}

///|
fn py_expr(expr : @symcore.Expr) -> String {
  @symprint.to_string(expr)
}

///|
fn py_matrix_expr(m : @symmatrices.Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    rows.push("[" + row.map(py_expr).join(", ") + "]")
  }
  "sympy.Matrix([" + rows.join(", ") + "])"
}

///|
fn py_sympify_expr(expr : @symcore.Expr) -> String {
  "sympy.sympify('" + py_expr(expr).replace_all(old="'", new="\\\\'") + "')"
}

///|
fn py_sympify_matrix_expr(m : @symmatrices.Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    rows.push("[" + row.map(py_sympify_expr).join(", ") + "]")
  }
  "sympy.Matrix([" + rows.join(", ") + "])"
}

///|
fn py_matrix_list_text(code : String) -> String raise {
  solvers_eval_str(
    "'[' + ', '.join('[' + ', '.join(sympy.sstr(v) for v in row) + ']' for row in (" +
    code +
    ").tolist()) + ']'",
  )
}

fn matrix_oracle_residual_text(
  local_matrix : @symmatrices.Matrix,
  oracle_code : String,
) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda x, y, z, C1, C2, C3: str(((" +
    py_sympify_matrix_expr(local_matrix) +
    ") - (" +
    oracle_code +
    ")).applyfunc(sympy.simplify)))(*sympy.symbols('x y z C1 C2 C3'))",
  )
}

///|
fn solvers_eval_str(expr : String) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda x, y, z: " + expr + ")(*sympy.symbols('x y z'))",
  )
}

///|
fn solvers_eval_str_symbols(expr : String, symbols : String) -> String raise {
  let parts = symbols.split(" ")
  let names : Array[String] = []
  for part in parts {
    let trimmed = part.trim().to_string()
    if trimmed != "" {
      names.push(trimmed)
    }
  }
  let params = names.join(", ")
  let symbol_expr = names.join(" ")
  if names.length() == 1 {
    @sympy_utilities.utilities_eval_str(
      "(lambda " + params + ": " + expr + ")(sympy.symbols('" + symbol_expr + "'))",
    )
  } else {
    @sympy_utilities.utilities_eval_str(
      "(lambda " + params + ": " + expr + ")(*sympy.symbols('" + symbol_expr + "'))",
    )
  }
}

///|
fn recurrence_expr_matches_oracle(
  expr_local : @symcore.Expr,
  oracle_expr : String,
  symbols : String,
) -> String raise {
  solvers_eval_str_symbols(
    "str(sympy.simplify((" + py_expr(expr_local) + ") - (" + oracle_expr + ")))",
    symbols,
  )
}

///|
fn local_matrix_list_text(m : @symmatrices.Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    rows.push("[" + row.map(@symprint.to_string).join(", ") + "]")
  }
  "[" + rows.join(", ") + "]"
}

///|
fn local_solution_dict_text(
  solution : Map[String, @symcore.Expr]?,
  names : Array[String],
) -> String {
  match solution {
    None => "None"
    Some(values) =>
      if values.is_empty() {
        "{}"
      } else {
        let items : Array[String] = []
        for name in names {
          match values.get(name) {
            Some(value) => items.push(name + ": " + @symprint.to_string(value))
            None => ()
          }
        }
        "{" + items.join(", ") + "}"
      }
  }
}

///|
fn local_expr_list_text(items : Array[@symcore.Expr]) -> String {
  "[" + items.map(@symprint.to_string).join(", ") + "]"
}

///|
fn local_set_list_text(items : Array[@symsets.Set]) -> String {
  "[" + items.map(@symsets.to_string).join(", ") + "]"
}

///|
fn local_inequality_result_text(result : @symsolvers.InequalityResult) -> String {
  match result {
    @symsolvers.InequalityResult::Set(set) => "Set(" + @symsets.to_string(set) + ")"
    @symsolvers.InequalityResult::Relational(expr) => "Relational(" + @symprint.to_string(expr) + ")"
  }
}

///|
fn local_expr_matrix_text(items : Array[Array[@symcore.Expr]]) -> String {
  "[" + items.map(local_expr_list_text).join(", ") + "]"
}

///|
fn local_expr_systems_text(items : Array[Array[@symcore.Expr]]) -> String {
  "[" + items.map(local_expr_list_text).join(", ") + "]"
}

///|
fn local_string_list_repr(items : Array[String]) -> String {
  "['" + items.join("', '") + "']"
}

///|
fn local_infinitesimals_text(items : Array[Map[String, @symcore.Expr]]) -> String {
  let rendered : Array[String] = []
  for item in items {
    rendered.push(
      "{'xi': " +
      @symprint.to_string(item.get("xi").unwrap_or(@symcore.int(0))) +
      ", 'eta': " +
      @symprint.to_string(item.get("eta").unwrap_or(@symcore.int(0))) +
      "}",
    )
  }
  "[" + rendered.join(", ") + "]"
}

///|
fn local_checkinfsol_text(items : Array[(Bool, @symcore.Expr)]) -> String {
  let rendered : Array[String] = []
  for item in items {
    rendered.push(
      "(" +
      item.0.to_string().to_lower() +
      ", " +
      @symprint.to_string(item.1) +
      ")",
    )
  }
  "[" + rendered.join(", ") + "]"
}

///|
fn normalize_solver_text(text : String) -> String {
  text
  .replace_all(old="/1", new="")
  .replace_all(old="-1*", new="-")
  .replace_all(old=" + -", new=" - ")
  .replace_all(old="True", new="true")
  .replace_all(old="False", new="false")
  .replace_all(old="None", new="none")
  .replace_all(old="-t_0 + 3", new="3 - t_0")
  .replace_all(old="exp(1*x**3/3)", new="exp(x**3/3)")
  .replace_all(old="-g(x) + 20*f(x)", new="20*f(x) - g(x)")
}

///|
fn normalize_braced_items_text(text : String) -> String {
  let trimmed = normalize_solver_text(text).trim().to_string()
  if !trimmed.has_prefix("{") || !trimmed.has_suffix("}") {
    return trimmed
  }
  let inner = trimmed[1:trimmed.length() - 1]
  if inner == "" {
    return "{}"
  }
  let parts : Array[String] = []
  for part in inner.split(", ") {
    parts.push(part.to_string())
  }
  parts.sort()
  "{" + parts.join(", ") + "}"
}

///|
fn local_expr_pair_text(pair : (@symcore.Expr, @symcore.Expr)) -> String {
  normalize_solver_text(
    "(" + @symprint.to_string(pair.0) + ", " + @symprint.to_string(pair.1) + ")",
  )
}

///|
fn sorted_map_keys(values : Map[String, @symcore.Expr]) -> Array[String] {
  let keys : Array[String] = []
  for key, _ in values {
    keys.push(key)
  }
  keys.sort()
  keys
}

///|
fn local_solve_result_text(result : @symsolvers.SolveResult) -> String {
  let dict_text = fn(values : Map[String, @symcore.Expr]) {
    local_solution_dict_text(Some(values), sorted_map_keys(values))
  }
  match result {
    @symsolvers.SolveResult::List(items) => local_expr_list_text(items)
    @symsolvers.SolveResult::Dict(values) => dict_text(values)
    @symsolvers.SolveResult::Dicts(items) => {
      let rendered : Array[String] = []
      for item in items {
        rendered.push(dict_text(item))
      }
      "[" + rendered.join(", ") + "]"
    }
  }
}

///|
fn local_diop_solve_result_text(result : @symsolvers.DiopSolveResult) -> String {
  match result {
    @symsolvers.DiopSolveResult::Tuple(items) => "(" + items.map(@symprint.to_string).join(", ") + ")"
    @symsolvers.DiopSolveResult::Set(set) => @symsets.to_string(set)
  }
}

///|
fn local_classify_diop_text(
  result : (Array[@symcore.Expr], Map[String, @symcore.Expr], String),
) -> String {
  let (symbols, coeffs, kind) = result
  let keys : Array[String] = []
  for key, _ in coeffs {
    keys.push(key)
  }
  keys.sort()
  let ordered = if keys.contains("1") {
    let tmp : Array[String] = ["1"]
    for key in keys {
      if key != "1" {
        tmp.push(key)
      }
    }
    tmp
  } else {
    keys
  }
  let coeff_parts : Array[String] = []
  for key in ordered {
    coeff_parts.push(key + ": " + @symprint.to_string(coeffs[key]))
  }
  "(" +
  local_expr_list_text(symbols) +
  ", {" +
  coeff_parts.join(", ") +
  "}, '" +
  kind +
  "')"
}

///|
fn local_lp_dict_result_text(result : (@symcore.Expr, Map[String, @symcore.Expr])) -> String {
  normalize_solver_text(
    "(" +
    @symprint.to_string(result.0) +
    ", " +
    local_solution_dict_text(Some(result.1), ["x", "y", "z"]) +
    ")",
  )
}

///|
fn local_linprog_result_text(result : (@symcore.Expr, Array[@symcore.Expr])) -> String {
  normalize_solver_text(
    "(" + @symprint.to_string(result.0) + ", " + local_expr_list_text(result.1) + ")",
  )
}

///|
fn local_maybe_bool_text(value : Bool?) -> String {
  match value {
    Some(v) => v.to_string().to_lower()
    None => "none"
  }
}

///|
fn local_failing_assumptions_text(values : Map[String, Bool?]) -> String {
  if values.is_empty() {
    return "{}"
  }
  let keys : Array[String] = []
  for key, _ in values {
    keys.push(key)
  }
  keys.sort()
  let parts : Array[String] = []
  for key in keys {
    let value = match values.get(key) {
      Some(Some(v)) => if v { "true" } else { "false" }
      _ => "None"
    }
    parts.push("'" + key + "': " + value)
  }
  "{" + parts.join(", ") + "}"
}

///|
fn local_maybe_solve_result_text(result : @symsolvers.SolveResult?) -> String {
  match result {
    None => "None"
    Some(value) => local_solve_result_text(value)
  }
}

///|
fn assumption_map(entries : Array[(String, Bool?)]) -> Map[String, Bool?] {
  let out : Map[String, Bool?] = {}
  for entry in entries {
    out[entry.0] = entry.1
  }
  out
}

///|
test "solvers parity linear_eq_to_matrix and linsolve" {
  let equations = [
    @symcore.add([x(), y(), @symcore.int(-3)]),
    @symcore.add([x(), @symcore.mul([@symcore.int(-1), y()]), @symcore.int(-1)]),
  ]
  let (a, b) = @symsolvers.linear_eq_to_matrix(equations, [x(), y()])
  assert_eq(
    local_matrix_list_text(a),
    py_matrix_list_text(
      "sympy.solvers.linear_eq_to_matrix([x + y - 3, x - y - 1], [x, y])[0]",
    ),
  )
  assert_eq(
    local_matrix_list_text(b),
    py_matrix_list_text(
      "sympy.solvers.linear_eq_to_matrix([x + y - 3, x - y - 1], [x, y])[1]",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(@symsolvers.linsolve_equations_input(equations), [
        x(),
        y(),
      ]),
    ),
    solvers_eval_str(
      "sympy.sstr(sympy.solvers.linsolve([x + y - 3, x - y - 1], (x, y)))",
    ),
  )
}

///|
test "solvers parity linear system helpers and matrix quick helpers" {
  let system = @symmatrices.matrix([
    [@symcore.int(1), @symcore.int(1), @symcore.int(3)],
    [@symcore.int(1), @symcore.int(-1), @symcore.int(1)],
  ])
  assert_eq(
    local_solution_dict_text(
      @symsolvers.solve_linear_system(system, [x(), y()]),
      ["x", "y"],
    ),
    solvers_eval_str(
      "repr(sympy.solvers.solve_linear_system(" +
      py_matrix_expr(system) +
      ", x, y))",
    ),
  )
  let lu_system = @symmatrices.matrix([
    [@symcore.int(2), @symcore.int(1), @symcore.int(5)],
    [@symcore.int(1), @symcore.int(-1), @symcore.int(1)],
  ])
  assert_eq(
    local_solution_dict_text(
      @symsolvers.solve_linear_system_LU(lu_system, [x(), y()]),
      ["x", "y"],
    ),
    solvers_eval_str(
      "repr(sympy.solvers.solve_linear_system_LU(" +
      py_matrix_expr(lu_system) +
      ", [x, y]))",
    ),
  )
  let m = @symmatrices.matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  assert_eq(
    @symprint.to_string(@symsolvers.det_quick(m)),
    solvers_eval_str(
      "sympy.sstr(sympy.solvers.det_quick(" + py_matrix_expr(m) + "))",
    ),
  )
  assert_eq(
    local_matrix_list_text(@symsolvers.inv_quick(m)),
    py_matrix_list_text("sympy.solvers.inv_quick(" + py_matrix_expr(m) + ")"),
  )
}

///|
test "solvers parity checksol on exact equations" {
  assert_eq(
    @symsolvers.checksol(
      @symcore.add([x(), @symcore.int(-2)]),
      x(),
      @symcore.int(2),
    )
    .map(v => v.to_string())
    .unwrap_or("None"),
    solvers_eval_str("str(sympy.solvers.checksol(x - 2, x, 2)).lower()"),
  )
  assert_eq(
    @symsolvers.checksol(
      @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), @symcore.int(2)),
      x(),
      @symcore.int(3),
    )
    .map(v => v.to_string())
    .unwrap_or("None"),
    solvers_eval_str(
      "str(sympy.solvers.checksol(sympy.Eq(x, 2), x, 3)).lower()",
    ),
  )
}

///|
test "solvers parity solve_linear solve solveset complexes and nsolve" {
  assert_eq(
    @symsets.to_string(@symsolvers.complexes),
    solvers_eval_str("sympy.sstr(sympy.solvers.Complexes)"),
  )
  assert_eq(
    local_expr_pair_text(
      @symsolvers.solve_linear(@symcore.add([x(), @symcore.int(2)]), symbols=[
        x(),
      ]),
    ),
    solvers_eval_str("repr(sympy.solvers.solve_linear(x + 2, symbols=[x]))"),
  )
  assert_eq(
    normalize_solver_text(
      @symsets.to_string(
        @symsolvers.solveset(
          @symcore.add([x() ^ @symcore.int(2), @symcore.int(-4)]),
          symbol=Some(x()),
          domain=@symsolvers.complexes,
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**2 - 4, x))"),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_solve_result_text(
        @symsolvers.solve(
          @symsolvers.solve_expr_input(
            @symcore.add([x() ^ @symcore.int(2), @symcore.int(-4)]),
          ),
          symbols=[x()],
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str("repr(sympy.solvers.solve(x**2 - 4, x))"),
    ),
  )
  let root_text = @symprint.to_string(
    @symsolvers.nsolve(
      @symcore.add([x() ^ @symcore.int(2), @symcore.int(-2)]),
      x(),
      @symcore.rational_from_ints(3, 2),
    ),
  )
  let oracle_text = solvers_eval_str(
    "sympy.sstr(sympy.solvers.nsolve(x**2 - 2, x, 1.5))",
  )
  assert_true(
    root_text.has_prefix(oracle_text.unsafe_substring(start=0, end=10)),
  )
}

///|
test "solvers parity nonlinsolve solve_poly_system and system solve wrapper" {
  let polynomial_system = [
    @symcore.add([x() ^ @symcore.int(2), @symcore.int(-1)]),
    @symcore.add([y(), @symcore.mul([@symcore.int(-1), x()])]),
  ]
  assert_eq(
    @symsets.to_string(@symsolvers.nonlinsolve(polynomial_system, [x(), y()])),
    solvers_eval_str(
      "sympy.sstr(sympy.solvers.nonlinsolve([x**2 - 1, y - x], [x, y]))",
    ),
  )
  assert_eq(
    local_expr_list_text(
      @symsolvers.solve_poly_system(polynomial_system, [x(), y()]),
    ),
    solvers_eval_str(
      "repr(sympy.solvers.solve_poly_system([x**2 - 1, y - x], x, y))",
    ),
  )
  assert_eq(
    local_expr_list_text(
      @symsolvers.solve_triangulated(polynomial_system, [x(), y()]),
    ),
    solvers_eval_str(
      "repr(sympy.solvers.solve_triangulated([x**2 - 1, y - x], x, y))",
    ),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.substitution(polynomial_system, [x(), y()])),
    solvers_eval_str(
      "sympy.sstr(sympy.solvers.substitution([x**2 - 1, y - x], [x, y]))",
    ),
  )
  let linear_system = [
    @symcore.add([x(), y(), @symcore.int(-3)]),
    @symcore.add([x(), @symcore.mul([@symcore.int(-1), y()]), @symcore.int(-1)]),
  ]
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(@symsolvers.solve_exprs_input(linear_system), symbols=[
        x(),
        y(),
      ]),
    ),
    solvers_eval_str(
      "repr(sympy.solvers.solve([x + y - 3, x - y - 1], [x, y]))",
    ),
  )
}

///|
test "solvers parity lpmin lpmax and linprog" {
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x(),
        [@symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(1))],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x, [x >= 1]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x(),
        [@symcore.Expr::Relational(@symcore.RelOp::Le, x(), @symcore.int(-1))],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x, [x <= -1]))"),
  )
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1)],
        bounds=Some([(Some(@symcore.int(1)), (None : @symcore.Expr?))]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1], bounds=[(1, None)]))"),
  )
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1)],
        a=Some(@symmatrices.matrix([[@symcore.int(-1)]])),
        b=Some([@symcore.int(-1)]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1], A=[[-1]], b=[-1]))"),
  )
}

///|
test "solvers parity decompogen" {
  assert_eq(
    normalize_solver_text(
      local_expr_list_text(@symsolvers.decompogen(sin(cos(x())), x())),
    ),
    normalize_solver_text(
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.sin(sympy.cos(x)), x))"),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_expr_list_text(
        @symsolvers.decompogen(
          @symcore.add([sin(x()) ^ @symcore.int(2), sin(x()), @symcore.int(1)]),
          x(),
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(sympy.solvers.decompogen(sympy.sin(x)**2 + sympy.sin(x) + 1, x))",
      ),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_expr_list_text(
        @symsolvers.decompogen(
          sqrt(
            @symcore.add([
              @symcore.mul([@symcore.int(6), x() ^ @symcore.int(2)]),
              @symcore.int(-5),
            ]),
          ),
          x(),
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.sqrt(6*x**2 - 5), x))"),
    ),
  )
}

///|
test "solvers parity assumptions and undetermined coeffs" {
  assert_eq(
    local_maybe_bool_text(
      @symsolvers.check_assumptions(
        @symcore.int(3),
        assumptions=assumption_map([("integer", Some(true)), ("real", Some(true))]),
      ),
    ),
    solvers_eval_str(
      "str(sympy.check_assumptions(3, integer=True, real=True)).lower()",
    ),
  )
  assert_eq(
    local_maybe_bool_text(
      @symsolvers.check_assumptions(
        x(),
        assumptions=assumption_map([("integer", Some(true))]),
      ),
    ),
    solvers_eval_str("str(sympy.check_assumptions(x, integer=True)).lower()"),
  )
  assert_eq(
    normalize_solver_text(
      local_failing_assumptions_text(
        @symsolvers.failing_assumptions(
          @symcore.int(-2),
          assumption_map([("positive", Some(true)), ("real", Some(true))]),
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(__import__('sympy.core.assumptions', fromlist=['failing_assumptions']).failing_assumptions(-2, positive=True, real=True))",
      ),
    ),
  )
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  assert_eq(
    normalize_solver_text(
      local_maybe_solve_result_text(
        @symsolvers.solve_undetermined_coeffs(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.add([@symcore.mul([a, x()]), b]),
            @symcore.add([x(), @symcore.int(2)]),
          ),
          [a, b],
          syms=[x()],
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "(lambda a, b: repr(sympy.solvers.solve_undetermined_coeffs(sympy.Eq(a*x + b, x + 2), [a, b], x)))(*sympy.symbols('a b'))",
      ),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_maybe_solve_result_text(
        @symsolvers.solve_undetermined_coeffs(
          @symcore.add([@symcore.mul([a ^ @symcore.int(2), x()]), b, @symcore.mul([@symcore.int(-1), x()])]),
          [a, b],
          syms=[x()],
          dict=true,
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "(lambda a, b: repr(sympy.solvers.solve_undetermined_coeffs(a**2*x + b - x, [a, b], x, dict=True)))(*sympy.symbols('a b'))",
      ),
    ),
  )
}

///|
test "solvers parity ode and pde utility front doors" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")
  assert_eq(
    local_string_list_repr(@symsolvers.allhints),
    solvers_eval_str(
      "repr(list(__import__('sympy.solvers.ode', fromlist=['allhints']).allhints))",
    ),
  )
  assert_eq(
    normalize_solver_text(@symprint.to_string(@symsolvers.constantsimp(c1 + c2, [c1, c2]))),
    normalize_solver_text(
      solvers_eval_str_symbols(
        "sympy.sstr(__import__('sympy.solvers.ode', fromlist=['constantsimp']).constantsimp(C1 + C2, [C1, C2]))",
        "C1 C2",
      ),
    ),
  )
  let system = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(f(x()), x()) - @symcore.int(7) * f(x()),
      @symcore.int(12) * g(x()),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(g(x()), x()) + g(x()),
      @symcore.int(20) * f(x()),
    ),
  ]
  assert_eq(
    normalize_solver_text(
      local_expr_systems_text(
        @symsolvers.canonical_odes(system, [f(x()), g(x())], x()),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(__import__('sympy.solvers.ode', fromlist=['canonical_odes']).canonical_odes([sympy.Eq(sympy.Function('f')(x).diff(x) - 7*sympy.Function('f')(x), 12*sympy.Function('g')(x)), sympy.Eq(sympy.Function('g')(x).diff(x) + sympy.Function('g')(x), 20*sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x))",
      ),
    ),
  )
  let (a_mats, b_mat) = @symsolvers.linear_ode_to_matrix(system, [f(x()), g(x())], x(), 1)
  assert_eq(
    local_matrix_list_text(a_mats[0]),
    py_matrix_list_text(
      "__import__('sympy.solvers.ode', fromlist=['linear_ode_to_matrix']).linear_ode_to_matrix([sympy.Eq(sympy.Function('f')(x).diff(x) - 7*sympy.Function('f')(x), 12*sympy.Function('g')(x)), sympy.Eq(sympy.Function('g')(x).diff(x) + sympy.Function('g')(x), 20*sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x, 1)[0][0]",
    ),
  )
  assert_eq(
    local_matrix_list_text(a_mats[1]),
    py_matrix_list_text(
      "__import__('sympy.solvers.ode', fromlist=['linear_ode_to_matrix']).linear_ode_to_matrix([sympy.Eq(sympy.Function('f')(x).diff(x) - 7*sympy.Function('f')(x), 12*sympy.Function('g')(x)), sympy.Eq(sympy.Function('g')(x).diff(x) + sympy.Function('g')(x), 20*sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x, 1)[0][1]",
    ),
  )
  assert_eq(
    local_matrix_list_text(b_mat),
    py_matrix_list_text(
      "__import__('sympy.solvers.ode', fromlist=['linear_ode_to_matrix']).linear_ode_to_matrix([sympy.Eq(sympy.Function('f')(x).diff(x) - 7*sympy.Function('f')(x), 12*sympy.Function('g')(x)), sympy.Eq(sympy.Function('g')(x).diff(x) + sympy.Function('g')(x), 20*sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x, 1)[1]",
    ),
  )
  assert_eq(
    matrix_oracle_residual_text(
      @symsolvers.linodesolve(@symmatrices.matrix([[@symcore.int(1)]]), x()),
      "sympy.Matrix([sympy.Symbol('C1')*sympy.exp(x)])",
    ),
    "Matrix([[0]])",
  )
  assert_eq(
    matrix_oracle_residual_text(
      @symsolvers.linodesolve(
        @symmatrices.matrix([
          [@symcore.int(1), @symcore.int(1)],
          [@symcore.int(0), @symcore.int(1)],
        ]),
        x(),
      ),
      "(sympy.exp(sympy.Matrix([[1, 1], [0, 1]])*x) * sympy.Matrix([sympy.Symbol('C1'), sympy.Symbol('C2')]))",
    ),
    "Matrix([[0], [0]])",
  )
  assert_eq(
    matrix_oracle_residual_text(
      @symsolvers.linodesolve(
        @symmatrices.matrix([
          [@symcore.int(1), @symcore.int(2)],
          [@symcore.int(0), @symcore.int(3)],
        ]),
        x(),
      ),
      "(sympy.exp(sympy.Matrix([[1, 2], [0, 3]])*x) * sympy.Matrix([sympy.Symbol('C1'), sympy.Symbol('C2')]))",
    ),
    "Matrix([[0], [0]])",
  )
  let lie_eq = @symcalculus.diff(f(x()), x()) - (x() ^ @symcore.int(2)) * f(x())
  assert_eq(
    normalize_solver_text(local_infinitesimals_text(@symsolvers.infinitesimals(lie_eq, func=Some(f(x()))))),
    normalize_solver_text(
      solvers_eval_str(
        "repr([{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x))])",
      ),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_checkinfsol_text(
        @symsolvers.checkinfsol(
          lie_eq,
          @symsolvers.infinitesimals(lie_eq, func=Some(f(x()))),
          func=Some(f(x())),
        ),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x), __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x))))",
      ),
    ),
  )
  let ode = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(f(x()), x()),
    f(x()),
  )
  assert_eq(
    @symsolvers.ode_order(ode, f(x())).to_string(),
    solvers_eval_str("str(sympy.solvers.ode_order(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x)), sympy.Function('f')(x)))"),
  )
  assert_eq(
    @symprint.to_string(
      @symsolvers.homogeneous_order(
        @symcore.add([x() ^ @symcore.int(2), y() ^ @symcore.int(2)]),
        [x(), y()],
      ).unwrap_or(@symcore.int(-1)),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.homogeneous_order(x**2 + y**2, x, y))"),
  )
  assert_eq(
    local_expr_list_text(@symsolvers.classify_ode(ode, func=Some(f(x()))).map(name => @symcore.Expr::Symbol(name))),
    local_expr_list_text([@symcore.Expr::Symbol("separable"), @symcore.Expr::Symbol("1st_linear"), @symcore.Expr::Symbol("Bernoulli")]),
  )
  assert_eq(
    normalize_solver_text(@symprint.to_string(@symsolvers.dsolve(ode, func=Some(f(x()))))),
    normalize_solver_text(
      solvers_eval_str(
        "sympy.sstr(sympy.solvers.dsolve(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x))))",
      ),
    ),
  )
  assert_eq(
    normalize_solver_text(
      "(" +
      @symsolvers.checkodesol(ode, @symsolvers.dsolve(ode, func=Some(f(x()))), func=Some(f(x()))).0.to_string() +
      ", " +
      @symprint.to_string(
        @symsolvers.checkodesol(
          ode,
          @symsolvers.dsolve(ode, func=Some(f(x()))),
          func=Some(f(x())),
        ).1,
      ) +
      ")",
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(sympy.solvers.checkodesol(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x)), sympy.solvers.dsolve(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x)))))",
      ),
    ),
  )
  let pde = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(u(x(), y()), x()),
    @symcalculus.diff(u(x(), y()), y()),
  )
  assert_eq(
    normalize_solver_text(
      local_expr_list_text(
        @symsolvers.pde_separate_add(
          pde,
          u(x(), y()),
          [xfun(x()), yfun(y())],
        ).unwrap_or([]),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(sympy.solvers.pde_separate_add(sympy.Eq(sympy.Function('u')(x, y).diff(x), sympy.Function('u')(x, y).diff(y)), sympy.Function('u')(x, y), [sympy.Function('X')(x), sympy.Function('Y')(y)]))",
      ),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_expr_list_text(
        @symsolvers.pde_separate_mul(
          pde,
          u(x(), y()),
          [xfun(x()), yfun(y())],
        ).unwrap_or([]),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(sympy.solvers.pde_separate_mul(sympy.Eq(sympy.Function('u')(x, y).diff(x), sympy.Function('u')(x, y).diff(y)), sympy.Function('u')(x, y), [sympy.Function('X')(x), sympy.Function('Y')(y)]))",
      ),
    ),
  )
  assert_eq(
    local_expr_list_text(@symsolvers.classify_pde(pde, func=Some(u(x(), y()))).map(name => @symcore.Expr::Symbol(name))),
    local_expr_list_text([@symcore.Expr::Symbol("1st_linear_constant_coeff_homogeneous")]),
  )
  assert_eq(
    normalize_solver_text(@symprint.to_string(@symsolvers.pdsolve(pde, func=Some(u(x(), y()))))),
    normalize_solver_text(
      solvers_eval_str(
        "sympy.sstr(sympy.solvers.pdsolve(sympy.Eq(sympy.Function('u')(x, y).diff(x), sympy.Function('u')(x, y).diff(y))))",
      ),
    ),
  )
}

///|
test "solvers parity inequalities factor_system and diophantine" {
  let poly = @sympolys.Poly::from_expr_defaults(
    (x() ^ @symcore.int(2)) - @symcore.int(1),
    gens=["x"],
  )
  let one = @sympolys.Poly::from_expr_defaults(@symcore.int(1), gens=["x"])
  assert_eq(
    local_set_list_text(@symsolvers.solve_poly_inequality(poly, "==")),
    solvers_eval_str(
      "repr(sympy.solvers.solve_poly_inequality(sympy.Poly(x**2 - 1, x, domain='ZZ'), '=='))",
    ),
  )
  assert_eq(
    local_set_list_text(@symsolvers.solve_poly_inequality(poly, "!=")),
    solvers_eval_str(
      "repr(sympy.solvers.solve_poly_inequality(sympy.Poly(x**2 - 1, x, domain='ZZ'), '!='))",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solve_rational_inequalities([
        [
          ((@sympolys.Poly::from_expr_defaults(x(), gens=["x"]), one), "!="),
          ((@sympolys.Poly::from_expr_defaults(@symcore.int(1) - x(), gens=["x"]), one), ">="),
        ],
      ]),
    ),
    solvers_eval_str(
      "sympy.sstr(sympy.solvers.solve_rational_inequalities([[((sympy.Poly(x, x, domain='ZZ'), sympy.Poly(1, x, domain='ZZ')), '!='), ((sympy.Poly(1 - x, x, domain='ZZ'), sympy.Poly(1, x, domain='ZZ')), '>=')]]))",
    ),
  )
  assert_eq(
    local_inequality_result_text(
      @symsolvers.solve_univariate_inequality(
        @symcore.Expr::Relational(@symcore.RelOp::Ge, x() ^ @symcore.int(2), @symcore.int(4)),
        x(),
        relational=false,
      ),
    ),
    "Set(" +
    solvers_eval_str(
      "sympy.sstr(sympy.solvers.solve_univariate_inequality(x**2 >= 4, x, relational=False))",
    ) +
    ")",
  )
  assert_eq(
    normalize_solver_text(
      local_expr_matrix_text(
        @symsolvers.factor_system(
          [x() * (x() + @symcore.int(1)), y() * (y() - @symcore.int(1))],
          gens=[x(), y()],
        ),
      ),
    ),
    "[[x, y], [x, y - 1], [x + 1, y], [x + 1, y - 1]]",
  )
  assert_eq(
    normalize_solver_text(
      @symsets.to_string(@symsolvers.diophantine(x() + y() - @symcore.int(3))),
    ),
    normalize_solver_text(
      solvers_eval_str("repr(sympy.solvers.diophantine(x + y - 3))"),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_classify_diop_text(
        @symsolvers.classify_diop(x() + y() - @symcore.int(3)),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(__import__('sympy.solvers.diophantine', fromlist=['classify_diop']).classify_diop(x + y - 3))",
      ),
    ),
  )
  assert_eq(
    normalize_solver_text(
      local_diop_solve_result_text(
        @symsolvers.diop_solve(x() + y() - @symcore.int(3)),
      ),
    ),
    normalize_solver_text(
      solvers_eval_str(
        "repr(__import__('sympy.solvers.diophantine', fromlist=['diop_solve']).diop_solve(x + y - 3))",
      ),
    ),
  )
  assert_eq(
    normalize_braced_items_text(
      @symsets.to_string(
        @symsolvers.diophantine((x() ^ @symcore.int(2)) - @symcore.int(1)),
      ),
    ),
    normalize_braced_items_text(
      solvers_eval_str("repr(sympy.solvers.diophantine(x**2 - 1))"),
    ),
  )
}

///|
test "solvers parity recurrence helpers" {
  let a = @symcore.Expr::Symbol("a")
  let poly_solution = @symsolvers.rsolve_poly([@symcore.int(-1), @symcore.int(1)], x(), x())
    .unwrap_or(@symcore.int(0))
  assert_eq(
    recurrence_expr_matches_oracle(
      poly_solution,
      "sympy.solvers.rsolve_poly([-1, 1], x, x)",
      "x C0",
    ),
    "0",
  )
  let hyper_solution = @symsolvers.rsolve_hyper(
    [@symcore.mul([@symcore.int(-1), a]), @symcore.int(1)],
    @symcore.int(0),
    x(),
  ).unwrap_or(@symcore.int(0))
  assert_eq(
    recurrence_expr_matches_oracle(
      hyper_solution,
      "sympy.solvers.rsolve_hyper([-a, 1], 0, x)",
      "x a C0",
    ),
    "0",
  )
  let recurrence = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    f(x() + @symcore.int(1)),
    @symcore.add([f(x()), x()]),
  )
  let general = @symsolvers.rsolve(recurrence, f(x())).unwrap_or(@symcore.int(0))
  assert_eq(
    recurrence_expr_matches_oracle(
      general,
      "sympy.solvers.rsolve(sympy.Eq(sympy.Function('f')(x + 1), sympy.Function('f')(x) + x), sympy.Function('f')(x))",
      "x C0",
    ),
    "0",
  )
  let with_init = @symsolvers.rsolve(
    recurrence,
    f(x()),
    init=Some(@symsolvers.rsolve_init_list([@symcore.int(0)])),
  ).unwrap_or(@symcore.int(0))
  assert_eq(
    recurrence_expr_matches_oracle(
      with_init,
      "sympy.solvers.rsolve(sympy.Eq(sympy.Function('f')(x + 1), sympy.Function('f')(x) + x), sympy.Function('f')(x), init=[0])",
      "x",
    ),
    "0",
  )
}
