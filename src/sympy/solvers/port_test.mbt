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
fn normalize_text(text : String) -> String {
  text
  .replace_all(old="/1", new="")
  .replace_all(old="-1*", new="-")
  .replace_all(old=" + -", new=" - ")
  .replace_all(old="-t_0 + 3", new="3 - t_0")
  .replace_all(old="exp(1*x**3/3)", new="exp(x**3/3)")
}

///|
fn py_matrix_list_text(code : String) -> String raise {
  solvers_eval_str(
    "'[' + ', '.join('[' + ', '.join(sympy.sstr(v) for v in row) + ']' for row in (" +
    code +
    ").tolist()) + ']'",
  )
}

///|
fn py_matrix_list_text_symbols(code : String, symbols : String) -> String raise {
  solvers_eval_str_symbols(
    "'[' + ', '.join('[' + ', '.join(sympy.sstr(v) for v in row) + ']' for row in (" +
    code +
    ").tolist()) + ']'",
    symbols,
  )
}

///|
fn compogen_oracle_expr(args_code : String) -> String {
  "(__import__('sympy.solvers.decompogen', fromlist=['compogen']).compogen(" +
  args_code +
  "))"
}

///|
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
fn solvers_eval_stmt_result_symbols(stmt : String, symbols : String) -> String raise {
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
  let globals_entries : Array[String] = ["'sympy': sympy"]
  for name in names {
    globals_entries.push("'" + name + "': " + name)
  }
  let globals_dict = "{" + globals_entries.join(", ") + ", 'box': ns}"
  let code = (
    "try:\n  " + stmt +
    "\n  box['out'] = 'OK'\nexcept Exception as e:\n  box['out'] = type(e).__name__"
  )
  let escaped = code
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"\"\"", new="\\\"\\\"\\\"")
  if names.length() == 1 {
    @sympy_utilities.utilities_eval_str(
      "(lambda " + params + ": (lambda ns: (__import__('builtins').exec(\"\"\"" + escaped + "\"\"\", " + globals_dict + ", ns), str(ns['out']))[1])({}))(sympy.symbols('" + symbol_expr + "'))",
    )
  } else {
    @sympy_utilities.utilities_eval_str(
      "(lambda " + params + ": (lambda ns: (__import__('builtins').exec(\"\"\"" + escaped + "\"\"\", " + globals_dict + ", ns), str(ns['out']))[1])({}))(*sympy.symbols('" + symbol_expr + "'))",
    )
  }
}

///|
fn local_linear_eq_result_type(
  result : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError],
) -> String {
  match result {
    Ok(_) => "OK"
    Err(@symsolvers.SolverError::ValueError(_)) => "ValueError"
    Err(@symsolvers.SolverError::NonlinearError(_)) => "NonlinearError"
    Err(@symsolvers.SolverError::ShapeError(_)) => "ShapeError"
    Err(@symsolvers.SolverError::InfeasibleLPError(_)) => "InfeasibleLPError"
    Err(@symsolvers.SolverError::UnboundedLPError(_)) => "UnboundedLPError"
  }
}

///|
fn local_lp_result_type(
  result : Result[(@symcore.Expr, Map[String, @symcore.Expr]), @symsolvers.SolverError],
) -> String {
  match result {
    Ok(_) => "OK"
    Err(@symsolvers.SolverError::ValueError(_)) => "ValueError"
    Err(@symsolvers.SolverError::NonlinearError(_)) => "NonlinearError"
    Err(@symsolvers.SolverError::ShapeError(_)) => "ShapeError"
    Err(@symsolvers.SolverError::InfeasibleLPError(_)) => "InfeasibleLPError"
    Err(@symsolvers.SolverError::UnboundedLPError(_)) => "UnboundedLPError"
  }
}

///|
fn expr_text_has_oracle_prefix(
  local_expr : @symcore.Expr,
  oracle_expr : String,
  symbols : String,
  prefix_len : Int,
) -> Bool raise {
  let local_text = @symprint.to_string(local_expr)
  let oracle_text = solvers_eval_str_symbols(oracle_expr, symbols)
  let end = if prefix_len < oracle_text.length() { prefix_len } else { oracle_text.length() }
  local_text.has_prefix(oracle_text.unsafe_substring(start=0, end=end))
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
fn constantsimp_oracle_text(
  oracle_expr : String,
  symbols : String,
) -> String raise {
  solvers_eval_str_symbols("str(" + oracle_expr + ")", symbols)
}

///|
fn solver_py_locals_dict(symbols : String) -> String {
  let parts = symbols.split(" ")
  let entries : Array[String] = []
  for part in parts {
    let trimmed = part.trim().to_string()
    if trimmed != "" {
      entries.push("'" + trimmed + "': " + trimmed)
    }
  }
  for fn_name in ["f", "g", "h", "u", "X", "Y"] {
    entries.push("'" + fn_name + "': " + fn_name)
  }
  "{" + entries.join(", ") + "}"
}

///|
fn relational_residual_matches_oracle(
  expr_local : @symcore.Expr,
  oracle_expr : String,
  symbols : String,
) -> String raise {
  let local_env = solver_py_locals_dict(symbols)
  let local_expr = "sympy.sympify('" +
    py_expr(expr_local).replace_all(old="'", new="\\\\'") +
    "', locals=" + local_env + ")"
  solvers_eval_str_symbols(
    "str(sympy.simplify(((" +
    local_expr +
    ").lhs - (" +
    local_expr +
    ").rhs) - ((" +
    oracle_expr +
    ").lhs - (" +
    oracle_expr +
    ").rhs)))",
    symbols,
  )
}

///|
fn relational_list_residuals_match_oracle(
  items_local : Array[@symcore.Expr],
  oracle_expr : String,
  symbols : String,
) -> String raise {
  let local_items = "[" + items_local.map(py_sympify_expr).join(", ") + "]"
  solvers_eval_str_symbols(
    "str([sympy.simplify((lhs.lhs - lhs.rhs) - (rhs.lhs - rhs.rhs)) for lhs, rhs in zip(" +
    local_items +
    ", (" +
    oracle_expr +
    "))])",
    symbols,
  )
}

///|
fn expr_list_residuals_match_oracle(
  items_local : Array[@symcore.Expr],
  oracle_expr : String,
  symbols : String,
) -> String raise {
  let local_items = "[" + items_local.map(py_sympify_expr).join(", ") + "]"
  solvers_eval_str_symbols(
    "str([sympy.simplify(lhs - rhs) for lhs, rhs in zip(" +
    local_items +
    ", (" +
    oracle_expr +
    "))])",
    symbols,
  )
}

///|
fn finite_set_single_tuple_residuals_match_oracle(
  local_set : @symsets.Set,
  oracle_expr : String,
  symbols : String,
) -> String raise {
  match local_set {
    @symsets.Set::FiniteSet(items) =>
      if items.length() != 1 {
        "bad-arity"
      } else {
        solvers_eval_str_symbols(
          "str([sympy.simplify(lhs - rhs) for lhs, rhs in zip(" +
          py_expr(items[0]) +
          ", list(next(iter(" +
          oracle_expr +
          "))))])",
          symbols,
        )
      }
    _ => "not-finiteset"
  }
}

///|
fn finite_set_exprs_match_oracle(
  local_set : @symsets.Set,
  oracle_expr : String,
  symbols : String,
) -> String raise {
  match local_set {
    @symsets.Set::FiniteSet(items) => {
      let local_items = "[" + items.map(py_sympify_expr).join(", ") + "]"
      solvers_eval_str_symbols(
        "str(len(" +
        local_items +
        ") == len(list(" +
        oracle_expr +
        ")) and all(any(sympy.simplify(lhs - rhs) == 0 for rhs in list(" +
        oracle_expr +
        ")) for lhs in " +
        local_items +
        "))",
        symbols,
      )
    }
    _ => "not-finiteset"
  }
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

fn py_expr_systems(items : Array[Array[@symcore.Expr]]) -> String {
  let systems : Array[String] = []
  for system in items {
    let exprs : Array[String] = []
    for expr in system {
      exprs.push(py_sympify_expr(expr))
    }
    systems.push("[" + exprs.join(", ") + "]")
  }
  "[" + systems.join(", ") + "]"
}

///|
fn ode_systems_oracle_residual_text(
  local_systems : Array[Array[@symcore.Expr]],
  oracle_code : String,
) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda x, y, z, C1, C2, C3: repr(([len(s) for s in (" +
    py_expr_systems(local_systems) +
    ")], [len(s) for s in (" +
    oracle_code +
    ")], [[sympy.simplify((lhs.lhs - lhs.rhs) - (rhs.lhs - rhs.rhs)) for lhs, rhs in zip(ls, rs)] for ls, rs in zip((" +
    py_expr_systems(local_systems) +
    "), (" +
    oracle_code +
    "))])))(*sympy.symbols('x y z C1 C2 C3'))",
  )
}

///|
fn local_string_list_repr(items : Array[String]) -> String {
  "['" + items.join("', '") + "']"
}

///|
fn local_is_test_constant_symbol(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => name.has_prefix("C")
    _ => false
  }
}

///|
fn local_test_constant_sort_expr(expr : @symcore.Expr) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  for symbol in @symcore.free_symbols(expr) {
    if local_is_test_constant_symbol(symbol) {
      match symbol {
        @symcore.Expr::Symbol(name) => env[name] = @symcore.int(1)
        _ => ()
      }
    }
  }
  @symcore.subst(expr, env)
}

///|
fn local_sympy_function_rank(name : String) -> Int {
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
fn local_sort_exprs_cmp(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> Int {
  let lhs_len = lhs.length()
  let rhs_len = rhs.length()
  let min_len = if lhs_len < rhs_len { lhs_len } else { rhs_len }
  for i in 0..<min_len {
    let cmp = local_sort_expr_cmp(lhs[i], rhs[i])
    if cmp != 0 {
      return cmp
    }
  }
  lhs_len.compare(rhs_len)
}

///|
fn local_sort_apply_head_cmp(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Int {
  match (lhs, rhs) {
    (@symcore.Expr::UndefinedFunction(lhs_name), @symcore.Expr::UndefinedFunction(rhs_name)) =>
      lhs_name.compare(rhs_name)
    (@symcore.Expr::UndefinedFunction(_), @symcore.Expr::FunctionHead(_)) => -1
    (@symcore.Expr::FunctionHead(_), @symcore.Expr::UndefinedFunction(_)) => 1
    (@symcore.Expr::FunctionHead(lhs_name), @symcore.Expr::FunctionHead(rhs_name)) => {
      let rank_cmp = local_sympy_function_rank(lhs_name).compare(local_sympy_function_rank(rhs_name))
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
fn local_sort_relop_rank(op : @symcore.RelOp) -> Int {
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
fn local_sort_node_count(expr : @symcore.Expr) -> Int {
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
    _ => 1 + @symcore.children(expr).fold(init=0, fn(acc, child) { acc + local_sort_node_count(child) })
  }
}

///|
fn local_sort_expr_cmp(lhs_raw : @symcore.Expr, rhs_raw : @symcore.Expr) -> Int {
  let lhs = local_test_constant_sort_expr(lhs_raw)
  let rhs = local_test_constant_sort_expr(rhs_raw)
  match (lhs, rhs) {
    (@symcore.Expr::Apply(lhs_head, lhs_args), @symcore.Expr::Apply(rhs_head, rhs_args)) => {
      let head_cmp = local_sort_apply_head_cmp(lhs_head, rhs_head)
      if head_cmp != 0 {
        return head_cmp
      }
      return local_sort_exprs_cmp(lhs_args, rhs_args)
    }
    (@symcore.Expr::Add(lhs_args), @symcore.Expr::Add(rhs_args))
    | (@symcore.Expr::Mul(lhs_args), @symcore.Expr::Mul(rhs_args)) =>
      local_sort_exprs_cmp(lhs_args, rhs_args)
    (@symcore.Expr::Pow(lhs_base, lhs_exp), @symcore.Expr::Pow(rhs_base, rhs_exp)) => {
      let base_cmp = local_sort_expr_cmp(lhs_base, rhs_base)
      if base_cmp != 0 {
        return base_cmp
      }
      return local_sort_expr_cmp(lhs_exp, rhs_exp)
    }
    (@symcore.Expr::Relational(lhs_op, lhs_lhs, lhs_rhs), @symcore.Expr::Relational(rhs_op, rhs_lhs, rhs_rhs)) => {
      let op_cmp = local_sort_relop_rank(lhs_op).compare(local_sort_relop_rank(rhs_op))
      if op_cmp != 0 {
        return op_cmp
      }
      let lhs_cmp = local_sort_expr_cmp(lhs_lhs, rhs_lhs)
      if lhs_cmp != 0 {
        return lhs_cmp
      }
      return local_sort_expr_cmp(lhs_rhs, rhs_rhs)
    }
    _ => {
      let node_cmp = local_sort_node_count(lhs).compare(local_sort_node_count(rhs))
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
fn local_sort_constant_args(items : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for item in items {
    let mut inserted = false
    for i in 0..<out.length() {
      if local_sort_expr_cmp(item, out[i]) < 0 {
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
  if local_is_test_constant_symbol(expr) {
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
        local_sort_constant_args(args).map(arg => local_constant_renumber_inner(arg, constants_found)),
      )
    @symcore.Expr::Mul(args) =>
      @symcore.Expr::Mul(
        local_sort_constant_args(args).map(arg => local_constant_renumber_inner(arg, constants_found)),
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

fn py_infinitesimals(items : Array[Map[String, @symcore.Expr]]) -> String {
  let rendered : Array[String] = []
  for item in items {
    rendered.push(
      "{'xi': " +
      py_sympify_expr(item.get("xi").unwrap_or(@symcore.int(0))) +
      ", 'eta': " +
      py_sympify_expr(item.get("eta").unwrap_or(@symcore.int(0))) +
      "}",
    )
  }
  "[" + rendered.join(", ") + "]"
}

///|
fn infinitesimals_oracle_residual_text(
  local_items : Array[Map[String, @symcore.Expr]],
  oracle_code : String,
) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda x, y, z, a, b, m, n, C1, C2: repr((len((" +
    py_infinitesimals(local_items) +
    ")), len((" +
    oracle_code +
    ")), [(sympy.simplify(lhs['xi'] - rhs['xi']), sympy.simplify(lhs['eta'] - rhs['eta'])) for lhs, rhs in zip((" +
    py_infinitesimals(local_items) +
    "), (" +
    oracle_code +
    "))])))(*sympy.symbols('x y z a b m n C1 C2'))",
  )
}

fn py_checkinfsol(items : Array[(Bool, @symcore.Expr)]) -> String {
  let rendered : Array[String] = []
  for item in items {
    rendered.push(
      "(" +
      (if item.0 { "True" } else { "False" }) +
      ", " +
      py_sympify_expr(item.1) +
      ")",
    )
  }
  "[" + rendered.join(", ") + "]"
}

///|
fn checkinfsol_oracle_residual_text(
  local_items : Array[(Bool, @symcore.Expr)],
  oracle_code : String,
) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda x, y, z, a, b, m, n, C1, C2: repr((len((" +
    py_checkinfsol(local_items) +
    ")), len((" +
    oracle_code +
    ")), [lhs[0] for lhs in (" +
    py_checkinfsol(local_items) +
    ")], [rhs[0] for rhs in (" +
    oracle_code +
    ")], [sympy.simplify(lhs[1] - rhs[1]) for lhs, rhs in zip((" +
    py_checkinfsol(local_items) +
    "), (" +
    oracle_code +
    "))])))(*sympy.symbols('x y z a b m n C1 C2'))",
  )
}

///|
fn checkodesol_oracle_text(oracle_code : String) -> String raise {
  solvers_eval_str_symbols(
    "'(' + str((" +
    oracle_code +
    ")[0]).lower() + ', ' + sympy.sstr((" +
    oracle_code +
    ")[1]) + ')'",
    "x C1",
  )
}

///|
fn normalize_braced_items_text(text : String) -> String {
  let trimmed = text.trim().to_string()
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
fn split_top_level_items_text(text : String) -> Array[String] {
  let parts : Array[String] = []
  let mut depth_paren = 0
  let mut depth_bracket = 0
  let mut depth_brace = 0
  let mut start = 0
  for i = 0; i < text.length(); i = i + 1 {
    match text.get_char(i) {
      Some('(') => depth_paren += 1
      Some(')') => depth_paren -= 1
      Some('[') => depth_bracket += 1
      Some(']') => depth_bracket -= 1
      Some('{') => depth_brace += 1
      Some('}') => depth_brace -= 1
      Some(',') =>
        if depth_paren == 0 &&
          depth_bracket == 0 &&
          depth_brace == 0 {
          parts.push(text[start:i].trim().to_string())
          start = i + 1
        }
      _ => ()
    }
  }
  parts.push(text[start:].trim().to_string())
  parts
}

///|
fn normalize_union_text(text : String) -> String {
  let trimmed = text.trim().to_string()
  if !trimmed.has_prefix("Union(") || !trimmed.has_suffix(")") {
    return trimmed
  }
  let inner = trimmed[6:trimmed.length() - 1].to_string()
  let parts = split_top_level_items_text(inner)
  parts.sort()
  "Union(" + parts.join(", ") + ")"
}

///|
fn local_expr_pair_text(pair : (@symcore.Expr, @symcore.Expr)) -> String {
  "(" + @symprint.to_string(pair.0) + ", " + @symprint.to_string(pair.1) + ")"
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
fn solve_dict_residuals_match_oracle(
  local_result : @symsolvers.SolveResult,
  oracle_expr : String,
  symbols : String,
) -> String raise {
  match local_result {
    @symsolvers.SolveResult::Dict(values) => {
      let residuals : Array[String] = []
      for key in sorted_map_keys(values) {
        residuals.push(
          "sympy.simplify((" +
          py_sympify_expr(values[key]) +
          ") - ((" +
          oracle_expr +
          ")[sympy.Symbol('" +
          key +
          "')]))",
        )
      }
      let residual_expr = "str([" + residuals.join(", ") + "])"
      solvers_eval_str_symbols(residual_expr, symbols)
    }
    _ => "not-dict"
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
  (
    "(" +
    @symprint.to_string(result.0) +
    ", " +
    local_solution_dict_text(Some(result.1), sorted_map_keys(result.1)) +
    ")",
  )
}

///|
fn local_linprog_result_text(result : (@symcore.Expr, Array[@symcore.Expr])) -> String {
  (
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
      Some(Some(v)) => if v { "True" } else { "False" }
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
    (
      @symsets.to_string(
        @symsolvers.solveset(
          @symcore.add([x() ^ @symcore.int(2), @symcore.int(-4)]),
          symbol=Some(x()),
          domain=@symsolvers.complexes,
        ),
      ),
    ),
    (
      solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**2 - 4, x))"),
    ),
  )
  assert_eq(
    (
      local_solve_result_text(
        @symsolvers.solve(
          @symsolvers.solve_expr_input(
            @symcore.add([x() ^ @symcore.int(2), @symcore.int(-4)]),
          ),
          symbols=[x()],
        ),
      ),
    ),
    (
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
test "solvers parity nsolve scalar batch 2" {
  assert_true(
    expr_text_has_oracle_prefix(
      @symsolvers.nsolve(sin(x()), x(), @symcore.int(2)),
      "sympy.sstr(sympy.solvers.nsolve(sympy.sin(x), 2))",
      "x",
      14,
    ),
  )
  let eq_root = @symsolvers.nsolve(
    @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(2) * x(), @symcore.int(2)),
    x(),
    @symcore.int(-10),
  )
  let linear_root = @symsolvers.nsolve(
    @symcore.int(2) * x() + @symcore.int(-2),
    x(),
    @symcore.int(-10),
  )
  assert_true(
    expr_text_has_oracle_prefix(
      eq_root,
      "sympy.sstr(sympy.solvers.nsolve(sympy.Eq(2*x, 2), x, -10))",
      "x",
      3,
    ),
  )
  assert_true(
    expr_text_has_oracle_prefix(
      linear_root,
      "sympy.sstr(sympy.solvers.nsolve(2*x - 2, x, -10))",
      "x",
      3,
    ),
  )
  assert_eq(@symprint.to_string(eq_root), @symprint.to_string(linear_root))
  assert_true(
    expr_text_has_oracle_prefix(
      @symsolvers.nsolve(
        (x() ^ @symcore.int(2)) - @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        x(),
        @symcore.Expr::Float(@symcore.float_from_double(3.0)),
      ),
      "sympy.sstr(sympy.solvers.nsolve(x**2 - sympy.pi, x, 3.0))",
      "x",
      15,
    ),
  )
  assert_true(
    expr_text_has_oracle_prefix(
      @symsolvers.nsolve(
        (x() ^ @symcore.int(2)) - @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        x(),
        @symcore.int(3),
        prec=128,
      ),
      "sympy.sstr(sympy.solvers.nsolve(x**2 - sympy.pi, x, 3, prec=128))",
      "x",
      28,
    ),
  )
  assert_true(
    expr_text_has_oracle_prefix(
      @symsolvers.nsolve(
        x() - @symcore.rational_from_ints(1, 3),
        x(),
        @symcore.int(0),
        prec=100,
      ),
      "sympy.sstr(sympy.solvers.nsolve(x - sympy.Rational(1, 3), x, 0, prec=100))",
      "x",
      24,
    ),
  )
  let a = @symcore.Expr::Symbol("a")
  assert_true(
    expr_text_has_oracle_prefix(
      @symsolvers.nsolve(
        @symcore.pow(@symcore.add([@symcore.Expr::Float(@symcore.float_from_double(0.001)), a]), @symcore.int(-3)) -
        @symcore.int(6) * @symcore.pow(@symcore.add([@symcore.Expr::Float(@symcore.float_from_double(0.9)), @symcore.int(-1) * a]), @symcore.int(-3)),
        a,
        @symcore.Expr::Float(@symcore.float_from_double(0.3)),
      ),
      "sympy.sstr(sympy.solvers.nsolve(1/(0.001 + a)**3 - 6/(0.9 - a)**3, a, 0.3))",
      "a",
      12,
    ),
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
test "solvers parity simplex-style Eq constraints and extra symbols" {
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x() - y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x - y, [x <= y + 2, sympy.Eq(x, y + 2), x >= 0, y >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(0), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, @symcore.int(0), y() + @symcore.int(2)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(y, [0 <= y + 2, 0 >= y + 2]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        y(),
        [@symcore.Expr::Relational(@symcore.RelOp::Eq, y(), @symcore.int(2))],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(y, [sympy.Eq(y, 2)]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(1)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + z()),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x, [y >= 1, x >= y + z, x >= 0, z >= 0]))"),
  )
}

///|
test "solvers parity simplex four-variable reference example" {
  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let result = @symsolvers.lpmax(
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
  assert_eq(
    "(" + @symprint.to_string(result.0) + ", " + local_solution_dict_text(Some(result.1), ["x1", "x2", "x3", "x4"]) + ")",
    solvers_eval_str_symbols(
      "repr(sympy.solvers.lpmax(x1 - 2*x2 - 3*x3 - x4, [x1 - x2 - 2*x3 - x4 <= 4, 2*x1 + x3 - 4*x4 <= 2, -2*x1 + x2 + x4 <= 1, x1 >= 0, x2 >= 0, x3 >= 0, x4 >= 0]))",
      "x1 x2 x3 x4",
    ),
  )
}

///|
test "solvers parity simplex linprog first reference example" {
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x() + y() - @symcore.int(2) * z(),
        [
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
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x + y - 2*z, [7*x + 4*y - 7*z <= 3, 3*x - y + 10*z <= 6, x >= 0, y >= 0, z >= 0]))"),
  )
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1), @symcore.int(1), @symcore.int(-2)],
        a=Some(
          @symmatrices.matrix([
            [@symcore.int(7), @symcore.int(4), @symcore.int(-7)],
            [@symcore.int(3), @symcore.int(-1), @symcore.int(10)],
          ]),
        ),
        b=Some([@symcore.int(3), @symcore.int(6)]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1, 1, -2], [[7, 4, -7], [3, -1, 10]], [3, 6]))"),
  )
}

///|
test "solvers parity simplex edge regressions" {
  let infeasible_const : Result[(@symcore.Expr, Map[String, @symcore.Expr]), @symsolvers.SolverError] = try? @symsolvers.lpmin(
    @symcore.int(5),
    [
      @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Eq, x() + z(), @symcore.int(1)),
      @symcore.Expr::Relational(@symcore.RelOp::Le, x() + @symcore.int(2) * z(), @symcore.int(0)),
    ],
  )
  assert_true(infeasible_const is Err(@symsolvers.SolverError::InfeasibleLPError(_)))

  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        @symcore.int(0),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(0, [x >= 0, y >= 0]))"),
  )
}

///|
test "solvers parity simplex batch 1 additional public cases" {
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        @symcore.int(-1) * x() - y() - @symcore.int(5) * z(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, y() + @symcore.int(2) * z(), @symcore.int(3)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(-1) * x() - @symcore.int(3) * z(), @symcore.int(-2)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(2) * x() + y() + @symcore.int(7) * z(), @symcore.int(5)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(-x - y - 5*z, [y + 2*z <= 3, -x - 3*z <= -2, 2*x + y + 7*z <= 5, x >= 0, y >= 0, z >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        @symcore.int(-1) * x() - y() - @symcore.int(5) * z(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x() - y() + @symcore.int(2) * z(), @symcore.int(3)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(-1) * x() + @symcore.int(2) * y() - @symcore.int(3) * z(), @symcore.int(-2)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(2) * x() + y() - @symcore.int(7) * z(), @symcore.int(-5)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(-x - y - 5*z, [x - y + 2*z <= 3, -x + 2*y - 3*z <= -2, 2*x + y - 7*z <= -5, x >= 0, y >= 0, z >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        @symcore.int(-1) * x() - y() - @symcore.int(5) * z() + @symcore.int(2),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x() - y() + @symcore.int(2) * z(), @symcore.int(-4)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(-1) * x() + @symcore.int(2) * y() - @symcore.int(3) * z(), @symcore.int(8)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(2) * x() + y() - @symcore.int(7) * z(), @symcore.int(10)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(-x - y - 5*z + 2, [x - y + 2*z <= -4, -x + 2*y - 3*z <= 8, 2*x + y - 7*z <= 10, x >= 0, y >= 0, z >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y()),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), z()),
          @symcore.Expr::Relational(@symcore.RelOp::Le, z(), @symcore.int(3)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x, [sympy.Eq(x, y), sympy.Eq(y, z), z <= 3]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(y, [x <= y + 2, x >= y + 2, y >= 0]))"),
  )
  let bounds_scalar = Some([(Some(@symcore.int(2)), Some(@symcore.int(3)))])
  let local_bounds = local_linprog_result_text(@symsolvers.linprog([@symcore.int(1)], bounds=bounds_scalar))
  assert_eq(local_bounds, solvers_eval_str("repr(sympy.solvers.linprog([[1]], [], [], bounds=(2, 3)))"))
  assert_eq(local_bounds, solvers_eval_str("repr(sympy.solvers.linprog([1], [], [], bounds=(2, 3)))"))
  assert_eq(local_bounds, solvers_eval_str("repr(sympy.solvers.linprog([1], bounds=(2, 3)))"))
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1), @symcore.int(-1)],
        a=Some(@symmatrices.matrix([[@symcore.int(1), @symcore.int(1)]])),
        b=Some([@symcore.int(2)]),
        bounds=Some([(Some(@symcore.int(0)), None), (None, None)]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1, -1], [[1, 1]], [2], bounds={1:(None, None)}))"),
  )
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1), @symcore.int(-1)],
        a=Some(@symmatrices.matrix([[@symcore.int(1), @symcore.int(1)]])),
        b=Some([@symcore.int(5)]),
        bounds=Some([(Some(@symcore.int(0)), None), (Some(@symcore.int(3)), None)]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1, -1], [[1, 1]], [5], bounds={1:(3, None)}))"),
  )
}

///|
test "solvers parity simplex batch 2 additional public cases" {
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x() - y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x - y, [x <= y + 2, x >= y + 2, x >= 0, y >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x() - y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), @symcore.int(2)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x - y, [x <= y + 2, sympy.Eq(x, 2)]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        y(),
        [@symcore.Expr::Relational(@symcore.RelOp::Eq, y(), @symcore.int(2))],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(y, [sympy.Eq(y, 2)]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(0), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, @symcore.int(0), y() + @symcore.int(2)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(y, [0 <= y + 2, 0 >= y + 2]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(0), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, @symcore.int(0), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, y(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(y, [0 <= y + 2, 0 >= y + 2, y <= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(1)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y()),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x, [y >= 1, x >= y]))"),
  )
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1), @symcore.int(1), @symcore.int(-2)],
        a=Some(
          @symmatrices.matrix([
            [@symcore.int(7), @symcore.int(4), @symcore.int(-7)],
            [@symcore.int(3), @symcore.int(-1), @symcore.int(10)],
          ]),
        ),
        b=Some([@symcore.int(3), @symcore.int(6)]),
        a_eq=Some(@symmatrices.matrix([[@symcore.int(-9), @symcore.int(1), @symcore.int(0)]])),
        b_eq=Some([@symcore.int(1)]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1, 1, -2], [[7, 4, -7], [3, -1, 10]], [3, 6], [[-9, 1, 0]], [1]))"),
  )
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1), @symcore.int(1), @symcore.int(-2)],
        a=Some(
          @symmatrices.matrix([
            [@symcore.int(7), @symcore.int(4), @symcore.int(-7)],
            [@symcore.int(3), @symcore.int(-1), @symcore.int(10)],
          ]),
        ),
        b=Some([@symcore.int(3), @symcore.int(6)]),
        a_eq=Some(@symmatrices.matrix([[@symcore.int(0), @symcore.int(-1), @symcore.int(1)]])),
        b_eq=Some([half]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1, 1, -2], [[7, 4, -7], [3, -1, 10]], [3, 6], [[0, -1, 1]], [sympy.S.Half]))"),
  )
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(1), @symcore.int(1), @symcore.int(-2)],
        a=Some(
          @symmatrices.matrix([
            [@symcore.int(7), @symcore.int(4), @symcore.int(-7)],
            [@symcore.int(3), @symcore.int(-1), @symcore.int(10)],
          ]),
        ),
        b=Some([@symcore.int(3), @symcore.int(6)]),
        bounds=Some([
          (Some(@symcore.int(0)), None),
          (Some(@symcore.int(0)), None),
          (None, Some(half)),
        ]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([1, 1, -2], [[7, 4, -7], [3, -1, 10]], [3, 6], bounds=[(0, None), (0, None), (None, sympy.S.Half)]))"),
  )
}

///|
test "solvers parity simplex and solveset batch 3 additional public cases" {
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        @symcore.int(-1) * x() - y() - @symcore.int(5) * z(),
        [
          @symcore.Expr::Relational(
            @symcore.RelOp::Le,
            x() - y() + @symcore.Expr::Float(@symcore.float_from_double(2.0)) * z(),
            @symcore.int(-4),
          ),
          @symcore.Expr::Relational(
            @symcore.RelOp::Le,
            @symcore.int(-1) * x() + @symcore.int(2) * y() - @symcore.Expr::Float(@symcore.float_from_double(3.0)) * z(),
            @symcore.int(8),
          ),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(2) * x() + y() - @symcore.int(7) * z(), @symcore.int(10)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(-x - y - 5*z, [x - y + 2.0*z <= -4, -x + 2*y - 3.0*z <= 8, 2*x + y - 7*z <= 10, x >= 0, y >= 0, z >= 0]))"),
  )
  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let infeasible_four_var : Result[(@symcore.Expr, Map[String, @symcore.Expr]), @symsolvers.SolverError] = try? @symsolvers.lpmin(
    @symcore.int(9) * x2 - @symcore.int(8) * x3 + @symcore.int(3) * x4 + @symcore.int(6),
    [
      @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(5) * x2 - @symcore.int(2) * x3, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(-1) * x1 - @symcore.int(8) * x2 + @symcore.int(9) * x3, @symcore.int(-3)),
      @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(10) * x1 - x2 + @symcore.int(9) * x4, @symcore.int(-4)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x1, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x2, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x3, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x4, @symcore.int(0)),
    ],
  )
  assert_true(infeasible_four_var is Err(@symsolvers.SolverError::InfeasibleLPError(_)))
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(4), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(4, x, sympy.S.Reals))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset((x() ^ @symcore.int(2)) + @symcore.int(1), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**2 + 1, x, sympy.S.Reals))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(0), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(0, x, sympy.S.Reals))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.int(0),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(1), @symcore.int(2)),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(0, x, sympy.Interval(1, 2)))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.int(-1) * (x() ^ @symcore.int(2)) - @symcore.int(2) * x() + ((x() + @symcore.int(1)) ^ @symcore.int(2)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(-x**2 - 2*x + (x + 1)**2 - 1, x, sympy.S.Reals))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.int(3) * x() + @symcore.int(-2),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(3*x - 2, x, sympy.S.Reals))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**2 - 1, x, sympy.S.Reals))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        sqrt(@symcore.int(1)) + @symcore.int(1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(sympy.sqrt(1) + 1, x, sympy.S.Reals))"),
  )
}

///|
test "solvers parity linear_eq_to_matrix and linsolve batch 4 additional public cases" {
  let (a0, b0) = @symsolvers.linear_eq_to_matrix([@symcore.int(0)], [x()])
  assert_eq(local_matrix_list_text(a0), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(0, x)[0]"))
  assert_eq(local_matrix_list_text(b0), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(0, x)[1]"))

  let (a1, b1) = @symsolvers.linear_eq_to_matrix([@symcore.int(1)], [x()])
  assert_eq(local_matrix_list_text(a1), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(1, x)[0]"))
  assert_eq(local_matrix_list_text(b1), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(1, x)[1]"))

  let eqns1 = [
    @symcore.int(2) * x() + y() - @symcore.int(2) * z() + @symcore.int(-3),
    x() - y() - z(),
    x() + y() + @symcore.int(3) * z() + @symcore.int(-12),
  ]
  let (a2, b2) = @symsolvers.linear_eq_to_matrix(eqns1, [x(), y(), z()])
  assert_eq(local_matrix_list_text(a2), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix([2*x + y - 2*z - 3, x - y - z, x + y + 3*z - 12], (x, y, z))[0]"))
  assert_eq(local_matrix_list_text(b2), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix([2*x + y - 2*z - 3, x - y - z, x + y + 3*z - 12], (x, y, z))[1]"))

  let eqns2 = [
    @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(3) * x() + @symcore.int(2) * y() - z(), @symcore.int(1)),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(2) * x() - @symcore.int(2) * y() + @symcore.int(4) * z(), @symcore.int(-2)),
    @symcore.int(-2) * x() + y() - @symcore.int(2) * z(),
  ]
  let (a3, b3) = @symsolvers.linear_eq_to_matrix(eqns2, [x(), y(), z()])
  assert_eq(local_matrix_list_text(a3), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix([sympy.Eq(3*x + 2*y - z, 1), sympy.Eq(2*x - 2*y + 4*z, -2), -2*x + y - 2*z], (x, y, z))[0]"))
  assert_eq(local_matrix_list_text(b3), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix([sympy.Eq(3*x + 2*y - z, 1), sympy.Eq(2*x - 2*y + 4*z, -2), -2*x + y - 2*z], (x, y, z))[1]"))

  let a_sym = @symcore.Expr::Symbol("a")
  let b_sym = @symcore.Expr::Symbol("b")
  let c_sym = @symcore.Expr::Symbol("c")
  let d_sym = @symcore.Expr::Symbol("d")
  let e_sym = @symcore.Expr::Symbol("e")
  let f_sym = @symcore.Expr::Symbol("f")
  let g_sym = @symcore.Expr::Symbol("g")
  let h_sym = @symcore.Expr::Symbol("h")
  let i_sym = @symcore.Expr::Symbol("i")
  let j_sym = @symcore.Expr::Symbol("j")
  let k_sym = @symcore.Expr::Symbol("k")
  let l_sym = @symcore.Expr::Symbol("l")
  let eqns3 = [
    a_sym * b_sym * x() + b_sym * y() + c_sym * z() - d_sym,
    e_sym * x() + d_sym * x() + f_sym * y() + g_sym * z() - h_sym,
    i_sym * x() + j_sym * y() + k_sym * z() - l_sym,
  ]
  let (a4, b4) = @symsolvers.linear_eq_to_matrix(eqns3, [x(), y(), z()])
  assert_eq(local_matrix_list_text(a4), py_matrix_list_text_symbols("sympy.solvers.linear_eq_to_matrix([a*b*x + b*y + c*z - d, e*x + d*x + f*y + g*z - h, i*x + j*y + k*z - l], (x, y, z))[0]", "x y z a b c d e f g h i j k l"))
  assert_eq(local_matrix_list_text(b4), py_matrix_list_text_symbols("sympy.solvers.linear_eq_to_matrix([a*b*x + b*y + c*z - d, e*x + d*x + f*y + g*z - h, i*x + j*y + k*z - l], (x, y, z))[1]", "x y z a b c d e f g h i j k l"))

  let (a5, b5) = @symsolvers.linear_eq_to_matrix(
    [x() + y() * (z() * (@symcore.int(3) * x() + @symcore.int(2)) + @symcore.int(3))],
    [x()],
  )
  assert_eq(local_matrix_list_text(a5), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(x + y*(z*(3*x + 2) + 3), x)[0]"))
  assert_eq(local_matrix_list_text(b5), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(x + y*(z*(3*x + 2) + 3), x)[1]"))

  let (a6, b6) = @symsolvers.linear_eq_to_matrix(
    [@symcore.Expr::Relational(@symcore.RelOp::Eq, x() + @symcore.int(2), @symcore.int(1))],
    [x()],
  )
  assert_eq(local_matrix_list_text(a6), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(sympy.Eq(x + 2, 1), x)[0]"))
  assert_eq(local_matrix_list_text(b6), py_matrix_list_text("sympy.solvers.linear_eq_to_matrix(sympy.Eq(x + 2, 1), x)[1]"))

  let (a7, b7) = @symsolvers.linear_eq_to_matrix(
    [@symcore.Expr::Relational(@symcore.RelOp::Eq, a_sym * (@symcore.int(2) * x() + @symcore.int(3) * y()) + @symcore.int(4) * y(), @symcore.int(5))],
    [x(), y()],
  )
  assert_eq(local_matrix_list_text(a7), py_matrix_list_text_symbols("sympy.solvers.linear_eq_to_matrix(sympy.Eq(a*(2*x + 3*y) + 4*y, 5), x, y)[0]", "x y a"))
  assert_eq(local_matrix_list_text(b7), py_matrix_list_text_symbols("sympy.solvers.linear_eq_to_matrix(sympy.Eq(a*(2*x + 3*y) + 4*y, 5), x, y)[1]", "x y a"))

  let a_free = @symcore.Expr::Symbol("a_free")
  let b_free = @symcore.Expr::Symbol("b_free")
  let c_free = @symcore.Expr::Symbol("c_free")
  let d_free = @symcore.Expr::Symbol("d_free")
  let e_free = @symcore.Expr::Symbol("e_free")
  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(
        @symsolvers.linsolve_augmented_matrix_input(
          @symmatrices.matrix([
            [@symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(0)],
            [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(0)],
          ]),
        ),
        [a_free, b_free, c_free, d_free, e_free],
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.linsolve(sympy.Matrix([[0, 1, 0, 0, 0, 0], [0, 0, 0, 1, 0, 0]]), (a_free, b_free, c_free, d_free, e_free)))", "a_free b_free c_free d_free e_free"),
  )

  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(
        @symsolvers.linsolve_equations_input([
          x() + @symcore.int(2) * y() + @symcore.int(3) * z(),
          @symcore.int(2) * x() + @symcore.int(4) * y() + @symcore.int(6) * z() + @symcore.int(-1),
          @symcore.int(3) * x() + @symcore.int(6) * y() + @symcore.int(9) * z(),
        ]),
        [x(), y(), z()],
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([x + 2*y + 3*z, 2*x + 4*y + 6*z - 1, 3*x + 6*y + 9*z], (x, y, z)))"),
  )
}

///|
test "solvers parity linsolve batch 5 additional public cases" {
  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let eqns = [
    x1 + @symcore.int(2) * x2 + x3 + x4 + @symcore.int(-7),
    x1 + @symcore.int(2) * x2 + @symcore.int(2) * x3 - x4 + @symcore.int(-12),
    @symcore.int(2) * x1 + @symcore.int(4) * x2 + @symcore.int(6) * x4 + @symcore.int(-4),
  ]
  assert_eq(
    finite_set_single_tuple_residuals_match_oracle(
      @symsolvers.linsolve(@symsolvers.linsolve_equations_input(eqns), [x1, x2, x3, x4]),
      "sympy.solvers.linsolve([x1 + 2*x2 + x3 + x4 - 7, x1 + 2*x2 + 2*x3 - x4 - 12, 2*x1 + 4*x2 + 6*x4 - 4], (x1, x2, x3, x4))",
      "x1 x2 x3 x4",
    ),
    "[0, 0, 0, 0]",
  )
  assert_eq(
    finite_set_single_tuple_residuals_match_oracle(
      @symsolvers.linsolve(
        @symsolvers.linsolve_augmented_matrix_input(
          @symmatrices.matrix([
            [@symcore.int(1), @symcore.int(2), @symcore.int(1), @symcore.int(1), @symcore.int(7)],
            [@symcore.int(1), @symcore.int(2), @symcore.int(2), @symcore.int(-1), @symcore.int(12)],
            [@symcore.int(2), @symcore.int(4), @symcore.int(0), @symcore.int(6), @symcore.int(4)],
          ]),
        ),
        [x1, x2, x3, x4],
      ),
      "sympy.solvers.linsolve(sympy.Matrix([[1, 2, 1, 1, 7], [1, 2, 2, -1, 12], [2, 4, 0, 6, 4]]), (x1, x2, x3, x4))",
      "x1 x2 x3 x4",
    ),
    "[0, 0, 0, 0]",
  )
  assert_eq(
    @symsets.to_string(@symsolvers.linsolve(@symsolvers.linsolve_equations_input([]), [x()])),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([], [x]))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.linsolve(@symsolvers.linsolve_equations_input([@symcore.int(0)]), [x()])),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([0], [x]))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.linsolve(@symsolvers.linsolve_equations_input([x()]), [x(), y()])),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([x], [x, y]))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.linsolve(@symsolvers.linsolve_equations_input([x(), @symcore.int(0)]), [x(), y()])),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([x, 0], [x, y]))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(
        @symsolvers.linsolve_equations_input([@symcore.Expr::Relational(@symcore.RelOp::Eq, x(), x() + y())]),
        [x(), y()],
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([sympy.Eq(x, x + y)], [x, y]))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(
        @symsolvers.linsolve_equations_input([@symcore.Expr::Relational(@symcore.RelOp::Eq, x() + x() * y(), @symcore.int(1) + y())]),
        [x()],
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([sympy.Eq(x + x*y, 1 + y)], [x]))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(
        @symsolvers.linsolve_equations_input([@symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(1) + y(), x() + x() * y())]),
        [x()],
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve([sympy.Eq(1 + y, x + x*y)], [x]))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(
        @symsolvers.linsolve_equations_input([
          x() + z() + @symcore.int(-1),
          (x() ^ @symcore.int(2)) + y() + @symcore.int(-3),
        ]),
        [z(), y()],
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.linsolve([x + z - 1, x**2 + y - 3], [z, y]))", "x y z"),
  )
}

///|
test "solvers parity linsolve and solveset batch 6 additional public cases" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let d = @symcore.Expr::Symbol("d")
  let e = @symcore.Expr::Symbol("e")
  let gsym = @symcore.Expr::Symbol("g")
  assert_eq(
    finite_set_single_tuple_residuals_match_oracle(
      @symsolvers.linsolve(
        @symsolvers.linsolve_equations_input([a * x() + b * y() + @symcore.int(-1) * e, c * x() + d * y() + @symcore.int(-1) * gsym]),
        [x(), y()],
      ),
      "sympy.solvers.linsolve([a*x + b*y - e, c*x + d*y - g], (x, y))",
      "x y a b c d e g",
    ),
    "[0, 0]",
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.linsolve(
        @symsolvers.linsolve_augmented_matrix_input(
          @symmatrices.matrix([
            [@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(0)],
            [@symcore.int(2), @symcore.int(4), @symcore.int(6), @symcore.int(0)],
            [@symcore.int(3), @symcore.int(6), @symcore.int(9), @symcore.int(1)],
          ]),
        ),
        [x(), y(), z()],
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.linsolve(sympy.Matrix([[1, 2, 3, 0], [2, 4, 6, 0], [3, 6, 9, 1]]), (x, y, z)))"),
  )
  let avar = @symcore.Expr::Symbol("A")
  let bvar = @symcore.Expr::Symbol("B")
  let j1 = @symcore.Expr::Symbol("J1")
  let j2 = @symcore.Expr::Symbol("J2")
  let imag = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  assert_eq(
    finite_set_single_tuple_residuals_match_oracle(
      @symsolvers.linsolve(
        @symsolvers.linsolve_augmented_matrix_input(
          @symmatrices.matrix([
            [@symcore.int(2) * imag * j1, @symcore.int(2) * imag * j2, @symcore.int(-2) * (j1 ^ @symcore.int(-1))],
            [@symcore.int(-2) * imag * j2, @symcore.int(-2) * imag * j1, @symcore.int(2) * (j2 ^ @symcore.int(-1))],
            [@symcore.int(0), @symcore.int(2), @symcore.int(2) * imag * ((j1 * j2) ^ @symcore.int(-1))],
            [@symcore.int(2), @symcore.int(0), @symcore.int(0)],
          ]),
        ),
        [avar, bvar],
      ),
      "sympy.solvers.linsolve(sympy.Matrix([[2*sympy.I*J1, 2*sympy.I*J2, -2/J1], [-2*sympy.I*J2, -2*sympy.I*J1, 2/J2], [0, 2, 2*sympy.I/(J1*J2)], [2, 0, 0]]), (A, B))",
      "A B J1 J2",
    ),
    "[0, 0]",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(a * (x() ^ @symcore.int(2)) + b * x() + c, symbol=Some(x()), domain=@symsolvers.complexes),
      "sympy.solvers.solveset(a*x**2 + b*x + c, x, sympy.solvers.Complexes)",
      "x a b c",
    ),
    "True",
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(0), symbol=Some(x()), domain=@symsolvers.complexes)),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(0, x, sympy.solvers.Complexes))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(4), symbol=Some(x()), domain=@symsolvers.complexes)),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(4, x, sympy.solvers.Complexes))"),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(@symcore.int(3) * x() + @symcore.int(-2), symbol=Some(x()), domain=@symsolvers.complexes),
      "sympy.solvers.solveset(3*x - 2, x, sympy.solvers.Complexes)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((x() ^ @symcore.int(2)) + @symcore.int(1), symbol=Some(x()), domain=@symsolvers.complexes),
      "sympy.solvers.solveset(x**2 + 1, x, sympy.solvers.Complexes)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((x() ^ @symcore.int(2)) + @symcore.int(-1), symbol=Some(x()), domain=@symsolvers.complexes),
      "sympy.solvers.solveset(x**2 - 1, x, sympy.solvers.Complexes)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((x() ^ @symcore.int(2)) + x(), symbol=Some(x()), domain=@symsolvers.complexes),
      "sympy.solvers.solveset(x**2 + x, x, sympy.solvers.Complexes)",
      "x",
    ),
    "True",
  )
}

///|
test "solvers parity solveset batch 7 additional public cases" {
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(@symcore.function("exp", [x()]) + @symcore.int(-3), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.exp(x) - 3, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(@symcore.function("log", [x()]) + @symcore.int(-3), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.log(x) - 3, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((@symcore.int(2) ^ x()) + @symcore.int(-10), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(2**x - 10, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((x() ^ @symcore.int(-1)) + @symcore.int(1), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(1/x + 1, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((@symcore.function("exp", [x()]) ^ @symcore.int(-1)) + @symcore.int(-1), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(1/sympy.exp(x) - 1, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(x() * (@symcore.int(1) + @symcore.int(-5) * (x() ^ @symcore.int(-1))), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x*(1 - 5/x), x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(
        @symcore.int(2) * x() * ((x() + @symcore.int(2)) ^ @symcore.int(-1)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(2*x/(x + 2) - 1, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(x() + @symcore.int(-1) * (y() ^ @symcore.int(3)), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x - y**3, x))",
      "x y",
    ),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(sqrt(x()) + @symcore.int(-2), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x) - 2, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(
        (x() ^ (@symcore.rational_from_ints(1, 4) catch { _ => fail("quarter") })) + @symcore.int(-2),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**sympy.Rational(1, 4) - 2, x)",
      "x",
    ),
    "True",
  )
}

///|
test "solvers parity solveset batch 8 additional public cases" {
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcore.raw_pow(@symcore.int(0), x()) + @symcore.int(-100), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(0**x - 100, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcore.raw_pow(@symcore.int(0), x()) + @symcore.int(-1), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(0**x - 1, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((@symcore.int(2) * x() + @symcore.int(8)) * (@symcore.int(8) + @symcore.function("exp", [x()])), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((2*x + 8)*(8 + sympy.exp(x)), x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(x() * (@symcore.function("log", [x()]) ^ @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x/sympy.log(x), x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcore.int(3) * x() + @symcore.int(-2), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(3*x - 2, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((x() ^ @symcore.int(2)) + @symcore.int(-1), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**2 - 1, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() ^ (@symcore.rational_from_ints(1, 3) catch { _ => fail("third") })) + @symcore.int(-3),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**sympy.Rational(1, 3) - 3, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(4), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(4, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(0), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(0, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.int(-1) * (x() ^ @symcore.int(2)) +
        @symcore.int(-2) * x() +
        ((x() + @symcore.int(1)) ^ @symcore.int(2)) +
        @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(-x**2 - 2*x + (x + 1)**2 - 1, x))",
      "x",
    ),
  )
}

///|
test "solvers parity solveset batch 9 additional public cases" {
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((x() ^ @symcore.int(3)) + @symcore.int(-8), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**3 - 8, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((x() ^ @symcore.int(3)) + @symcore.int(1), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**3 + 1, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((@symcore.int(2) ^ (x() + @symcore.int(1))) + @symcore.int(-8), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(2**(x + 1) - 8, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcore.function("exp", [@symcore.int(2) * x()]) + @symcore.int(-1), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.exp(2*x) - 1, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(sqrt(x() + @symcore.int(1)) + @symcore.int(-3), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x + 1) - 3, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        ((x() + @symcore.int(1)) ^ (@symcore.rational_from_ints(1, 3) catch { _ => fail("third") })) + @symcore.int(-2),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x + 1)**sympy.Rational(1, 3) - 2, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(((x() + @symcore.int(-2)) ^ @symcore.int(-1)) + @symcore.int(1), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(1/(x - 2) + 1, x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((x() + @symcore.int(-1)) * ((x() + @symcore.int(2)) ^ @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x - 1)/(x + 2), x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(((x() ^ @symcore.int(2)) + @symcore.int(-4)) * ((x() + @symcore.int(-2)) ^ @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x**2 - 4)/(x - 2), x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((x() + @symcore.int(-2)) * ((x() ^ @symcore.int(2)) + @symcore.int(1)), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x - 2)*(x**2 + 1), x))",
      "x",
    ),
  )
}

///|
test "solvers parity solveset batch 10 additional public cases" {
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcalculus.diff((x() ^ @symcore.int(2)) * ((@symcore.int(7) + @symcore.int(-1) * x()) ^ @symcore.int(-1)), x()), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.diff(x**2/(7 - x), x), x))",
      "x",
    ),
  )
  assert_eq(@symsets.to_string(@symsolvers.solveset(@symcore.int(3) ^ (x() + @symcore.int(2)), symbol=Some(x()), domain=@symsets.reals())), solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(3**(x + 2), x))", "x"))
  assert_eq(@symsets.to_string(@symsolvers.solveset(@symcore.int(3) ^ (@symcore.int(2) + @symcore.int(-1) * x()), symbol=Some(x()), domain=@symsets.reals())), solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(3**(2 - x), x))", "x"))
  assert_eq(@symsets.to_string(@symsolvers.solveset(@symcore.function("exp", [x()]), symbol=Some(x()), domain=@symsets.reals())), solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.exp(x), x))", "x"))
  assert_eq(@symsets.to_string(@symsolvers.solveset((x() ^ @symcore.int(2)) + @symcore.int(1), symbol=Some(x()), domain=@symsets.reals())), solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**2 + 1, x))", "x"))
  assert_eq(@symsets.to_string(@symsolvers.solveset(x() ^ @symcore.int(-1), symbol=Some(x()), domain=@symsets.reals())), solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(1/x, x))", "x"))
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (@symcore.int(-1) * ((@symcore.int(1) + x()) * ((@symcore.int(2) + x()) ^ @symcore.int(-2)))) + ((@symcore.int(2) + x()) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(-(1 + x)/(2 + x)**2 + 1/(2 + x), x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(((x() * ((x() + @symcore.int(1)) ^ @symcore.int(-1))) + @symcore.int(3)) ^ @symcore.int(-2), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x/(x + 1) + 3)**(-2), x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset((x() + @symcore.int(-1)) * ((@symcore.int(1) + ((x() + @symcore.int(-1)) ^ @symcore.int(-1))) ^ @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x - 1)/(1 + 1/(x - 1)), x))",
      "x",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(sqrt((x() + @symcore.int(-3)) * (x() ^ @symcore.int(-1))) + (@symcore.int(-1) * half), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt((x - 3)/x) - sympy.Rational(1, 2), x))",
      "x",
    ),
  )
}

///|
test "solvers parity simplex and solveset batch 11 additional public cases" {
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")

  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x() - y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x - y, [x <= y + 2, sympy.Eq(x, y + 2), x >= 0, y >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(1)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + z()),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x, [y >= 1, x >= y + z, x >= 0, z >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        @symcore.int(5) * x2 + x3 + @symcore.int(4) * x4 - x1,
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(5) * x2 + @symcore.int(2) * x3 + @symcore.int(5) * x4 - x1, @symcore.int(5)),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(3) * x2 + x4, @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(-1) * x1 + x3 + @symcore.int(2) * x4, @symcore.int(1)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x1, @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, x1, @symcore.int(1)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x2, @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, x2, @symcore.int(1)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x3, @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, x3, @symcore.int(1)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x4, @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, x4, @symcore.int(1)),
        ],
      ),
    ),
    solvers_eval_str_symbols("repr(sympy.solvers.lpmin(5*x2 + x3 + 4*x4 - x1, [5*x2 + 2*x3 + 5*x4 - (x1 + 5) <= 0, sympy.Eq(3*x2 + x4, 2), sympy.Eq(-x1 + x3 + 2*x4, 1), x1 >= 0, x1 <= 1, x2 >= 0, x2 <= 1, x3 >= 0, x3 <= 1, x4 >= 0, x4 <= 1]))", "x1 x2 x3 x4"),
  )
  assert_eq(
    local_linprog_result_text(
      @symsolvers.linprog(
        [@symcore.int(-1), @symcore.int(5), @symcore.int(1), @symcore.int(4)],
        a=Some(@symmatrices.matrix([[@symcore.int(-1), @symcore.int(5), @symcore.int(2), @symcore.int(5)]])),
        b=Some([@symcore.int(5)]),
        a_eq=Some(@symmatrices.matrix([
          [@symcore.int(0), @symcore.int(3), @symcore.int(0), @symcore.int(1)],
          [@symcore.int(-1), @symcore.int(0), @symcore.int(1), @symcore.int(2)],
        ])),
        b_eq=Some([@symcore.int(2), @symcore.int(1)]),
        bounds=Some([
          (Some(@symcore.int(0)), Some(@symcore.int(1))),
          (Some(@symcore.int(0)), Some(@symcore.int(1))),
          (Some(@symcore.int(0)), Some(@symcore.int(1))),
          (Some(@symcore.int(0)), Some(@symcore.int(1))),
        ]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.linprog([-1, 5, 1, 4], [[-1, 5, 2, 5]], [5], [[0, 3, 0, 1], [-1, 0, 1, 2]], [2, 1], bounds=(0, 1)))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x() + y() - @symcore.int(2) * z() + @symcore.int(1),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(7) * x() + @symcore.int(4) * y() - @symcore.int(7) * z(), @symcore.int(3)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(3) * x() - y() + @symcore.int(10) * z(), @symcore.int(6)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, y() + @symcore.int(-9) * x(), @symcore.int(1)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x + y - 2*z + 1, [7*x + 4*y - 7*z <= 3, 3*x - y + 10*z <= 6, x >= 0, y >= 0, z >= 0, sympy.Eq(y - 9*x, 1)]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x() + y() - @symcore.int(2) * z() + @symcore.int(1),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(7) * x() + @symcore.int(4) * y() - @symcore.int(7) * z(), @symcore.int(3)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(3) * x() - y() + @symcore.int(10) * z(), @symcore.int(6)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, z() - y(), half),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x + y - 2*z + 1, [7*x + 4*y - 7*z <= 3, 3*x - y + 10*z <= 6, x >= 0, y >= 0, z >= 0, z - y <= S.Half]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        x() + y() - @symcore.int(2) * z() + @symcore.int(1),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(7) * x() + @symcore.int(4) * y() - @symcore.int(7) * z(), @symcore.int(3)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(3) * x() - y() + @symcore.int(10) * z(), @symcore.int(6)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, z(), half),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(x + y - 2*z + 1, [7*x + 4*y - 7*z <= 3, 3*x - y + 10*z <= 6, x >= 0, y >= 0, z >= 0, z <= S.Half]))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(sqrt(x()) + @symcore.int(-1), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x) - 1, x))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(sqrt(x() + @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x - 1), x))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(sqrt((x() + @symcore.int(-3)) * (x() ^ @symcore.int(-1))), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt((x - 3)/x), x))", "x"),
  )
}

///|
test "solvers parity solveset batch 12 additional public cases" {
  let positive_infinity = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() ^ @symcore.int(2)) + (@symcore.int(-1) * x()) + @symcore.int(-6),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(0), positive_infinity),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**2 - x - 6, x, sympy.Interval(0, sympy.oo)))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(0), positive_infinity),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**2 - 1, x, sympy.Interval(0, sympy.oo)))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() ^ @symcore.int(4)) + @symcore.int(-16),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(0), @symcore.int(10)),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**4 - 16, x, sympy.Interval(0, 10)))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          ((((x() ^ @symcore.int(2)) + @symcore.int(-4)) ^ @symcore.int(-1)) + x()),
          ((((x() ^ @symcore.int(2)) + @symcore.int(-4)) ^ @symcore.int(-1)) + @symcore.int(2)),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq(1/(x**2 - 4) + x, 1/(x**2 - 4) + 2), x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          (x() ^ @symcore.int(-1)) + x(),
          x() ^ @symcore.int(-1),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq(1/x + x, 1/x), x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.raw_pow(@symcore.int(-2), x()), @symcore.int(4)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq((-2)**x, 4), x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(-1) * (@symcore.int(2) ^ x()), @symcore.int(4)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq(-2**x, 4), x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.raw_pow(@symcore.int(-3), x()), @symcore.int(27)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq((-3)**x, 27), x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.raw_pow(@symcore.int(-5), x() + @symcore.int(1)), @symcore.int(625)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq((-5)**(x + 1), 625), x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(2) ^ (x() + @symcore.int(-3)), @symcore.int(-16)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq(2**(x - 3), -16), x, sympy.S.Reals))", "x"),
  )
}

///|
test "solvers parity simplex and solveset batch 13 additional public cases" {
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmin(
        y(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + @symcore.int(2)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmin(y, [x <= y + 2, x >= y + 2, y >= 0]))"),
  )
  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y()),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), z()),
          @symcore.Expr::Relational(@symcore.RelOp::Le, z(), @symcore.int(3)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x, [sympy.Eq(x, y), sympy.Eq(y, z), z <= 3]))"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(1), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(1, x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.Expr::Boolean(true), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(True, x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.Expr::Boolean(false), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(False, x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.function("exp", [x()]) + @symcore.int(-1), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.exp(x) - 1, x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.function("exp", [x()]), @symcore.int(1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq(sympy.exp(x), 1), x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Ge, x() + @symcore.int(-1), @symcore.int(0)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(x - 1 >= 0, x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Ge, x() ^ @symcore.int(2), @symcore.int(0)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(x**2 >= 0, x, sympy.S.Reals))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-3), x() + @symcore.int(-3)),
          @symcore.int(-1) * (@symcore.int(3) ^ @symcore.int(39)),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("sympy.sstr(sympy.solvers.solveset(sympy.Eq((-3)**(x - 3), -3**39), x, sympy.S.Reals))", "x"),
  )
}

///|
test "solvers parity solve batch 14 additional public cases" {
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_expr_input(@symcore.int(42)))),
    solvers_eval_str("repr(sympy.solvers.solve(42))"),
  )
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_expr_input(@symcore.int(42)), symbols=[x()])),
    solvers_eval_str("repr(sympy.solvers.solve(42, x))"),
  )
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_exprs_input([@symcore.int(1), @symcore.int(2)]))),
    solvers_eval_str("repr(sympy.solvers.solve([1, 2]))"),
  )
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_exprs_input([sqrt(@symcore.int(2))]), symbols=[x()])),
    solvers_eval_str("repr(sympy.solvers.solve([sympy.sqrt(2)], [x]))"),
  )
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_expr_input(y() + @symcore.int(-3)), symbols=[y()])),
    solvers_eval_str("repr(sympy.solvers.solve(y - 3, y))"),
  )
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_expr_input(x() + y() + @symcore.int(-3)), symbols=[x(), y()])),
    solvers_eval_str("repr(sympy.solvers.solve(x + y - 3, [x, y]))"),
  )
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_expr_input(x() + y() + @symcore.int(-3)))),
    solvers_eval_str("repr(sympy.solvers.solve(x + y - 3))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(@symcore.Expr::Symbol("a") + @symcore.Expr::Symbol("b") * x() + @symcore.int(-2)),
        symbols=[@symcore.Expr::Symbol("a"), @symcore.Expr::Symbol("b")],
      ),
    ),
    solvers_eval_str_symbols("repr(sympy.solvers.solve(a + b*x - 2, [a, b]))", "x a b"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input((@symcore.Expr::Symbol("a") + @symcore.Expr::Symbol("b")) * x() + @symcore.Expr::Symbol("b") - @symcore.Expr::Symbol("c")),
        symbols=[@symcore.Expr::Symbol("a"), @symcore.Expr::Symbol("b")],
      ),
    ),
    solvers_eval_str_symbols("repr(sympy.solvers.solve((a + b)*x + b - c, [a, b]))", "x a b c"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(x() - (y() ^ @symcore.int(3))),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(x - y**3, x))"),
  )
}

///|
test "solvers parity solve batch 15 additional public cases" {
  let a11 = @symcore.Expr::Symbol("a11")
  let a12 = @symcore.Expr::Symbol("a12")
  let a21 = @symcore.Expr::Symbol("a21")
  let a22 = @symcore.Expr::Symbol("a22")
  let b1 = @symcore.Expr::Symbol("b1")
  let b2 = @symcore.Expr::Symbol("b2")
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_expr_input(@symcore.int(3) * x() + @symcore.int(-2)), symbols=[x()])),
    solvers_eval_str("repr(sympy.solvers.solve(3*x - 2, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(@symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.int(3) * x(), @symcore.int(2))),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(sympy.Eq(3*x, 2), x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input((x() ^ @symcore.int(2)) + @symcore.int(-1)),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(x**2 - 1, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(@symcore.Expr::Relational(@symcore.RelOp::Eq, x() ^ @symcore.int(2), @symcore.int(1))),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(sympy.Eq(x**2, 1), x))"),
  )
  assert_eq(
    solve_dict_residuals_match_oracle(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([
          a11 * x() + a12 * y() + @symcore.int(-1) * b1,
          a21 * x() + a22 * y() + @symcore.int(-1) * b2,
        ]),
        symbols=[x(), y()],
      ),
      "sympy.solvers.solve([a11*x + a12*y - b1, a21*x + a22*y - b2], x, y)",
      "x y a11 a12 a21 a22 b1 b2",
    ),
    "[0, 0]",
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([x() + @symcore.int(-1) * y(), x() + y()]),
        symbols=[x(), y()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve((x - y, x + y), x, y))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([(x() ^ @symcore.int(2)) + @symcore.int(-4), y() + @symcore.int(-2)]),
        symbols=[x(), y()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve((x**2 - 4, y - 2), x, y))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([x() + y() + @symcore.int(-2), @symcore.int(2) * x() + @symcore.int(2) * y() + @symcore.int(-4)]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve((x + y - 2, 2*x + 2*y - 4)))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x() ^ @symcore.int(2),
            @symcore.Expr::Float(@symcore.float_from_double(0.0)),
          ),
        ),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(sympy.Eq(x**2, 0.0)))"),
  )
  assert_eq(
    local_solve_result_text(@symsolvers.solve(@symsolvers.solve_exprs_input([]), symbols=[x()])),
    solvers_eval_str("repr(sympy.solvers.solve([], [x]))"),
  )
}

///|
test "solvers parity solve batch 16 additional public cases" {
  let one_third = @symcore.rational_from_ints(1, 3) catch { _ => fail("one_third") }
  let quarter = @symcore.rational_from_ints(1, 4) catch { _ => fail("quarter") }
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([x() + y() + @symcore.int(-3), x() + @symcore.int(-1) * y() + @symcore.int(-5)]),
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve([x + y - 3, x - y - 5]))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([(x() ^ @symcore.int(2)) + @symcore.int(-4), y() + @symcore.int(-2)]),
        symbols=[y(), x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve((x**2 - 4, y - 2), y, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), x()),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), x() + @symcore.int(1)),
        ]),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve([sympy.Eq(x, x), sympy.Eq(x, x + 1)], x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_exprs_input([
          @symcore.Expr::Boolean(true),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), x() + @symcore.int(1)),
        ]),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve([True, sympy.Eq(x, 0), sympy.Eq(x, x + 1)], x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(@symcore.Expr::Boolean(true)),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(True, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(sqrt(x()) + @symcore.int(-1)),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(sympy.sqrt(x) - 1, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(sqrt(x()) + @symcore.int(-2)),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(sympy.sqrt(x) - 2, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input((x() ^ quarter) + @symcore.int(-2)),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(x**sympy.Rational(1, 4) - 2, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input((x() ^ one_third) + @symcore.int(-3)),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(x**sympy.Rational(1, 3) - 3, x))"),
  )
  assert_eq(
    local_solve_result_text(
      @symsolvers.solve(
        @symsolvers.solve_expr_input(@symcore.int(4)),
        symbols=[x()],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.solve(4, x))"),
  )
}

///|
test "solvers parity solveset complex batch 17 additional public cases" {
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(0), symbol=Some(x()), domain=@symsolvers.complexes)),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(0, x, sympy.solvers.Complexes))"),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(x() + (x() ^ @symcore.int(-1)) + @symcore.int(-1), symbol=Some(x()), domain=@symsolvers.complexes),
      "sympy.solvers.solveset(x + 1/x - 1, x, sympy.solvers.Complexes)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(
        (x() + @symcore.int(-1)) *
        (x() + @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit) * @symcore.int(-1)) *
        ((x() + @symcore.int(-3)) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsolvers.complexes,
      ),
      "sympy.solvers.solveset((x - 1)*(x - sympy.I)/(x - 3), x, sympy.solvers.Complexes)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(
        (x() + @symcore.int(-1) * (y() ^ @symcore.int(3))) * (((y() ^ @symcore.int(2)) * sqrt(@symcore.int(1) + @symcore.int(-1) * (y() ^ @symcore.int(2)))) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsolvers.complexes,
      ),
      "sympy.solvers.solveset((x - y**3)/((y**2)*sympy.sqrt(1 - y**2)), x, sympy.solvers.Complexes)",
      "x y",
    ),
    "True",
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset((@symcore.function("exp", [x()])) ^ @symcore.int(-1), symbol=Some(x()), domain=@symsolvers.complexes)),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(1/sympy.exp(x), x, sympy.solvers.Complexes))"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() + @symcore.int(-1) * (y() ^ @symcore.int(3))) * (((y() ^ @symcore.int(2)) * sqrt(@symcore.int(1) + @symcore.int(-1) * (y() ^ @symcore.int(2)))) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x - y**3)/((y**2)*sympy.sqrt(1 - y**2)), x))",
      "x y",
    ),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(sqrt(x() + @symcore.int(-2)) + @symcore.int(-5), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x - 2) - 5, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(sqrt(x()) + @symcore.int(-7), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x) - 2 - 5, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(sqrt(x() ^ @symcore.int(3)), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x**3), x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(sqrt(x() + @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(x - 1), x)",
      "x",
    ),
    "True",
  )
}

///|
test "solvers parity solveset domain and no-solution batch 18 additional public cases" {
  let a = @symcore.Expr::Symbol("a")
  let positive_infinity = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
  let one_third = @symcore.rational_from_ints(1, 3) catch { _ => fail("one_third") }
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.int(-1) * (x() ^ @symcore.int(2)) +
        @symcore.int(-2) * x() +
        ((x() + @symcore.int(1)) ^ @symcore.int(2)) +
        @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols(
      "str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(-x**2 - 2*x + (x + 1)**2 - 1, x))",
      "x",
    ),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((x() ^ @symcore.int(2)) + @symcore.int(-1) * x() + @symcore.int(-6), symbol=Some(x()), domain=@symsets.interval(@symcore.int(0), positive_infinity)),
      "sympy.solvers.solveset(x**2 - x - 6, x, sympy.Interval(0, sympy.oo))",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((x() ^ @symcore.int(2)) + @symcore.int(-1), symbol=Some(x()), domain=@symsets.interval(@symcore.int(0), positive_infinity)),
      "sympy.solvers.solveset(x**2 - 1, x, sympy.Interval(0, sympy.oo))",
      "x",
    ),
    "True",
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(sqrt(@symcore.int(1)) + @symcore.int(1), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.sqrt(1) + 1, x))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(1) + @symcore.int(-1) * positive_infinity * x(), symbol=Some(x()))),
    solvers_eval_str_symbols("str(sympy.solvers.solveset(1 - sympy.oo*x, x))", "x"),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset((((@symcore.int(2) * x()) + @symcore.int(-5)) ^ one_third) + @symcore.int(-3), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((2*x - 5)**sympy.Rational(1, 3) - 3, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(positive_infinity * x() + @symcore.int(-1) * positive_infinity, symbol=Some(x()))),
    solvers_eval_str_symbols("str(sympy.solvers.solveset(sympy.oo*x - sympy.oo, x))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(@symcore.int(-3) * a * (sqrt(x()) ^ @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(-3*a/sympy.sqrt(x), x))", "x a"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        ((x() * ((x() + @symcore.int(1)) ^ @symcore.int(-1))) + @symcore.int(3)) ^ @symcore.int(-2),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x/(x + 1) + 3)**(-2), x))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() + @symcore.int(-1)) * ((@symcore.int(1) + ((x() + @symcore.int(-1)) ^ @symcore.int(-1))) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real((x - 1)/(1 + 1/(x - 1)), x))", "x"),
  )
}

///|
test "solvers parity solveset abs and radical batch 19 additional public cases" {
  let positive_infinity = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
  let abs = fn(expr : @symcore.Expr) { @symcore.function("Abs", [expr]) }

  assert_eq(
    @symsets.to_string(@symsolvers.solveset(positive_infinity * x(), symbol=Some(x()))),
    solvers_eval_str_symbols("str(sympy.solvers.solveset(sympy.oo*x, x))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.int(-1) * (x() + @symcore.int(1)) * ((x() + @symcore.int(2)) ^ @symcore.int(-2)) +
        ((x() + @symcore.int(2)) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(-(1 + x)/(2 + x)**2 + 1/(2 + x), x))", "x"),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(abs(x()) + @symcore.int(-2), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.Abs(x) - 2, x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(abs(x()) + @symcore.int(2), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.Abs(x) + 2, x))", "x"),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(abs(x() + @symcore.int(3)) + @symcore.int(-2) * abs(x() + @symcore.int(-3)), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.Abs(x + 3) - 2*sympy.Abs(x - 3), x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(@symcore.int(2) * abs(x()) + @symcore.int(-1) * abs(x() + @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(2*sympy.Abs(x) - sympy.Abs(x - 1), x)",
      "x",
    ),
    "True",
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(x() * (sqrt((x() ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
      "__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x/sympy.sqrt(x**2 + 1), x)",
      "x",
    ),
    "True",
  )
}

///|
test "solvers parity solveset batch 20 additional public cases" {
  let abs = fn(expr : @symcore.Expr) { @symcore.function("Abs", [expr]) }
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let three_halves = @symcore.rational_from_ints(3, 2) catch { _ => fail("3/2") }
  let minus_three_halves = @symcore.rational_from_ints(-3, 2) catch { _ => fail("-3/2") }
  assert_eq(
    @symsets.to_string(@symsolvers.solveset(abs(x()) + @symcore.int(1), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(sympy.Abs(x) + 1, x))", "x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, a, a),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str_symbols("str(sympy.solvers.solveset(sympy.Eq(a, a), x, sympy.S.Reals))", "a x"),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, a, a),
        symbol=Some(y()),
        domain=@symsets.complexes(),
      ),
    ),
    solvers_eval_str_symbols("str(sympy.solvers.solveset(sympy.Eq(a, a), y, sympy.S.Complexes))", "a y"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset((x() ^ three_halves) + @symcore.int(4), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**sympy.Rational(3, 2) + 4, x))", "x"),
  )
  assert_eq(
    @symsets.to_string(@symsolvers.solveset((x() ^ minus_three_halves) + @symcore.int(4), symbol=Some(x()), domain=@symsets.reals())),
    solvers_eval_str_symbols("str(__import__('sympy.solvers.solveset', fromlist=['solveset_real']).solveset_real(x**sympy.Rational(-3, 2) + 4, x))", "x"),
  )
  assert_eq(
    finite_set_exprs_match_oracle(
      @symsolvers.solveset(
        x() + ((a + @symcore.int(-1) * b) * ((@symcore.int(-2) * a + @symcore.int(2) * b) ^ @symcore.int(-1))),
        symbol=Some(x()),
      ),
      "sympy.solvers.solveset(x + (a - b)/(-2*a + 2*b), x)",
      "a b x",
    ),
    "True",
  )
}

///|
test "solvers parity linear_eq_to_matrix and solveset batch 21 additional public cases" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let d = @symcore.Expr::Symbol("d")
  let e = @symcore.Expr::Symbol("e")
  let f_sym = @symcore.Expr::Symbol("f_sym")
  let g_sym = @symcore.Expr::Symbol("g_sym")
  let h = @symcore.Expr::Symbol("h")
  let i = @symcore.Expr::Symbol("i")
  let j = @symcore.Expr::Symbol("j")
  let k = @symcore.Expr::Symbol("k")
  let l = @symcore.Expr::Symbol("l")
  let eqns3 = [
    a * b * x() + b * y() + c * z() - d,
    e * x() + d * x() + f_sym * y() + g_sym * z() - h,
    i * x() + j * y() + k * z() - l,
  ]
  let no_symbols : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix(eqns3, [])
  assert_eq(
    local_linear_eq_result_type(no_symbols),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([a*b*x + b*y + c*z - d, e*x + d*x + f_sym*y + g_sym*z - h, i*x + j*y + k*z - l])",
      "x y z a b c d e f_sym g_sym h i j k l",
    ),
  )

  let duplicate_symbols : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix(eqns3, [x(), x(), y()])
  assert_eq(
    local_linear_eq_result_type(duplicate_symbols),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([a*b*x + b*y + c*z - d, e*x + d*x + f_sym*y + g_sym*z - h, i*x + j*y + k*z - l], [x, x, y])",
      "x y z a b c d e f_sym g_sym h i j k l",
    ),
  )

  let inv_x = x() ^ @symcore.int(-1)
  let nonlinear_recip : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix(
      [@symcore.Expr::Relational(@symcore.RelOp::Eq, inv_x + x(), inv_x)],
      [x()],
    )
  assert_eq(
    local_linear_eq_result_type(nonlinear_recip),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix(sympy.Eq(1/x + x, 1/x), [x])",
      "x",
    ),
  )

  let nonlinear_square : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([x() ^ @symcore.int(2)], [x()])
  assert_eq(
    local_linear_eq_result_type(nonlinear_square),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([x**2], [x])",
      "x",
    ),
  )

  let nonlinear_xy : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([x() * y()], [x(), y()])
  assert_eq(
    local_linear_eq_result_type(nonlinear_xy),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([x*y], [x, y])",
      "x y",
    ),
  )

  let nonlinear_issue_14987 : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix(
      [x() * ((@symcore.int(-3) * inv_x) + @symcore.int(1)) + @symcore.int(2) * y() - a],
      [x(), y()],
    )
  assert_eq(
    local_linear_eq_result_type(nonlinear_issue_14987),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([x*(-3/x + 1) + 2*y - a], [x, y])",
      "x y a",
    ),
  )

  let auto_true : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([@symcore.Expr::Boolean(true)], [x()])
  assert_eq(
    local_linear_eq_result_type(auto_true),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix(sympy.Eq(x, x), x)",
      "x",
    ),
  )

  let auto_false : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([@symcore.Expr::Boolean(false)], [x()])
  assert_eq(
    local_linear_eq_result_type(auto_false),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix(sympy.Eq(x, x + 1), x)",
      "x",
    ),
  )

  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let pi_over_two = half * @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(f(x()) - pi_over_two, symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str(
      "str((lambda f: sympy.solvers.solveset(f(x) - sympy.pi/2, x, sympy.S.Reals))(sympy.Function('f')))",
    ),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(f(g(x())) - pi_over_two, symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str(
      "str((lambda f, g: sympy.solvers.solveset(f(g(x)) - sympy.pi/2, x, sympy.S.Reals))(sympy.Function('f'), sympy.Function('g')))",
    ),
  )
}

///|
test "solvers parity linear_eq_to_matrix and solveset batch 22 additional public cases" {
  let inv_x = x() ^ @symcore.int(-1)

  let nonlinear_cancelled_rational : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([((x() ^ @symcore.int(2)) - @symcore.int(3) * x()) * ((x() + @symcore.int(-3)) ^ @symcore.int(-1)) + @symcore.int(-3)], [x()])
  assert_eq(
    local_linear_eq_result_type(nonlinear_cancelled_rational),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([(x**2 - 3*x)/(x - 3) - 3], x)",
      "x",
    ),
  )

  let nonlinear_binomial_expand : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([((x() + @symcore.int(1)) ^ @symcore.int(3)) + @symcore.int(-1) * (x() ^ @symcore.int(3)) + @symcore.int(-3) * (x() ^ @symcore.int(2)) + @symcore.int(7)], [x()])
  assert_eq(
    local_linear_eq_result_type(nonlinear_binomial_expand),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([(x + 1)**3 - x**3 - 3*x**2 + 7], x)",
      "x",
    ),
  )

  let nonlinear_cancelled_linear : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([x() * (inv_x + @symcore.int(1)) + y()], [x(), y()])
  assert_eq(
    local_linear_eq_result_type(nonlinear_cancelled_linear),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([x*(1/x + 1) + y], [x, y])",
      "x y",
    ),
  )

  let nonlinear_mixed_mul : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix([(x() + @symcore.int(1)) * y()], [x(), y()])
  assert_eq(
    local_linear_eq_result_type(nonlinear_mixed_mul),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([(x + 1)*y], [x, y])",
      "x y",
    ),
  )

  let nonlinear_eq_recip : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix(
      [@symcore.Expr::Relational(@symcore.RelOp::Eq, inv_x, inv_x + y())],
      [x(), y()],
    )
  assert_eq(
    local_linear_eq_result_type(nonlinear_eq_recip),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([sympy.Eq(1/x, 1/x + y)], [x, y])",
      "x y",
    ),
  )

  let nonlinear_eq_y_over_x : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix(
      [@symcore.Expr::Relational(@symcore.RelOp::Eq, y() * inv_x, y() * inv_x + y())],
      [x(), y()],
    )
  assert_eq(
    local_linear_eq_result_type(nonlinear_eq_y_over_x),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([sympy.Eq(y/x, y/x + y)], [x, y])",
      "x y",
    ),
  )

  let nonlinear_eq_quadratic : Result[(@symmatrices.Matrix, @symmatrices.Matrix), @symsolvers.SolverError] = try?
    @symsolvers.linear_eq_to_matrix(
      [@symcore.Expr::Relational(@symcore.RelOp::Eq, x() * (x() + @symcore.int(1)), (x() ^ @symcore.int(2)) + y())],
      [x(), y()],
    )
  assert_eq(
    local_linear_eq_result_type(nonlinear_eq_quadratic),
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.linear_eq_to_matrix([sympy.Eq(x*(x + 1), x**2 + y)], [x, y])",
      "x y",
    ),
  )

  let issue_8715 = @symcore.Expr::Relational(
    @symcore.RelOp::Gt,
    x() + inv_x,
    @symcore.int(-2) + inv_x,
  )
  assert_eq(
    normalize_union_text(@symsets.to_string(
      @symsolvers.solveset(issue_8715, symbol=Some(x()), domain=@symsets.reals()),
    )),
    normalize_union_text(
      solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x + 1/x > -2 + 1/x, x, sympy.S.Reals))"),
    ),
  )

  let log_x = @symcore.function("log", [x()])
  let issue_8715_log = @symcore.Expr::Relational(
    @symcore.RelOp::Gt,
    log_x + (log_x ^ @symcore.int(-1)),
    @symcore.int(-2) + (log_x ^ @symcore.int(-1)),
  )
  assert_eq(
    normalize_union_text(@symsets.to_string(
      @symsolvers.solveset(issue_8715_log, symbol=Some(x()), domain=@symsets.reals()),
    )),
    normalize_union_text(
      solvers_eval_str("sympy.sstr(sympy.solvers.solveset(sympy.log(x) + 1/sympy.log(x) > -2 + 1/sympy.log(x), x, sympy.S.Reals))"),
    ),
  )

  let issue_11174 = (z() ^ @symcore.int(2)) + @symcore.function("exp", [@symcore.int(2) * x()]) - sin(y())
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(issue_11174, symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(z**2 + sympy.exp(2*x) - sympy.sin(y), x, sympy.S.Reals))"),
  )
}

///|
test "solvers parity solveset and simplex batch 23 additional public cases" {
  let t = @symcore.Expr::Symbol("t")
  let r = @symcore.Expr::Symbol("r")
  let tan_t = @symcore.function("tan", [t])
  let abs = fn(expr : @symcore.Expr) { @symcore.function("Abs", [expr]) }

  let issue_11174_b = @symcore.add([
    @symcore.mul([
      sqrt(r),
      abs(tan_t),
      @symcore.pow(sqrt((tan_t ^ @symcore.int(2)) + @symcore.int(1)), @symcore.int(-1)),
    ]),
    @symcore.mul([x(), tan_t]),
  ])
  let issue_11174_b_expected = @symsets.intersection([
    @symsets.reals(),
    @symsets.finite_set([
      @symcore.mul([
        @symcore.int(-1),
        sqrt(r),
        abs(tan_t),
        @symcore.pow(
          @symcore.mul([sqrt((tan_t ^ @symcore.int(2)) + @symcore.int(1)), tan_t]),
          @symcore.int(-1),
        ),
      ]),
    ]),
  ])
  assert_eq(
    @symsets.compare_set(
      @symsolvers.solveset(issue_11174_b, symbol=Some(x()), domain=@symsets.reals()),
      issue_11174_b_expected,
    ),
    0,
  )
  assert_eq(
    solvers_eval_str_symbols(
      "str(sympy.solvers.solveset(sympy.sqrt(r)*sympy.Abs(sympy.tan(t))/sympy.sqrt(sympy.tan(t)**2 + 1) + x*sympy.tan(t), x, sympy.S.Reals) == sympy.Intersection(sympy.S.Reals, sympy.FiniteSet(-sympy.sqrt(r)*sympy.Abs(sympy.tan(t))/(sympy.sqrt(sympy.tan(t)**2 + 1)*sympy.tan(t)))))",
      "x y z r t",
    ),
    "True",
  )

  let issue_10477 = @symcore.Expr::Relational(
    @symcore.RelOp::Lt,
    @symcore.mul([
      (x() ^ @symcore.int(2)) + @symcore.int(4) * x() + @symcore.int(-3),
      x() ^ @symcore.int(-1),
    ]),
    @symcore.int(2),
  )
  assert_eq(
    normalize_union_text(@symsets.to_string(
      @symsolvers.solveset(issue_10477, symbol=Some(x()), domain=@symsets.reals()),
    )),
    normalize_union_text(
      solvers_eval_str("sympy.sstr(sympy.solvers.solveset((x**2 + 4*x - 3)/x < 2, x, sympy.S.Reals))"),
    ),
  )

  let issue_10671_b = @symcore.Expr::Relational(
    @symcore.RelOp::Lt,
    @symcalculus.diff(x() ^ @symcore.int(-1), x()),
    @symcore.int(0),
  )
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        issue_10671_b,
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(1), @symcore.int(10)),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(sympy.diff(1/x, x) < 0, x, sympy.Interval(1, 10)))"),
  )

  let issue_12478 = sqrt(x() + @symcore.int(-2)) + @symcore.int(2)
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(issue_12478, symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str("sympy.sstr(sympy.solveset(sympy.sqrt(x - 2) + 2, x, sympy.S.Reals))"),
  )
  let issue_14300 = @symcore.add([
    @symcore.int(1),
    @symcore.mul([@symcore.int(-1), @symcore.function("exp", [@symcore.int(-18000000) * x()])]),
    @symcore.mul([@symcore.int(-1), y()]),
  ])
  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(issue_14300, symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(1 - sympy.exp(-18000000*x) - y, x, sympy.S.Reals))"),
  )

  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-2) * x() + @symcore.int(-15),
        symbol=Some(x()),
        domain=@symsets.interval(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity),
          @symcore.int(0),
          left_open=true,
          right_open=false,
        ),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(x**2 - 2*x - 15, x, sympy.Interval(-sympy.oo, 0)))"),
  )

  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        x(),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y()),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), z()),
          @symcore.Expr::Relational(@symcore.RelOp::Le, z(), @symcore.int(3)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(x, [sympy.Eq(x, y), sympy.Eq(y, z), z <= 3]))"),
  )

  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        @symcore.int(2) + @symcore.mul([@symcore.int(-1), x()]) + @symcore.mul([@symcore.int(-1), y()]) + @symcore.mul([@symcore.int(-5), z()]),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x() - y() + @symcore.int(2) * z(), @symcore.int(-4)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.mul([@symcore.int(-1), x()]) + @symcore.int(2) * y() + @symcore.mul([@symcore.int(-3), z()]), @symcore.int(8)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(2) * x() + y() + @symcore.mul([@symcore.int(-7), z()]), @symcore.int(10)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(-x - y - 5*z + 2, [x - y + 2*z <= -4, -x + 2*y - 3*z <= 8, 2*x + y - 7*z <= 10, x >= 0, y >= 0, z >= 0]))"),
  )

  assert_eq(
    local_lp_dict_result_text(
      @symsolvers.lpmax(
        @symcore.mul([@symcore.int(-1), x()]) + @symcore.mul([@symcore.int(-1), y()]) + @symcore.mul([@symcore.int(-5), z()]),
        [
          @symcore.Expr::Relational(@symcore.RelOp::Le, x() - y() + @symcore.int(2) * z(), @symcore.int(3)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.mul([@symcore.int(-1), x()]) + @symcore.int(2) * y() + @symcore.mul([@symcore.int(-3), z()]), @symcore.int(-2)),
          @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(2) * x() + y() + @symcore.mul([@symcore.int(-7), z()]), @symcore.int(-5)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
          @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
        ],
      ),
    ),
    solvers_eval_str("repr(sympy.solvers.lpmax(-x - y - 5*z, [x - y + 2*z <= 3, -x + 2*y - 3*z <= -2, 2*x + y - 7*z <= -5, x >= 0, y >= 0, z >= 0]))"),
  )
}

///|
test "solvers parity solveset and simplex invalid inputs batch 24 additional public cases" {
  let one_fifth = @symcore.rational_from_ints(1, 5) catch { _ => fail("1/5") }
  let t = @symcore.Expr::Symbol("t")

  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcore.pow(sqrt(x()), @symcore.int(-1)), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(1/sympy.sqrt(x), x, sympy.S.Reals))"),
  )

  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcalculus.diff(sqrt(x() + (x() ^ @symcore.int(-1))), x()), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str("sympy.sstr(sympy.solvers.solveset(sympy.diff(sympy.sqrt(1/x + x)), x, sympy.S.Reals))"),
  )

  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.pow(@symcore.int(1) + @symcore.int(-1) * (x() ^ @symcore.int(3)), @symcore.int(-2)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solveset(1/(1 - x**3)**2, x, sympy.S.Reals))"),
  )

  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(
        @symcore.mul([
          x() + @symcore.int(5),
          @symcore.pow(sqrt(@symcore.int(-1) * (x() ^ @symcore.int(2)) + @symcore.int(-10) * x()), @symcore.int(-1)),
        ]),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    solvers_eval_str("sympy.sstr(sympy.solveset((x + 5)/sympy.sqrt(-x**2 - 10*x), x, sympy.S.Reals))"),
  )

  let issue_17276_expected = @symsets.finite_set([
    @symcore.Expr::Tuple([
      @symcore.int(5) ^ one_fifth,
      @symcore.int(25) * sqrt(@symcore.int(5)) * (@symcore.int(5) ^ (@symcore.int(-1) * one_fifth)),
    ]),
  ])
  assert_eq(
    @symsets.compare_set(
      @symsolvers.nonlinsolve(
        [
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), @symcore.int(5) ^ one_fifth),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x() * y(), @symcore.int(25) * sqrt(@symcore.int(5))),
        ],
        [x(), y()],
      ),
      issue_17276_expected,
    ),
    0,
  )
  assert_eq(
    solvers_eval_str(
      "str((lambda res: len(res) == 1 and sympy.simplify(list(res)[0][0] - 5**(sympy.S(1)/5)) == 0 and sympy.simplify(list(res)[0][1] - 25*5**(sympy.S(3)/10)) == 0)(sympy.solvers.nonlinsolve([sympy.Eq(x, 5**(sympy.S(1)/5)), sympy.Eq(x*y, 25*sympy.sqrt(5))], [x, y])))",
    ),
    "True",
  )

  assert_eq(
    @symsets.to_string(
      @symsolvers.nonlinsolve(
        [
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.mul([t, sqrt(@symcore.int(5)) + sqrt(@symcore.int(2))]) + @symcore.int(-1) * sqrt(@symcore.int(2)),
            @symcore.int(0),
          ),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, t, @symcore.int(0)),
        ],
        [t],
      ),
    ),
    solvers_eval_str_symbols(
      "sympy.sstr(sympy.solvers.nonlinsolve((t*(sympy.sqrt(5) + sympy.sqrt(2)) - sympy.sqrt(2), t), t))",
      "t",
    ),
  )

  assert_eq(
    @symsets.to_string(
      @symsolvers.solveset(@symcore.int(3) ^ x(), symbol=Some(x()), domain=@symsets.reals()),
    ),
    solvers_eval_str("sympy.sstr(sympy.solveset(3**x, x, sympy.S.Reals))"),
  )

  let irrational_lp : Result[(@symcore.Expr, Map[String, @symcore.Expr]), @symsolvers.SolverError] = try?
    @symsolvers.lpmax(
      @symcore.int(-1) * x() - y() - @symcore.int(5) * z(),
      [
        @symcore.Expr::Relational(@symcore.RelOp::Le, x() - y() + sqrt(@symcore.int(2)) * z(), @symcore.int(-4)),
        @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(-1) * x() + @symcore.int(2) * y() - @symcore.int(3) * z(), @symcore.int(8)),
        @symcore.Expr::Relational(@symcore.RelOp::Le, @symcore.int(2) * x() + y() - @symcore.int(7) * z(), @symcore.int(10)),
        @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
        @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
        @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
      ],
    )
  assert_eq(local_lp_result_type(irrational_lp), "ValueError")
  assert_eq(
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.lpmax(-x - y - 5*z, [x - y + sympy.sqrt(2)*z <= -4, -x + 2*y - 3*z <= 8, 2*x + y - 7*z <= 10, x >= 0, y >= 0, z >= 0])",
      "x y z",
    ),
    "TypeError",
  )

  let strict_lp : Result[(@symcore.Expr, Map[String, @symcore.Expr]), @symsolvers.SolverError] = try?
    @symsolvers.lpmax(
      x(),
      [@symcore.Expr::Relational(@symcore.RelOp::Gt, x(), @symcore.int(0))],
    )
  assert_eq(local_lp_result_type(strict_lp), "ValueError")
  assert_eq(
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.lpmax(x, [x > 0])",
      "x",
    ),
    "TypeError",
  )

  let ne_lp : Result[(@symcore.Expr, Map[String, @symcore.Expr]), @symsolvers.SolverError] = try?
    @symsolvers.lpmax(
      x(),
      [@symcore.Expr::Relational(@symcore.RelOp::Ne, x(), @symcore.int(0))],
    )
  assert_eq(local_lp_result_type(ne_lp), "ValueError")
  assert_eq(
    solvers_eval_stmt_result_symbols(
      "sympy.solvers.lpmax(x, [sympy.Ne(x, 0)])",
      "x",
    ),
    "TypeError",
  )
}

///|
test "solvers parity decompogen" {
  assert_eq(
    (
      local_expr_list_text(@symsolvers.decompogen(sin(cos(x())), x())),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.sin(sympy.cos(x)), x))"),
    ),
  )
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.decompogen(
          @symcore.add([sin(x()) ^ @symcore.int(2), sin(x()), @symcore.int(1)]),
          x(),
        ),
      ),
    ),
    (
      solvers_eval_str(
        "repr(sympy.solvers.decompogen(sympy.sin(x)**2 + sympy.sin(x) + 1, x))",
      ),
    ),
  )
  assert_eq(
    (
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
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.sqrt(6*x**2 - 5), x))"),
    ),
  )
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.decompogen(
          sin(sqrt(cos((x() ^ @symcore.int(2)) + @symcore.int(1)))),
          x(),
        ),
      ),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.sin(sympy.sqrt(sympy.cos(x**2 + 1))), x))"),
    ),
  )
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.decompogen(
          @symcore.function(
            "Abs",
            [(cos(x()) ^ @symcore.int(2)) + @symcore.int(3) * cos(x()) + @symcore.int(-4)],
          ),
          x(),
        ),
      ),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.Abs(sympy.cos(x)**2 + 3*sympy.cos(x) - 4), x))"),
    ),
  )
  assert_eq(
    expr_list_residuals_match_oracle(
      @symsolvers.decompogen(
        (sin(x()) ^ @symcore.int(2)) + sin(x()) + @symcore.mul([@symcore.int(-1), sqrt(@symcore.int(3)), @symcore.pow(@symcore.int(2), @symcore.int(-1))]),
        x(),
      ),
      "sympy.solvers.decompogen(sympy.sin(x)**2 + sympy.sin(x) - sympy.sqrt(3)/2, x)",
      "x",
    ),
    "[0, 0]",
  )
  assert_eq(
    expr_list_residuals_match_oracle(
      @symsolvers.decompogen(
        @symcore.function(
          "Abs",
          [(cos(y()) ^ @symcore.int(2)) + @symcore.int(3) * cos(x()) + @symcore.int(-4)],
        ),
        x(),
      ),
      "sympy.solvers.decompogen(sympy.Abs(sympy.cos(y)**2 + 3*sympy.cos(x) - 4), x)",
      "x y",
    ),
    "[0, 0, 0]",
  )
  assert_eq(
    (
      local_expr_list_text(@symsolvers.decompogen(x(), y())),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(x, y))"),
    ),
  )
  assert_eq(
    (
      local_expr_list_text(@symsolvers.decompogen(@symcore.int(1), x())),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(1, x))"),
    ),
  )
  assert_eq(
    (
      local_expr_list_text(@symsolvers.decompogen(@symcore.function("Max", [@symcore.int(3), x()]), x())),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.Max(3, x), x))"),
    ),
  )
  let u_linear = @symcore.int(2) * x() + @symcore.int(3)
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.decompogen(
          @symcore.function("Max", [sqrt(u_linear), u_linear ^ @symcore.int(2)]),
          x(),
        ),
      ),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.Max(sympy.sqrt(2*x + 3), (2*x + 3)**2), x))"),
    ),
  )
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.decompogen(
          @symcore.function("Max", [u_linear, u_linear ^ @symcore.int(2), y()]),
          x(),
        ),
      ),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(sympy.Max(2*x + 3, (2*x + 3)**2, y), x))"),
    ),
  )
  assert_eq(
    expr_list_residuals_match_oracle(
      @symsolvers.decompogen(
        @symcore.function("Max", [sin(x()), u_linear]),
        x(),
      ),
      "sympy.solvers.decompogen(sympy.Max(sympy.sin(x), 2*x + 3), x)",
      "x",
    ),
    "[0]",
  )
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.decompogen(
          (x() ^ @symcore.int(4)) + @symcore.int(2) * (x() ^ @symcore.int(2)) + @symcore.int(1),
          x(),
        ),
      ),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.decompogen(x**4 + 2*x**2 + 1, x))"),
    ),
  )
  assert_eq(
    expr_list_residuals_match_oracle(
      @symsolvers.decompogen(
        (x() ^ @symcore.int(4)) + @symcore.int(2) * (x() ^ @symcore.int(3)) - x() + @symcore.int(-1),
        x(),
      ),
      "sympy.solvers.decompogen(x**4 + 2*x**3 - x - 1, x)",
      "x",
    ),
    "[0, 0]",
  )
}

///|
test "solvers parity compogen" {
  assert_eq(
    @symprint.to_string(@symsolvers.compogen([sin(x()), cos(x())], x())),
    solvers_eval_str("repr(" + compogen_oracle_expr("[sympy.sin(x), sympy.cos(x)], x") + ")"),
  )
  assert_eq(
    normalize_text(
      @symprint.to_string(
        @symsolvers.compogen(
          [(x() ^ @symcore.int(2)) + x() + @symcore.int(1), sin(x())],
          x(),
        ),
      ),
    ),
    solvers_eval_str("repr(" + compogen_oracle_expr("[x**2 + x + 1, sympy.sin(x)], x") + ")"),
  )
  assert_eq(
    normalize_text(
      @symprint.to_string(
        @symsolvers.compogen(
          [sqrt(x()), @symcore.int(6) * (x() ^ @symcore.int(2)) + @symcore.int(-5)],
          x(),
        ),
      ),
    ),
    solvers_eval_str("repr(" + compogen_oracle_expr("[sympy.sqrt(x), 6*x**2 - 5], x") + ")"),
  )
  assert_eq(
    normalize_text(
      @symprint.to_string(
        @symsolvers.compogen(
          [sin(x()), sqrt(x()), cos(x()), (x() ^ @symcore.int(2)) + @symcore.int(1)],
          x(),
        ),
      ),
    ),
    solvers_eval_str("repr(" + compogen_oracle_expr("[sympy.sin(x), sympy.sqrt(x), sympy.cos(x), x**2 + 1], x") + ")"),
  )
  assert_eq(
    normalize_text(
      @symprint.to_string(
        @symsolvers.compogen(
          [@symcore.function("Abs", [x()]), (x() ^ @symcore.int(2)) + @symcore.int(3) * x() + @symcore.int(-4), cos(x())],
          x(),
        ),
      ),
    ),
    solvers_eval_str("repr(" + compogen_oracle_expr("[sympy.Abs(x), x**2 + 3*x - 4, sympy.cos(x)], x") + ")"),
  )
  assert_eq(
    recurrence_expr_matches_oracle(
      @symsolvers.compogen(
        [
          (x() ^ @symcore.int(2)) + x() + @symcore.mul([@symcore.int(-1), sqrt(@symcore.int(3)), @symcore.pow(@symcore.int(2), @symcore.int(-1))]),
          sin(x()),
        ],
        x(),
      ),
      compogen_oracle_expr("[x**2 + x - sympy.sqrt(3)/2, sympy.sin(x)], x"),
      "x",
    ),
    "0",
  )
  assert_eq(
    recurrence_expr_matches_oracle(
      @symsolvers.compogen(
        [
          (x() ^ @symcore.int(2)) + @symcore.int(3) * x() + (cos(y()) ^ @symcore.int(2)) + @symcore.int(-4),
          cos(x()),
        ],
        x(),
      ),
      compogen_oracle_expr("[x**2 + 3*x + sympy.cos(y)**2 - 4, sympy.cos(x)], x"),
      "x y",
    ),
    "0",
  )
  assert_eq(
    normalize_text(
      @symprint.to_string(
        @symsolvers.compogen(
          [(x() ^ @symcore.int(2)) + @symcore.int(2) * x() + @symcore.int(1), x() ^ @symcore.int(2)],
          x(),
        ),
      ),
    ),
    solvers_eval_str("repr(" + compogen_oracle_expr("[x**2 + 2*x + 1, x**2], x") + ")"),
  )
  assert_eq(
    recurrence_expr_matches_oracle(
      @symsolvers.compogen(
        [(x() ^ @symcore.int(2)) - x() + @symcore.int(-1), (x() ^ @symcore.int(2)) + x()],
        x(),
      ),
      compogen_oracle_expr("[x**2 - x - 1, x**2 + x], x"),
      "x",
    ),
    "0",
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
    (
      local_failing_assumptions_text(
        @symsolvers.failing_assumptions(
          @symcore.int(-2),
          assumption_map([("positive", Some(true)), ("real", Some(true))]),
        ),
      ),
    ),
    (
      solvers_eval_str(
        "repr(__import__('sympy.core.assumptions', fromlist=['failing_assumptions']).failing_assumptions(-2, positive=True, real=True))",
      ),
    ),
  )
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  assert_eq(
    (
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
    (
      solvers_eval_str(
        "(lambda a, b: repr(sympy.solvers.solve_undetermined_coeffs(sympy.Eq(a*x + b, x + 2), [a, b], x)))(*sympy.symbols('a b'))",
      ),
    ),
  )
  assert_eq(
    (
      local_maybe_solve_result_text(
        @symsolvers.solve_undetermined_coeffs(
          @symcore.add([@symcore.mul([a ^ @symcore.int(2), x()]), b, @symcore.mul([@symcore.int(-1), x()])]),
          [a, b],
          syms=[x()],
          dict=true,
        ),
      ),
    ),
    (
      solvers_eval_str(
        "(lambda a, b: repr(sympy.solvers.solve_undetermined_coeffs(a**2*x + b - x, [a, b], x, dict=True)))(*sympy.symbols('a b'))",
      ),
    ),
  )
}

///|
test "solvers parity ode system matrix front doors" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")
  assert_eq(
    local_string_list_repr(@symsolvers.allhints),
    solvers_eval_str(
      "repr(list(__import__('sympy.solvers.ode', fromlist=['allhints']).allhints))",
    ),
  )
  assert_eq(
    (@symprint.to_string(@symsolvers.constantsimp(c1 + c2, [c1, c2]))),
    (
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
    ode_systems_oracle_residual_text(
      @symsolvers.canonical_odes(system, [f(x()), g(x())], x()),
      "__import__('sympy.solvers.ode', fromlist=['canonical_odes']).canonical_odes([sympy.Eq(sympy.Function('f')(x).diff(x) - 7*sympy.Function('f')(x), 12*sympy.Function('g')(x)), sympy.Eq(sympy.Function('g')(x).diff(x) + sympy.Function('g')(x), 20*sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x)",
    ),
    "([2], [2], [[0, 0]])",
  )
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
  assert_eq(
    ode_systems_oracle_residual_text(
      @symsolvers.canonical_odes(nonlinear_system, [f(x()), g(x())], x()),
      "__import__('sympy.solvers.ode', fromlist=['canonical_odes']).canonical_odes([sympy.Eq(sympy.diff(sympy.Function('f')(x), x)**2 - 2*sympy.diff(sympy.Function('f')(x), x) + 1, 4), sympy.Eq(-y*sympy.Function('f')(x) + sympy.diff(sympy.Function('g')(x), x), 0)], [sympy.Function('f')(x), sympy.Function('g')(x)], x)",
    ),
    "([2, 2], [2, 2], [[0, 0], [0, 0]])",
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
  let (higher_a, higher_b) = @symsolvers.linear_ode_to_matrix(higher_order, [f(x()), g(x())], x(), 2)
  assert_eq(
    local_matrix_list_text(higher_a[0]),
    py_matrix_list_text(
      "__import__('sympy.solvers.ode', fromlist=['linear_ode_to_matrix']).linear_ode_to_matrix([sympy.Eq(sympy.diff(sympy.Function('f')(x), x, 2), sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + sympy.Function('g')(x) + 1), sympy.Eq(sympy.diff(sympy.Function('g')(x), x, 2), 2*sympy.diff(sympy.Function('g')(x), x) - sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x, 2)[0][0]",
    ),
  )
  assert_eq(
    local_matrix_list_text(higher_a[1]),
    py_matrix_list_text(
      "__import__('sympy.solvers.ode', fromlist=['linear_ode_to_matrix']).linear_ode_to_matrix([sympy.Eq(sympy.diff(sympy.Function('f')(x), x, 2), sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + sympy.Function('g')(x) + 1), sympy.Eq(sympy.diff(sympy.Function('g')(x), x, 2), 2*sympy.diff(sympy.Function('g')(x), x) - sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x, 2)[0][1]",
    ),
  )
  assert_eq(
    local_matrix_list_text(higher_a[2]),
    py_matrix_list_text(
      "__import__('sympy.solvers.ode', fromlist=['linear_ode_to_matrix']).linear_ode_to_matrix([sympy.Eq(sympy.diff(sympy.Function('f')(x), x, 2), sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + sympy.Function('g')(x) + 1), sympy.Eq(sympy.diff(sympy.Function('g')(x), x, 2), 2*sympy.diff(sympy.Function('g')(x), x) - sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x, 2)[0][2]",
    ),
  )
  assert_eq(
    local_matrix_list_text(higher_b),
    py_matrix_list_text(
      "__import__('sympy.solvers.ode', fromlist=['linear_ode_to_matrix']).linear_ode_to_matrix([sympy.Eq(sympy.diff(sympy.Function('f')(x), x, 2), sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + sympy.Function('g')(x) + 1), sympy.Eq(sympy.diff(sympy.Function('g')(x), x, 2), 2*sympy.diff(sympy.Function('g')(x), x) - sympy.Function('f')(x))], [sympy.Function('f')(x), sympy.Function('g')(x)], x, 2)[1]",
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
}

///|
test "solvers parity constantsimp initial migrated cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  assert_eq(
    recurrence_expr_matches_oracle(
      local_constant_renumber(@symsolvers.constantsimp(y() * c1 * x(), [c1, y()])),
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(y*C1*x, [C1, y]))",
      "x y C1",
    ),
    "0",
  )
  assert_eq(
    recurrence_expr_matches_oracle(
      local_constant_renumber(@symsolvers.constantsimp(c1 * x() * y() * x() * y() * @symcore.int(2), [c1, y()])),
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(C1*x*y*x*y*2, [C1, y]))",
      "x y C1",
    ),
    "0",
  )
  assert_eq(
    recurrence_expr_matches_oracle(
      local_constant_renumber(@symsolvers.constantsimp(@symcore.function("exp", [c1 + x()]), [c1])),
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.exp(sympy.Symbol('C1') + x), [sympy.Symbol('C1')]))",
      "x C1",
    ),
    "0",
  )
}

///|
test "solvers parity constantsimp migrated power function and Eq cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")

  assert_eq(
    @symprint.to_string(local_constant_renumber(@symsolvers.constantsimp(c1 ^ x(), [c1]))),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(C1**x, [C1]))",
      "x C1",
    ),
  )
  assert_eq(
    @symprint.to_string(local_constant_renumber(@symsolvers.constantsimp(y() ^ c1, [c1, y()]))),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(y**C1, [C1, y]))",
      "x y C1",
    ),
  )
  assert_eq(
    @symprint.to_string(local_constant_renumber(@symsolvers.constantsimp(@symcore.function("exp", [c1]), [c1]))),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.exp(C1), [C1]))",
      "x C1",
    ),
  )
  assert_eq(
    @symprint.to_string(local_constant_renumber(@symsolvers.constantsimp(@symcore.applied_undefined_function("f", [c1, x()]), [c1]))),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Function('f')(C1, x), [C1]))",
      "x C1",
    ),
  )
  assert_eq(
    recurrence_expr_matches_oracle(
      local_constant_renumber(
        @symsolvers.constantsimp(
          @symcore.function("sin", [@symcore.int(2) * c1]) + x() + @symcore.function("sqrt", [@symcore.int(2)]),
          [c1],
        ),
      ),
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.sin(2*C1) + x + sympy.sqrt(2), [C1]))",
      "x C1",
    ),
    "0",
  )
  assert_eq(
    @symprint.to_string(
      local_constant_renumber(
        @symsolvers.constantsimp(
          @symcore.Expr::Relational(@symcore.RelOp::Eq, c1, @symcore.int(3) + @symcore.applied_undefined_function("f", [x()]) * x()),
          [c1],
        ),
      ),
    ),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(C1, 3 + sympy.Function('f')(x)*x), [C1]))",
      "x C1",
    ),
  )
  assert_eq(
    @symprint.to_string(
      local_constant_renumber(
        @symsolvers.constantsimp(
          @symcore.Expr::Relational(@symcore.RelOp::Eq, c1, @symcore.int(3) * @symcore.applied_undefined_function("f", [x()]) * x()),
          [c1],
        ),
      ),
    ),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(C1, 3*sympy.Function('f')(x)*x), [C1]))",
      "x C1",
    ),
  )
  assert_eq(
    @symprint.to_string(local_constant_renumber(@symsolvers.constantsimp(@symcore.int(2) * c1 + c2, [c1, c2]))),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(2*C1 + C2, [C1, C2]))",
      "x C1 C2",
    ),
  )
}

///|
test "solvers parity constantsimp initial migrated ode solution cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")
  let c3 = @symcore.Expr::Symbol("C3")
  let u2 = @symcore.Expr::Symbol("u2")
  let a0 = @symcore.Expr::Symbol("_a")
  let one_third = @symcore.rational_from_ints(1, 3) catch { _ => fail("one_third") }
  let imag = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)

  assert_eq(
    @symprint.to_string(
      local_constant_renumber(
        @symsolvers.constantsimp(
          c1 * @symcore.function("exp", [@symcore.int(2) * x()]) +
          @symcore.function("exp", [x()]) * (c2 + c3),
          [c1, c2, c3],
        ),
      ),
    ),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(C1*sympy.exp(2*x) + sympy.exp(x)*(C2 + C3), [C1, C2, C3]))",
      "x C1 C2 C3",
    ),
  )

  assert_eq(
    @symprint.to_string(
      local_constant_renumber(
        @symsolvers.constantsimp(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.applied_undefined_function("f", [x()]),
            imag * c1 * @symcore.function("sinh", [x() * one_third]) +
            c2 * @symcore.function("cosh", [x() * one_third]),
          ),
          [c1, c2],
        ),
      ),
    ),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(sympy.Function('f')(x), sympy.I*C1*sympy.sinh(x/3) + C2*sympy.cosh(x/3)), [C1, C2]))",
      "x C1 C2",
    ),
  )

  assert_eq(
    @symprint.to_string(
      local_constant_renumber(
        @symsolvers.constantsimp(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.applied_undefined_function("f", [x()]),
            @symcore.function(
              "acos",
              [@symcore.int(-1) * c1 * (@symcore.function("cos", [x()]) ^ @symcore.int(-1))],
            ),
          ),
          [c1],
        ),
      ),
    ),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(sympy.Function('f')(x), sympy.acos((-C1)/sympy.cos(x))), [C1]))",
      "x C1",
    ),
  )

  assert_eq(
    @symprint.to_string(
      local_constant_renumber(
        @symsolvers.constantsimp(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.function("log", [@symcore.applied_undefined_function("f", [x()]) * (c1 ^ @symcore.int(-1))]) +
            @symcore.int(2) * @symcore.function("exp", [x() * (@symcore.applied_undefined_function("f", [x()]) ^ @symcore.int(-1))]),
            @symcore.int(0),
          ),
          [c1],
        ),
      ),
    ),
    constantsimp_oracle_text(
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(sympy.log(sympy.Function('f')(x)/C1) + 2*sympy.exp(x/sympy.Function('f')(x)), 0), [C1]))",
      "x C1",
    ),
  )

  let sqrt_log_local = local_constant_renumber(
    @symsolvers.constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        (x() ^ @symcore.int(2)) * (@symcore.int(2) ^ @symcore.int(-1)) * (@symcore.applied_undefined_function("f", [x()]) ^ @symcore.int(-2)) +
        @symcore.function(
          "log",
          [
            @symcore.function("sqrt", [@symcore.int(2)]) *
            x() *
            @symcore.function("sqrt", [x() ^ @symcore.int(-1)]) *
            @symcore.function("sqrt", [@symcore.applied_undefined_function("f", [x()])]) *
            (c1 ^ @symcore.int(-1)),
          ],
        ),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  assert_eq(
    relational_residual_matches_oracle(
      sqrt_log_local,
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(sympy.log(x*sympy.sqrt(2)*sympy.sqrt(1/x)*sympy.sqrt(sympy.Function('f')(x))/C1) + x**2/(2*sympy.Function('f')(x)**2), 0), [C1]))",
      "x C1",
    ),
    "0",
  )

  let ratio = @symcore.applied_undefined_function("f", [x()]) * (x() ^ @symcore.int(-1))
  let exp_ratio = @symcore.function("exp", [@symcore.int(-1) * ratio])
  let trig_log_local = local_constant_renumber(
    @symsolvers.constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.function("log", [x() * (c1 ^ @symcore.int(-1))]) -
        exp_ratio * @symcore.function("sin", [ratio]) * (@symcore.int(2) ^ @symcore.int(-1)) -
        exp_ratio * @symcore.function("cos", [ratio]) * (@symcore.int(2) ^ @symcore.int(-1)),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  assert_eq(
    relational_residual_matches_oracle(
      trig_log_local,
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(-sympy.exp(-sympy.Function('f')(x)/x)*sympy.sin(sympy.Function('f')(x)/x)/2 + sympy.log(x/C1) - sympy.cos(sympy.Function('f')(x)/x)*sympy.exp(-sympy.Function('f')(x)/x)/2, 0), [C1]))",
      "x C1",
    ),
    "0",
  )

  assert_eq(
    relational_list_residuals_match_oracle(
      [
        @symsolvers.constantsimp(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.applied_undefined_function("f", [x()]),
            @symcore.function("sqrt", [@symcore.int(-1) * c1 * x() + (x() ^ @symcore.int(2))]),
          ),
          [c1],
        ),
        @symsolvers.constantsimp(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.applied_undefined_function("f", [x()]),
            @symcore.int(-1) * @symcore.function("sqrt", [@symcore.int(-1) * c1 * x() + (x() ^ @symcore.int(2))]),
          ),
          [c1],
        ),
      ],
      "[__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(i, [C1]) for i in [sympy.Eq(sympy.Function('f')(x), sympy.sqrt(-C1*x + x**2)), sympy.Eq(sympy.Function('f')(x), -sympy.sqrt(-C1*x + x**2))]]",
      "x C1",
    ),
    "[0, 0]",
  )

  let integral_local = local_constant_renumber(
    @symsolvers.constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.int(-1) *
        @symcore.function(
          "Integral",
          [
            @symcore.int(-1) *
            ((u2 * @symcore.function("sqrt", [@symcore.int(1) - (u2 ^ @symcore.int(2))])) ^ @symcore.int(-1)),
            @symcore.Expr::Tuple([u2, a0, x() * (@symcore.applied_undefined_function("f", [x()]) ^ @symcore.int(-1))]),
          ],
        ) +
        @symcore.function("log", [@symcore.applied_undefined_function("f", [x()]) * (c1 ^ @symcore.int(-1))]),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  assert_eq(
    relational_residual_matches_oracle(
      integral_local,
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp', 'constant_renumber']).constant_renumber(__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(sympy.Eq(-sympy.Integral(-1/(sympy.Symbol('u2')*sympy.sqrt(1 - sympy.Symbol('u2')**2)), (sympy.Symbol('u2'), sympy.Symbol('_a'), x/sympy.Function('f')(x))) + sympy.log(sympy.Function('f')(x)/C1), 0), [C1]))",
      "x C1 u2 _a",
    ),
    "0",
  )
}

///|
test "solvers parity constantsimp upstream xfail nonlocal simplification behavior" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")
  assert_eq(
    recurrence_expr_matches_oracle(
      @symsolvers.constantsimp(c1 + c2 + x() * c2, [c1, c2]),
      "__import__('sympy.solvers.ode.ode', fromlist=['constantsimp']).constantsimp(C1 + C2 + x*C2, [C1, C2])",
      "x C1 C2",
    ),
    "0",
  )
}

///|
test "solvers parity lie infinitesimals front doors" {
  let lie_eq = @symcalculus.diff(f(x()), x()) - (x() ^ @symcore.int(2)) * f(x())
  assert_eq(
    infinitesimals_oracle_residual_text(
      @symsolvers.infinitesimals(lie_eq, func=Some(f(x()))),
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x))]",
    ),
    "(1, 1, [(0, 0)])",
  )
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(
        lie_eq,
        @symsolvers.infinitesimals(lie_eq, func=Some(f(x()))),
        func=Some(f(x())),
      ),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x), __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x)))",
    ),
    "(1, 1, [True], [True], [0])",
  )
  let lie_abaco = @symsolvers.infinitesimals(lie_eq, func=Some(f(x())), hint="abaco1_simple")
  assert_eq(
    infinitesimals_oracle_residual_text(
      lie_abaco,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x), hint='abaco1_simple')]",
    ),
    "(3, 3, [(0, 0), (0, 0), (0, 0)])",
  )
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(lie_eq, lie_abaco, func=Some(f(x()))),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x), __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**2*sympy.Function('f')(x), hint='abaco1_simple'))",
    ),
    "(3, 3, [True, True, True], [True, True, True], [0, 0, 0])",
  )
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
  let abaco1_product_inf = @symsolvers.infinitesimals(
    abaco1_product_eq,
    func=Some(f(x())),
    hint="abaco1_product",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      abaco1_product_inf,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - (sympy.Function('f')(x)/x)*(x*sympy.log(x**2/sympy.Function('f')(x)) + 2), hint='abaco1_product')]",
    ),
    "(1, 1, [(0, 0)])",
  )
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(abaco1_product_eq, abaco1_product_inf, func=Some(f(x()))),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol(sympy.diff(sympy.Function('f')(x), x) - (sympy.Function('f')(x)/x)*(x*sympy.log(x**2/sympy.Function('f')(x)) + 2), __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - (sympy.Function('f')(x)/x)*(x*sympy.log(x**2/sympy.Function('f')(x)) + 2), hint='abaco1_product'))",
    ),
    "(1, 1, [True], [True], [0])",
  )
  let chi_eq = x() * @symcalculus.diff(f(x()), x()) + @symcore.int(1) - (f(x()) ^ @symcore.int(2))
  let chi_inf = @symsolvers.infinitesimals(
    chi_eq,
    func=Some(f(x())),
    hint="chi",
  )
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(chi_eq, chi_inf, func=Some(f(x()))),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol(x*sympy.diff(sympy.Function('f')(x), x) + 1 - sympy.Function('f')(x)**2, __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(x*sympy.diff(sympy.Function('f')(x), x) + 1 - sympy.Function('f')(x)**2, hint='chi'))",
    ),
    "(1, 1, [True], [True], [0])",
  )
  let function_sum_eq = @symcalculus.diff(f(x()), x()) -
    @symcore.add([
      @symcore.mul([
        @symcore.int(3),
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([x() ^ @symcore.int(2), f(x()) ^ @symcore.int(-2)]),
        ]),
        @symcore.function(
          "atan",
          [@symcore.mul([f(x()), x() ^ @symcore.int(-1)])],
        ),
      ]),
      @symcore.mul([
        @symcore.add([@symcore.int(1), @symcore.int(-2) * f(x())]),
        x() ^ @symcore.int(-1),
      ]),
      @symcore.mul([
        @symcore.add([@symcore.int(1), @symcore.int(-3) * f(x())]),
        x(),
        f(x()) ^ @symcore.int(-2),
      ]),
    ])
  let function_sum_inf = @symsolvers.infinitesimals(
    function_sum_eq,
    func=Some(f(x())),
    hint="function_sum",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      function_sum_inf,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - (3*(1 + x**2/sympy.Function('f')(x)**2)*sympy.atan(sympy.Function('f')(x)/x) + (1 - 2*sympy.Function('f')(x))/x + (1 - 3*sympy.Function('f')(x))*(x/sympy.Function('f')(x)**2)), hint='function_sum')]",
    ),
    "(1, 1, [(0, 0)])",
  )
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let m = @symcore.Expr::Symbol("m")
  let n = @symcore.Expr::Symbol("n")
  let similar_eq_1 = @symcalculus.diff(f(x()), x()) -
    @symcore.applied_undefined_function("F", [a * x() + b * f(x())])
  let similar_inf_1 = @symsolvers.infinitesimals(
    similar_eq_1,
    func=Some(f(x())),
    hint="abaco2_similar",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      similar_inf_1,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - sympy.Function('F')(a*x + b*sympy.Function('f')(x)), hint='abaco2_similar')]",
    ),
    "(1, 1, [(0, 0)])",
  )
  let unique_unknown_eq_1 = @symcalculus.diff(f(x()), x()) -
    @symcore.mul([
      x() ^ (@symcore.add([a, @symcore.int(-1)])),
      f(x()) ^ (@symcore.add([@symcore.int(1), @symcore.int(-1) * b])),
      @symcore.applied_undefined_function(
        "F",
        [
          @symcore.add([
            @symcore.mul([x() ^ a, a ^ @symcore.int(-1)]),
            @symcore.mul([f(x()) ^ b, b ^ @symcore.int(-1)]),
          ]),
        ],
      ),
    ])
  let unique_unknown_inf_1 = @symsolvers.infinitesimals(
    unique_unknown_eq_1,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      unique_unknown_inf_1,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**(a - 1)*(sympy.Function('f')(x)**(1 - b))*sympy.Function('F')(x**a/a + sympy.Function('f')(x)**b/b), hint='abaco2_unique_unknown')]",
    ),
    "(1, 1, [(0, 0)])",
  )
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
  let unique_unknown_inf_2 = @symsolvers.infinitesimals(
    unique_unknown_eq_2,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      unique_unknown_inf_2,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) + sympy.tan(sympy.Function('F')(x**2 + sympy.Function('f')(x)**2) + sympy.atan(x/sympy.Function('f')(x))), hint='abaco2_unique_unknown')]",
    ),
    "(1, 1, [(0, 0)])",
  )
  let unique_unknown_eq_3 =
    ((
      x() * @symcalculus.diff(f(x()), x()) + f(x()) + @symcore.int(2) * x()
    ) ^ @symcore.int(2)) -
    @symcore.int(4) * x() * f(x()) -
    @symcore.int(4) * (x() ^ @symcore.int(2)) -
    @symcore.int(4) * a
  let unique_unknown_inf_3 = @symsolvers.infinitesimals(
    unique_unknown_eq_3,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(unique_unknown_eq_3, unique_unknown_inf_3, func=Some(f(x()))),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol((x*sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + 2*x)**2 - 4*x*sympy.Function('f')(x) - 4*x**2 - 4*a, __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals((x*sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + 2*x)**2 - 4*x*sympy.Function('f')(x) - 4*x**2 - 4*a, hint='abaco2_unique_unknown'))",
    ),
    "(1, 1, [True], [True], [0])",
  )
  let leading_power = x() ^
    (@symcore.add([n * (@symcore.add([m, @symcore.int(1)])), @symcore.mul([@symcore.int(-1), m])]))
  let forcing_power = x() ^ (@symcore.mul([n, @symcore.add([m, @symcore.int(1)])]))
  let linear_eq =
    (
      leading_power * @symcalculus.diff(f(x()), x()) -
      a * (f(x()) ^ n) -
      b * forcing_power
    )
  let linear_inf = @symsolvers.infinitesimals(linear_eq, func=Some(f(x())), hint="linear")
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(linear_eq, linear_inf, func=Some(f(x()))),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol(x**(n*(m + 1) - m)*sympy.diff(sympy.Function('f')(x), x) - a*sympy.Function('f')(x)**n - b*x**(n*(m + 1)), __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(x**(n*(m + 1) - m)*sympy.diff(sympy.Function('f')(x), x) - a*sympy.Function('f')(x)**n - b*x**(n*(m + 1)), hint='linear'))",
    ),
    "(1, 1, [True], [True], [0])",
  )
}

///|
test "solvers parity abaco2_unique_unknown reference cases" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let unique_unknown_eq_1 = @symcalculus.diff(f(x()), x()) -
    @symcore.mul([
      x() ^ (@symcore.add([a, @symcore.int(-1)])),
      f(x()) ^ (@symcore.add([@symcore.int(1), @symcore.int(-1) * b])),
      @symcore.applied_undefined_function(
        "F",
        [
          @symcore.add([
            @symcore.mul([x() ^ a, a ^ @symcore.int(-1)]),
            @symcore.mul([f(x()) ^ b, b ^ @symcore.int(-1)]),
          ]),
        ],
      ),
    ])
  let unique_unknown_inf_1 = @symsolvers.infinitesimals(
    unique_unknown_eq_1,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      unique_unknown_inf_1,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - x**(a - 1)*(sympy.Function('f')(x)**(1 - b))*sympy.Function('F')(x**a/a + sympy.Function('f')(x)**b/b), hint='abaco2_unique_unknown')]",
    ),
    "(1, 1, [(0, 0)])",
  )
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
  let unique_unknown_inf_2 = @symsolvers.infinitesimals(
    unique_unknown_eq_2,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      unique_unknown_inf_2,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) + sympy.tan(sympy.Function('F')(x**2 + sympy.Function('f')(x)**2) + sympy.atan(x/sympy.Function('f')(x))), hint='abaco2_unique_unknown')]",
    ),
    "(1, 1, [(0, 0)])",
  )
  let unique_unknown_eq_3 =
    ((
      x() * @symcalculus.diff(f(x()), x()) + f(x()) + @symcore.int(2) * x()
    ) ^ @symcore.int(2)) -
    @symcore.int(4) * x() * f(x()) -
    @symcore.int(4) * (x() ^ @symcore.int(2)) -
    @symcore.int(4) * a
  let unique_unknown_inf_3 = @symsolvers.infinitesimals(
    unique_unknown_eq_3,
    func=Some(f(x())),
    hint="abaco2_unique_unknown",
  )
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(unique_unknown_eq_3, unique_unknown_inf_3, func=Some(f(x()))),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol((x*sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + 2*x)**2 - 4*x*sympy.Function('f')(x) - 4*x**2 - 4*a, __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals((x*sympy.diff(sympy.Function('f')(x), x) + sympy.Function('f')(x) + 2*x)**2 - 4*x*sympy.Function('f')(x) - 4*x**2 - 4*a, hint='abaco2_unique_unknown'))",
    ),
    "(1, 1, [True], [True], [0])",
  )
}

///|
test "solvers parity ode scalar front doors" {
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
    (@symprint.to_string(@symsolvers.dsolve(ode, func=Some(f(x()))))),
    (
      solvers_eval_str(
        "sympy.sstr(sympy.solvers.dsolve(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x))))",
      ),
    ),
  )
  assert_eq(
    (
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
    (
      checkodesol_oracle_text(
        "sympy.solvers.checkodesol(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x)), sympy.solvers.dsolve(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x))))",
      ),
    ),
  )
}

///|
test "solvers parity pde front doors" {
  let pde = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(u(x(), y()), x()),
    @symcalculus.diff(u(x(), y()), y()),
  )
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.pde_separate_add(
          pde,
          u(x(), y()),
          [xfun(x()), yfun(y())],
        ).unwrap_or([]),
      ),
    ),
    (
      solvers_eval_str(
        "repr(sympy.solvers.pde_separate_add(sympy.Eq(sympy.Function('u')(x, y).diff(x), sympy.Function('u')(x, y).diff(y)), sympy.Function('u')(x, y), [sympy.Function('X')(x), sympy.Function('Y')(y)]))",
      ),
    ),
  )
  assert_eq(
    (
      local_expr_list_text(
        @symsolvers.pde_separate_mul(
          pde,
          u(x(), y()),
          [xfun(x()), yfun(y())],
        ).unwrap_or([]),
      ),
    ),
    (
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
    (@symprint.to_string(@symsolvers.pdsolve(pde, func=Some(u(x(), y()))))),
    (
      solvers_eval_str(
        "sympy.sstr(sympy.solvers.pdsolve(sympy.Eq(sympy.Function('u')(x, y).diff(x), sympy.Function('u')(x, y).diff(y))))",
      ),
    ),
  )
}

///|
test "solvers parity checkodesol subscheck cases" {
  let exact_sol = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    (f(x()) ^ @symcore.int(5)) + @symcore.int(9) * f(x()) + x(),
    @symcore.int(0),
  )
  assert_eq(
    (
      "(" +
      @symsolvers.checkodesol(
        @symcalculus.diff((f(x()) ^ @symcore.int(5)) + @symcore.int(9) * f(x()) + x(), x()),
        exact_sol,
        func=Some(f(x())),
      ).0.to_string() +
      ", " +
      @symprint.to_string(
        @symsolvers.checkodesol(
          @symcalculus.diff((f(x()) ^ @symcore.int(5)) + @symcore.int(9) * f(x()) + x(), x()),
          exact_sol,
          func=Some(f(x())),
        ).1,
      ) +
      ")"
    ),
    checkodesol_oracle_text(
      "sympy.solvers.checkodesol(sympy.diff(sympy.Function('f')(x)**5 + 9*sympy.Function('f')(x) + x, x), sympy.Eq(sympy.Function('f')(x)**5 + 9*sympy.Function('f')(x) + x, 0))",
    ),
  )
  let implicit_sol = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.function("exp", [f(x())]) + x(),
    @symcore.int(0),
  )
  assert_eq(
    (
      "(" +
      @symsolvers.checkodesol(
        x() * @symcalculus.diff(@symcore.function("exp", [f(x())]) + x(), x()),
        implicit_sol,
        func=Some(f(x())),
        solve_for_func=false,
      ).0.to_string() +
      ", " +
      @symprint.to_string(
        @symsolvers.checkodesol(
          x() * @symcalculus.diff(@symcore.function("exp", [f(x())]) + x(), x()),
          implicit_sol,
          func=Some(f(x())),
          solve_for_func=false,
        ).1,
      ) +
      ")"
    ),
    checkodesol_oracle_text(
      "sympy.solvers.checkodesol(x*sympy.diff(sympy.exp(sympy.Function('f')(x)) + x, x), sympy.Eq(sympy.exp(sympy.Function('f')(x)) + x, 0), solve_for_func=False)",
    ),
  )
  let c1 = @symcore.Expr::Symbol("C1")
  assert_eq(
    (
      "(" +
      @symsolvers.checkodesol(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcalculus.diff(f(x()), x()),
          f(x()),
        ),
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          c1 * @symcore.function("exp", [x()]),
          f(x()),
        ),
        func=Some(f(x())),
      ).0.to_string() +
      ", " +
      @symprint.to_string(
        @symsolvers.checkodesol(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcalculus.diff(f(x()), x()),
            f(x()),
          ),
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            c1 * @symcore.function("exp", [x()]),
            f(x()),
          ),
          func=Some(f(x())),
        ).1,
      ) +
      ")"
    ),
    checkodesol_oracle_text(
      "sympy.solvers.checkodesol(sympy.Eq(sympy.Function('f')(x).diff(x), sympy.Function('f')(x)), sympy.Eq(sympy.Symbol('C1')*sympy.exp(x), sympy.Function('f')(x)))",
    ),
  )
  assert_eq(
    (
      "(" +
      @symsolvers.checkodesol(
        @symcalculus.diff(f(x()), x()),
        @symcore.Expr::Relational(@symcore.RelOp::Eq, f(x()), x()),
        func=Some(f(x())),
      ).0.to_string() +
      ", " +
      @symprint.to_string(
        @symsolvers.checkodesol(
          @symcalculus.diff(f(x()), x()),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, f(x()), x()),
          func=Some(f(x())),
        ).1,
      ) +
      ")"
    ),
    checkodesol_oracle_text(
      "sympy.solvers.checkodesol(sympy.diff(sympy.Function('f')(x), x), sympy.Eq(sympy.Function('f')(x), x))",
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
    (
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
    (
      @symsets.to_string(@symsolvers.diophantine(x() + y() - @symcore.int(3))),
    ),
    (
      solvers_eval_str("repr(sympy.solvers.diophantine(x + y - 3))"),
    ),
  )
  assert_eq(
    (
      local_classify_diop_text(
        @symsolvers.classify_diop(x() + y() - @symcore.int(3)),
      ),
    ),
    (
      solvers_eval_str(
        "repr(__import__('sympy.solvers.diophantine', fromlist=['classify_diop']).classify_diop(x + y - 3))",
      ),
    ),
  )
  assert_eq(
    (
      local_diop_solve_result_text(
        @symsolvers.diop_solve(x() + y() - @symcore.int(3)),
      ),
    ),
    (
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

///|
test "solvers parity lie heuristic function_sum" {
  let function_sum_eq = @symcalculus.diff(f(x()), x()) -
    @symcore.add([
      @symcore.mul([
        @symcore.int(3),
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([x() ^ @symcore.int(2), f(x()) ^ @symcore.int(-2)]),
        ]),
        @symcore.function(
          "atan",
          [@symcore.mul([f(x()), x() ^ @symcore.int(-1)])],
        ),
      ]),
      @symcore.mul([
        @symcore.add([@symcore.int(1), @symcore.int(-2) * f(x())]),
        x() ^ @symcore.int(-1),
      ]),
      @symcore.mul([
        @symcore.add([@symcore.int(1), @symcore.int(-3) * f(x())]),
        x(),
        f(x()) ^ @symcore.int(-2),
      ]),
    ])
  let function_sum_inf = @symsolvers.infinitesimals(
    function_sum_eq,
    func=Some(f(x())),
    hint="function_sum",
  )
  assert_eq(
    infinitesimals_oracle_residual_text(
      function_sum_inf,
      "[{'xi': item[sympy.Function('xi')(x, sympy.Function('f')(x))], 'eta': item[sympy.Function('eta')(x, sympy.Function('f')(x))]} for item in __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - (3*(1 + x**2/sympy.Function('f')(x)**2)*sympy.atan(sympy.Function('f')(x)/x) + (1 - 2*sympy.Function('f')(x))/x + (1 - 3*sympy.Function('f')(x))*(x/sympy.Function('f')(x)**2)), hint='function_sum')]",
    ),
    "(1, 1, [(0, 0)])",
  )
  assert_eq(
    checkinfsol_oracle_residual_text(
      @symsolvers.checkinfsol(function_sum_eq, function_sum_inf, func=Some(f(x()))),
      "__import__('sympy.solvers.ode', fromlist=['checkinfsol', 'infinitesimals']).checkinfsol(sympy.diff(sympy.Function('f')(x), x) - (3*(1 + x**2/sympy.Function('f')(x)**2)*sympy.atan(sympy.Function('f')(x)/x) + (1 - 2*sympy.Function('f')(x))/x + (1 - 3*sympy.Function('f')(x))*(x/sympy.Function('f')(x)**2)), __import__('sympy.solvers.ode', fromlist=['infinitesimals']).infinitesimals(sympy.diff(sympy.Function('f')(x), x) - (3*(1 + x**2/sympy.Function('f')(x)**2)*sympy.atan(sympy.Function('f')(x)/x) + (1 - 2*sympy.Function('f')(x))/x + (1 - 3*sympy.Function('f')(x))*(x/sympy.Function('f')(x)**2)), hint='function_sum'))",
    ),
    "(1, 1, [True], [True], [0])",
  )
}
