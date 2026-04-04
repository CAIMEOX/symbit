///|
fn x() -> @symcore.Expr {
  @symcore.Expr::Symbol("x")
}

///|
fn y() -> @symcore.Expr {
  @symcore.Expr::Symbol("y")
}

///|
fn z() -> @symcore.Expr {
  @symcore.Expr::Symbol("z")
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
fn h(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("h", [expr])
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
fn expr_list_text(items : Array[@symcore.Expr]) -> String {
  "[" + items.map(@symprint.to_string).join(", ") + "]"
}

///|
fn set_list_text(items : Array[@symsets.Set]) -> String {
  "[" + items.map(@symsets.to_string).join(", ") + "]"
}

///|
fn inequality_result_text(result : InequalityResult) -> String {
  match result {
    InequalityResult::Set(set) => "Set(" + @symsets.to_string(set) + ")"
    InequalityResult::Relational(expr) => "Relational(" + @symprint.to_string(expr) + ")"
  }
}

///|
fn expr_matrix_text(items : Array[Array[@symcore.Expr]]) -> String {
  "[" + items.map(expr_list_text).join(", ") + "]"
}

///|
fn local_infinitesimals_text(items : Array[Map[String, @symcore.Expr]]) -> String {
  let rendered : Array[String] = []
  for item in items {
    rendered.push(
      "{xi: " +
      @symprint.to_string(item.get("xi").unwrap_or(@symcore.int(0))) +
      ", eta: " +
      @symprint.to_string(item.get("eta").unwrap_or(@symcore.int(0))) +
      "}",
    )
  }
  "[" + rendered.join(", ") + "]"
}

///|
fn normalize_text(text : String) -> String {
  text
  .replace_all(old="/1", new="")
  .replace_all(old="-1*", new="-")
  .replace_all(old=" + -", new=" - ")
  .replace_all(old="-t_0 + 3", new="3 - t_0")
  .replace_all(old="exp(1*x**3/3)", new="exp(x**3/3)")
}

///|
fn expr_pair_text(pair : (@symcore.Expr, @symcore.Expr)) -> String {
  normalize_text(
    "(" + @symprint.to_string(pair.0) + ", " + @symprint.to_string(pair.1) + ")",
  )
}

///|
fn solve_result_text(result : SolveResult) -> String {
  let dict_text = fn(values : Map[String, @symcore.Expr]) {
    let names : Array[String] = []
    for name, _ in values {
      names.push(name)
    }
    names.sort()
    let items : Array[String] = []
    for name in names {
      items.push(name + ": " + @symprint.to_string(values[name]))
    }
    "{" + items.join(", ") + "}"
  }
  match result {
    SolveResult::List(items) => expr_list_text(items)
    SolveResult::Dict(values) => dict_text(values)
    SolveResult::Dicts(items) => {
      let rendered : Array[String] = []
      for item in items {
        rendered.push(dict_text(item))
      }
      "[" + rendered.join(", ") + "]"
    }
  }
}

///|
fn diop_solve_result_text(result : DiopSolveResult) -> String {
  match result {
    DiopSolveResult::Tuple(items) => "(" + items.map(@symprint.to_string).join(", ") + ")"
    DiopSolveResult::Set(set) => @symsets.to_string(set)
  }
}

///|
fn classify_diop_text(
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
  expr_list_text(symbols) +
  ", {" +
  coeff_parts.join(", ") +
  "}, '" +
  kind +
  "')"
}

///|
fn maybe_solve_result_text(result : SolveResult?) -> String {
  match result {
    None => "None"
    Some(value) => solve_result_text(value)
  }
}

///|
fn is_test_constant_symbol(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => name.has_prefix("C")
    _ => false
  }
}

///|
fn test_constant_sort_expr(expr : @symcore.Expr) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  for symbol in @symcore.free_symbols(expr) {
    if is_test_constant_symbol(symbol) {
      match symbol {
        @symcore.Expr::Symbol(name) => env[name] = @symcore.int(1)
        _ => ()
      }
    }
  }
  @symcore.subst(expr, env)
}

///|
fn test_sympy_function_rank(name : String) -> Int {
  match name {
    "Derivative" | "derivative" => 0
    "Integral" | "integral" => 1
    "abs" | "Abs" => 2
    "sign" | "Sign" => 3
    "sqrt" | "Sqrt" => 4
    "floor" | "Floor" => 5
    "ceiling" | "Ceiling" => 6
    "re" | "Re" => 7
    "im" | "Im" => 8
    "arg" | "Arg" => 9
    "conjugate" | "Conjugate" => 10
    "exp" | "Exp" => 11
    "log" | "Log" => 12
    "sin" | "Sin" => 13
    "cos" | "Cos" => 14
    "tan" | "Tan" => 15
    "cot" | "Cot" => 16
    "asin" | "ASin" => 17
    "acos" | "ACos" => 18
    "atan" | "ATan" => 19
    "acot" | "ACot" => 20
    "sinh" | "Sinh" => 21
    "cosh" | "Cosh" => 22
    "tanh" | "Tanh" => 23
    "coth" | "Coth" => 24
    "asinh" | "ASinh" => 25
    "acosh" | "ACosh" => 26
    "atanh" | "ATanh" => 27
    "acoth" | "ACoth" => 28
    "risingfactorial" | "RisingFactorial" => 29
    "fallingfactorial" | "FallingFactorial" => 30
    "factorial" => 31
    "binomial" => 32
    "gamma" | "Gamma" => 33
    "lowergamma" | "LowerGamma" => 34
    "uppergamma" | "UpperGamma" => 35
    "polygamma" | "PolyGamma" => 36
    "erf" | "Erf" => 37
    _ => 10000
  }
}

///|
fn test_sort_exprs_cmp(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> Int {
  let lhs_len = lhs.length()
  let rhs_len = rhs.length()
  let min_len = if lhs_len < rhs_len { lhs_len } else { rhs_len }
  for i in 0..<min_len {
    let cmp = test_sort_expr_cmp(lhs[i], rhs[i])
    if cmp != 0 {
      return cmp
    }
  }
  lhs_len.compare(rhs_len)
}

///|
fn test_sort_apply_head_cmp(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Int {
  match (lhs, rhs) {
    (@symcore.Expr::UndefinedFunction(lhs_name), @symcore.Expr::UndefinedFunction(rhs_name)) =>
      lhs_name.compare(rhs_name)
    (@symcore.Expr::UndefinedFunction(_), @symcore.Expr::FunctionHead(_)) => -1
    (@symcore.Expr::FunctionHead(_), @symcore.Expr::UndefinedFunction(_)) => 1
    (@symcore.Expr::FunctionHead(lhs_name), @symcore.Expr::FunctionHead(rhs_name)) => {
      let rank_cmp = test_sympy_function_rank(lhs_name).compare(test_sympy_function_rank(rhs_name))
      if rank_cmp != 0 {
        rank_cmp
      } else {
        lhs_name.compare(rhs_name)
      }
    }
    _ => @symcore.compare_expr(lhs, rhs)
  }
}

///|
fn test_sort_relop_rank(op : @symcore.RelOp) -> Int {
  match op {
    @symcore.RelOp::Eq => 0
    @symcore.RelOp::Ne => 1
    @symcore.RelOp::Lt => 2
    @symcore.RelOp::Le => 3
    @symcore.RelOp::Gt => 4
    @symcore.RelOp::Ge => 5
  }
}

///|
fn test_sort_node_count(expr : @symcore.Expr) -> Int {
  match expr {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::ComplexFloat(_)
    | @symcore.Expr::NumberSymbol(_)
    | @symcore.Expr::Boolean(_)
    | @symcore.Expr::IdentityFunction
    | @symcore.Expr::Symbol(_)
    | @symcore.Expr::Dummy(_, _)
    | @symcore.Expr::Wild(_, _, _)
    | @symcore.Expr::WildFunction(_, _)
    | @symcore.Expr::FunctionHead(_)
    | @symcore.Expr::UndefinedFunction(_) => 1
    _ => 1 + @symcore.children(expr).fold(init=0, fn(acc, child) { acc + test_sort_node_count(child) })
  }
}

///|
fn test_sort_expr_cmp(lhs_raw : @symcore.Expr, rhs_raw : @symcore.Expr) -> Int {
  let lhs = test_constant_sort_expr(lhs_raw)
  let rhs = test_constant_sort_expr(rhs_raw)
  match (lhs, rhs) {
    (@symcore.Expr::Apply(lhs_head, lhs_args), @symcore.Expr::Apply(rhs_head, rhs_args)) => {
      let head_cmp = test_sort_apply_head_cmp(lhs_head, rhs_head)
      if head_cmp != 0 {
        return head_cmp
      }
      return test_sort_exprs_cmp(lhs_args, rhs_args)
    }
    (@symcore.Expr::Add(lhs_args), @symcore.Expr::Add(rhs_args))
    | (@symcore.Expr::Mul(lhs_args), @symcore.Expr::Mul(rhs_args)) =>
      test_sort_exprs_cmp(lhs_args, rhs_args)
    (@symcore.Expr::Pow(lhs_base, lhs_exp), @symcore.Expr::Pow(rhs_base, rhs_exp)) => {
      let base_cmp = test_sort_expr_cmp(lhs_base, rhs_base)
      if base_cmp != 0 {
        return base_cmp
      }
      return test_sort_expr_cmp(lhs_exp, rhs_exp)
    }
    (@symcore.Expr::Relational(lhs_op, lhs_lhs, lhs_rhs), @symcore.Expr::Relational(rhs_op, rhs_lhs, rhs_rhs)) => {
      let op_cmp = test_sort_relop_rank(lhs_op).compare(test_sort_relop_rank(rhs_op))
      if op_cmp != 0 {
        return op_cmp
      }
      let lhs_cmp = test_sort_expr_cmp(lhs_lhs, rhs_lhs)
      if lhs_cmp != 0 {
        return lhs_cmp
      }
      return test_sort_expr_cmp(lhs_rhs, rhs_rhs)
    }
    _ => {
      let node_cmp = test_sort_node_count(lhs).compare(test_sort_node_count(rhs))
      if node_cmp != 0 {
        return node_cmp
      }
      let cmp = @symcore.compare_expr(lhs, rhs)
      if cmp != 0 {
        cmp
      } else {
        @symprint.to_string(lhs).compare(@symprint.to_string(rhs))
      }
    }
  }
}

///|
fn test_sort_constant_args(items : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for item in items {
    let mut inserted = false
    for i in 0..<out.length() {
      if test_sort_expr_cmp(item, out[i]) < 0 {
        out.insert(i, item)
        inserted = true
        break
      }
    }
    if !inserted {
      out.push(item)
    }
  }
  out
}

///|
fn local_constant_renumber_inner(
  expr : @symcore.Expr,
  constants_found : Array[String],
) -> @symcore.Expr {
  if is_test_constant_symbol(expr) {
    match expr {
      @symcore.Expr::Symbol(name) =>
        if !constants_found.contains(name) {
          constants_found.push(name)
        }
      _ => ()
    }
    return expr
  }
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.Expr::Add(
        test_sort_constant_args(args).map(arg => local_constant_renumber_inner(arg, constants_found)),
      )
    @symcore.Expr::Mul(args) =>
      @symcore.Expr::Mul(
        test_sort_constant_args(args).map(arg => local_constant_renumber_inner(arg, constants_found)),
      )
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(
        local_constant_renumber_inner(base, constants_found),
        local_constant_renumber_inner(exp, constants_found),
      )
    @symcore.Expr::Relational(op, lhs, rhs) =>
      @symcore.Expr::Relational(
        op,
        local_constant_renumber_inner(lhs, constants_found),
        local_constant_renumber_inner(rhs, constants_found),
      )
    _ => @symcore.map_children(
      expr,
      child => local_constant_renumber_inner(child, constants_found),
    )
  }
}

///|
fn local_constant_renumber(expr : @symcore.Expr) -> @symcore.Expr {
  let constants_found : Array[String] = []
  let reordered = local_constant_renumber_inner(expr, constants_found)
  let env : Map[String, @symcore.Expr] = {}
  for i in 0..<constants_found.length() {
    env[constants_found[i]] = @symcore.Expr::Symbol("C\{i + 1}")
  }
  @symcore.subst(reordered, env)
}

///|
fn expr_semantically_equal(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  let diff = @symsimplify.simplify(lhs + @symcore.int(-1) * rhs)
  @symcore.compare_expr(diff, @symcore.int(0)) == 0 || @symcore.is_zero(diff)
}

///|
fn solution_dict_text(
  solution : Map[String, @symcore.Expr],
  names : Array[String],
) -> String {
  let items : Array[String] = []
  for name in names {
    match solution.get(name) {
      Some(value) => items.push(name + ": " + @symprint.to_string(value))
      None => ()
    }
  }
  "{" + items.join(", ") + "}"
}

///|
fn maybe_bool_text(value : Bool?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "None"
  }
}

///|
fn maybe_expr_text(value : @symcore.Expr?) -> String {
  match value {
    Some(v) => @symprint.to_string(v)
    None => "None"
  }
}

///|
fn maybe_expr_compare_text(value : @symcore.Expr?, expected : @symcore.Expr) -> String {
  match value {
    Some(v) => @symcore.compare_expr(v, expected).to_string()
    None => "None"
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
test "linear_eq_to_matrix builds coefficient and rhs matrices" {
  let (a, b) = linear_eq_to_matrix(
    [
      @symcore.add([x(), y(), @symcore.int(-3)]),
      @symcore.add([
        x(),
        @symcore.mul([@symcore.int(-1), y()]),
        @symcore.int(-1),
      ]),
    ],
    [x(), y()],
  )
  inspect(a.to_string(), content="Matrix([[1, 1], [1, -1]])")
  inspect(b.to_string(), content="Matrix([[3], [1]])")
}

///|
test "linsolve solves equation input with unique solution" {
  let result = linsolve(
    linsolve_equations_input([
      @symcore.add([x(), y(), @symcore.int(-3)]),
      @symcore.add([
        x(),
        @symcore.mul([@symcore.int(-1), y()]),
        @symcore.int(-1),
      ]),
    ]),
    [x(), y()],
  )
  inspect(@symsets.to_string(result), content="{(2, 1)}")
}

///|
test "linsolve keeps parametric solutions in tuple form" {
  let result = linsolve(
    linsolve_equations_input([
      @symcore.add([x(), y(), z(), @symcore.int(-3)]),
      @symcore.add([
        x(),
        @symcore.mul([@symcore.int(-1), y()]),
        @symcore.int(-1),
      ]),
    ]),
    [x(), y(), z()],
  )
  inspect(@symsets.to_string(result), content="{(2 - z/2, 1 - z/2, z)}")
}

///|
test "solve_linear_system handles augmented matrices" {
  let system = @symmatrices.matrix([
    [@symcore.int(1), @symcore.int(1), @symcore.int(3)],
    [@symcore.int(1), @symcore.int(-1), @symcore.int(1)],
  ])
  let solved = solve_linear_system(system, [x(), y()]).unwrap_or({})
  inspect(
    @symprint.to_string(solved.get("x").unwrap_or(@symcore.int(0))),
    content="2",
  )
  inspect(
    @symprint.to_string(solved.get("y").unwrap_or(@symcore.int(0))),
    content="1",
  )
}

///|
test "solve_linear_system_LU uses dense matrix solve" {
  let system = @symmatrices.matrix([
    [@symcore.int(2), @symcore.int(1), @symcore.int(5)],
    [@symcore.int(1), @symcore.int(-1), @symcore.int(1)],
  ])
  let solved = solve_linear_system_LU(system, [x(), y()]).unwrap_or({})
  inspect(
    @symprint.to_string(solved.get("x").unwrap_or(@symcore.int(0))),
    content="2",
  )
  inspect(
    @symprint.to_string(solved.get("y").unwrap_or(@symcore.int(0))),
    content="1",
  )
}

///|
test "det_quick and inv_quick delegate to matrix algorithms" {
  let m = @symmatrices.matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  inspect(@symprint.to_string(det_quick(m)), content="-2")
  inspect(inv_quick(m).to_string(), content="Matrix([[-2, 1], [3/2, -1/2]])")
}

///|
test "checksol substitutes and verifies exact equalities" {
  inspect(
    checksol(@symcore.add([x(), @symcore.int(-2)]), x(), @symcore.int(2))
    .map(v => v.to_string())
    .unwrap_or("None"),
    content="true",
  )
  inspect(
    checksol(
      @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), @symcore.int(2)),
      x(),
      @symcore.int(3),
    )
    .map(v => v.to_string())
    .unwrap_or("None"),
    content="false",
  )
}

///|
test "complexes alias and solve_linear expose basic solver front door" {
  inspect(@symsets.to_string(complexes), content="Complexes")
  inspect(
    expr_pair_text(
      solve_linear(@symcore.add([x(), @symcore.int(2)]), symbols=[x()]),
    ),
    content="(x, -2)",
  )
}

///|
test "solveset and solve handle univariate exact equations" {
  let eq = @symcore.add([x() ^ @symcore.int(2), @symcore.int(-4)])
  inspect(
    normalize_text(
      @symsets.to_string(solveset(eq, symbol=Some(x()), domain=complexes)),
    ),
    content="{-2, 2}",
  )
  inspect(
    normalize_text(
      solve_result_text(solve(solve_expr_input(eq), symbols=[x()])),
    ),
    content="[-2, 2]",
  )
}

///|
test "nonlinsolve and solve_poly_system solve zero-dimensional polynomial systems" {
  let equations = [
    @symcore.add([x() ^ @symcore.int(2), @symcore.int(-1)]),
    @symcore.add([y(), @symcore.mul([@symcore.int(-1), x()])]),
  ]
  inspect(
    @symsets.to_string(nonlinsolve(equations, [x(), y()])),
    content="{(-1, -1), (1, 1)}",
  )
  inspect(
    expr_list_text(solve_poly_system(equations, [x(), y()])),
    content="[(-1, -1), (1, 1)]",
  )
  inspect(
    expr_list_text(solve_triangulated(equations, [x(), y()])),
    content="[(-1, -1), (1, 1)]",
  )
  inspect(
    @symsets.to_string(substitution(equations, [x(), y()])),
    content="{(-1, -1), (1, 1)}",
  )
}

///|
test "solve returns dicts for systems and nsolve refines numeric roots" {
  let equations = [
    @symcore.add([x(), y(), @symcore.int(-3)]),
    @symcore.add([x(), @symcore.mul([@symcore.int(-1), y()]), @symcore.int(-1)]),
  ]
  inspect(
    solve_result_text(solve(solve_exprs_input(equations), symbols=[x(), y()])),
    content="{x: 2, y: 1}",
  )
  let root = nsolve(
    @symcore.add([x() ^ @symcore.int(2), @symcore.int(-2)]),
    x(),
    @symcore.rational_from_ints(3, 2),
  )
  assert_true(@symprint.to_string(root).has_prefix("1.414213562"))
}

///|
test "lpmin lpmax and linprog solve basic linear programs" {
  let min_result = lpmin(
    x(),
    [@symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(1))],
  )
  inspect(@symprint.to_string(min_result.0), content="1")
  inspect(solution_dict_text(min_result.1, ["x"]), content="{x: 1}")

  let max_result = lpmax(
    x(),
    [@symcore.Expr::Relational(@symcore.RelOp::Le, x(), @symcore.int(-1))],
  )
  inspect(@symprint.to_string(max_result.0), content="-1")
  inspect(solution_dict_text(max_result.1, ["x"]), content="{x: -1}")

  let prog_result = linprog(
    [@symcore.int(1)],
    bounds=Some([(Some(@symcore.int(1)), (None : @symcore.Expr?))]),
  )
  inspect(@symprint.to_string(prog_result.0), content="1")
  inspect(expr_list_text(prog_result.1), content="[1]")
}

///|
test "lp solvers report infeasible and unbounded cases" {
  let infeasible : Result[(@symcore.Expr, Map[String, @symcore.Expr]), SolverError] = try? lpmax(
    x(),
    [
      @symcore.Expr::Relational(@symcore.RelOp::Le, x(), @symcore.int(-1)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    ],
  )
  assert_true(infeasible is Err(SolverError::InfeasibleLPError(_)))

  let unbounded : Result[(@symcore.Expr, Map[String, @symcore.Expr]), SolverError] = try? lpmin(
    x(),
    [@symcore.Expr::Relational(@symcore.RelOp::Le, x(), @symcore.int(3))],
  )
  assert_true(unbounded is Err(SolverError::UnboundedLPError(_)))
}

///|
test "lp solvers handle Eq constraints and extra symbols like SymPy simplex front doors" {
  let eq_max = lpmax(
    x() - y(),
    [
      @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
      @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y() + @symcore.int(2)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
    ],
  )
  inspect(@symprint.to_string(eq_max.0), content="2")
  inspect(solution_dict_text(eq_max.1, ["x", "y"]), content="{x: 2, y: 0}")

  let eq_min = lpmin(
    y(),
    [
      @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(0), y() + @symcore.int(2)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, @symcore.int(0), y() + @symcore.int(2)),
    ],
  )
  inspect(@symprint.to_string(eq_min.0), content="-2")
  inspect(solution_dict_text(eq_min.1, ["y"]), content="{y: -2}")

  let single_eq = lpmax(
    y(),
    [@symcore.Expr::Relational(@symcore.RelOp::Eq, y(), @symcore.int(2))],
  )
  inspect(@symprint.to_string(single_eq.0), content="2")
  inspect(solution_dict_text(single_eq.1, ["y"]), content="{y: 2}")

  let extra_symbol = lpmin(
    x(),
    [
      @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(1)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + z()),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
    ],
  )
  inspect(@symprint.to_string(extra_symbol.0), content="1")
  inspect(solution_dict_text(extra_symbol.1, ["x", "y", "z"]), content="{x: 1, y: 1, z: 0}")
}

///|
test "lp solvers match SymPy simplex four-variable reference example" {
  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let result = lpmax(
    x1 - @symcore.int(2) * x2 - @symcore.int(3) * x3 - x4,
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        x1 - x2 - @symcore.int(2) * x3 - x4,
        @symcore.int(4),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(2) * x1 + x3 - @symcore.int(4) * x4,
        @symcore.int(2),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(-2) * x1 + x2 + x4,
        @symcore.int(1),
      ),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x1, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x2, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x3, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x4, @symcore.int(0)),
    ],
  )
  inspect(@symprint.to_string(result.0), content="4")
  inspect(solution_dict_text(result.1, ["x1", "x2", "x3", "x4"]), content="{x1: 7, x2: 0, x3: 0, x4: 3}")
}

///|
test "linprog matches first SymPy simplex reference example" {
  let objective = x() + y() - @symcore.int(2) * z()
  let ineq = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(7) * x() + @symcore.int(4) * y() - @symcore.int(7) * z(),
      @symcore.int(3),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(3) * x() - y() + @symcore.int(10) * z(),
      @symcore.int(6),
    ),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
  ]
  let min_result = lpmin(objective, ineq)
  inspect(@symprint.to_string(min_result.0), content="-6/5")
  inspect(solution_dict_text(min_result.1, ["x", "y", "z"]), content="{x: 0, y: 0, z: 3/5}")

  let prog_result = linprog(
    [@symcore.int(1), @symcore.int(1), @symcore.int(-2)],
    a=Some(
      @symmatrices.matrix([
        [@symcore.int(7), @symcore.int(4), @symcore.int(-7)],
        [@symcore.int(3), @symcore.int(-1), @symcore.int(10)],
      ]),
    ),
    b=Some([@symcore.int(3), @symcore.int(6)]),
  )
  inspect(@symprint.to_string(prog_result.0), content="-6/5")
  inspect(expr_list_text(prog_result.1), content="[0, 0, 3/5]")
}

///|
test "decompogen factors functional composition and polynomial composition" {
  inspect(
    expr_list_text(decompogen(sin(cos(x())), x())),
    content="[sin(x), cos(x)]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        decompogen(
          @symcore.add([sin(x()) ^ @symcore.int(2), sin(x()), @symcore.int(1)]),
          x(),
        ),
      ),
    ),
    content="[x**2 + x + 1, sin(x)]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        decompogen(
          sqrt(@symcore.add([@symcore.mul([@symcore.int(6), x() ^ @symcore.int(2)]), @symcore.int(-5)])),
          x(),
        ),
      ),
    ),
    content="[sqrt(x), 6*x**2 - 5]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        decompogen(
          sin(sqrt(cos((x() ^ @symcore.int(2)) + @symcore.int(1)))),
          x(),
        ),
      ),
    ),
    content="[sin(x), sqrt(x), cos(x), x**2 + 1]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        decompogen(
          @symcore.function(
            "Abs",
            [(cos(x()) ^ @symcore.int(2)) + @symcore.int(3) * cos(x()) + @symcore.int(-4)],
          ),
          x(),
        ),
      ),
    ),
    content="[Abs(x), x**2 + 3*x - 4, cos(x)]",
  )
  let trig_poly = decompogen(
    (sin(x()) ^ @symcore.int(2)) + sin(x()) + @symcore.mul([@symcore.int(-1), sqrt(@symcore.int(3)), @symcore.pow(@symcore.int(2), @symcore.int(-1))]),
    x(),
  )
  let trig_poly_expected = [
    @symcore.add([
      x() ^ @symcore.int(2),
      x(),
      @symcore.mul([@symcore.int(-1), sqrt(@symcore.int(3)), @symcore.pow(@symcore.int(2), @symcore.int(-1))]),
    ]),
    sin(x()),
  ]
  assert_eq(trig_poly.length(), trig_poly_expected.length())
  for i in 0..<trig_poly.length() {
    assert_true(expr_semantically_equal(trig_poly[i], trig_poly_expected[i]))
  }
  let mixed_abs = decompogen(
    @symcore.function(
      "Abs",
      [(cos(y()) ^ @symcore.int(2)) + @symcore.int(3) * cos(x()) + @symcore.int(-4)],
    ),
    x(),
  )
  let mixed_abs_expected = [
    @symcore.function("Abs", [x()]),
    @symcore.int(3) * x() + (cos(y()) ^ @symcore.int(2)) + @symcore.int(-4),
    cos(x()),
  ]
  assert_eq(mixed_abs.length(), mixed_abs_expected.length())
  for i in 0..<mixed_abs.length() {
    assert_true(expr_semantically_equal(mixed_abs[i], mixed_abs_expected[i]))
  }
  inspect(expr_list_text(decompogen(x(), y())), content="[x]")
  inspect(expr_list_text(decompogen(@symcore.int(1), x())), content="[1]")
  inspect(
    expr_list_text(decompogen(@symcore.function("Max", [@symcore.int(3), x()]), x())),
    content="[Max(3, x)]",
  )
  let u_linear = @symcore.int(2) * x() + @symcore.int(3)
  inspect(
    normalize_text(
      expr_list_text(
        decompogen(
          @symcore.function("Max", [sqrt(u_linear), u_linear ^ @symcore.int(2)]),
          x(),
        ),
      ),
    ),
    content="[Max(sqrt(x), x**2), 2*x + 3]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        decompogen(
          @symcore.function("Max", [u_linear, u_linear ^ @symcore.int(2), y()]),
          x(),
        ),
      ),
    ),
    content="[Max(x, x**2, y), 2*x + 3]",
  )
  inspect(
    expr_list_text(
      decompogen(
        @symcore.function("Max", [sin(x()), u_linear]),
        x(),
      ),
    ),
    content="[Max(sin(x), 2*x + 3)]",
  )
  inspect(
    normalize_text(expr_list_text(decompogen((x() ^ @symcore.int(4)) + @symcore.int(2) * (x() ^ @symcore.int(2)) + @symcore.int(1), x()))),
    content="[x**2 + 2*x + 1, x**2]",
  )
  let quartic_poly = decompogen(
    (x() ^ @symcore.int(4)) + @symcore.int(2) * (x() ^ @symcore.int(3)) - x() + @symcore.int(-1),
    x(),
  )
  let quartic_poly_expected = [
    (x() ^ @symcore.int(2)) - x() + @symcore.int(-1),
    (x() ^ @symcore.int(2)) + x(),
  ]
  assert_eq(quartic_poly.length(), quartic_poly_expected.length())
  for i in 0..<quartic_poly.length() {
    assert_true(expr_semantically_equal(quartic_poly[i], quartic_poly_expected[i]))
  }
  let relational_try : Result[Array[@symcore.Expr], SolverError] = try? decompogen(
    @symcore.Expr::Relational(@symcore.RelOp::Lt, x(), @symcore.int(5)),
    x(),
  )
  assert_true(relational_try is Err(SolverError::ValueError(_)))
}

///|
test "compogen composes source-compatible examples" {
  inspect(@symprint.to_string(compogen([sin(x()), cos(x())], x())), content="sin(cos(x))")
  inspect(
    normalize_text(@symprint.to_string(compogen([(x() ^ @symcore.int(2)) + x() + @symcore.int(1), sin(x())], x()))),
    content="sin(x)**2 + sin(x) + 1",
  )
  inspect(
    normalize_text(@symprint.to_string(compogen([sqrt(x()), @symcore.int(6) * (x() ^ @symcore.int(2)) + @symcore.int(-5)], x()))),
    content="sqrt(6*x**2 - 5)",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        compogen(
          [sin(x()), sqrt(x()), cos(x()), (x() ^ @symcore.int(2)) + @symcore.int(1)],
          x(),
        ),
      ),
    ),
    content="sin(sqrt(cos(x**2 + 1)))",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        compogen(
          [@symcore.function("Abs", [x()]), (x() ^ @symcore.int(2)) + @symcore.int(3) * x() + @symcore.int(-4), cos(x())],
          x(),
        ),
      ),
    ),
    content="Abs(cos(x)**2 + 3*cos(x) - 4)",
  )
  assert_true(
    expr_semantically_equal(
      compogen(
        [
          (x() ^ @symcore.int(2)) + x() + @symcore.mul([@symcore.int(-1), sqrt(@symcore.int(3)), @symcore.pow(@symcore.int(2), @symcore.int(-1))]),
          sin(x()),
        ],
        x(),
      ),
      @symcore.add([
        sin(x()) ^ @symcore.int(2),
        sin(x()),
        @symcore.mul([@symcore.int(-1), sqrt(@symcore.int(3)), @symcore.pow(@symcore.int(2), @symcore.int(-1))]),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      compogen(
        [
          (x() ^ @symcore.int(2)) + @symcore.int(3) * x() + (cos(y()) ^ @symcore.int(2)) + @symcore.int(-4),
          cos(x()),
        ],
        x(),
      ),
      (cos(x()) ^ @symcore.int(2)) + @symcore.int(3) * cos(x()) + (cos(y()) ^ @symcore.int(2)) + @symcore.int(-4),
    ),
  )
  inspect(
    normalize_text(
      @symprint.to_string(compogen([(x() ^ @symcore.int(2)) + @symcore.int(2) * x() + @symcore.int(1), x() ^ @symcore.int(2)], x())),
    ),
    content="x**4 + 2*x**2 + 1",
  )
  assert_true(
    expr_semantically_equal(
      compogen([(x() ^ @symcore.int(2)) - x() + @symcore.int(-1), (x() ^ @symcore.int(2)) + x()], x()),
      @symcore.add([
        @symcore.pow((x() ^ @symcore.int(2)) + x(), @symcore.int(2)),
        @symcore.mul([@symcore.int(-1), x() ^ @symcore.int(2)]),
        @symcore.mul([@symcore.int(-1), x()]),
        @symcore.int(-1),
      ]),
    ),
  )
}

///|
test "assumption helpers follow tri-valued semantics" {
  inspect(
    maybe_bool_text(
      check_assumptions(
        @symcore.int(3),
        assumptions=assumption_map([("integer", Some(true)), ("real", Some(true))]),
      ),
    ),
    content="true",
  )
  inspect(
    maybe_bool_text(
      check_assumptions(
        x(),
        assumptions=assumption_map([("integer", Some(true))]),
      ),
    ),
    content="None",
  )
  let failed = failing_assumptions(
    @symcore.int(-2),
    assumption_map([("positive", Some(true)), ("real", Some(true))]),
  )
  inspect(
    maybe_bool_text(failed.get("positive").unwrap_or(None)),
    content="false",
  )
  inspect(
    (failed.get("real") is None).to_string(),
    content="true",
  )
}

///|
test "solve_undetermined_coeffs matches coefficients into symbolic dicts" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  inspect(
    maybe_solve_result_text(
      solve_undetermined_coeffs(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.add([@symcore.mul([a, x()]), b]),
          @symcore.add([x(), @symcore.int(2)]),
        ),
        [a, b],
        syms=[x()],
      ),
    ),
    content="{a: 1, b: 2}",
  )
  inspect(
    maybe_solve_result_text(
      solve_undetermined_coeffs(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.add([@symcore.mul([a ^ @symcore.int(2), x()]), b]),
          x(),
        ),
        [a, b],
        syms=[x()],
        dict=true,
      ),
    ),
    content="[{a: -1, b: 0}, {a: 1, b: 0}]",
  )
  inspect(
    maybe_solve_result_text(
      solve_undetermined_coeffs(sin(x()), [c], syms=[x()]),
    ),
    content="[]",
  )
}

///|
test "canonical_odes covers low-level source-compatible entry points" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")
  inspect(allhints.length().to_string(), content="45")
  inspect(allhints[0], content="factorable")
  inspect(
    allhints[allhints.length() - 1],
    content="2nd_nonlinear_autonomous_conserved_Integral",
  )
  inspect(
    @symprint.to_string(constantsimp(c1 + c2, [c1, c2])),
    content="C1",
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
  let canonical = canonical_odes(system, [f(x()), g(x())], x())
  inspect(canonical.length().to_string(), content="1")
  inspect(
    normalize_text(expr_matrix_text(canonical)),
    content="[[Eq(Derivative(f(x), x), 7*f(x) + 12*g(x)), Eq(Derivative(g(x), x), 20*f(x) - g(x))]]",
  )
}

///|
test "constantsimp matches initial SymPy constantsimp cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")

  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(y() * c1, [c1])), c1 * y()),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(x() * c1, [c1])), x() * c1),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(@symcore.int(2) * c1, [c1])), c1),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(y() * c1 * x(), [c1, y()])), c1 * x()),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(c1 * x() * y() * x() * y() * @symcore.int(2), [c1, y()])), c1 * (x() ^ @symcore.int(2))),
  )

  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(c1 + c1, [c1])), c1),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(c1 + @symcore.int(2), [c1])), c1),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(c1 + y(), [c1, y()])), c1),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(c1 + x(), [c1])), c1 + x()),
  )
  assert_true(
    expr_semantically_equal(local_constant_renumber(constantsimp(c1 + c2 + c1, [c1, c2])), c1),
  )

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.function("exp", [c1 + x()]), [c1])),
      c1 * @symcore.function("exp", [x()]),
    ),
  )
}

///|
test "constantsimp matches SymPy power cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")

  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(c1 ^ c1, [c1])), c1))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(c1 ^ c2, [c1, c2])), c1))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(c2 ^ c1, [c1, c2])), c1))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(c1 ^ y(), [c1, y()])), c1))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(c1 ^ x(), [c1])), c1 ^ x()))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(c1 ^ @symcore.int(2), [c1])), c1))
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 ^ (x() * y()), [c1])),
      c1 ^ (x() * y()),
    ),
  )

  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(x() ^ c1, [c1])), x() ^ c1))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(y() ^ c1, [c1, y()])), c1))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(x() ^ (y() ^ c1), [c1, y()])), x() ^ c1))
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp((x() ^ y()) ^ c1, [c1])),
      (x() ^ y()) ^ c1,
    ),
  )
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(x() ^ (c1 ^ y()), [c1, y()])), x() ^ c1))
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(@symcore.int(2) ^ c1, [c1])), c1))
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.function("exp", [c1]), [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.function("exp", [c1 + x()]), [c1])),
      c1 * @symcore.function("exp", [x()]),
    ),
  )
}

///|
test "constantsimp matches SymPy function and mixed cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.function("sin", [c1]), [c1])),
      c1,
    ),
  )
  assert_true(expr_semantically_equal(local_constant_renumber(constantsimp(f(c1), [c1])), c1))
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.applied_undefined_function("f", [c1, c1]), [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.applied_undefined_function("f", [c1, c2]), [c1, c2])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.applied_undefined_function("f", [c1, x()]), [c1])),
      @symcore.applied_undefined_function("f", [c1, x()]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.applied_undefined_function("f", [c1, y()]), [c1, y()])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.applied_undefined_function("f", [c1, y(), c2]), [c1, c2, y()])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.applied_undefined_function("f", [c1, c1, x()]), [c1])),
      @symcore.applied_undefined_function("f", [c1, c1, x()]),
    ),
  )

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 * @symcore.int(2) + @symcore.int(2), [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(x() * @symcore.int(2) * (c1 ^ @symcore.int(-1)), [c1])),
      c1 * x(),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp((c1 ^ @symcore.int(2)) * @symcore.int(2) + @symcore.int(2), [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(
          @symcore.function("sin", [@symcore.int(2) * c1]) + x() + @symcore.function("sqrt", [@symcore.int(2)]),
          [c1],
        ),
      ),
      c1 + x(),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.int(2) * c1 + c2, [c1, c2])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(c1 + c1 * x()),
      c1 + c1 * x(),
    ),
  )
}

///|
test "constantsimp matches SymPy Eq normalization cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let eq_add = constantsimp(
    @symcore.Expr::Relational(@symcore.RelOp::Eq, c1, @symcore.int(3) + f(x()) * x()),
    [c1],
  )
  assert_eq(
    @symcore.compare_expr(
      local_constant_renumber(eq_add),
      @symcore.Expr::Relational(@symcore.RelOp::Eq, x() * f(x()), c1),
    ),
    0,
  )
  let eq_mul = constantsimp(
    @symcore.Expr::Relational(@symcore.RelOp::Eq, c1, @symcore.int(3) * f(x()) * x()),
    [c1],
  )
  assert_eq(
    @symcore.compare_expr(
      local_constant_renumber(eq_mul),
      @symcore.Expr::Relational(@symcore.RelOp::Eq, x() * f(x()), c1),
    ),
    0,
  )
}

///|
test "constantsimp matches initial SymPy ODE solution normalization cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")
  let c3 = @symcore.Expr::Symbol("C3")
  let u2 = @symcore.Expr::Symbol("u2")
  let a0 = @symcore.Expr::Symbol("_a")
  let one_third = @symcore.rational_from_ints(1, 3) catch { _ => fail("one_third") }
  let imag = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(
          c1 * @symcore.function("exp", [@symcore.int(2) * x()]) +
          @symcore.function("exp", [x()]) * (c2 + c3),
          [c1, c2, c3],
        ),
      ),
      local_constant_renumber(
        c1 * @symcore.function("exp", [x()]) +
        c2 * @symcore.function("exp", [@symcore.int(2) * x()]),
      ),
    ),
  )

  let hyperbolic = local_constant_renumber(
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        f(x()),
        imag * c1 * @symcore.function("sinh", [x() * one_third]) +
        c2 * @symcore.function("cosh", [x() * one_third]),
      ),
      [c1, c2],
    ),
  )
  let hyperbolic_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      f(x()),
      c1 * @symcore.function("sinh", [x() * one_third]) +
      c2 * @symcore.function("cosh", [x() * one_third]),
    ),
  )
  assert_eq(@symcore.compare_expr(hyperbolic, hyperbolic_expected), 0)

  let acos_case = local_constant_renumber(
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        f(x()),
        @symcore.function(
          "acos",
          [@symcore.int(-1) * c1 * (cos(x()) ^ @symcore.int(-1))],
        ),
      ),
      [c1],
    ),
  )
  let acos_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      f(x()),
      @symcore.function("acos", [c1 * (cos(x()) ^ @symcore.int(-1))]),
    ),
  )
  assert_eq(@symcore.compare_expr(acos_case, acos_expected), 0)

  let log_case = local_constant_renumber(
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.function("log", [f(x()) * (c1 ^ @symcore.int(-1))]) +
        @symcore.int(2) * @symcore.function("exp", [x() * (f(x()) ^ @symcore.int(-1))]),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  let log_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.function("log", [c1 * f(x())]) +
      @symcore.int(2) * @symcore.function("exp", [x() * (f(x()) ^ @symcore.int(-1))]),
      @symcore.int(0),
    ),
  )
  assert_eq(@symcore.compare_expr(log_case, log_expected), 0)

  let sqrt_log_case = local_constant_renumber(
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        (x() ^ @symcore.int(2)) * (@symcore.int(2) ^ @symcore.int(-1)) * (f(x()) ^ @symcore.int(-2)) +
        @symcore.function(
          "log",
          [
            sqrt(@symcore.int(2)) *
            x() *
            sqrt(x() ^ @symcore.int(-1)) *
            sqrt(f(x())) *
            (c1 ^ @symcore.int(-1)),
          ],
        ),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  let sqrt_log_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      (x() ^ @symcore.int(2)) * (@symcore.int(2) ^ @symcore.int(-1)) * (f(x()) ^ @symcore.int(-2)) +
      @symcore.function("log", [c1 * sqrt(x()) * sqrt(f(x()))]),
      @symcore.int(0),
    ),
  )
  assert_eq(@symcore.compare_expr(sqrt_log_case, sqrt_log_expected), 0)

  let ratio = f(x()) * (x() ^ @symcore.int(-1))
  let exp_ratio = @symcore.function("exp", [@symcore.int(-1) * ratio])
  let trig_log_case = local_constant_renumber(
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.function("log", [x() * (c1 ^ @symcore.int(-1))]) -
        exp_ratio * sin(ratio) * (@symcore.int(2) ^ @symcore.int(-1)) -
        exp_ratio * cos(ratio) * (@symcore.int(2) ^ @symcore.int(-1)),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  let trig_log_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.function("log", [c1 * x()]) -
      exp_ratio * sin(ratio) * (@symcore.int(2) ^ @symcore.int(-1)) -
      exp_ratio * cos(ratio) * (@symcore.int(2) ^ @symcore.int(-1)),
      @symcore.int(0),
    ),
  )
  assert_eq(@symcore.compare_expr(trig_log_case, trig_log_expected), 0)

  let sqrt_pair = [
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        f(x()),
        sqrt(@symcore.int(-1) * c1 * x() + (x() ^ @symcore.int(2))),
      ),
      [c1],
    ),
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        f(x()),
        @symcore.int(-1) * sqrt(@symcore.int(-1) * c1 * x() + (x() ^ @symcore.int(2))),
      ),
      [c1],
    ),
  ]
  let sqrt_pair_expected = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      f(x()),
      sqrt(x() * (c1 + x())),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      f(x()),
      @symcore.int(-1) * sqrt(x() * (c1 + x())),
    ),
  ]
  assert_eq(expr_list_text(sqrt_pair), expr_list_text(sqrt_pair_expected))

  let integral_case = local_constant_renumber(
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.int(-1) *
        @symcore.function(
          "Integral",
          [
            @symcore.int(-1) *
            ((u2 * sqrt(@symcore.int(1) - (u2 ^ @symcore.int(2)))) ^ @symcore.int(-1)),
            @symcore.Expr::Tuple([u2, a0, x() * (f(x()) ^ @symcore.int(-1))]),
          ],
        ) +
        @symcore.function("log", [f(x()) * (c1 ^ @symcore.int(-1))]),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  let integral_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.int(-1) *
      @symcore.function(
        "Integral",
        [
          @symcore.int(-1) *
          ((u2 * sqrt(@symcore.int(1) - (u2 ^ @symcore.int(2)))) ^ @symcore.int(-1)),
          @symcore.Expr::Tuple([u2, a0, x() * (f(x()) ^ @symcore.int(-1))]),
        ],
      ) +
      @symcore.function("log", [c1 * f(x())]),
      @symcore.int(0),
    ),
  )
  assert_eq(@symcore.compare_expr(integral_case, integral_expected), 0)
}

///|
test "constantsimp matches current upstream XFAIL nonlocal simplification behavior" {
  // Upstream keeps this under @XFAIL. Pin current SymPy runtime behavior so
  // our compat layer does not drift while the upstream bug remains open.
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")
  let nonlocal_case = constantsimp(c1 + c2 + x() * c2, [c1, c2])
  let nonlocal_expected = c1 + c2 * x() + c2
  assert_true(expr_semantically_equal(nonlocal_case, nonlocal_expected))
}

///|
test "linear_ode_to_matrix covers low-level source-compatible entry points" {
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
  let (a_mats, b_mat) = linear_ode_to_matrix(system, [f(x()), g(x())], x(), 1)
  inspect(a_mats[0].to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(a_mats[1].to_string(), content="Matrix([[7, 12], [20, -1]])")
  inspect(b_mat.to_string(), content="Matrix([[0], [0]])")
}

///|
test "canonical_odes and linear_ode_to_matrix handle nonlinear branches and higher order systems" {
  let nonlinear_system = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      (@symcalculus.diff(f(x()), x()) ^ @symcore.int(2)) +
      @symcore.mul([@symcore.int(-2), @symcalculus.diff(f(x()), x())]) +
      @symcore.int(1),
      @symcore.int(4),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.add([
        @symcore.mul([@symcore.int(-1), y(), f(x())]),
        @symcalculus.diff(g(x()), x()),
      ]),
      @symcore.int(0),
    ),
  ]
  let canonical = canonical_odes(nonlinear_system, [f(x()), g(x())], x())
  inspect(canonical.length().to_string(), content="2")
  inspect(
    normalize_text(expr_list_text(canonical[0])),
    content="[Eq(Derivative(f(x), x), -1), Eq(Derivative(g(x), x), y*f(x))]",
  )
  inspect(
    normalize_text(expr_list_text(canonical[1])),
    content="[Eq(Derivative(f(x), x), 3), Eq(Derivative(g(x), x), y*f(x))]",
  )

  let higher_order = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(@symcalculus.diff(f(x()), x()), x()),
      @symcore.add([
        @symcalculus.diff(f(x()), x()),
        f(x()),
        g(x()),
        @symcore.int(1),
      ]),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(@symcalculus.diff(g(x()), x()), x()),
      @symcore.add([
        @symcore.int(2) * @symcalculus.diff(g(x()), x()),
        @symcore.mul([@symcore.int(-1), f(x())]),
      ]),
    ),
  ]
  let (a_mats, b_mat) = linear_ode_to_matrix(higher_order, [f(x()), g(x())], x(), 2)
  inspect(a_mats.length().to_string(), content="3")
  inspect(a_mats[0].to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(a_mats[1].to_string(), content="Matrix([[1, 0], [0, 2]])")
  inspect(a_mats[2].to_string(), content="Matrix([[1, 1], [-1, 0]])")
  inspect(b_mat.to_string(), content="Matrix([[1], [0]])")
}

///|
test "linodesolve covers low-level source-compatible entry points" {
  inspect(
    linodesolve(@symmatrices.matrix([[@symcore.int(1)]]), x()).to_string(),
    content="Matrix([[C1*exp(x)]])",
  )
  inspect(
    normalize_text(
      linodesolve(
        @symmatrices.matrix([
          [@symcore.int(1), @symcore.int(1)],
          [@symcore.int(0), @symcore.int(1)],
        ]),
        x(),
      ).to_string(),
    ),
  content=(#|Matrix([[x*C2*exp(x) + C1*exp(x)], [C2*exp(x)]])
  ))
  inspect(
    normalize_text(
      linodesolve(
        @symmatrices.matrix([
          [@symcore.int(1), @symcore.int(2)],
          [@symcore.int(0), @symcore.int(3)],
        ]),
        x(),
      ).to_string(),
    ),
  content=(#|Matrix([[C1*exp(x) + C2*exp(3*x) - C2*exp(x)], [C2*exp(3*x)]])
  ))
}

///|
test "lie helpers cover source-compatible infinitesimal entry points" {
  let lie_eq = @symcalculus.diff(f(x()), x()) - (x() ^ @symcore.int(2)) * f(x())
  let infs = infinitesimals(lie_eq, func=Some(f(x())))
  inspect(
    @symprint.to_string(infs[0].get("xi").unwrap_or(@symcore.int(1))),
    content="0",
  )
  inspect(
    normalize_text(@symprint.to_string(infs[0].get("eta").unwrap_or(@symcore.int(0)))),
    content="exp(x**3/3)",
  )
  let inf_check = checkinfsol(lie_eq, infs, func=Some(f(x())))
  inspect(inf_check[0].0.to_string(), content="true")
  inspect(@symprint.to_string(inf_check[0].1), content="0")
}

///|
test "lie heuristics expose abaco1_simple explicitly" {
  let lie_eq = @symcalculus.diff(f(x()), x()) - (x() ^ @symcore.int(2)) * f(x())
  let abaco = infinitesimals(lie_eq, func=Some(f(x())), hint="abaco1_simple")
  inspect(abaco.length().to_string(), content="3")
  inspect(
    normalize_text(@symprint.to_string(abaco[1].get("eta").unwrap_or(@symcore.int(0)))),
    content="f(x)",
  )
  inspect(
    normalize_text(@symprint.to_string(abaco[2].get("xi").unwrap_or(@symcore.int(0)))),
    content="x**-2",
  )
  let checks = checkinfsol(lie_eq, abaco, func=Some(f(x())))
  inspect(checks.all(item => item.0).to_string(), content="true")
}

///|
test "canonical_odes matches additional SymPy explicit linear case" {
  let system_1 = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(@symcalculus.diff(f(x()), x()), x()),
      f(x()) + @symcore.int(2) * g(x()),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      g(x()) + @symcore.int(1),
      @symcalculus.diff(g(x()), x()) + f(x()),
    ),
  ]
  inspect(ode_order(system_1[0], f(x())).to_string(), content="2")
  inspect(ode_order(system_1[1], g(x())).to_string(), content="1")
  inspect(
    normalize_text(expr_matrix_text(canonical_odes(system_1, [f(x()), g(x())], x()))),
    content="[[Eq(Derivative(f(x), x, x), f(x) + 2*g(x)), Eq(Derivative(g(x), x), -f(x) + g(x) + 1)]]",
  )
}

///|
test "canonical_odes matches additional SymPy triangular nonlinear case" {
  let system_2 = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(f(x()), x()),
      @symcalculus.diff(h(x()), x()) + f(x()),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(g(x()), x()) ^ @symcore.int(2),
      f(x()) + h(x()),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(h(x()), x()),
      f(x()),
    ),
  ]
  inspect(canonical_odes(system_2, [f(x()), g(x()), h(x())], x()).length().to_string(), content="2")
  inspect(
    normalize_text(expr_list_text(canonical_odes(system_2, [f(x()), g(x()), h(x())], x())[0])),
    content="[Eq(Derivative(f(x), x), 2*f(x)), Eq(Derivative(g(x), x), -sqrt(f(x) + h(x))), Eq(Derivative(h(x), x), f(x))]",
  )
  inspect(
    normalize_text(expr_list_text(canonical_odes(system_2, [f(x()), g(x()), h(x())], x())[1])),
    content="[Eq(Derivative(f(x), x), 2*f(x)), Eq(Derivative(g(x), x), sqrt(f(x) + h(x))), Eq(Derivative(h(x), x), f(x))]",
  )
}

///|
test "linear_ode_to_matrix matches additional SymPy matrix forms and errors" {
  let system_3 = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.int(2) * @symcalculus.diff(f(x()), x()) +
      @symcore.int(3) * @symcalculus.diff(h(x()), x()),
      f(x()) + g(x()),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.int(4) * @symcalculus.diff(h(x()), x()) +
      @symcore.int(5) * @symcalculus.diff(g(x()), x()),
      f(x()) + h(x()),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.int(5) * @symcalculus.diff(f(x()), x()) +
      @symcore.int(4) * @symcalculus.diff(g(x()), x()),
      g(x()) + h(x()),
    ),
  ]
  let (a_sys3, b_sys3) = linear_ode_to_matrix(system_3, [f(x()), g(x()), h(x())], x(), 1)
  inspect(a_sys3[0].to_string(), content="Matrix([[2, 0, 3], [0, 5, 4], [5, 4, 0]])")
  inspect(a_sys3[1].to_string(), content="Matrix([[1, 1, 0], [1, 0, 1], [0, 1, 1]])")
  inspect(b_sys3.to_string(), content="Matrix([[0], [0], [0]])")

  let system_4 = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(@symcalculus.diff(f(x()), x()), x()) + h(x()),
      @symcalculus.diff(f(x()), x()) + g(x()),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.int(2) * @symcalculus.diff(@symcalculus.diff(h(x()), x()), x()) +
      @symcalculus.diff(@symcalculus.diff(g(x()), x()), x()) +
      @symcalculus.diff(g(x()), x()) +
      g(x()),
      @symcore.int(0),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.int(3) * @symcalculus.diff(h(x()), x()),
      @symcore.int(4),
    ),
  ]
  let (a_sys4, b_sys4) = linear_ode_to_matrix(system_4, [f(x()), g(x()), h(x())], x(), 2)
  inspect(a_sys4[0].to_string(), content="Matrix([[1, 0, 0], [0, 1, 2], [0, 0, 0]])")
  inspect(a_sys4[1].to_string(), content="Matrix([[1, 0, 0], [0, -1, 0], [0, 0, -3]])")
  inspect(a_sys4[2].to_string(), content="Matrix([[0, 1, -1], [0, -1, 0], [0, 0, 0]])")
  inspect(b_sys4.to_string(), content="Matrix([[0], [0], [4]])")

  let bad_order : Result[(Array[@symmatrices.Matrix], @symmatrices.Matrix), SolverError] = try?
    linear_ode_to_matrix(
      [
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcalculus.diff(@symcalculus.diff(f(x()), x()), x()),
          g(x()),
        ),
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcalculus.diff(f(x()), x()) + @symcalculus.diff(g(x()), x()),
          f(x()),
        ),
      ],
      [f(x()), g(x())],
      x(),
      1,
    )
  inspect(
    match bad_order {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"Cannot represent system in 1-order form\")",
  )

  let nonlinear : Result[(Array[@symmatrices.Matrix], @symmatrices.Matrix), SolverError] = try?
    linear_ode_to_matrix(
      [
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcalculus.diff(f(x()), x()),
          f(x()) ^ @symcore.int(2),
        ),
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcalculus.diff(g(x()), x()),
          f(x()) + g(x()),
        ),
      ],
      [f(x()), g(x())],
      x(),
      1,
    )
  inspect(
    match nonlinear {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"The system of ODEs is nonlinear.\")",
  )
}

///|
test "lie heuristic abaco1_product follows SymPy reference case" {
  let abaco1_product_eq = @symcalculus.diff(f(x()), x()) -
    @symcore.mul([
      f(x()),
      @symcore.add([
        x() * @symcore.function(
          "log",
          [
            @symcore.mul([
              x() ^ @symcore.int(2),
              f(x()) ^ @symcore.int(-1),
            ]),
          ],
        ),
        @symcore.int(2),
      ]),
      x() ^ @symcore.int(-1),
    ])
  let abaco1_product_inf = infinitesimals(
    abaco1_product_eq,
    func=Some(f(x())),
    hint="abaco1_product",
  )
  inspect(
    normalize_text(local_infinitesimals_text(abaco1_product_inf)),
    content="[{xi: 0, eta: f(x)*exp(-x)}]",
  )
  inspect(
    checkinfsol(abaco1_product_eq, abaco1_product_inf, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

///|
test "lie heuristic chi follows SymPy reference case" {
  let chi_eq = x() * @symcalculus.diff(f(x()), x()) + @symcore.int(1) - (f(x()) ^ @symcore.int(2))
  let chi_inf = infinitesimals(chi_eq, func=Some(f(x())), hint="chi")
  inspect(checkinfsol(chi_eq, chi_inf, func=Some(f(x())))[0].0.to_string(), content="true")
}

///|
test "lie heuristic function_sum follows SymPy reference case" {
  let function_sum_eq = @symcalculus.diff(f(x()), x()) -
    @symcore.add([
      @symcore.mul([
        @symcore.int(3),
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([
            x() ^ @symcore.int(2),
            f(x()) ^ @symcore.int(-2),
          ]),
        ]),
        @symcore.function(
          "atan",
          [@symcore.mul([f(x()), x() ^ @symcore.int(-1)])],
        ),
      ]),
      @symcore.mul([
        @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-2), f(x())])]),
        x() ^ @symcore.int(-1),
      ]),
      @symcore.mul([
        @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-3), f(x())])]),
        x(),
        f(x()) ^ @symcore.int(-2),
      ]),
    ])
  let function_sum_inf = infinitesimals(
    function_sum_eq,
    func=Some(f(x())),
    hint="function_sum",
  )
  inspect(
    normalize_text(local_infinitesimals_text(function_sum_inf)),
    content="[{xi: 0, eta: f(x)**-2 + x**-2}]",
  )
  inspect(
    checkinfsol(function_sum_eq, function_sum_inf, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

///|
test "lie heuristic abaco2_similar eq1 follows SymPy reference case" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let big_f = @symcore.applied_undefined_function("F", [
    a * x() + b * f(x()),
  ])
  let similar_eq_1 = @symcalculus.diff(f(x()), x()) - big_f
  let similar_inf_1 = infinitesimals(
    similar_eq_1,
    func=Some(f(x())),
    hint="abaco2_similar",
  )
  inspect(
    normalize_text(local_infinitesimals_text(similar_inf_1)),
    content="[{xi: 1, eta: -a/b}]",
  )
  inspect(
    checkinfsol(similar_eq_1, similar_inf_1, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

///|
test "lie heuristic abaco2_similar eq2 follows SymPy reference case" {
  let similar_eq_2 = @symcalculus.diff(f(x()), x()) -
    @symcore.mul([
      f(x()) ^ @symcore.int(2),
      @symcore.add([
        @symcore.function(
          "sin",
          [@symcore.add([f(x()), @symcore.mul([@symcore.int(-1), x()])])],
        ),
        @symcore.mul([@symcore.int(-1), x() ^ @symcore.int(2)]),
        @symcore.mul([@symcore.int(2), x(), f(x())]),
      ]) ^ @symcore.int(-1),
    ])
  let similar_inf_2 = infinitesimals(
    similar_eq_2,
    func=Some(f(x())),
    hint="abaco2_similar",
  )
  inspect(
    normalize_text(local_infinitesimals_text(similar_inf_2)),
    content="[{xi: f(x)**2, eta: f(x)**2}]",
  )
  inspect(
    checkinfsol(similar_eq_2, similar_inf_2, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

///|
test "lie heuristic abaco2_unique_unknown eq1 follows SymPy reference case" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let unknown_f = @symcore.applied_undefined_function("F", [
    @symcore.add([
      @symcore.mul([x() ^ a, a ^ @symcore.int(-1)]),
      @symcore.mul([f(x()) ^ b, b ^ @symcore.int(-1)]),
    ]),
  ])
  let unique_unknown_eq_1 = @symcalculus.diff(f(x()), x()) -
    @symcore.mul([
      x() ^ (@symcore.add([a, @symcore.int(-1)])),
      f(x()) ^ (@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), b])])),
      unknown_f,
    ])
  let unique_unknown_inf_1 = infinitesimals(
    unique_unknown_eq_1,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  inspect(
    normalize_text(local_infinitesimals_text(unique_unknown_inf_1)),
    content="[{xi: x**(1 - a), eta: -f(x)**(1 - b)}]",
  )
  inspect(
    checkinfsol(unique_unknown_eq_1, unique_unknown_inf_1, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

test "lie heuristic abaco2_unique_unknown eq2 follows SymPy reference case" {
  let unique_unknown_eq_2 = @symcalculus.diff(f(x()), x()) +
    @symcore.function(
      "tan",
      [
        @symcore.applied_undefined_function("F", [
          @symcore.add([
            x() ^ @symcore.int(2),
            f(x()) ^ @symcore.int(2),
          ]),
        ]) + @symcore.function(
          "atan",
          [@symcore.mul([x(), f(x()) ^ @symcore.int(-1)])],
        ),
      ],
    )
  let unique_unknown_inf_2 = infinitesimals(
    unique_unknown_eq_2,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  inspect(
    normalize_text(local_infinitesimals_text(unique_unknown_inf_2)),
    content="[{xi: -f(x), eta: x}]",
  )
  inspect(
    checkinfsol(unique_unknown_eq_2, unique_unknown_inf_2, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

test "lie heuristic abaco2_unique_unknown eq3 follows SymPy reference case" {
  let a = @symcore.Expr::Symbol("a")
  let unique_unknown_eq_3 =
    ((
      x() * @symcalculus.diff(f(x()), x()) + f(x()) + @symcore.int(2) * x()
    ) ^ @symcore.int(2)) -
    @symcore.int(4) * x() * f(x()) -
    @symcore.int(4) * (x() ^ @symcore.int(2)) -
    @symcore.int(4) * a
  let unique_unknown_inf_3 = infinitesimals(
    unique_unknown_eq_3,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  inspect(
    checkinfsol(unique_unknown_eq_3, unique_unknown_inf_3, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

test "lie heuristic linear follows SymPy reference cases" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let m = @symcore.Expr::Symbol("m")
  let n = @symcore.Expr::Symbol("n")
  let leading_power = x() ^
    (@symcore.add([n * (@symcore.add([m, @symcore.int(1)])), @symcore.mul([@symcore.int(-1), m])]))
  let forcing_power = x() ^ (@symcore.mul([n, @symcore.add([m, @symcore.int(1)])]))
  let linear_eq =
    (
      leading_power * @symcalculus.diff(f(x()), x()) -
      a * (f(x()) ^ n) -
      b * forcing_power
    )
  let linear_inf = infinitesimals(linear_eq, func=Some(f(x())), hint="linear")
  inspect(checkinfsol(linear_eq, linear_inf, func=Some(f(x())))[0].0.to_string(), content="true")
}

test "ode and pde high-level helpers cover source-compatible entry points" {
  let ode = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(f(x()), x()),
    f(x()),
  )
  inspect(ode_order(ode, f(x())).to_string(), content="1")
  inspect(
    maybe_expr_text(
      homogeneous_order(
        @symcore.add([x() ^ @symcore.int(2), y() ^ @symcore.int(2)]),
        [x(), y()],
      ),
    ),
    content="2",
  )
  inspect(
    expr_list_text(classify_ode(ode, func=Some(f(x()))).map(name => @symcore.Expr::Symbol(name))),
    content="[separable, 1st_linear, Bernoulli]",
  )
  let ode_solution = dsolve(ode, func=Some(f(x())))
  inspect(
    normalize_text(@symprint.to_string(ode_solution)),
    content="Eq(f(x), C1*exp(x))",
  )
  inspect(
    normalize_text(
      "(" +
      checkodesol(ode, ode_solution, func=Some(f(x()))).0.to_string() +
      ", " +
      @symprint.to_string(checkodesol(ode, ode_solution, func=Some(f(x()))).1) +
      ")",
    ),
    content="(true, 0)",
  )

  let pde = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(u(x(), y()), x()),
    @symcalculus.diff(u(x(), y()), y()),
  )
  inspect(
    expr_list_text(
      pde_separate_add(
        pde,
        u(x(), y()),
        [xfun(x()), yfun(y())],
      ).unwrap_or([]),
    ),
    content="[Derivative(X(x), x), Derivative(Y(y), y)]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        pde_separate_mul(
          pde,
          u(x(), y()),
          [xfun(x()), yfun(y())],
        ).unwrap_or([]),
      ),
    ),
    content="[Derivative(X(x), x)/X(x), Derivative(Y(y), y)/Y(y)]",
  )
  inspect(
    expr_list_text(classify_pde(pde, func=Some(u(x(), y()))).map(name => @symcore.Expr::Symbol(name))),
    content="[1st_linear_constant_coeff_homogeneous]",
  )
  let pde_solution = pdsolve(pde, func=Some(u(x(), y())))
  inspect(
    normalize_text(@symprint.to_string(pde_solution)),
    content="Eq(u(x, y), F(-x - y))",
  )
  inspect(
    normalize_text(
      "(" +
      checkpdesol(pde, pde_solution, func=Some(u(x(), y()))).0.to_string() +
      ", " +
      @symprint.to_string(checkpdesol(pde, pde_solution, func=Some(u(x(), y()))).1) +
      ")",
    ),
    content="(true, 0)",
  )
}

///|
test "checkodesol follows SymPy subscheck-style implicit and exact cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let exact_sol = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    (f(x()) ^ @symcore.int(5)) + @symcore.int(9) * f(x()) + x(),
    @symcore.int(0),
  )
  let exact_ode = @symcalculus.diff(
    (f(x()) ^ @symcore.int(5)) + @symcore.int(9) * f(x()) + x(),
    x(),
  )
  let exact_check = checkodesol(exact_ode, exact_sol, func=Some(f(x())))
  inspect(exact_check.0.to_string(), content="true")
  inspect(@symprint.to_string(exact_check.1), content="0")

  let implicit_sol = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.function("exp", [f(x())]) + x(),
    @symcore.int(0),
  )
  let implicit_ode = x() *
    @symcalculus.diff(@symcore.function("exp", [f(x())]) + x(), x())
  let implicit_check = checkodesol(
    implicit_ode,
    implicit_sol,
    func=Some(f(x())),
    solve_for_func=false,
  )
  inspect(implicit_check.0.to_string(), content="true")
  inspect(@symprint.to_string(implicit_check.1), content="0")

  let reversed_sol = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    c1 * @symcore.function("exp", [x()]),
    f(x()),
  )
  let reversed_check = checkodesol(
    @symcalculus.diff(f(x()), x()) - f(x()),
    reversed_sol,
    func=Some(f(x())),
  )
  inspect(reversed_check.0.to_string(), content="true")
  inspect(@symprint.to_string(reversed_check.1), content="0")

  let bad_check = checkodesol(
    @symcalculus.diff(f(x()), x()),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, f(x()), x()),
    func=Some(f(x())),
  )
  inspect(bad_check.0.to_string(), content="false")
  inspect(@symprint.to_string(bad_check.1), content="1")
}

///|
test "inequalities, factor_system and diophantine cover source-compatible public APIs" {
  let poly = @sympolys.Poly::from_expr_defaults(
    (x() ^ @symcore.int(2)) - @symcore.int(1),
    gens=["x"],
  )
  let one = @sympolys.Poly::from_expr_defaults(@symcore.int(1), gens=["x"])
  inspect(
    set_list_text(solve_poly_inequality(poly, "==")),
    content="[{-1}, {1}]",
  )
  inspect(
    set_list_text(solve_poly_inequality(poly, "!=")),
    content="[Interval.open(-oo, -1), Interval.open(-1, 1), Interval.open(1, oo)]",
  )
  inspect(
    @symsets.to_string(
      solve_rational_inequalities([
        [
          ((@sympolys.Poly::from_expr_defaults(x(), gens=["x"]), one), "!="),
          ((@sympolys.Poly::from_expr_defaults(@symcore.int(1) - x(), gens=["x"]), one), ">="),
        ],
      ]),
    ),
    content="Union(Interval.open(-oo, 0), Interval.Lopen(0, 1))",
  )
  inspect(
    inequality_result_text(
      solve_univariate_inequality(
        @symcore.Expr::Relational(@symcore.RelOp::Ge, x() ^ @symcore.int(2), @symcore.int(4)),
        x(),
        relational=false,
      ),
    ),
    content="Set(Union(Interval(-oo, -2), Interval(2, oo)))",
  )
  inspect(
    normalize_text(
      inequality_result_text(
        solve_univariate_inequality(
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x() ^ @symcore.int(2), @symcore.int(4)),
          x(),
        ),
      ),
    ),
    content="Relational(Or(x <= -2, 2 <= x))",
  )
  inspect(
    normalize_text(@symprint.to_string(reduce_abs_inequality(@symcore.function("Abs", [x() - @symcore.int(5)]) - @symcore.int(3), "<", x()))),
    content="And(x < 8, 2 < x)",
  )
  inspect(
    normalize_text(@symprint.to_string(reduce_abs_inequality(@symcore.function("Abs", [x() - @symcore.int(5)]) - @symcore.int(3), "==", x()))),
  content=(#|Or(Eq(x, 2), Eq(x, 8))
  ))
  inspect(
    normalize_text(@symprint.to_string(reduce_abs_inequality(@symcore.function("Abs", [x() - @symcore.int(5)]) - @symcore.int(3), "!=", x()))),
  content=(#|Contains(x, Complement(Reals, {2, 8}))
  ))
  inspect(
    normalize_text(
      @symprint.to_string(
        reduce_inequalities(
          [@symcore.Expr::Relational(@symcore.RelOp::Ge, x() ^ @symcore.int(2), @symcore.int(4))],
          symbols=[x()],
        ),
      ),
    ),
    content="Or(x <= -2, 2 <= x)",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        reduce_inequalities(
          [
            @symcore.Expr::Relational(@symcore.RelOp::Gt, x(), @symcore.int(1)),
            @symcore.Expr::Relational(@symcore.RelOp::Lt, y(), @symcore.int(2)),
          ],
          symbols=[x(), y()],
        ),
      ),
    ),
  content=(#|And(1 < x, y < 2)
  ))
  inspect(
    normalize_text(
      expr_matrix_text(
        factor_system(
          [x() * (x() + @symcore.int(1)), y() * (y() - @symcore.int(1))],
          gens=[x(), y()],
        ),
      ),
    ),
    content="[[x, y], [x, y - 1], [x + 1, y], [x + 1, y - 1]]",
  )
  inspect(
    normalize_text(@symsets.to_string(diophantine(x() + y() - @symcore.int(3)))),
    content="{(t_0, 3 - t_0)}",
  )
  inspect(
    normalize_text(classify_diop_text(classify_diop(x() + y() - @symcore.int(3)))),
    content="([x, y], {1: -3, x: 1, y: 1}, 'linear')",
  )
  inspect(
    normalize_text(diop_solve_result_text(diop_solve(x() + y() - @symcore.int(3)))),
    content="(t_0, 3 - t_0)",
  )
  inspect(
    normalize_text(@symsets.to_string(diophantine((x() ^ @symcore.int(2)) - @symcore.int(1)))),
    content="{(-1,), (1,)}",
  )
  inspect(
    normalize_text(
      @symsets.to_string(
        diophantine(
          @symcore.add([
            @symcore.mul([@symcore.int(4), x()]),
            @symcore.mul([@symcore.int(6), y()]),
            @symcore.mul([@symcore.int(8), z()]),
            @symcore.int(-10),
          ]),
        ),
      ),
    ),
  content=(#|{(3*t_0 + 4*t_1 - 5, -4*t_1 - 2*t_0 + 5, t_1)}
  ))
}

///|
test "recurrence solvers cover first-order source-compatible entry points" {
  let a = @symcore.Expr::Symbol("a")
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let expected_poly = @symcore.add([
    @symcore.Expr::Symbol("C0"),
    @symcore.mul([half, x() ^ @symcore.int(2)]),
    @symcore.mul([@symcore.int(-1), half, x()]),
  ])
  inspect(
    maybe_expr_compare_text(
      rsolve_poly([@symcore.int(-1), @symcore.int(1)], x(), x()),
      expected_poly,
    ),
    content="0",
  )
  let expected_hyper = @symcore.mul([@symcore.Expr::Symbol("C0"), a ^ x()])
  inspect(
    maybe_expr_compare_text(
      rsolve_hyper(
        [@symcore.mul([@symcore.int(-1), a]), @symcore.int(1)],
        @symcore.int(0),
        x(),
      ),
      expected_hyper,
    ),
    content="0",
  )
  let recurrence = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    f(x() + @symcore.int(1)),
    @symcore.add([f(x()), x()]),
  )
  inspect(
    maybe_expr_compare_text(rsolve(recurrence, f(x())), expected_poly),
    content="0",
  )
  let expected_init = @symcore.add([
    @symcore.mul([half, x() ^ @symcore.int(2)]),
    @symcore.mul([@symcore.int(-1), half, x()]),
  ])
  inspect(
    maybe_expr_compare_text(
      rsolve(
        recurrence,
        f(x()),
        init=Some(rsolve_init_list([@symcore.int(0)])),
      ),
      expected_init,
    ),
    content="0",
  )
}
