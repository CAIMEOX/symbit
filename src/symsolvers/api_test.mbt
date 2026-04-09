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
fn t() -> @symcore.Expr {
  @symcore.Expr::Symbol("t")
}

///|
fn r() -> @symcore.Expr {
  @symcore.Expr::Symbol("r")
}

///|
fn theta() -> @symcore.Expr {
  @symcore.Expr::Symbol("theta")
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
fn phi(
  rv : @symcore.Expr,
  tv : @symcore.Expr,
  zv : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.applied_undefined_function("Phi", [rv, tv, zv])
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
fn tfun(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("T", [expr])
}

///|
fn zfun(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("Z", [expr])
}

///|
fn rfun(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.applied_undefined_function("R", [expr])
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
    InequalityResult::Relational(expr) =>
      "Relational(" + @symprint.to_string(expr) + ")"
  }
}

///|
fn expr_matrix_text(items : Array[Array[@symcore.Expr]]) -> String {
  "[" + items.map(expr_list_text).join(", ") + "]"
}

///|
fn local_infinitesimals_text(
  items : Array[Map[String, @symcore.Expr]],
) -> String {
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
    DiopSolveResult::Tuple(items) =>
      "(" + items.map(@symprint.to_string).join(", ") + ")"
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
    (
      @symcore.Expr::UndefinedFunction(lhs_name),
      @symcore.Expr::UndefinedFunction(rhs_name),
    ) => lhs_name.compare(rhs_name)
    (@symcore.Expr::UndefinedFunction(_), @symcore.Expr::FunctionHead(_)) => -1
    (@symcore.Expr::FunctionHead(_), @symcore.Expr::UndefinedFunction(_)) => 1
    (
      @symcore.Expr::FunctionHead(lhs_name),
      @symcore.Expr::FunctionHead(rhs_name),
    ) => {
      let rank_cmp = test_sympy_function_rank(lhs_name).compare(
        test_sympy_function_rank(rhs_name),
      )
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
    _ =>
      1 +
      @symcore.children(expr).fold(init=0, fn(acc, child) {
        acc + test_sort_node_count(child)
      })
  }
}

///|
fn test_sort_expr_cmp(lhs_raw : @symcore.Expr, rhs_raw : @symcore.Expr) -> Int {
  let lhs = test_constant_sort_expr(lhs_raw)
  let rhs = test_constant_sort_expr(rhs_raw)
  match (lhs, rhs) {
    (
      @symcore.Expr::Apply(lhs_head, lhs_args),
      @symcore.Expr::Apply(rhs_head, rhs_args),
    ) => {
      let head_cmp = test_sort_apply_head_cmp(lhs_head, rhs_head)
      if head_cmp != 0 {
        return head_cmp
      }
      return test_sort_exprs_cmp(lhs_args, rhs_args)
    }
    (@symcore.Expr::Add(lhs_args), @symcore.Expr::Add(rhs_args))
    | (@symcore.Expr::Mul(lhs_args), @symcore.Expr::Mul(rhs_args)) =>
      test_sort_exprs_cmp(lhs_args, rhs_args)
    (
      @symcore.Expr::Pow(lhs_base, lhs_exp),
      @symcore.Expr::Pow(rhs_base, rhs_exp),
    ) => {
      let base_cmp = test_sort_expr_cmp(lhs_base, rhs_base)
      if base_cmp != 0 {
        return base_cmp
      }
      return test_sort_expr_cmp(lhs_exp, rhs_exp)
    }
    (
      @symcore.Expr::Relational(lhs_op, lhs_lhs, lhs_rhs),
      @symcore.Expr::Relational(rhs_op, rhs_lhs, rhs_rhs),
    ) => {
      let op_cmp = test_sort_relop_rank(lhs_op).compare(
        test_sort_relop_rank(rhs_op),
      )
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
      let node_cmp = test_sort_node_count(lhs).compare(
        test_sort_node_count(rhs),
      )
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
fn test_sort_constant_args(
  items : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
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
        test_sort_constant_args(args).map(arg => {
          local_constant_renumber_inner(arg, constants_found)
        }),
      )
    @symcore.Expr::Mul(args) =>
      @symcore.Expr::Mul(
        test_sort_constant_args(args).map(arg => {
          local_constant_renumber_inner(arg, constants_found)
        }),
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
    _ =>
      @symcore.map_children(expr, child => {
        local_constant_renumber_inner(child, constants_found)
      })
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
  let lhs_norm = local_semantic_normalize(lhs)
  let rhs_norm = local_semantic_normalize(rhs)
  if @symcore.compare_expr(lhs_norm, rhs_norm) == 0 {
    return true
  }
  let raw_diff = lhs_norm + @symcore.int(-1) * rhs_norm
  if @symcore.compare_expr(raw_diff, @symcore.int(0)) == 0 ||
    @symcore.is_zero(raw_diff) {
    return true
  }
  let simplified = @symsimplify.simplify(raw_diff)
  if @symcore.compare_expr(simplified, @symcore.int(0)) == 0 ||
    @symcore.is_zero(simplified) {
    return true
  }
  let rational = @symsimplify.ratsimp(raw_diff, max_passes=4)
  if @symcore.compare_expr(rational, @symcore.int(0)) == 0 ||
    @symcore.is_zero(rational) {
    return true
  }
  let expanded = local_semantic_normalize(@symsimplify.numer_expand(raw_diff))
  if @symcore.compare_expr(expanded, @symcore.int(0)) == 0 ||
    @symcore.is_zero(expanded) {
    return true
  }
  let expanded_simplified = local_semantic_normalize(
    @symsimplify.simplify(expanded, max_passes=4),
  )
  if @symcore.compare_expr(expanded_simplified, @symcore.int(0)) == 0 ||
    @symcore.is_zero(expanded_simplified) {
    return true
  }
  let expanded_rational = local_semantic_normalize(
    @symsimplify.ratsimp(expanded, max_passes=4),
  )
  @symcore.compare_expr(expanded_rational, @symcore.int(0)) == 0 ||
  @symcore.is_zero(expanded_rational)
}

///|
fn local_canonical_expr(expr : @symcore.Expr) -> @symcore.Expr {
  @symsimplify.simplify(
    @sympolys.domain_normal_expr(@sympolys.Domain::EX, expr) catch {
      _ => expr
    },
  )
}

///|
fn local_expand_exp_sums(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => @symcore.add(args.map(local_expand_exp_sums))
    @symcore.Expr::Mul(args) => @symcore.mul(args.map(local_expand_exp_sums))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(local_expand_exp_sums(base), local_expand_exp_sums(exp))
    @symcore.Expr::Tuple(items) =>
      @symcore.Expr::Tuple(items.map(local_expand_exp_sums))
    @symcore.Expr::Relational(op, lhs, rhs) =>
      @symcore.Expr::Relational(
        op,
        local_expand_exp_sums(lhs),
        local_expand_exp_sums(rhs),
      )
    @symcore.Expr::Apply(head, args) => {
      let head_norm = local_expand_exp_sums(head)
      let args_norm = args.map(arg => {
        local_canonical_expr(local_expand_exp_sums(arg))
      })
      match (head_norm, args_norm) {
        (@symcore.Expr::FunctionHead(name), [@symcore.Expr::Add(add_args)]) if name ==
          "exp" =>
          @symcore.mul(add_args.map(arg => @symcore.function("exp", [arg])))
        _ => @symcore.Expr::Apply(head_norm, args_norm)
      }
    }
    _ => expr
  }
}

///|
fn local_combine_exp_products(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(local_combine_exp_products))
    @symcore.Expr::Mul(args) => {
      let exp_args : Array[@symcore.Expr] = []
      let other_args : Array[@symcore.Expr] = []
      for arg in args.map(local_combine_exp_products) {
        match arg {
          @symcore.Expr::Apply(@symcore.Expr::FunctionHead(name), [inner]) if name ==
            "exp" => exp_args.push(inner)
          _ => other_args.push(arg)
        }
      }
      if exp_args.is_empty() {
        @symcore.mul(other_args)
      } else {
        other_args.push(@symcore.function("exp", [@symcore.add(exp_args)]))
        @symcore.mul(other_args)
      }
    }
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(
        local_combine_exp_products(base),
        local_combine_exp_products(exp),
      )
    @symcore.Expr::Tuple(items) =>
      @symcore.Expr::Tuple(items.map(local_combine_exp_products))
    @symcore.Expr::Relational(op, lhs, rhs) =>
      @symcore.Expr::Relational(
        op,
        local_combine_exp_products(lhs),
        local_combine_exp_products(rhs),
      )
    @symcore.Expr::Apply(head, args) =>
      @symcore.Expr::Apply(
        local_combine_exp_products(head),
        args.map(arg => local_canonical_expr(local_combine_exp_products(arg))),
      )
    _ => expr
  }
}

///|
fn local_semantic_normalize(expr : @symcore.Expr) -> @symcore.Expr {
  local_canonical_expr(local_combine_exp_products(local_expand_exp_sums(expr)))
}

///|
fn tuple_expr_semantically_equal(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> Bool {
  match lhs {
    @symcore.Expr::Tuple(lhs_items) =>
      match rhs {
        @symcore.Expr::Tuple(rhs_items) => {
          if lhs_items.length() != rhs_items.length() {
            return false
          }
          for i in 0..<lhs_items.length() {
            if !expr_semantically_equal(lhs_items[i], rhs_items[i]) {
              return false
            }
          }
          true
        }
        _ => expr_semantically_equal(lhs, rhs)
      }
    _ => expr_semantically_equal(lhs, rhs)
  }
}

///|
fn finite_set_exprs_semantically_equal(
  actual : @symsets.Set,
  expected : Array[@symcore.Expr],
) -> Bool {
  match actual {
    @symsets.Set::FiniteSet(items) => {
      if items.length() != expected.length() {
        return false
      }
      let used = Array::make(expected.length(), false)
      for item in items {
        let mut matched = false
        for i in 0..<expected.length() {
          if !used[i] && tuple_expr_semantically_equal(item, expected[i]) {
            used[i] = true
            matched = true
            break
          }
        }
        if !matched {
          return false
        }
      }
      true
    }
    _ => false
  }
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
fn expr_dict_get(expr : @symcore.Expr, key : String) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Dict(items) => {
      for item in items {
        let (k, v) = item
        if @symprint.to_string(k) == key {
          return Some(v)
        }
      }
      None
    }
    _ => None
  }
}

///|
fn expr_dict_len_text(expr : @symcore.Expr) -> String {
  match expr {
    @symcore.Expr::Dict(items) => items.length().to_string()
    _ => "None"
  }
}

///|
fn maybe_expr_compare_text(
  value : @symcore.Expr?,
  expected : @symcore.Expr,
) -> String {
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
test "nsolve matches additional SymPy scalar numeric cases batch 2" {
  let sin_root = nsolve(sin(x()), x(), @symcore.int(2))
  assert_true(@symprint.to_string(sin_root).has_prefix("3.14159265358979"))

  let eq_root = nsolve(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.int(2) * x(),
      @symcore.int(2),
    ),
    x(),
    @symcore.int(-10),
  )
  inspect(@symprint.to_string(eq_root), content="1.0")

  let linear_root = nsolve(
    @symcore.int(2) * x() + @symcore.int(-2),
    x(),
    @symcore.int(-10),
  )
  inspect(@symprint.to_string(linear_root), content="1.0")
  assert_eq(@symprint.to_string(eq_root), @symprint.to_string(linear_root))

  let pi_root_default = nsolve(
    (x() ^ @symcore.int(2)) -
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
    x(),
    @symcore.Expr::Float(@symcore.float_from_double(3.0)),
  )
  assert_true(
    @symprint.to_string(pi_root_default).has_prefix("1.77245385090551"),
  )

  let pi_root_precise = nsolve(
    (x() ^ @symcore.int(2)) -
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
    x(),
    @symcore.int(3),
    prec=128,
  )
  assert_true(
    @symprint.to_string(pi_root_precise).has_prefix(
      "1.77245385090551602729816748",
    ),
  )

  let third_root = nsolve(
    x() - @symcore.rational_from_ints(1, 3),
    x(),
    @symcore.int(0),
    prec=100,
  )
  assert_true(
    @symprint.to_string(third_root).has_prefix("0.333333333333333333333333"),
  )

  let a = @symcore.Expr::Symbol("a")
  let delicate_root = nsolve(
    @symcore.pow(
      @symcore.add([@symcore.Expr::Float(@symcore.float_from_double(0.001)), a]),
      @symcore.int(-3),
    ) -
    @symcore.int(6) *
    @symcore.pow(
      @symcore.add([
        @symcore.Expr::Float(@symcore.float_from_double(0.9)),
        @symcore.int(-1) * a,
      ]),
      @symcore.int(-3),
    ),
    a,
    @symcore.Expr::Float(@symcore.float_from_double(0.3)),
  )
  assert_true(@symprint.to_string(delicate_root).has_prefix("0.318830113873"))
}

///|
test "lpmin lpmax and linprog solve basic linear programs" {
  let min_result = lpmin(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(1)),
  ])
  inspect(@symprint.to_string(min_result.0), content="1")
  inspect(solution_dict_text(min_result.1, ["x"]), content="{x: 1}")

  let max_result = lpmax(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), @symcore.int(-1)),
  ])
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
  let infeasible : Result[
    (@symcore.Expr, Map[String, @symcore.Expr]),
    SolverError,
  ] = try? lpmax(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), @symcore.int(-1)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
  ])
  assert_true(infeasible is Err(SolverError::InfeasibleLPError(_)))

  let unbounded : Result[
    (@symcore.Expr, Map[String, @symcore.Expr]),
    SolverError,
  ] = try? lpmin(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), @symcore.int(3)),
  ])
  assert_true(unbounded is Err(SolverError::UnboundedLPError(_)))
}

///|
test "lp solvers handle Eq constraints and extra symbols like SymPy simplex front doors" {
  let eq_max = lpmax(x() - y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(eq_max.0), content="2")
  inspect(solution_dict_text(eq_max.1, ["x", "y"]), content="{x: 2, y: 0}")

  let eq_min = lpmin(y(), [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(0),
      y() + @symcore.int(2),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Ge,
      @symcore.int(0),
      y() + @symcore.int(2),
    ),
  ])
  inspect(@symprint.to_string(eq_min.0), content="-2")
  inspect(solution_dict_text(eq_min.1, ["y"]), content="{y: -2}")

  let single_eq = lpmax(y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), @symcore.int(2)),
  ])
  inspect(@symprint.to_string(single_eq.0), content="2")
  inspect(solution_dict_text(single_eq.1, ["y"]), content="{y: 2}")

  let extra_symbol = lpmin(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(1)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + z()),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(extra_symbol.0), content="1")
  inspect(
    solution_dict_text(extra_symbol.1, ["x", "y", "z"]),
    content="{x: 1, y: 1, z: 0}",
  )
}

///|
test "lp solvers match SymPy simplex four-variable reference example" {
  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let result = lpmax(x1 - @symcore.int(2) * x2 - @symcore.int(3) * x3 - x4, [
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
  ])
  inspect(@symprint.to_string(result.0), content="4")
  inspect(
    solution_dict_text(result.1, ["x1", "x2", "x3", "x4"]),
    content="{x1: 7, x2: 0, x3: 0, x4: 3}",
  )
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
  inspect(
    solution_dict_text(min_result.1, ["x", "y", "z"]),
    content="{x: 0, y: 0, z: 3/5}",
  )

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
test "lp simplex edge cases match SymPy issue regressions" {
  let infeasible_const : Result[
    (@symcore.Expr, Map[String, @symcore.Expr]),
    SolverError,
  ] = try? lpmin(@symcore.int(5), [
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, x() + z(), @symcore.int(1)),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      x() + @symcore.int(2) * z(),
      @symcore.int(0),
    ),
  ])
  assert_true(infeasible_const is Err(SolverError::InfeasibleLPError(_)))

  let zero_objective = lpmax(@symcore.int(0), [
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(zero_objective.0), content="0")
  inspect(
    solution_dict_text(zero_objective.1, ["x", "y"]),
    content="{x: 0, y: 0}",
  )
}

///|
test "lp and linprog match additional SymPy simplex public cases batch 1" {
  let case1 = lpmax(@symcore.int(-1) * x() - y() - @symcore.int(5) * z(), [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      y() + @symcore.int(2) * z(),
      @symcore.int(3),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(-1) * x() - @symcore.int(3) * z(),
      @symcore.int(-2),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(2) * x() + y() + @symcore.int(7) * z(),
      @symcore.int(5),
    ),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(case1.0), content="-2")
  inspect(
    solution_dict_text(case1.1, ["x", "y", "z"]),
    content="{x: 2, y: 0, z: 0}",
  )

  let case2 = lpmax(@symcore.int(-1) * x() - y() - @symcore.int(5) * z(), [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      x() - y() + @symcore.int(2) * z(),
      @symcore.int(3),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(-1) * x() + @symcore.int(2) * y() - @symcore.int(3) * z(),
      @symcore.int(-2),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(2) * x() + y() - @symcore.int(7) * z(),
      @symcore.int(-5),
    ),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(case2.0), content="-25/7")
  inspect(
    solution_dict_text(case2.1, ["x", "y", "z"]),
    content="{x: 0, y: 0, z: 5/7}",
  )

  let case3 = lpmax(
    @symcore.int(-1) * x() - y() - @symcore.int(5) * z() + @symcore.int(2),
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        x() - y() + @symcore.int(2) * z(),
        @symcore.int(-4),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(-1) * x() + @symcore.int(2) * y() - @symcore.int(3) * z(),
        @symcore.int(8),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(2) * x() + y() - @symcore.int(7) * z(),
        @symcore.int(10),
      ),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
    ],
  )
  inspect(@symprint.to_string(case3.0), content="-2")
  inspect(
    solution_dict_text(case3.1, ["x", "y", "z"]),
    content="{x: 0, y: 4, z: 0}",
  )

  let case4 = lpmax(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y()),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), z()),
    @symcore.Expr::Relational(@symcore.RelOp::Le, z(), @symcore.int(3)),
  ])
  inspect(@symprint.to_string(case4.0), content="3")
  inspect(
    solution_dict_text(case4.1, ["x", "y", "z"]),
    content="{x: 3, y: 3, z: 3}",
  )

  let case5 = lpmin(y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(case5.0), content="0")
  inspect(solution_dict_text(case5.1, ["x", "y"]), content="{x: 2, y: 0}")

  let bounds_scalar = Some([(Some(@symcore.int(2)), Some(@symcore.int(3)))])
  let lin1 = linprog([@symcore.int(1)], bounds=bounds_scalar)
  inspect(@symprint.to_string(lin1.0), content="2")
  inspect(expr_list_text(lin1.1), content="[2]")

  let lin2 = linprog(
    [@symcore.int(1), @symcore.int(-1)],
    a=Some(@symmatrices.matrix([[@symcore.int(1), @symcore.int(1)]])),
    b=Some([@symcore.int(2)]),
    bounds=Some([(Some(@symcore.int(0)), None), (None, None)]),
  )
  inspect(@symprint.to_string(lin2.0), content="-2")
  inspect(expr_list_text(lin2.1), content="[0, 2]")

  let lin3 = linprog(
    [@symcore.int(1), @symcore.int(-1)],
    a=Some(@symmatrices.matrix([[@symcore.int(1), @symcore.int(1)]])),
    b=Some([@symcore.int(5)]),
    bounds=Some([(Some(@symcore.int(0)), None), (Some(@symcore.int(3)), None)]),
  )
  inspect(@symprint.to_string(lin3.0), content="-5")
  inspect(expr_list_text(lin3.1), content="[0, 5]")
}

///|
test "lp and linprog match additional SymPy simplex public cases batch 2" {
  let case1 = lpmax(x() - y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(case1.0), content="2")
  inspect(solution_dict_text(case1.1, ["x", "y"]), content="{x: 2, y: 0}")

  let case2 = lpmax(x() - y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), @symcore.int(2)),
  ])
  inspect(@symprint.to_string(case2.0), content="2")
  inspect(solution_dict_text(case2.1, ["x", "y"]), content="{x: 2, y: 0}")

  let case3 = lpmax(y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), @symcore.int(2)),
  ])
  inspect(@symprint.to_string(case3.0), content="2")
  inspect(solution_dict_text(case3.1, ["y"]), content="{y: 2}")

  let case4 = lpmax(y(), [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(0),
      y() + @symcore.int(2),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Ge,
      @symcore.int(0),
      y() + @symcore.int(2),
    ),
  ])
  inspect(@symprint.to_string(case4.0), content="-2")
  inspect(solution_dict_text(case4.1, ["y"]), content="{y: -2}")

  let case5 = lpmax(y(), [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(0),
      y() + @symcore.int(2),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Ge,
      @symcore.int(0),
      y() + @symcore.int(2),
    ),
    @symcore.Expr::Relational(@symcore.RelOp::Le, y(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(case5.0), content="-2")
  inspect(solution_dict_text(case5.1, ["y"]), content="{y: -2}")

  let case6 = lpmin(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(1)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y()),
  ])
  inspect(@symprint.to_string(case6.0), content="1")
  inspect(solution_dict_text(case6.1, ["x", "y"]), content="{x: 1, y: 1}")

  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let lin1 = linprog(
    [@symcore.int(1), @symcore.int(1), @symcore.int(-2)],
    a=Some(
      @symmatrices.matrix([
        [@symcore.int(7), @symcore.int(4), @symcore.int(-7)],
        [@symcore.int(3), @symcore.int(-1), @symcore.int(10)],
      ]),
    ),
    b=Some([@symcore.int(3), @symcore.int(6)]),
    a_eq=Some(
      @symmatrices.matrix([[@symcore.int(-9), @symcore.int(1), @symcore.int(0)]]),
    ),
    b_eq=Some([@symcore.int(1)]),
  )
  inspect(@symprint.to_string(lin1.0), content="-2/5")
  inspect(expr_list_text(lin1.1), content="[0, 1, 7/10]")

  let lin2 = linprog(
    [@symcore.int(1), @symcore.int(1), @symcore.int(-2)],
    a=Some(
      @symmatrices.matrix([
        [@symcore.int(7), @symcore.int(4), @symcore.int(-7)],
        [@symcore.int(3), @symcore.int(-1), @symcore.int(10)],
      ]),
    ),
    b=Some([@symcore.int(3), @symcore.int(6)]),
    a_eq=Some(
      @symmatrices.matrix([[@symcore.int(0), @symcore.int(-1), @symcore.int(1)]]),
    ),
    b_eq=Some([half]),
  )
  inspect(@symprint.to_string(lin2.0), content="-10/9")
  inspect(expr_list_text(lin2.1), content="[0, 1/9, 11/18]")

  let lin3 = linprog(
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
  )
  inspect(@symprint.to_string(lin3.0), content="-1")
  inspect(expr_list_text(lin3.1), content="[0, 0, 1/2]")
}

///|
test "simplex and solveset match additional SymPy public cases batch 3" {
  let float_case = lpmax(@symcore.int(-1) * x() - y() - @symcore.int(5) * z(), [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      x() - y() + @symcore.Expr::Float(@symcore.float_from_double(2.0)) * z(),
      @symcore.int(-4),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(-1) * x() +
      @symcore.int(2) * y() -
      @symcore.Expr::Float(@symcore.float_from_double(3.0)) * z(),
      @symcore.int(8),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(2) * x() + y() - @symcore.int(7) * z(),
      @symcore.int(10),
    ),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(float_case.0), content="-4")
  inspect(
    solution_dict_text(float_case.1, ["x", "y", "z"]),
    content="{x: 0, y: 4, z: 0}",
  )

  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let infeasible_four_var : Result[
    (@symcore.Expr, Map[String, @symcore.Expr]),
    SolverError,
  ] = try? lpmin(
    @symcore.int(9) * x2 -
    @symcore.int(8) * x3 +
    @symcore.int(3) * x4 +
    @symcore.int(6),
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(5) * x2 - @symcore.int(2) * x3,
        @symcore.int(0),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(-1) * x1 - @symcore.int(8) * x2 + @symcore.int(9) * x3,
        @symcore.int(-3),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(10) * x1 - x2 + @symcore.int(9) * x4,
        @symcore.int(-4),
      ),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x1, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x2, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x3, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x4, @symcore.int(0)),
    ],
  )
  assert_true(infeasible_four_var is Err(SolverError::InfeasibleLPError(_)))

  inspect(
    @symsets.to_string(
      solveset(@symcore.int(4), symbol=Some(x()), domain=@symsets.reals()),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(@symcore.int(0), symbol=Some(x()), domain=@symsets.reals()),
    ),
    content="Reals",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(0),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(1), @symcore.int(2)),
      ),
    ),
    content="Interval(1, 2)",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(-1) * (x() ^ @symcore.int(2)) -
        @symcore.int(2) * x() +
        ((x() + @symcore.int(1)) ^ @symcore.int(2)) +
        @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="Reals",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(3) * x() + @symcore.int(-2),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{2/3}",
  )
  inspect(
    normalize_text(
      @symsets.to_string(
        solveset(
          (x() ^ @symcore.int(2)) + @symcore.int(-1),
          symbol=Some(x()),
          domain=@symsets.reals(),
        ),
      ),
    ),
    content="{-1, 1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        sqrt(@symcore.int(1)) + @symcore.int(1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="EmptySet",
  )
}

///|
test "linear_eq_to_matrix and linsolve match additional SymPy linear cases batch 4" {
  let (a0, b0) = linear_eq_to_matrix([@symcore.int(0)], [x()])
  inspect(a0.to_string(), content="Matrix([[0]])")
  inspect(b0.to_string(), content="Matrix([[0]])")

  let (a1, b1) = linear_eq_to_matrix([@symcore.int(1)], [x()])
  inspect(a1.to_string(), content="Matrix([[0]])")
  inspect(b1.to_string(), content="Matrix([[-1]])")

  let (a2, b2) = linear_eq_to_matrix(
    [
      @symcore.int(2) * x() + y() - @symcore.int(2) * z() + @symcore.int(-3),
      x() - y() - z(),
      x() + y() + @symcore.int(3) * z() + @symcore.int(-12),
    ],
    [x(), y(), z()],
  )
  inspect(
    a2.to_string(),
    content="Matrix([[2, 1, -2], [1, -1, -1], [1, 1, 3]])",
  )
  inspect(b2.to_string(), content="Matrix([[3], [0], [12]])")

  let (a3, b3) = linear_eq_to_matrix(
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.int(3) * x() + @symcore.int(2) * y() - z(),
        @symcore.int(1),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.int(2) * x() - @symcore.int(2) * y() + @symcore.int(4) * z(),
        @symcore.int(-2),
      ),
      @symcore.int(-2) * x() + y() - @symcore.int(2) * z(),
    ],
    [x(), y(), z()],
  )
  inspect(
    a3.to_string(),
    content="Matrix([[3, 2, -1], [2, -2, 4], [-2, 1, -2]])",
  )
  inspect(b3.to_string(), content="Matrix([[1], [-2], [0]])")

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
  let (a4, b4) = linear_eq_to_matrix(
    [
      a_sym * b_sym * x() + b_sym * y() + c_sym * z() - d_sym,
      e_sym * x() + d_sym * x() + f_sym * y() + g_sym * z() - h_sym,
      i_sym * x() + j_sym * y() + k_sym * z() - l_sym,
    ],
    [x(), y(), z()],
  )
  inspect(
    a4.to_string(),
    content="Matrix([[a*b, b, c], [d + e, f, g], [i, j, k]])",
  )
  inspect(b4.to_string(), content="Matrix([[d], [h], [l]])")

  let (a5, b5) = linear_eq_to_matrix(
    [
      x() +
      y() * (z() * (@symcore.int(3) * x() + @symcore.int(2)) + @symcore.int(3)),
    ],
    [x()],
  )
  inspect(a5.to_string(), content="Matrix([[3*y*z + 1]])")
  inspect(b5.to_string(), content="Matrix([[-y*(2*z + 3)]])")

  let (a6, b6) = linear_eq_to_matrix(
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        x() + @symcore.int(2),
        @symcore.int(1),
      ),
    ],
    [x()],
  )
  inspect(a6.to_string(), content="Matrix([[1]])")
  inspect(b6.to_string(), content="Matrix([[-1]])")

  let (a7, b7) = linear_eq_to_matrix(
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        a_sym * (@symcore.int(2) * x() + @symcore.int(3) * y()) +
        @symcore.int(4) * y(),
        @symcore.int(5),
      ),
    ],
    [x(), y()],
  )
  inspect(a7.to_string(), content="Matrix([[2*a, 3*a + 4]])")
  inspect(b7.to_string(), content="Matrix([[5]])")

  let a_free = @symcore.Expr::Symbol("a_free")
  let b_free = @symcore.Expr::Symbol("b_free")
  let c_free = @symcore.Expr::Symbol("c_free")
  let d_free = @symcore.Expr::Symbol("d_free")
  let e_free = @symcore.Expr::Symbol("e_free")
  let linsolve_symbolic = linsolve(
    linsolve_augmented_matrix_input(
      @symmatrices.matrix([
        [
          @symcore.int(0),
          @symcore.int(1),
          @symcore.int(0),
          @symcore.int(0),
          @symcore.int(0),
          @symcore.int(0),
        ],
        [
          @symcore.int(0),
          @symcore.int(0),
          @symcore.int(0),
          @symcore.int(1),
          @symcore.int(0),
          @symcore.int(0),
        ],
      ]),
    ),
    [a_free, b_free, c_free, d_free, e_free],
  )
  inspect(
    @symsets.to_string(linsolve_symbolic),
    content="{(a_free, 0, c_free, 0, e_free)}",
  )

  let linsolve_no_solution = linsolve(
    linsolve_equations_input([
      x() + @symcore.int(2) * y() + @symcore.int(3) * z(),
      @symcore.int(2) * x() +
      @symcore.int(4) * y() +
      @symcore.int(6) * z() +
      @symcore.int(-1),
      @symcore.int(3) * x() + @symcore.int(6) * y() + @symcore.int(9) * z(),
    ]),
    [x(), y(), z()],
  )
  inspect(@symsets.to_string(linsolve_no_solution), content="EmptySet")
}

///|
test "linsolve matches additional SymPy public cases batch 5" {
  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let eqns = [
    x1 + @symcore.int(2) * x2 + x3 + x4 + @symcore.int(-7),
    x1 + @symcore.int(2) * x2 + @symcore.int(2) * x3 - x4 + @symcore.int(-12),
    @symcore.int(2) * x1 +
    @symcore.int(4) * x2 +
    @symcore.int(6) * x4 +
    @symcore.int(-4),
  ]
  let expected_parametric = @symcore.Expr::Tuple([
    @symcore.int(-2) * x2 + @symcore.int(-3) * x4 + @symcore.int(2),
    x2,
    @symcore.int(2) * x4 + @symcore.int(5),
    x4,
  ])
  let linsolve_eqns = linsolve(linsolve_equations_input(eqns), [x1, x2, x3, x4])
  let linsolve_aug = linsolve(
    linsolve_augmented_matrix_input(
      @symmatrices.matrix([
        [
          @symcore.int(1),
          @symcore.int(2),
          @symcore.int(1),
          @symcore.int(1),
          @symcore.int(7),
        ],
        [
          @symcore.int(1),
          @symcore.int(2),
          @symcore.int(2),
          @symcore.int(-1),
          @symcore.int(12),
        ],
        [
          @symcore.int(2),
          @symcore.int(4),
          @symcore.int(0),
          @symcore.int(6),
          @symcore.int(4),
        ],
      ]),
    ),
    [x1, x2, x3, x4],
  )
  match linsolve_eqns {
    @symsets.Set::FiniteSet(items) => {
      assert_eq(items.length(), 1)
      assert_true(tuple_expr_semantically_equal(items[0], expected_parametric))
    }
    _ => fail("linsolve parametric equations should return FiniteSet")
  }
  match linsolve_aug {
    @symsets.Set::FiniteSet(items) => {
      assert_eq(items.length(), 1)
      assert_true(tuple_expr_semantically_equal(items[0], expected_parametric))
    }
    _ => fail("linsolve parametric matrix should return FiniteSet")
  }

  inspect(
    @symsets.to_string(linsolve(linsolve_equations_input([]), [x()])),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      linsolve(linsolve_equations_input([@symcore.int(0)]), [x()]),
    ),
    content="{(x,)}",
  )
  inspect(
    @symsets.to_string(linsolve(linsolve_equations_input([x()]), [x(), y()])),
    content="{(0, y)}",
  )
  inspect(
    @symsets.to_string(
      linsolve(linsolve_equations_input([x(), @symcore.int(0)]), [x(), y()]),
    ),
    content="{(0, y)}",
  )
  inspect(
    @symsets.to_string(
      linsolve(
        linsolve_equations_input([
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), x() + y()),
        ]),
        [x(), y()],
      ),
    ),
    content="{(x, 0)}",
  )
  inspect(
    @symsets.to_string(
      linsolve(
        linsolve_equations_input([
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x() + x() * y(),
            @symcore.int(1) + y(),
          ),
        ]),
        [x()],
      ),
    ),
    content="{(1,)}",
  )
  inspect(
    @symsets.to_string(
      linsolve(
        linsolve_equations_input([
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.int(1) + y(),
            x() + x() * y(),
          ),
        ]),
        [x()],
      ),
    ),
    content="{(1,)}",
  )
  inspect(
    @symsets.to_string(
      linsolve(
        linsolve_equations_input([
          x() + z() + @symcore.int(-1),
          (x() ^ @symcore.int(2)) + y() + @symcore.int(-3),
        ]),
        [z(), y()],
      ),
    ),
    content="{(1 - x, 3 - x**2)}",
  )
}

///|
test "linsolve and solveset match additional SymPy public cases batch 6" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let d = @symcore.Expr::Symbol("d")
  let e = @symcore.Expr::Symbol("e")
  let gsym = @symcore.Expr::Symbol("g")
  let linsolve_symbolic = linsolve(
    linsolve_equations_input([
      a * x() + b * y() + @symcore.int(-1) * e,
      c * x() + d * y() + @symcore.int(-1) * gsym,
    ]),
    [x(), y()],
  )
  let symbolic_den = a * d + @symcore.int(-1) * b * c
  let symbolic_expected = @symcore.Expr::Tuple([
    (@symcore.int(-1) * b * gsym + d * e) * (symbolic_den ^ @symcore.int(-1)),
    (a * gsym + @symcore.int(-1) * c * e) * (symbolic_den ^ @symcore.int(-1)),
  ])
  assert_true(
    finite_set_exprs_semantically_equal(linsolve_symbolic, [symbolic_expected]),
  )

  let no_solution = linsolve(
    linsolve_augmented_matrix_input(
      @symmatrices.matrix([
        [@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(0)],
        [@symcore.int(2), @symcore.int(4), @symcore.int(6), @symcore.int(0)],
        [@symcore.int(3), @symcore.int(6), @symcore.int(9), @symcore.int(1)],
      ]),
    ),
    [x(), y(), z()],
  )
  inspect(@symsets.to_string(no_solution), content="EmptySet")

  let avar = @symcore.Expr::Symbol("A")
  let bvar = @symcore.Expr::Symbol("B")
  let j1 = @symcore.Expr::Symbol("J1")
  let j2 = @symcore.Expr::Symbol("J2")
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let issue_10056 = linsolve(
    linsolve_augmented_matrix_input(
      @symmatrices.matrix([
        [
          @symcore.int(2) * imag * j1,
          @symcore.int(2) * imag * j2,
          @symcore.int(-2) * (j1 ^ @symcore.int(-1)),
        ],
        [
          @symcore.int(-2) * imag * j2,
          @symcore.int(-2) * imag * j1,
          @symcore.int(2) * (j2 ^ @symcore.int(-1)),
        ],
        [
          @symcore.int(0),
          @symcore.int(2),
          @symcore.int(2) * imag * ((j1 * j2) ^ @symcore.int(-1)),
        ],
        [@symcore.int(2), @symcore.int(0), @symcore.int(0)],
      ]),
    ),
    [avar, bvar],
  )
  let issue_10056_expected = @symcore.Expr::Tuple([
    @symcore.int(0),
    imag * ((j1 * j2) ^ @symcore.int(-1)),
  ])
  assert_true(
    finite_set_exprs_semantically_equal(issue_10056, [issue_10056_expected]),
  )

  let disc = b * b + @symcore.int(-4) * a * c
  let quadratic_roots = [
    (@symcore.int(-1) * b + @symcore.int(-1) * sqrt(disc)) *
    ((@symcore.int(2) * a) ^ @symcore.int(-1)),
    (@symcore.int(-1) * b + sqrt(disc)) *
    ((@symcore.int(2) * a) ^ @symcore.int(-1)),
  ]
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        a * (x() ^ @symcore.int(2)) + b * x() + c,
        symbol=Some(x()),
        domain=complexes,
      ),
      quadratic_roots,
    ),
  )
  inspect(
    @symsets.to_string(
      solveset(@symcore.int(0), symbol=Some(x()), domain=complexes),
    ),
    content="Complexes",
  )
  inspect(
    @symsets.to_string(
      solveset(@symcore.int(4), symbol=Some(x()), domain=complexes),
    ),
    content="EmptySet",
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        @symcore.int(3) * x() + @symcore.int(-2),
        symbol=Some(x()),
        domain=complexes,
      ),
      [@symcore.int(2) * (@symcore.int(3) ^ @symcore.int(-1))],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(1),
        symbol=Some(x()),
        domain=complexes,
      ),
      [imag, @symcore.int(-1) * imag],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=complexes,
      ),
      [@symcore.int(1), @symcore.int(-1)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() ^ @symcore.int(2)) + x(),
        symbol=Some(x()),
        domain=complexes,
      ),
      [@symcore.int(0), @symcore.int(-1)],
    ),
  )
}

///|
test "solveset matches additional SymPy public cases batch 7" {
  let real_domain = @symsets.reals()
  let log2 = @symcore.function("log", [@symcore.int(2)])
  let log3 = @symcore.function("log", [@symcore.int(3)])
  let log5 = @symcore.function("log", [@symcore.int(5)])
  let exp3 = @symcore.function("exp", [@symcore.int(3)])
  let quarter = @symcore.rational_from_ints(1, 4) catch { _ => fail("quarter") }

  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        @symcore.function("exp", [x()]) + @symcore.int(-3),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [log3],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        @symcore.function("log", [x()]) + @symcore.int(-3),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [exp3],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (@symcore.int(2) ^ x()) + @symcore.int(-10),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(1) + log5 * (log2 ^ @symcore.int(-1))],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() ^ @symcore.int(-1)) + @symcore.int(1),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(-1)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (@symcore.function("exp", [x()]) ^ @symcore.int(-1)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(0)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        x() * (@symcore.int(1) + @symcore.int(-5) * (x() ^ @symcore.int(-1))),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(5)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        @symcore.int(2) * x() * ((x() + @symcore.int(2)) ^ @symcore.int(-1)) +
        @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(2)],
    ),
  )
  assert_eq(
    @symsets.compare_set(
      solveset(
        x() + @symcore.int(-1) * (y() ^ @symcore.int(3)),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.intersection([
        @symsets.finite_set([y() ^ @symcore.int(3)]),
        real_domain,
      ]),
    ),
    0,
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        sqrt(x()) + @symcore.int(-2),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(4)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() ^ quarter) + @symcore.int(-2),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(16)],
    ),
  )
}

///|
test "solveset matches additional SymPy public cases batch 8" {
  let real_domain = @symsets.reals()
  let two_thirds = @symcore.rational_from_ints(2, 3) catch {
    _ => fail("two_thirds")
  }
  let one_third = @symcore.rational_from_ints(1, 3) catch {
    _ => fail("one_third")
  }

  inspect(
    @symsets.to_string(
      solveset(
        @symcore.raw_pow(@symcore.int(0), x()) + @symcore.int(-100),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.raw_pow(@symcore.int(0), x()) + @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{0}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (@symcore.int(2) * x() + @symcore.int(8)) *
        (@symcore.int(8) + @symcore.function("exp", [x()])),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{-4}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        x() * (@symcore.function("log", [x()]) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(3) * x() + @symcore.int(-2),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{" + @symprint.to_string(two_thirds) + "}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{-1, 1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ one_third) + @symcore.int(-3),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{27}",
  )
  inspect(
    @symsets.to_string(
      solveset(@symcore.int(4), symbol=Some(x()), domain=real_domain),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(@symcore.int(0), symbol=Some(x()), domain=real_domain),
    ),
    content="Reals",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(-1) * (x() ^ @symcore.int(2)) +
        @symcore.int(-2) * x() +
        ((x() + @symcore.int(1)) ^ @symcore.int(2)) +
        @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="Reals",
  )
}

///|
test "solveset matches additional SymPy public cases batch 9" {
  let real_domain = @symsets.reals()
  let one_third = @symcore.rational_from_ints(1, 3) catch {
    _ => fail("one_third")
  }

  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(3)) + @symcore.int(-8),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{2}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(3)) + @symcore.int(1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{-1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (@symcore.int(2) ^ (x() + @symcore.int(1))) + @symcore.int(-8),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{2}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.function("exp", [@symcore.int(2) * x()]) + @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{0}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        sqrt(x() + @symcore.int(1)) + @symcore.int(-3),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{8}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        ((x() + @symcore.int(1)) ^ one_third) + @symcore.int(-2),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{7}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        ((x() + @symcore.int(-2)) ^ @symcore.int(-1)) + @symcore.int(1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() + @symcore.int(-1)) * ((x() + @symcore.int(2)) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        ((x() ^ @symcore.int(2)) + @symcore.int(-4)) *
        ((x() + @symcore.int(-2)) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{-2}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() + @symcore.int(-2)) * ((x() ^ @symcore.int(2)) + @symcore.int(1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{2}",
  )
}

///|
test "solveset matches additional SymPy public cases batch 10" {
  let real_domain = @symsets.reals()
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }

  inspect(
    @symsets.to_string(
      solveset(
        @symcalculus.diff(
          (x() ^ @symcore.int(2)) *
          ((@symcore.int(7) + @symcore.int(-1) * x()) ^ @symcore.int(-1)),
          x(),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{0, 14}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(3) ^ (x() + @symcore.int(2)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(3) ^ (@symcore.int(2) + @symcore.int(-1) * x()),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.function("exp", [x()]),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(x() ^ @symcore.int(-1), symbol=Some(x()), domain=real_domain),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(-1) *
        ((@symcore.int(1) + x()) * ((@symcore.int(2) + x()) ^ @symcore.int(-2))) +
        ((@symcore.int(2) + x()) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() * ((x() + @symcore.int(1)) ^ @symcore.int(-1)) + @symcore.int(3)) ^
        @symcore.int(-2),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() + @symcore.int(-1)) *
        (
          (@symcore.int(1) + ((x() + @symcore.int(-1)) ^ @symcore.int(-1))) ^
          @symcore.int(-1)
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        sqrt((x() + @symcore.int(-3)) * (x() ^ @symcore.int(-1))) +
        @symcore.int(-1) * half,
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="{4}",
  )
}

///|
test "simplex and solveset match additional SymPy public cases batch 11" {
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }

  let eq_case = lpmax(x() - y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(eq_case.0), content="2")
  inspect(solution_dict_text(eq_case.1, ["x", "y"]), content="{x: 2, y: 0}")

  let extra_symbol_case = lpmin(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(1)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + z()),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(extra_symbol_case.0), content="1")
  inspect(
    solution_dict_text(extra_symbol_case.1, ["x", "y", "z"]),
    content="{x: 1, y: 1, z: 0}",
  )

  let x1 = @symcore.Expr::Symbol("x1")
  let x2 = @symcore.Expr::Symbol("x2")
  let x3 = @symcore.Expr::Symbol("x3")
  let x4 = @symcore.Expr::Symbol("x4")
  let bounded_front = lpmin(
    @symcore.int(5) * x2 + x3 + @symcore.int(4) * x4 - x1,
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(5) * x2 + @symcore.int(2) * x3 + @symcore.int(5) * x4 - x1,
        @symcore.int(5),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.int(3) * x2 + x4,
        @symcore.int(2),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.int(-1) * x1 + x3 + @symcore.int(2) * x4,
        @symcore.int(1),
      ),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x1, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Le, x1, @symcore.int(1)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x2, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Le, x2, @symcore.int(1)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x3, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Le, x3, @symcore.int(1)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x4, @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Le, x4, @symcore.int(1)),
    ],
  )
  inspect(@symprint.to_string(bounded_front.0), content="9/2")
  inspect(
    solution_dict_text(bounded_front.1, ["x1", "x2", "x3", "x4"]),
    content="{x1: 0, x2: 1/2, x3: 0, x4: 1/2}",
  )

  let bounded_lin = linprog(
    [@symcore.int(-1), @symcore.int(5), @symcore.int(1), @symcore.int(4)],
    a=Some(
      @symmatrices.matrix([
        [@symcore.int(-1), @symcore.int(5), @symcore.int(2), @symcore.int(5)],
      ]),
    ),
    b=Some([@symcore.int(5)]),
    a_eq=Some(
      @symmatrices.matrix([
        [@symcore.int(0), @symcore.int(3), @symcore.int(0), @symcore.int(1)],
        [@symcore.int(-1), @symcore.int(0), @symcore.int(1), @symcore.int(2)],
      ]),
    ),
    b_eq=Some([@symcore.int(2), @symcore.int(1)]),
    bounds=Some([
      (Some(@symcore.int(0)), Some(@symcore.int(1))),
      (Some(@symcore.int(0)), Some(@symcore.int(1))),
      (Some(@symcore.int(0)), Some(@symcore.int(1))),
      (Some(@symcore.int(0)), Some(@symcore.int(1))),
    ]),
  )
  inspect(@symprint.to_string(bounded_lin.0), content="9/2")
  inspect(expr_list_text(bounded_lin.1), content="[0, 1/2, 0, 1/2]")

  let shifted_eq = lpmin(x() + y() - @symcore.int(2) * z() + @symcore.int(1), [
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
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      y() + @symcore.int(-9) * x(),
      @symcore.int(1),
    ),
  ])
  inspect(@symprint.to_string(shifted_eq.0), content="3/5")
  inspect(
    solution_dict_text(shifted_eq.1, ["x", "y", "z"]),
    content="{x: 0, y: 1, z: 7/10}",
  )

  let shifted_ineq = lpmin(
    x() + y() - @symcore.int(2) * z() + @symcore.int(1),
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
      @symcore.Expr::Relational(@symcore.RelOp::Le, z() - y(), half),
    ],
  )
  inspect(@symprint.to_string(shifted_ineq.0), content="-1/9")
  inspect(
    solution_dict_text(shifted_ineq.1, ["x", "y", "z"]),
    content="{x: 0, y: 1/9, z: 11/18}",
  )

  let shifted_bound = lpmin(
    x() + y() - @symcore.int(2) * z() + @symcore.int(1),
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
      @symcore.Expr::Relational(@symcore.RelOp::Le, z(), half),
    ],
  )
  inspect(@symprint.to_string(shifted_bound.0), content="0")
  inspect(
    solution_dict_text(shifted_bound.1, ["x", "y", "z"]),
    content="{x: 0, y: 0, z: 1/2}",
  )

  inspect(
    @symsets.to_string(
      solveset(
        sqrt(x()) + @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        sqrt(x() + @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        sqrt((x() + @symcore.int(-3)) * (x() ^ @symcore.int(-1))),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{3}",
  )
}

///|
test "solveset matches additional SymPy public cases batch 12" {
  let positive_infinity = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::Infinity,
  )
  let nonnegative_reals = @symsets.interval(@symcore.int(0), positive_infinity)

  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1) * x() + @symcore.int(-6),
        symbol=Some(x()),
        domain=nonnegative_reals,
      ),
    ),
    content="{3}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=nonnegative_reals,
      ),
    ),
    content="{1}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(4)) + @symcore.int(-16),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(0), @symcore.int(10)),
      ),
    ),
    content="{2}",
  )

  let issue9522_a = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    (((x() ^ @symcore.int(2)) + @symcore.int(-4)) ^ @symcore.int(-1)) + x(),
    (((x() ^ @symcore.int(2)) + @symcore.int(-4)) ^ @symcore.int(-1)) +
    @symcore.int(2),
  )
  inspect(
    @symsets.to_string(
      solveset(issue9522_a, symbol=Some(x()), domain=@symsets.reals()),
    ),
    content="EmptySet",
  )

  let issue9522_b = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    (x() ^ @symcore.int(-1)) + x(),
    x() ^ @symcore.int(-1),
  )
  inspect(
    @symsets.to_string(
      solveset(issue9522_b, symbol=Some(x()), domain=@symsets.reals()),
    ),
    content="EmptySet",
  )

  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-2), x()),
          @symcore.int(4),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{2}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.int(-1) * (@symcore.int(2) ^ x()),
          @symcore.int(4),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-3), x()),
          @symcore.int(27),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-5), x() + @symcore.int(1)),
          @symcore.int(625),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{3}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.int(2) ^ (x() + @symcore.int(-3)),
          @symcore.int(-16),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="EmptySet",
  )
}

///|
test "simplex and solveset match additional SymPy public cases batch 13" {
  let simplex_min = lpmin(y(), [
    @symcore.Expr::Relational(@symcore.RelOp::Le, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), y() + @symcore.int(2)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
  ])
  inspect(@symprint.to_string(simplex_min.0), content="0")
  inspect(solution_dict_text(simplex_min.1, ["x", "y"]), content="{x: 2, y: 0}")

  let simplex_chain = lpmax(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y()),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), z()),
    @symcore.Expr::Relational(@symcore.RelOp::Le, z(), @symcore.int(3)),
  ])
  inspect(@symprint.to_string(simplex_chain.0), content="3")
  inspect(
    solution_dict_text(simplex_chain.1, ["x", "y", "z"]),
    content="{x: 3, y: 3, z: 3}",
  )

  inspect(
    @symsets.to_string(
      solveset(@symcore.int(1), symbol=Some(x()), domain=@symsets.reals()),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Boolean(true),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="Reals",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Boolean(false),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.function("exp", [x()]) + @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{0}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.function("exp", [x()]),
          @symcore.int(1),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{0}",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Ge,
          x() + @symcore.int(-1),
          @symcore.int(0),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="Interval(1, oo)",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Ge,
          x() ^ @symcore.int(2),
          @symcore.int(0),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="Reals",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-3), x() + @symcore.int(-3)),
          @symcore.int(-1) * (@symcore.int(3) ^ @symcore.int(39)),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
    ),
    content="{42}",
  )
}

///|
test "solve matches additional SymPy public cases batch 14" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  inspect(
    solve_result_text(solve(solve_expr_input(@symcore.int(42)))),
    content="[]",
  )
  inspect(
    solve_result_text(solve(solve_expr_input(@symcore.int(42)), symbols=[x()])),
    content="[]",
  )
  inspect(
    solve_result_text(
      solve(solve_exprs_input([@symcore.int(1), @symcore.int(2)])),
    ),
    content="[]",
  )
  inspect(
    solve_result_text(
      solve(solve_exprs_input([sqrt(@symcore.int(2))]), symbols=[x()]),
    ),
    content="[]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input(y() + @symcore.int(-3)), symbols=[y()]),
    ),
    content="[3]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input(x() + y() + @symcore.int(-3)), symbols=[x(), y()]),
    ),
    content="[(3 - y, y)]",
  )
  inspect(
    solve_result_text(solve(solve_expr_input(x() + y() + @symcore.int(-3)))),
    content="[{x: 3 - y}]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input(a + b * x() + @symcore.int(-2)), symbols=[a, b]),
    ),
    content="{a: 2, b: 0}",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input((a + b) * x() + b + @symcore.int(-1) * c), symbols=[
        a, b,
      ]),
    ),
    content="{a: -c, b: c}",
  )
  inspect(
    solve_result_text(
      solve(
        solve_expr_input(x() + @symcore.int(-1) * (y() ^ @symcore.int(3))),
        symbols=[x()],
      ),
    ),
    content="[y**3]",
  )
}

///|
test "solve matches additional SymPy public cases batch 15" {
  let a11 = @symcore.Expr::Symbol("a11")
  let a12 = @symcore.Expr::Symbol("a12")
  let a21 = @symcore.Expr::Symbol("a21")
  let a22 = @symcore.Expr::Symbol("a22")
  let b1 = @symcore.Expr::Symbol("b1")
  let b2 = @symcore.Expr::Symbol("b2")
  inspect(
    solve_result_text(
      solve(solve_expr_input(@symcore.int(3) * x() + @symcore.int(-2)), symbols=[
        x(),
      ]),
    ),
    content="[2/3]",
  )
  inspect(
    solve_result_text(
      solve(
        solve_expr_input(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.int(3) * x(),
            @symcore.int(2),
          ),
        ),
        symbols=[x()],
      ),
    ),
    content="[2/3]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input((x() ^ @symcore.int(2)) + @symcore.int(-1)), symbols=[
        x(),
      ]),
    ),
    content="[-1, 1]",
  )
  inspect(
    solve_result_text(
      solve(
        solve_expr_input(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x() ^ @symcore.int(2),
            @symcore.int(1),
          ),
        ),
        symbols=[x()],
      ),
    ),
    content="[-1, 1]",
  )
  let symbolic_linear = solve(
    solve_exprs_input([
      a11 * x() + a12 * y() + @symcore.int(-1) * b1,
      a21 * x() + a22 * y() + @symcore.int(-1) * b2,
    ]),
    symbols=[x(), y()],
  )
  match symbolic_linear {
    SolveResult::Dict(values) => {
      let expected_x = (a22 * b1 + @symcore.int(-1) * (a12 * b2)) *
        ((a11 * a22 + @symcore.int(-1) * (a12 * a21)) ^ @symcore.int(-1))
      let expected_y = (a11 * b2 + @symcore.int(-1) * (a21 * b1)) *
        ((a11 * a22 + @symcore.int(-1) * (a12 * a21)) ^ @symcore.int(-1))
      assert_eq(
        @symcore.compare_expr(
          values.get("x").unwrap_or(@symcore.int(0)),
          expected_x,
        ),
        0,
      )
      assert_eq(
        @symcore.compare_expr(
          values.get("y").unwrap_or(@symcore.int(0)),
          expected_y,
        ),
        0,
      )
    }
    _ => fail("expected symbolic 2x2 solve to return Dict")
  }
  inspect(
    solve_result_text(
      solve(solve_exprs_input([x() + @symcore.int(-1) * y(), x() + y()]), symbols=[
        x(),
        y(),
      ]),
    ),
    content="{x: 0, y: 0}",
  )
  inspect(
    solve_result_text(
      solve(
        solve_exprs_input([
          (x() ^ @symcore.int(2)) + @symcore.int(-4),
          y() + @symcore.int(-2),
        ]),
        symbols=[x(), y()],
      ),
    ),
    content="[(-2, 2), (2, 2)]",
  )
  inspect(
    solve_result_text(
      solve(
        solve_exprs_input([
          x() + y() + @symcore.int(-2),
          @symcore.int(2) * x() + @symcore.int(2) * y() + @symcore.int(-4),
        ]),
      ),
    ),
    content="{x: 2 - y}",
  )
  inspect(
    solve_result_text(
      solve(
        solve_expr_input(
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x() ^ @symcore.int(2),
            @symcore.Expr::Float(@symcore.float_from_double(0.0)),
          ),
        ),
      ),
    ),
    content="[0.0]",
  )
  inspect(
    solve_result_text(solve(solve_exprs_input([]), symbols=[x()])),
    content="[]",
  )
}

///|
test "solve matches additional SymPy public cases batch 16" {
  let one_third = @symcore.rational_from_ints(1, 3) catch {
    _ => fail("one_third")
  }
  let quarter = @symcore.rational_from_ints(1, 4) catch { _ => fail("quarter") }
  inspect(
    solve_result_text(
      solve(
        solve_exprs_input([
          x() + y() + @symcore.int(-3),
          x() + @symcore.int(-1) * y() + @symcore.int(-5),
        ]),
      ),
    ),
    content="{x: 4, y: -1}",
  )
  inspect(
    solve_result_text(
      solve(
        solve_exprs_input([
          (x() ^ @symcore.int(2)) + @symcore.int(-4),
          y() + @symcore.int(-2),
        ]),
        symbols=[y(), x()],
      ),
    ),
    content="[(2, -2), (2, 2)]",
  )
  inspect(
    solve_result_text(
      solve(
        solve_exprs_input([
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), x()),
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x(),
            x() + @symcore.int(1),
          ),
        ]),
        symbols=[x()],
      ),
    ),
    content="[]",
  )
  inspect(
    solve_result_text(
      solve(
        solve_exprs_input([
          @symcore.Expr::Boolean(true),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), @symcore.int(0)),
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x(),
            x() + @symcore.int(1),
          ),
        ]),
        symbols=[x()],
      ),
    ),
    content="[]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input(@symcore.Expr::Boolean(true)), symbols=[x()]),
    ),
    content="[]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input(sqrt(x()) + @symcore.int(-1)), symbols=[x()]),
    ),
    content="[1]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input(sqrt(x()) + @symcore.int(-2)), symbols=[x()]),
    ),
    content="[4]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input((x() ^ quarter) + @symcore.int(-2)), symbols=[x()]),
    ),
    content="[16]",
  )
  inspect(
    solve_result_text(
      solve(solve_expr_input((x() ^ one_third) + @symcore.int(-3)), symbols=[
        x(),
      ]),
    ),
    content="[27]",
  )
  inspect(
    solve_result_text(solve(solve_expr_input(@symcore.int(4)), symbols=[x()])),
    content="[]",
  )
}

///|
test "solveset matches additional SymPy complex public cases batch 17" {
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let sqrt3 = sqrt(@symcore.int(3))

  inspect(
    @symsets.to_string(
      solveset(@symcore.int(0), symbol=Some(x()), domain=complexes),
    ),
    content="Complexes",
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        x() + (x() ^ @symcore.int(-1)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=complexes,
      ),
      [
        half + half * imag * sqrt3,
        half + @symcore.int(-1) * half * imag * sqrt3,
      ],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() + @symcore.int(-1)) *
        (x() + @symcore.int(-1) * imag) *
        ((x() + @symcore.int(-3)) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=complexes,
      ),
      [@symcore.int(1), imag],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() + @symcore.int(-1) * (y() ^ @symcore.int(3))) *
        (
          (
            (y() ^ @symcore.int(2)) *
            sqrt(@symcore.int(1) + @symcore.int(-1) * (y() ^ @symcore.int(2)))
          ) ^
          @symcore.int(-1)
        ),
        symbol=Some(x()),
        domain=complexes,
      ),
      [y() ^ @symcore.int(3)],
    ),
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.function("exp", [x()]) ^ @symcore.int(-1),
        symbol=Some(x()),
        domain=complexes,
      ),
    ),
    content="EmptySet",
  )
  assert_eq(
    @symsets.compare_set(
      solveset(
        (x() + @symcore.int(-1) * (y() ^ @symcore.int(3))) *
        (
          (
            (y() ^ @symcore.int(2)) *
            sqrt(@symcore.int(1) + @symcore.int(-1) * (y() ^ @symcore.int(2)))
          ) ^
          @symcore.int(-1)
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      @symsets.intersection([
        @symsets.finite_set([y() ^ @symcore.int(3)]),
        @symsets.reals(),
      ]),
    ),
    0,
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        sqrt(x() + @symcore.int(-2)) + @symcore.int(-5),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      [@symcore.int(27)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        sqrt(x()) + @symcore.int(-7),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      [@symcore.int(49)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        sqrt(x() ^ @symcore.int(3)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      [@symcore.int(0)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        sqrt(x() + @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      [@symcore.int(1)],
    ),
  )
}

///|
test "solveset matches additional SymPy domain and no-solution cases batch 18" {
  let a = @symcore.Expr::Symbol("a")
  let real_domain = @symsets.reals()
  let positive_infinity = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::Infinity,
  )
  let one_third = @symcore.rational_from_ints(1, 3) catch {
    _ => fail("one_third")
  }

  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(-1) * (x() ^ @symcore.int(2)) +
        @symcore.int(-2) * x() +
        ((x() + @symcore.int(1)) ^ @symcore.int(2)) +
        @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="Reals",
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1) * x() + @symcore.int(-6),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(0), positive_infinity),
      ),
      [@symcore.int(3)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-1),
        symbol=Some(x()),
        domain=@symsets.interval(@symcore.int(0), positive_infinity),
      ),
      [@symcore.int(1)],
    ),
  )
  inspect(
    @symsets.to_string(
      solveset(
        sqrt(@symcore.int(1)) + @symcore.int(1),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(1) + @symcore.int(-1) * positive_infinity * x(),
        symbol=Some(x()),
      ),
    ),
    content="EmptySet",
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        ((@symcore.int(2) * x() + @symcore.int(-5)) ^ one_third) +
        @symcore.int(-3),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(16)],
    ),
  )
  inspect(
    @symsets.to_string(
      solveset(
        positive_infinity * x() + @symcore.int(-1) * positive_infinity,
        symbol=Some(x()),
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(-3) * a * (sqrt(x()) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() * ((x() + @symcore.int(1)) ^ @symcore.int(-1)) + @symcore.int(3)) ^
        @symcore.int(-2),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() + @symcore.int(-1)) *
        (
          (@symcore.int(1) + ((x() + @symcore.int(-1)) ^ @symcore.int(-1))) ^
          @symcore.int(-1)
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
}

///|
test "solveset matches additional SymPy abs and radical cases batch 19" {
  let real_domain = @symsets.reals()
  let positive_infinity = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::Infinity,
  )
  let abs = fn(expr : @symcore.Expr) { @symcore.function("Abs", [expr]) }

  inspect(
    @symsets.to_string(solveset(positive_infinity * x(), symbol=Some(x()))),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.int(-1) *
        (x() + @symcore.int(1)) *
        ((x() + @symcore.int(2)) ^ @symcore.int(-2)) +
        ((x() + @symcore.int(2)) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        abs(x()) + @symcore.int(-2),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(-2), @symcore.int(2)],
    ),
  )
  inspect(
    @symsets.to_string(
      solveset(abs(x()) + @symcore.int(2), symbol=Some(x()), domain=real_domain),
    ),
    content="EmptySet",
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        abs(x() + @symcore.int(3)) +
        @symcore.int(-2) * abs(x() + @symcore.int(-3)),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(1), @symcore.int(9)],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        @symcore.int(2) * abs(x()) +
        @symcore.int(-1) * abs(x() + @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [
        @symcore.int(-1),
        @symcore.rational_from_ints(1, 3) catch {
          _ => fail("third")
        },
      ],
    ),
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        x() *
        (sqrt((x() ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(0)],
    ),
  )
}

///|
test "solveset matches additional SymPy public cases batch 20" {
  let real_domain = @symsets.reals()
  let complex_domain = @symsets.complexes()
  let abs = fn(expr : @symcore.Expr) { @symcore.function("Abs", [expr]) }
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let three_halves = @symcore.rational_from_ints(3, 2) catch {
    _ => fail("3/2")
  }
  let minus_three_halves = @symcore.rational_from_ints(-3, 2) catch {
    _ => fail("-3/2")
  }
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("1/2") }

  inspect(
    @symsets.to_string(
      solveset(abs(x()) + @symcore.int(1), symbol=Some(x()), domain=real_domain),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, a, a),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="Reals",
  )
  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(@symcore.RelOp::Eq, a, a),
        symbol=Some(y()),
        domain=complex_domain,
      ),
    ),
    content="Complexes",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ three_halves) + @symcore.int(4),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ minus_three_halves) + @symcore.int(4),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="EmptySet",
  )
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        x() +
        (a + @symcore.int(-1) * b) *
        ((@symcore.int(-2) * a + @symcore.int(2) * b) ^ @symcore.int(-1)),
        symbol=Some(x()),
      ),
      [half],
    ),
  )
}

///|
test "linear_eq_to_matrix and solveset match additional SymPy public cases batch 21" {
  let real_domain = @symsets.reals()
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
  let no_symbols : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(eqns3, [])
  assert_true(no_symbols is Err(SolverError::ValueError(_)))

  let duplicate_symbols : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(eqns3, [x(), x(), y()])
  assert_true(duplicate_symbols is Err(SolverError::ValueError(_)))

  let inv_x = x() ^ @symcore.int(-1)
  let nonlinear_recip : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(
    [@symcore.Expr::Relational(@symcore.RelOp::Eq, inv_x + x(), inv_x)],
    [x()],
  )
  assert_true(nonlinear_recip is Err(SolverError::NonlinearError(_)))

  let nonlinear_square : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix([x() ^ @symcore.int(2)], [x()])
  assert_true(nonlinear_square is Err(SolverError::NonlinearError(_)))

  let nonlinear_xy : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix([x() * y()], [x(), y()])
  assert_true(nonlinear_xy is Err(SolverError::NonlinearError(_)))

  let nonlinear_issue_14987 : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(
    [
      x() * (@symcore.int(-3) * inv_x + @symcore.int(1)) +
      @symcore.int(2) * y() -
      a,
    ],
    [x(), y()],
  )
  assert_true(nonlinear_issue_14987 is Err(SolverError::NonlinearError(_)))

  let auto_true : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix([@symcore.Expr::Boolean(true)], [x()])
  assert_true(auto_true is Err(SolverError::ValueError(_)))

  let auto_false : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix([@symcore.Expr::Boolean(false)], [x()])
  assert_true(auto_false is Err(SolverError::ValueError(_)))

  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let pi_over_two = half *
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  assert_eq(
    @symsets.compare_set(
      solveset(f(x()) - pi_over_two, symbol=Some(x()), domain=real_domain),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq(f(x) - pi/2, 0)"),
        base=real_domain,
      ),
    ),
    0,
  )
  assert_eq(
    @symsets.compare_set(
      solveset(f(g(x())) - pi_over_two, symbol=Some(x()), domain=real_domain),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq(f(g(x)) - pi/2, 0)"),
        base=real_domain,
      ),
    ),
    0,
  )
}

///|
test "linear_eq_to_matrix and solveset match additional SymPy public cases batch 22" {
  let inv_x = x() ^ @symcore.int(-1)
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }

  let nonlinear_cancelled_rational : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(
    [
      ((x() ^ @symcore.int(2)) - @symcore.int(3) * x()) *
      ((x() + @symcore.int(-3)) ^ @symcore.int(-1)) +
      @symcore.int(-3),
    ],
    [x()],
  )
  assert_true(
    nonlinear_cancelled_rational is Err(SolverError::NonlinearError(_)),
  )

  let nonlinear_binomial_expand : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(
    [
      ((x() + @symcore.int(1)) ^ @symcore.int(3)) +
      @symcore.int(-1) * (x() ^ @symcore.int(3)) +
      @symcore.int(-3) * (x() ^ @symcore.int(2)) +
      @symcore.int(7),
    ],
    [x()],
  )
  assert_true(nonlinear_binomial_expand is Err(SolverError::NonlinearError(_)))

  let nonlinear_cancelled_linear : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix([x() * (inv_x + @symcore.int(1)) + y()], [
    x(),
    y(),
  ])
  assert_true(nonlinear_cancelled_linear is Err(SolverError::NonlinearError(_)))

  let nonlinear_mixed_mul : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix([(x() + @symcore.int(1)) * y()], [x(), y()])
  assert_true(nonlinear_mixed_mul is Err(SolverError::NonlinearError(_)))

  let nonlinear_eq_recip : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(
    [@symcore.Expr::Relational(@symcore.RelOp::Eq, inv_x, inv_x + y())],
    [x(), y()],
  )
  assert_true(nonlinear_eq_recip is Err(SolverError::NonlinearError(_)))

  let nonlinear_eq_y_over_x : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        y() * inv_x,
        y() * inv_x + y(),
      ),
    ],
    [x(), y()],
  )
  assert_true(nonlinear_eq_y_over_x is Err(SolverError::NonlinearError(_)))

  let nonlinear_eq_quadratic : Result[
    (@symmatrices.Matrix, @symmatrices.Matrix),
    SolverError,
  ] = try? linear_eq_to_matrix(
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        x() * (x() + @symcore.int(1)),
        (x() ^ @symcore.int(2)) + y(),
      ),
    ],
    [x(), y()],
  )
  assert_true(nonlinear_eq_quadratic is Err(SolverError::NonlinearError(_)))

  let issue_8715 = @symcore.Expr::Relational(
    @symcore.RelOp::Gt,
    x() + inv_x,
    @symcore.int(-2) + inv_x,
  )
  assert_eq(
    @symsets.compare_set(
      solveset(issue_8715, symbol=Some(x()), domain=@symsets.reals()),
      @symsets.union([
        @symsets.interval(
          @symcore.int(-2),
          @symcore.int(0),
          left_open=true,
          right_open=true,
        ),
        @symsets.interval(
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          left_open=true,
          right_open=true,
        ),
      ]),
    ),
    0,
  )

  let log_x = @symcore.function("log", [x()])
  let issue_8715_log = @symcore.Expr::Relational(
    @symcore.RelOp::Gt,
    log_x + (log_x ^ @symcore.int(-1)),
    @symcore.int(-2) + (log_x ^ @symcore.int(-1)),
  )
  assert_eq(
    @symsets.compare_set(
      solveset(issue_8715_log, symbol=Some(x()), domain=@symsets.reals()),
      @symsets.union([
        @symsets.interval(
          @symcore.function("exp", [@symcore.int(-2)]),
          @symcore.int(1),
          left_open=true,
          right_open=true,
        ),
        @symsets.interval(
          @symcore.int(1),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          left_open=true,
          right_open=true,
        ),
      ]),
    ),
    0,
  )

  let issue_11174 = (z() ^ @symcore.int(2)) +
    @symcore.function("exp", [@symcore.int(2) * x()]) -
    sin(y())
  assert_eq(
    @symsets.compare_set(
      solveset(issue_11174, symbol=Some(x()), domain=@symsets.reals()),
      @symsets.intersection([
        @symsets.reals(),
        @symsets.finite_set([
          half *
          @symcore.function("log", [
            @symcore.int(-1) * (z() ^ @symcore.int(2)) + sin(y()),
          ]),
        ]),
      ]),
    ),
    0,
  )
}

///|
test "solveset and simplex match additional SymPy public cases batch 23" {
  let neg_inf = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::NegativeInfinity,
  )
  let t = @symcore.Expr::Symbol("t")
  let r = @symcore.Expr::Symbol("r")
  let tan_t = @symcore.function("tan", [t])
  let abs = fn(expr : @symcore.Expr) { @symcore.function("Abs", [expr]) }

  let issue_11174_b = @symcore.add([
    @symcore.mul([
      sqrt(r),
      abs(tan_t),
      @symcore.pow(
        sqrt((tan_t ^ @symcore.int(2)) + @symcore.int(1)),
        @symcore.int(-1),
      ),
    ]),
    @symcore.mul([x(), tan_t]),
  ])
  let issue_11174_b_expected = @symcore.mul([
    @symcore.int(-1),
    sqrt(r),
    abs(tan_t),
    @symcore.pow(
      @symcore.mul([sqrt((tan_t ^ @symcore.int(2)) + @symcore.int(1)), tan_t]),
      @symcore.int(-1),
    ),
  ])
  assert_eq(
    @symsets.compare_set(
      solveset(issue_11174_b, symbol=Some(x()), domain=@symsets.reals()),
      @symsets.intersection([
        @symsets.reals(),
        @symsets.finite_set([issue_11174_b_expected]),
      ]),
    ),
    0,
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
    @symsets.compare_set(
      solveset(issue_10477, symbol=Some(x()), domain=@symsets.reals()),
      @symsets.union([
        @symsets.interval(
          neg_inf,
          @symcore.int(-3),
          left_open=true,
          right_open=true,
        ),
        @symsets.interval(
          @symcore.int(0),
          @symcore.int(1),
          left_open=true,
          right_open=true,
        ),
      ]),
    ),
    0,
  )

  let issue_10671_b = @symcore.Expr::Relational(
    @symcore.RelOp::Lt,
    @symcalculus.diff(x() ^ @symcore.int(-1), x()),
    @symcore.int(0),
  )
  let closed_unit_ten = @symsets.interval(@symcore.int(1), @symcore.int(10))
  assert_eq(
    @symsets.compare_set(
      solveset(issue_10671_b, symbol=Some(x()), domain=closed_unit_ten),
      closed_unit_ten,
    ),
    0,
  )

  let issue_12478 = sqrt(x() + @symcore.int(-2)) + @symcore.int(2)
  assert_eq(
    @symsets.compare_set(
      solveset(issue_12478, symbol=Some(x()), domain=@symsets.reals()),
      @symsets.empty_set(),
    ),
    0,
  )
  let issue_14300 = @symcore.add([
    @symcore.int(1),
    @symcore.mul([
      @symcore.int(-1),
      @symcore.function("exp", [@symcore.int(-18000000) * x()]),
    ]),
    @symcore.mul([@symcore.int(-1), y()]),
  ])
  inspect(
    @symsets.to_string(
      solveset(issue_14300, symbol=Some(x()), domain=@symsets.reals()),
    ),
    content="Intersection({-log(1 - y)/18000000}, Reals)",
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        (x() ^ @symcore.int(2)) + @symcore.int(-2) * x() + @symcore.int(-15),
        symbol=Some(x()),
        domain=@symsets.interval(
          neg_inf,
          @symcore.int(0),
          left_open=true,
          right_open=false,
        ),
      ),
      @symsets.finite_set([@symcore.int(-3)]),
    ),
    0,
  )

  let eq_chain = lpmax(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Eq, x(), y()),
    @symcore.Expr::Relational(@symcore.RelOp::Eq, y(), z()),
    @symcore.Expr::Relational(@symcore.RelOp::Le, z(), @symcore.int(3)),
  ])
  inspect(@symprint.to_string(eq_chain.0), content="3")
  inspect(
    solution_dict_text(eq_chain.1, ["x", "y", "z"]),
    content="{x: 3, y: 3, z: 3}",
  )

  let shifted_lp = lpmax(
    @symcore.int(2) +
    @symcore.mul([@symcore.int(-1), x()]) +
    @symcore.mul([@symcore.int(-1), y()]) +
    @symcore.mul([@symcore.int(-5), z()]),
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        x() - y() + @symcore.int(2) * z(),
        @symcore.int(-4),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.mul([@symcore.int(-1), x()]) +
        @symcore.int(2) * y() +
        @symcore.mul([@symcore.int(-3), z()]),
        @symcore.int(8),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(2) * x() + y() + @symcore.mul([@symcore.int(-7), z()]),
        @symcore.int(10),
      ),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
    ],
  )
  inspect(@symprint.to_string(shifted_lp.0), content="-2")
  inspect(
    solution_dict_text(shifted_lp.1, ["x", "y", "z"]),
    content="{x: 0, y: 4, z: 0}",
  )

  let shifted_lp_alt = lpmax(
    @symcore.mul([@symcore.int(-1), x()]) +
    @symcore.mul([@symcore.int(-1), y()]) +
    @symcore.mul([@symcore.int(-5), z()]),
    [
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        x() - y() + @symcore.int(2) * z(),
        @symcore.int(3),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.mul([@symcore.int(-1), x()]) +
        @symcore.int(2) * y() +
        @symcore.mul([@symcore.int(-3), z()]),
        @symcore.int(-2),
      ),
      @symcore.Expr::Relational(
        @symcore.RelOp::Le,
        @symcore.int(2) * x() + y() + @symcore.mul([@symcore.int(-7), z()]),
        @symcore.int(-5),
      ),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
      @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
    ],
  )
  inspect(@symprint.to_string(shifted_lp_alt.0), content="-25/7")
  inspect(
    solution_dict_text(shifted_lp_alt.1, ["x", "y", "z"]),
    content="{x: 0, y: 0, z: 5/7}",
  )
}

///|
test "solveset and simplex invalid inputs match additional SymPy public cases batch 24" {
  let one_fifth = @symcore.rational_from_ints(1, 5) catch { _ => fail("1/5") }
  let t = @symcore.Expr::Symbol("t")

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.pow(sqrt(x()), @symcore.int(-1)),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      @symsets.empty_set(),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcalculus.diff(sqrt((x() ^ @symcore.int(-1)) + x()), x()),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      @symsets.finite_set([@symcore.int(-1), @symcore.int(1)]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.pow(
          @symcore.int(1) + @symcore.int(-1) * (x() ^ @symcore.int(3)),
          @symcore.int(-2),
        ),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      @symsets.empty_set(),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.mul([
          x() + @symcore.int(5),
          @symcore.pow(
            sqrt(
              @symcore.int(-1) * (x() ^ @symcore.int(2)) +
              @symcore.int(-10) * x(),
            ),
            @symcore.int(-1),
          ),
        ]),
        symbol=Some(x()),
        domain=@symsets.reals(),
      ),
      @symsets.finite_set([@symcore.int(-5)]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      nonlinsolve(
        [
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x(),
            @symcore.int(5) ^ one_fifth,
          ),
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            x() * y(),
            @symcore.int(25) * sqrt(@symcore.int(5)),
          ),
        ],
        [x(), y()],
      ),
      @symsets.finite_set([
        @symcore.Expr::Tuple([
          @symcore.int(5) ^ one_fifth,
          @symcore.int(25) *
          sqrt(@symcore.int(5)) *
          (@symcore.int(5) ^ (@symcore.int(-1) * one_fifth)),
        ]),
      ]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      nonlinsolve(
        [
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            @symcore.mul([t, sqrt(@symcore.int(5)) + sqrt(@symcore.int(2))]) +
            @symcore.int(-1) * sqrt(@symcore.int(2)),
            @symcore.int(0),
          ),
          @symcore.Expr::Relational(@symcore.RelOp::Eq, t, @symcore.int(0)),
        ],
        [t],
      ),
      @symsets.empty_set(),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(@symcore.int(3) ^ x(), symbol=Some(x()), domain=@symsets.reals()),
      @symsets.empty_set(),
    ),
    0,
  )

  let irrational_lp : Result[
    (@symcore.Expr, Map[String, @symcore.Expr]),
    SolverError,
  ] = try? lpmax(@symcore.int(-1) * x() - y() - @symcore.int(5) * z(), [
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      x() - y() + sqrt(@symcore.int(2)) * z(),
      @symcore.int(-4),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(-1) * x() + @symcore.int(2) * y() - @symcore.int(3) * z(),
      @symcore.int(8),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Le,
      @symcore.int(2) * x() + y() - @symcore.int(7) * z(),
      @symcore.int(10),
    ),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, x(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, y(), @symcore.int(0)),
    @symcore.Expr::Relational(@symcore.RelOp::Ge, z(), @symcore.int(0)),
  ])
  assert_true(irrational_lp is Err(SolverError::ValueError(_)))

  let strict_lp : Result[
    (@symcore.Expr, Map[String, @symcore.Expr]),
    SolverError,
  ] = try? lpmax(x(), [
    @symcore.Expr::Relational(@symcore.RelOp::Gt, x(), @symcore.int(0)),
  ])
  assert_true(strict_lp is Err(SolverError::ValueError(_)))

  let ne_lp : Result[(@symcore.Expr, Map[String, @symcore.Expr]), SolverError] = try? lpmax(
    x(),
    [@symcore.Expr::Relational(@symcore.RelOp::Ne, x(), @symcore.int(0))],
  )
  assert_true(ne_lp is Err(SolverError::ValueError(_)))
}

///|
test "solveset matches additional SymPy exponential conditionset cases batch 25" {
  let real_domain = @symsets.reals()
  let positive_infinity = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::Infinity,
  )
  let positive_open = @symsets.interval(
    @symcore.int(0),
    positive_infinity,
    left_open=true,
  )

  let f1 = ((@symcore.function("exp", [x()]) + @symcore.int(1)) ^ x()) +
    @symcore.int(-2)
  assert_eq(
    @symsets.compare_set(
      solveset(f1, symbol=Some(x()), domain=real_domain),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq((exp(x) + 1)**x - 2, 0)"),
        base=real_domain,
      ),
    ),
    0,
  )

  let f2 = ((x() + @symcore.int(2)) ^ y()) * x() + @symcore.int(-3)
  assert_eq(
    @symsets.compare_set(
      solveset(f2, symbol=Some(x()), domain=real_domain),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq(x*(x + 2)**y - 3, 0)"),
        base=real_domain,
      ),
    ),
    0,
  )

  let f3 = (@symcore.int(2) ^ x()) +
    @symcore.int(-1) * @symcore.function("exp", [x()]) +
    @symcore.int(-3)
  assert_eq(
    @symsets.compare_set(
      solveset(f3, symbol=Some(x()), domain=real_domain),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq(2**x - exp(x) - 3, 0)"),
        base=real_domain,
      ),
    ),
    0,
  )

  let f4 = @symcore.function("log", [x()]) +
    @symcore.int(-1) * @symcore.function("exp", [x()])
  assert_eq(
    @symsets.compare_set(
      solveset(f4, symbol=Some(x()), domain=real_domain),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq(log(x) - exp(x), 0)"),
        base=real_domain,
      ),
    ),
    0,
  )

  let f5 = (@symcore.int(2) ^ x()) +
    (@symcore.int(3) ^ x()) +
    @symcore.int(-1) * (@symcore.int(5) ^ x())
  assert_eq(
    @symsets.compare_set(
      solveset(f5, symbol=Some(x()), domain=real_domain),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq(2**x + 3**x - 5**x, 0)"),
        base=real_domain,
      ),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(x() ^ x(), symbol=Some(x()), domain=positive_open),
      @symsets.condition_set(
        x(),
        @symlogic.bool_symbol("Eq(x**x, 0)"),
        base=positive_open,
      ),
    ),
    0,
  )
}

///|
test "solveset matches additional SymPy logarithmic and shifted exponential cases batch 26" {
  let real_domain = @symsets.reals()
  let exp3 = @symcore.function("exp", [@symcore.int(3)])
  let inv3 = @symcore.int(3) ^ @symcore.int(-1)
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let pow2_half = @symcore.int(2) ^ half
  let pow10_half = @symcore.int(10) ^ half

  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(
        @symcore.function("log", [x()]),
        symbol=Some(x()),
        domain=real_domain,
      ),
      [@symcore.int(1)],
    ),
  )

  let log_product = @symcore.function("log", [
    (x() + @symcore.int(-1)) * (x() + @symcore.int(1)),
  ])
  assert_eq(
    @symsets.compare_set(
      solveset(log_product, symbol=Some(x()), domain=real_domain),
      @symsets.finite_set([pow2_half, @symcore.int(-1) * pow2_half]),
    ),
    0,
  )

  let log_pair = @symcore.function("log", [x() + @symcore.int(-3)]) +
    @symcore.function("log", [x() + @symcore.int(3)])
  assert_eq(
    @symsets.compare_set(
      solveset(log_pair, symbol=Some(x()), domain=real_domain),
      @symsets.finite_set([pow10_half, @symcore.int(-1) * pow10_half]),
    ),
    0,
  )

  let scaled_log = @symcore.function("log", [@symcore.int(3) * x()]) +
    @symcore.int(-3)
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(scaled_log, symbol=Some(x()), domain=real_domain),
      [exp3 * inv3],
    ),
  )

  let shifted_exp = @symcore.function("exp", [x() + @symcore.int(3)]) +
    @symcore.int(-1)
  assert_true(
    finite_set_exprs_semantically_equal(
      solveset(shifted_exp, symbol=Some(x()), domain=real_domain),
      [@symcore.int(-3)],
    ),
  )

  let exp_param = @symcore.function("exp", [x()]) + @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(exp_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({log(y)}, Reals)",
  )

  let log_param = @symcore.function("log", [x()]) + @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(log_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({exp(y)}, Reals)",
  )

  let shifted_exp_param = @symcore.function("exp", [x() + @symcore.int(3)]) +
    @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(shifted_exp_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({log(y) - 3}, Reals)",
  )

  let scaled_log_param = @symcore.function("log", [@symcore.int(3) * x()]) +
    @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(scaled_log_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({exp(y)/3}, Reals)",
  )

  let shifted_log_param = @symcore.function("log", [x() + @symcore.int(3)]) +
    @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(shifted_log_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({exp(y) - 3}, Reals)",
  )
}

///|
test "solveset matches additional SymPy scaled logarithmic and exponential cases batch 27" {
  let real_domain = @symsets.reals()
  let third = @symcore.rational_from_ints(1, 3) catch { _ => fail("third") }

  let scaled_exp_param = @symcore.function("exp", [@symcore.int(3) * x()]) +
    @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(scaled_exp_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({log(y)/3}, Reals)",
  )

  let scaled_exp_coeff_param = @symcore.int(3) * @symcore.function("exp", [x()]) +
    @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(scaled_exp_coeff_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({log(y/3)}, Reals)",
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.function("log", [@symcore.int(3) * x()]),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([third]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.function("log", [x() + @symcore.int(3)]),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.int(-2)]),
    ),
    0,
  )

  let shifted_exp_coeff_param = @symcore.function("exp", [x()]) +
    @symcore.int(3) +
    @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(shifted_exp_coeff_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({log(y - 3)}, Reals)",
  )

  let scaled_log_param = @symcore.int(3) * @symcore.function("log", [x()]) +
    @symcore.int(-1) * y()
  inspect(
    @symsets.to_string(
      solveset(scaled_log_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({exp(y/3)}, Reals)",
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.function("exp", [x() + @symcore.int(3)]) + @symcore.int(-3),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([
        @symcore.function("log", [@symcore.int(3)]) + @symcore.int(-3),
      ]),
    ),
    0,
  )

  let log_ratio_param = @symcore.function("log", [@symcore.int(3) * x()]) +
    @symcore.int(-1) * @symcore.function("log", [y()])
  inspect(
    @symsets.to_string(
      solveset(log_ratio_param, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({y/3}, Reals)",
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.int(3) * @symcore.function("exp", [x()]) + @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.function("log", [third])]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.function("exp", [@symcore.int(3) * x()]) + @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.int(0)]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.int(3) * @symcore.function("log", [x()]) + @symcore.int(-3),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.function("exp", [@symcore.int(1)])]),
    ),
    0,
  )
}

///|
test "solveset matches additional SymPy real exponential equation cases batch 28" {
  let real_domain = @symsets.reals()

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-2), x()),
          @symcore.int(4),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.int(2)]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.int(-1) * (@symcore.int(2) ^ x()),
          @symcore.int(4),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.empty_set(),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-3), x()),
          @symcore.int(27),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.empty_set(),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-5), x() + @symcore.int(1)),
          @symcore.int(625),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.int(3)]),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.int(2) ^ (x() + @symcore.int(-3)),
          @symcore.int(-16),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.empty_set(),
    ),
    0,
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.raw_pow(@symcore.int(-3), x() + @symcore.int(-3)),
          @symcore.int(-1) * (@symcore.int(3) ^ @symcore.int(39)),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.int(42)]),
    ),
    0,
  )

  inspect(
    @symsets.to_string(
      solveset(
        (@symcore.int(2) ^ x()) + @symcore.int(-1) * y(),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="Intersection({log(y)/log(2)}, Reals)",
  )

  inspect(
    @symsets.to_string(
      solveset(
        @symcore.Expr::Relational(
          @symcore.RelOp::Eq,
          @symcore.int(2) ^ x(),
          y(),
        ),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="Intersection({log(y)/log(2)}, Reals)",
  )

  inspect(
    @symsets.to_string(
      solveset(
        (z() ^ x()) + @symcore.int(-1) * y(),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="ConditionSet(x, Eq(z**x - y, 0), Reals)",
  )

  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ y()) + @symcore.int(-1),
        symbol=Some(y()),
        domain=real_domain,
      ),
    ),
    content="ConditionSet(y, Eq(x**y - 1, 0), Reals)",
  )
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
          @symcore.function("Abs", [
            (cos(x()) ^ @symcore.int(2)) +
            @symcore.int(3) * cos(x()) +
            @symcore.int(-4),
          ]),
          x(),
        ),
      ),
    ),
    content="[Abs(x), x**2 + 3*x - 4, cos(x)]",
  )
  let trig_poly = decompogen(
    (sin(x()) ^ @symcore.int(2)) +
    sin(x()) +
    @symcore.mul([
      @symcore.int(-1),
      sqrt(@symcore.int(3)),
      @symcore.pow(@symcore.int(2), @symcore.int(-1)),
    ]),
    x(),
  )
  let trig_poly_expected = [
    @symcore.add([
      x() ^ @symcore.int(2),
      x(),
      @symcore.mul([
        @symcore.int(-1),
        sqrt(@symcore.int(3)),
        @symcore.pow(@symcore.int(2), @symcore.int(-1)),
      ]),
    ]),
    sin(x()),
  ]
  assert_eq(trig_poly.length(), trig_poly_expected.length())
  for i in 0..<trig_poly.length() {
    assert_true(expr_semantically_equal(trig_poly[i], trig_poly_expected[i]))
  }
  let mixed_abs = decompogen(
    @symcore.function("Abs", [
      (cos(y()) ^ @symcore.int(2)) +
      @symcore.int(3) * cos(x()) +
      @symcore.int(-4),
    ]),
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
    expr_list_text(
      decompogen(@symcore.function("Max", [@symcore.int(3), x()]), x()),
    ),
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
      decompogen(@symcore.function("Max", [sin(x()), u_linear]), x()),
    ),
    content="[Max(sin(x), 2*x + 3)]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        decompogen(
          (x() ^ @symcore.int(4)) +
          @symcore.int(2) * (x() ^ @symcore.int(2)) +
          @symcore.int(1),
          x(),
        ),
      ),
    ),
    content="[x**2 + 2*x + 1, x**2]",
  )
  let quartic_poly = decompogen(
    (x() ^ @symcore.int(4)) +
    @symcore.int(2) * (x() ^ @symcore.int(3)) -
    x() +
    @symcore.int(-1),
    x(),
  )
  let quartic_poly_expected = [
    (x() ^ @symcore.int(2)) - x() + @symcore.int(-1),
    (x() ^ @symcore.int(2)) + x(),
  ]
  assert_eq(quartic_poly.length(), quartic_poly_expected.length())
  for i in 0..<quartic_poly.length() {
    assert_true(
      expr_semantically_equal(quartic_poly[i], quartic_poly_expected[i]),
    )
  }
  let relational_try : Result[Array[@symcore.Expr], SolverError] = try? decompogen(
    @symcore.Expr::Relational(@symcore.RelOp::Lt, x(), @symcore.int(5)),
    x(),
  )
  assert_true(relational_try is Err(SolverError::ValueError(_)))
}

///|
test "compogen composes source-compatible examples" {
  inspect(
    @symprint.to_string(compogen([sin(x()), cos(x())], x())),
    content="sin(cos(x))",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        compogen(
          [(x() ^ @symcore.int(2)) + x() + @symcore.int(1), sin(x())],
          x(),
        ),
      ),
    ),
    content="sin(x)**2 + sin(x) + 1",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        compogen(
          [
            sqrt(x()),
            @symcore.int(6) * (x() ^ @symcore.int(2)) + @symcore.int(-5),
          ],
          x(),
        ),
      ),
    ),
    content="sqrt(6*x**2 - 5)",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        compogen(
          [
            sin(x()),
            sqrt(x()),
            cos(x()),
            (x() ^ @symcore.int(2)) + @symcore.int(1),
          ],
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
          [
            @symcore.function("Abs", [x()]),
            (x() ^ @symcore.int(2)) + @symcore.int(3) * x() + @symcore.int(-4),
            cos(x()),
          ],
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
          (x() ^ @symcore.int(2)) +
          x() +
          @symcore.mul([
            @symcore.int(-1),
            sqrt(@symcore.int(3)),
            @symcore.pow(@symcore.int(2), @symcore.int(-1)),
          ]),
          sin(x()),
        ],
        x(),
      ),
      @symcore.add([
        sin(x()) ^ @symcore.int(2),
        sin(x()),
        @symcore.mul([
          @symcore.int(-1),
          sqrt(@symcore.int(3)),
          @symcore.pow(@symcore.int(2), @symcore.int(-1)),
        ]),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      compogen(
        [
          (x() ^ @symcore.int(2)) +
          @symcore.int(3) * x() +
          (cos(y()) ^ @symcore.int(2)) +
          @symcore.int(-4),
          cos(x()),
        ],
        x(),
      ),
      (cos(x()) ^ @symcore.int(2)) +
      @symcore.int(3) * cos(x()) +
      (cos(y()) ^ @symcore.int(2)) +
      @symcore.int(-4),
    ),
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        compogen(
          [
            (x() ^ @symcore.int(2)) + @symcore.int(2) * x() + @symcore.int(1),
            x() ^ @symcore.int(2),
          ],
          x(),
        ),
      ),
    ),
    content="x**4 + 2*x**2 + 1",
  )
  assert_true(
    expr_semantically_equal(
      compogen(
        [
          (x() ^ @symcore.int(2)) - x() + @symcore.int(-1),
          (x() ^ @symcore.int(2)) + x(),
        ],
        x(),
      ),
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
        assumptions=assumption_map([
          ("integer", Some(true)),
          ("real", Some(true)),
        ]),
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
  inspect((failed.get("real") is None).to_string(), content="true")
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
  inspect(allhints.length().to_string(), content="46")
  inspect(allhints[0], content="factorable")
  inspect(
    allhints.contains("2nd_linear_bessel_transform").to_string(),
    content="true",
  )
  inspect(
    allhints[allhints.length() - 1],
    content="2nd_nonlinear_autonomous_conserved_Integral",
  )
  inspect(@symprint.to_string(constantsimp(c1 + c2, [c1, c2])), content="C1")
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
    expr_semantically_equal(
      local_constant_renumber(constantsimp(y() * c1, [c1])),
      c1 * y(),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(x() * c1, [c1])),
      x() * c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.int(2) * c1, [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(y() * c1 * x(), [c1, y()])),
      c1 * x(),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(c1 * x() * y() * x() * y() * @symcore.int(2), [c1, y()]),
      ),
      c1 * (x() ^ @symcore.int(2)),
    ),
  )

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 + c1, [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 + @symcore.int(2), [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 + y(), [c1, y()])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 + x(), [c1])),
      c1 + x(),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 + c2 + c1, [c1, c2])),
      c1,
    ),
  )

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.function("exp", [c1 + x()]), [c1]),
      ),
      c1 * @symcore.function("exp", [x()]),
    ),
  )
}

///|
test "constantsimp matches SymPy power cases" {
  let c1 = @symcore.Expr::Symbol("C1")
  let c2 = @symcore.Expr::Symbol("C2")

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 ^ c1, [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 ^ c2, [c1, c2])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c2 ^ c1, [c1, c2])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 ^ y(), [c1, y()])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 ^ x(), [c1])),
      c1 ^ x(),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 ^ @symcore.int(2), [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(c1 ^ (x() * y()), [c1])),
      c1 ^ (x() * y()),
    ),
  )

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(x() ^ c1, [c1])),
      x() ^ c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(y() ^ c1, [c1, y()])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(x() ^ (y() ^ c1), [c1, y()])),
      x() ^ c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(x() ^ y() ^ c1, [c1])),
      x() ^ y() ^ c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(x() ^ (c1 ^ y()), [c1, y()])),
      x() ^ c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(@symcore.int(2) ^ c1, [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.function("exp", [c1]), [c1]),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.function("exp", [c1 + x()]), [c1]),
      ),
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
      local_constant_renumber(
        constantsimp(@symcore.function("sin", [c1]), [c1]),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(constantsimp(f(c1), [c1])),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.applied_undefined_function("f", [c1, c1]), [c1]),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.applied_undefined_function("f", [c1, c2]), [
          c1, c2,
        ]),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.applied_undefined_function("f", [c1, x()]), [c1]),
      ),
      @symcore.applied_undefined_function("f", [c1, x()]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.applied_undefined_function("f", [c1, y()]), [
          c1,
          y(),
        ]),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.applied_undefined_function("f", [c1, y(), c2]), [
          c1,
          c2,
          y(),
        ]),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(@symcore.applied_undefined_function("f", [c1, c1, x()]), [
          c1,
        ]),
      ),
      @symcore.applied_undefined_function("f", [c1, c1, x()]),
    ),
  )

  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(c1 * @symcore.int(2) + @symcore.int(2), [c1]),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(x() * @symcore.int(2) * (c1 ^ @symcore.int(-1)), [c1]),
      ),
      c1 * x(),
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(
          (c1 ^ @symcore.int(2)) * @symcore.int(2) + @symcore.int(2),
          [c1],
        ),
      ),
      c1,
    ),
  )
  assert_true(
    expr_semantically_equal(
      local_constant_renumber(
        constantsimp(
          @symcore.function("sin", [@symcore.int(2) * c1]) +
          x() +
          @symcore.function("sqrt", [@symcore.int(2)]),
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
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      c1,
      @symcore.int(3) + f(x()) * x(),
    ),
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
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      c1,
      @symcore.int(3) * f(x()) * x(),
    ),
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
  let one_third = @symcore.rational_from_ints(1, 3) catch {
    _ => fail("one_third")
  }
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )

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
        @symcore.function("acos", [
          @symcore.int(-1) * c1 * (cos(x()) ^ @symcore.int(-1)),
        ]),
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
        @symcore.int(2) *
        @symcore.function("exp", [x() * (f(x()) ^ @symcore.int(-1))]),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  let log_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcore.function("log", [c1 * f(x())]) +
      @symcore.int(2) *
      @symcore.function("exp", [x() * (f(x()) ^ @symcore.int(-1))]),
      @symcore.int(0),
    ),
  )
  assert_eq(@symcore.compare_expr(log_case, log_expected), 0)

  let sqrt_log_case = local_constant_renumber(
    constantsimp(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        (x() ^ @symcore.int(2)) *
        (@symcore.int(2) ^ @symcore.int(-1)) *
        (f(x()) ^ @symcore.int(-2)) +
        @symcore.function("log", [
          sqrt(@symcore.int(2)) *
          x() *
          sqrt(x() ^ @symcore.int(-1)) *
          sqrt(f(x())) *
          (c1 ^ @symcore.int(-1)),
        ]),
        @symcore.int(0),
      ),
      [c1],
    ),
  )
  let sqrt_log_expected = local_constant_renumber(
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      (x() ^ @symcore.int(2)) *
      (@symcore.int(2) ^ @symcore.int(-1)) *
      (f(x()) ^ @symcore.int(-2)) +
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
        @symcore.int(-1) *
        sqrt(@symcore.int(-1) * c1 * x() + (x() ^ @symcore.int(2))),
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
        @symcore.function("Integral", [
          @symcore.int(-1) *
          (
            (u2 * sqrt(@symcore.int(1) - (u2 ^ @symcore.int(2)))) ^
            @symcore.int(-1)
          ),
          @symcore.Expr::Tuple([u2, a0, x() * (f(x()) ^ @symcore.int(-1))]),
        ]) +
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
      @symcore.function("Integral", [
        @symcore.int(-1) *
        (
          (u2 * sqrt(@symcore.int(1) - (u2 ^ @symcore.int(2)))) ^
          @symcore.int(-1)
        ),
        @symcore.Expr::Tuple([u2, a0, x() * (f(x()) ^ @symcore.int(-1))]),
      ]) +
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
  let (a_mats, b_mat) = linear_ode_to_matrix(
    higher_order,
    [f(x()), g(x())],
    x(),
    2,
  )
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
    content=(
      #|Matrix([[x*C2*exp(x) + C1*exp(x)], [C2*exp(x)]])
    ),
  )
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
    content=(
      #|Matrix([[C1*exp(x) + C2*exp(3*x) - C2*exp(x)], [C2*exp(3*x)]])
    ),
  )
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
    normalize_text(
      @symprint.to_string(infs[0].get("eta").unwrap_or(@symcore.int(0))),
    ),
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
    normalize_text(
      @symprint.to_string(abaco[1].get("eta").unwrap_or(@symcore.int(0))),
    ),
    content="f(x)",
  )
  inspect(
    normalize_text(
      @symprint.to_string(abaco[2].get("xi").unwrap_or(@symcore.int(0))),
    ),
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
    normalize_text(
      expr_matrix_text(canonical_odes(system_1, [f(x()), g(x())], x())),
    ),
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
  inspect(
    canonical_odes(system_2, [f(x()), g(x()), h(x())], x()).length().to_string(),
    content="2",
  )
  inspect(
    normalize_text(
      expr_list_text(canonical_odes(system_2, [f(x()), g(x()), h(x())], x())[0]),
    ),
    content="[Eq(Derivative(f(x), x), 2*f(x)), Eq(Derivative(g(x), x), -sqrt(f(x) + h(x))), Eq(Derivative(h(x), x), f(x))]",
  )
  inspect(
    normalize_text(
      expr_list_text(canonical_odes(system_2, [f(x()), g(x()), h(x())], x())[1]),
    ),
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
  let (a_sys3, b_sys3) = linear_ode_to_matrix(
    system_3,
    [f(x()), g(x()), h(x())],
    x(),
    1,
  )
  inspect(
    a_sys3[0].to_string(),
    content="Matrix([[2, 0, 3], [0, 5, 4], [5, 4, 0]])",
  )
  inspect(
    a_sys3[1].to_string(),
    content="Matrix([[1, 1, 0], [1, 0, 1], [0, 1, 1]])",
  )
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
  let (a_sys4, b_sys4) = linear_ode_to_matrix(
    system_4,
    [f(x()), g(x()), h(x())],
    x(),
    2,
  )
  inspect(
    a_sys4[0].to_string(),
    content="Matrix([[1, 0, 0], [0, 1, 2], [0, 0, 0]])",
  )
  inspect(
    a_sys4[1].to_string(),
    content="Matrix([[1, 0, 0], [0, -1, 0], [0, 0, -3]])",
  )
  inspect(
    a_sys4[2].to_string(),
    content="Matrix([[0, 1, -1], [0, -1, 0], [0, 0, 0]])",
  )
  inspect(b_sys4.to_string(), content="Matrix([[0], [0], [4]])")

  let bad_order : Result[
    (Array[@symmatrices.Matrix], @symmatrices.Matrix),
    SolverError,
  ] = try? linear_ode_to_matrix(
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

  let nonlinear : Result[
    (Array[@symmatrices.Matrix], @symmatrices.Matrix),
    SolverError,
  ] = try? linear_ode_to_matrix(
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
        x() *
        @symcore.function("log", [
          @symcore.mul([x() ^ @symcore.int(2), f(x()) ^ @symcore.int(-1)]),
        ]),
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
  let chi_eq = x() * @symcalculus.diff(f(x()), x()) +
    @symcore.int(1) -
    (f(x()) ^ @symcore.int(2))
  let chi_inf = infinitesimals(chi_eq, func=Some(f(x())), hint="chi")
  inspect(
    checkinfsol(chi_eq, chi_inf, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

///|
test "lie heuristic function_sum follows SymPy reference case" {
  let function_sum_eq = @symcalculus.diff(f(x()), x()) -
    @symcore.add([
      @symcore.mul([
        @symcore.int(3),
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([x() ^ @symcore.int(2), f(x()) ^ @symcore.int(-2)]),
        ]),
        @symcore.function("atan", [
          @symcore.mul([f(x()), x() ^ @symcore.int(-1)]),
        ]),
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
  let big_f = @symcore.applied_undefined_function("F", [a * x() + b * f(x())])
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
        @symcore.function("sin", [
          @symcore.add([f(x()), @symcore.mul([@symcore.int(-1), x()])]),
        ]),
        @symcore.mul([@symcore.int(-1), x() ^ @symcore.int(2)]),
        @symcore.mul([@symcore.int(2), x(), f(x())]),
      ]) ^
      @symcore.int(-1),
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
      x() ^ @symcore.add([a, @symcore.int(-1)]),
      f(x()) ^
      @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), b])]),
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

///|
test "lie heuristic abaco2_unique_unknown eq2 follows SymPy reference case" {
  let unique_unknown_eq_2 = @symcalculus.diff(f(x()), x()) +
    @symcore.function("tan", [
      @symcore.applied_undefined_function("F", [
        @symcore.add([x() ^ @symcore.int(2), f(x()) ^ @symcore.int(2)]),
      ]) +
      @symcore.function("atan", [@symcore.mul([x(), f(x()) ^ @symcore.int(-1)])]),
    ])
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

///|
test "lie heuristic abaco2_unique_unknown eq3 follows SymPy reference case" {
  let a = @symcore.Expr::Symbol("a")
  let unique_unknown_eq_3 = (
      (x() * @symcalculus.diff(f(x()), x()) + f(x()) + @symcore.int(2) * x()) ^
      @symcore.int(2)
    ) -
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

///|
test "lie heuristic linear follows SymPy reference cases" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let m = @symcore.Expr::Symbol("m")
  let n = @symcore.Expr::Symbol("n")
  let leading_power = x() ^
    @symcore.add([
      n * @symcore.add([m, @symcore.int(1)]),
      @symcore.mul([@symcore.int(-1), m]),
    ])
  let forcing_power = x() ^
    @symcore.mul([n, @symcore.add([m, @symcore.int(1)])])
  let linear_eq = leading_power * @symcalculus.diff(f(x()), x()) -
    a * (f(x()) ^ n) -
    b * forcing_power
  let linear_inf = infinitesimals(linear_eq, func=Some(f(x())), hint="linear")
  inspect(
    checkinfsol(linear_eq, linear_inf, func=Some(f(x())))[0].0.to_string(),
    content="true",
  )
}

///|
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
    expr_list_text(
      classify_ode(ode, func=Some(f(x()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
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
      pde_separate_add(pde, u(x(), y()), [xfun(x()), yfun(y())]).unwrap_or([]),
    ),
    content="[Derivative(X(x), x), Derivative(Y(y), y)]",
  )
  inspect(
    normalize_text(
      expr_list_text(
        pde_separate_mul(pde, u(x(), y()), [xfun(x()), yfun(y())]).unwrap_or([]),
      ),
    ),
    content="[Derivative(X(x), x)/X(x), Derivative(Y(y), y)/Y(y)]",
  )
  inspect(
    expr_list_text(
      classify_pde(pde, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
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
      @symprint.to_string(
        checkpdesol(pde, pde_solution, func=Some(u(x(), y()))).1,
      ) +
      ")",
    ),
    content="(true, 0)",
  )
}

///|
test "pde separation matches additional SymPy source cases" {
  let ut = @symcore.applied_undefined_function("u", [x(), t()])
  let add_eq = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(ut, x()),
    @symcore.mul([@symcalculus.diff(ut, t()), @symcore.function("exp", [ut])]),
  )
  let add_res = pde_separate_add(add_eq, ut, [xfun(x()), tfun(t())]).unwrap_or([])
  inspect(add_res.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      add_res[0],
      @symcore.mul([
        @symcalculus.diff(xfun(x()), x()),
        @symcore.function("exp", [@symcore.mul([@symcore.int(-1), xfun(x())])]),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      add_res[1],
      @symcore.mul([
        @symcalculus.diff(tfun(t()), t()),
        @symcore.function("exp", [tfun(t())]),
      ]),
    ),
  )

  let invalid_strategy : Result[Array[@symcore.Expr]?, SolverError] = try? pde_separate(
    add_eq,
    ut,
    [xfun(x()), tfun(t())],
    strategy="div",
  )
  inspect(
    match invalid_strategy {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"Unknown strategy: div\")",
  )

  let fxyz = @symcore.applied_undefined_function("F", [x(), y(), z()])
  let sum_eq = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcalculus.diff(fxyz, x()),
      @symcalculus.diff(fxyz, y()),
      @symcalculus.diff(fxyz, z()),
    ]),
    @symcore.int(0),
  )
  let duplicate_args : Result[Array[@symcore.Expr]?, SolverError] = try? pde_separate_mul(
    sum_eq,
    fxyz,
    [xfun(x()), @symcore.applied_undefined_function("u", [z(), z()])],
  )
  inspect(
    match duplicate_args {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"Duplicate substitution arguments detected\")",
  )
  let wrong_count : Result[Array[@symcore.Expr]?, SolverError] = try? pde_separate_mul(
    sum_eq,
    fxyz,
    [xfun(x()), yfun(y())],
  )
  inspect(
    match wrong_count {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"Variable counts do not match\")",
  )
  let wrong_args : Result[Array[@symcore.Expr]?, SolverError] = try? pde_separate_mul(
    sum_eq,
    fxyz,
    [xfun(t()), @symcore.applied_undefined_function("Y", [x(), y()])],
  )
  inspect(
    match wrong_args {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"Arguments do not match\")",
  )

  let split_y = pde_separate_mul(sum_eq, fxyz, [yfun(y()), u(x(), z())]).unwrap_or([],
  )
  inspect(split_y.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      split_y[0],
      @symcore.mul([
        @symcalculus.diff(yfun(y()), y()),
        @symcore.pow(yfun(y()), @symcore.int(-1)),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      split_y[1],
      @symcore.add([
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(u(x(), z()), x()),
          @symcore.pow(u(x(), z()), @symcore.int(-1)),
        ]),
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(u(x(), z()), z()),
          @symcore.pow(u(x(), z()), @symcore.int(-1)),
        ]),
      ]),
    ),
  )

  let split_xyz = pde_separate_mul(sum_eq, fxyz, [
    xfun(x()),
    yfun(y()),
    zfun(z()),
  ]).unwrap_or([])
  inspect(split_xyz.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      split_xyz[0],
      @symcore.mul([
        @symcalculus.diff(xfun(x()), x()),
        @symcore.pow(xfun(x()), @symcore.int(-1)),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      split_xyz[1],
      @symcore.add([
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(zfun(z()), z()),
          @symcore.pow(zfun(z()), @symcore.int(-1)),
        ]),
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(yfun(y()), y()),
          @symcore.pow(yfun(y()), @symcore.int(-1)),
        ]),
      ]),
    ),
  )

  let c = @symcore.Expr::Symbol("C")
  let wave_eq = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(@symcalculus.diff(ut, t()), t()),
    (c ^ @symcore.int(2)) * @symcalculus.diff(@symcalculus.diff(ut, x()), x()),
  )
  let wave_res = pde_separate_mul(wave_eq, ut, [xfun(x()), tfun(t())]).unwrap_or([],
  )
  inspect(wave_res.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      wave_res[0],
      @symcore.mul([
        @symcalculus.diff(@symcalculus.diff(xfun(x()), x()), x()),
        @symcore.pow(xfun(x()), @symcore.int(-1)),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      wave_res[1],
      @symcore.mul([
        @symcalculus.diff(@symcalculus.diff(tfun(t()), t()), t()),
        @symcore.pow(
          @symcore.mul([c ^ @symcore.int(2), tfun(t())]),
          @symcore.int(-1),
        ),
      ]),
    ),
  )

  let laplace_eq = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcore.mul([
        @symcore.pow(r(), @symcore.int(-1)),
        @symcalculus.diff(phi(r(), theta(), z()), r()),
      ]),
      @symcalculus.diff(@symcalculus.diff(phi(r(), theta(), z()), r()), r()),
      @symcore.mul([
        @symcore.pow(r(), @symcore.int(-2)),
        @symcalculus.diff(
          @symcalculus.diff(phi(r(), theta(), z()), theta()),
          theta(),
        ),
      ]),
      @symcalculus.diff(@symcalculus.diff(phi(r(), theta(), z()), z()), z()),
    ]),
    @symcore.int(0),
  )
  let laplace_sep_z = pde_separate_mul(laplace_eq, phi(r(), theta(), z()), [
    zfun(z()),
    u(theta(), r()),
  ]).unwrap_or([])
  inspect(laplace_sep_z.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      laplace_sep_z[0],
      @symcore.mul([
        @symcalculus.diff(@symcalculus.diff(zfun(z()), z()), z()),
        @symcore.pow(zfun(z()), @symcore.int(-1)),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      laplace_sep_z[1],
      @symcore.add([
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(@symcalculus.diff(u(theta(), r()), r()), r()),
          @symcore.pow(u(theta(), r()), @symcore.int(-1)),
        ]),
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(u(theta(), r()), r()),
          @symcore.pow(@symcore.mul([r(), u(theta(), r())]), @symcore.int(-1)),
        ]),
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(
            @symcalculus.diff(u(theta(), r()), theta()),
            theta(),
          ),
          @symcore.pow(
            @symcore.mul([r() ^ @symcore.int(2), u(theta(), r())]),
            @symcore.int(-1),
          ),
        ]),
      ]),
    ),
  )
  let c_eq = @symcore.Expr::Relational(@symcore.RelOp::Eq, laplace_sep_z[1], c)
  let laplace_sep_theta = pde_separate_mul(c_eq, u(theta(), r()), [
    tfun(theta()),
    rfun(r()),
  ]).unwrap_or([])
  inspect(laplace_sep_theta.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      laplace_sep_theta[0],
      @symcore.mul([
        @symcalculus.diff(@symcalculus.diff(tfun(theta()), theta()), theta()),
        @symcore.pow(tfun(theta()), @symcore.int(-1)),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      laplace_sep_theta[1],
      @symcore.add([
        @symcore.mul([
          @symcore.int(-1),
          r(),
          @symcalculus.diff(rfun(r()), r()),
          @symcore.pow(rfun(r()), @symcore.int(-1)),
        ]),
        @symcore.mul([
          @symcore.int(-1),
          r() ^ @symcore.int(2),
          @symcalculus.diff(@symcalculus.diff(rfun(r()), r()), r()),
          @symcore.pow(rfun(r()), @symcore.int(-1)),
        ]),
        @symcore.int(-1) * c * (r() ^ @symcore.int(2)),
      ]),
    ),
  )
  let laplace_sep_r = pde_separate_mul(c_eq, u(theta(), r()), [
    rfun(r()),
    tfun(theta()),
  ]).unwrap_or([])
  inspect(laplace_sep_r.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      laplace_sep_r[0],
      @symcore.add([
        @symcore.mul([
          r(),
          @symcalculus.diff(rfun(r()), r()),
          @symcore.pow(rfun(r()), @symcore.int(-1)),
        ]),
        @symcore.mul([
          r() ^ @symcore.int(2),
          @symcalculus.diff(@symcalculus.diff(rfun(r()), r()), r()),
          @symcore.pow(rfun(r()), @symcore.int(-1)),
        ]),
        c * (r() ^ @symcore.int(2)),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      laplace_sep_r[1],
      @symcore.mul([
        @symcore.int(-1),
        @symcalculus.diff(@symcalculus.diff(tfun(theta()), theta()), theta()),
        @symcore.pow(tfun(theta()), @symcore.int(-1)),
      ]),
    ),
  )

  let issue_res = pde_separate(
    @symcalculus.diff(@symcalculus.diff(ut, x()), x()) +
    @symcore.mul([
      @symcore.int(-1),
      @symcalculus.diff(@symcalculus.diff(ut, t()), t()),
    ]),
    ut,
    [
      @symcore.applied_undefined_function("T", [x()]),
      @symcore.applied_undefined_function("X", [t()]),
    ],
  ).unwrap_or([])
  inspect(issue_res.length().to_string(), content="2")
  assert_true(
    expr_semantically_equal(
      issue_res[0],
      @symcore.mul([
        @symcalculus.diff(
          @symcalculus.diff(
            @symcore.applied_undefined_function("T", [x()]),
            x(),
          ),
          x(),
        ),
        @symcore.pow(
          @symcore.applied_undefined_function("T", [x()]),
          @symcore.int(-1),
        ),
      ]),
    ),
  )
  assert_true(
    expr_semantically_equal(
      issue_res[1],
      @symcore.mul([
        @symcalculus.diff(
          @symcalculus.diff(
            @symcore.applied_undefined_function("X", [t()]),
            t(),
          ),
          t(),
        ),
        @symcore.pow(
          @symcore.applied_undefined_function("X", [t()]),
          @symcore.int(-1),
        ),
      ]),
    ),
  )
}

///|
test "dsolve meta-hints cover SymPy-style front doors" {
  let ode = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcalculus.diff(f(x()), x()),
    f(x()),
  )
  let ode_all = dsolve(ode, func=Some(f(x())), hint="all")
  inspect(expr_dict_len_text(ode_all), content="10")
  inspect(
    maybe_expr_text(expr_dict_get(ode_all, "default")),
    content="separable",
  )
  inspect(maybe_expr_text(expr_dict_get(ode_all, "order")), content="1")
  inspect(maybe_expr_text(expr_dict_get(ode_all, "all")), content="True")
  inspect(
    normalize_text(maybe_expr_text(expr_dict_get(ode_all, "1st_linear"))),
    content="Eq(f(x), C1*exp(x))",
  )
  let ode_all_integral = dsolve(ode, func=Some(f(x())), hint="all_Integral")
  inspect(
    normalize_text(
      maybe_expr_text(expr_dict_get(ode_all_integral, "1st_linear_Integral")),
    ),
    content="Eq(f(x), C1*exp(-Integral(-1, (x,))))",
  )
  let mismatched_ode : Result[@symcore.Expr, SolverError] = try? dsolve(
    ode,
    func=Some(f(x())),
    hint="factorable",
  )
  inspect(
    match mismatched_ode {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"ODE Eq(Derivative(f(x), x), f(x)) does not match hint factorable\")",
  )
}

///|
test "pdsolve meta-hints cover SymPy-style front doors" {
  let pde_source = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcore.mul([@symcore.int(-2), @symcalculus.diff(u(x(), y()), x())]),
      @symcore.mul([@symcore.int(4), @symcalculus.diff(u(x(), y()), y())]),
      @symcore.mul([@symcore.int(5), u(x(), y())]),
    ]),
    @symcore.function("exp", [x() + @symcore.int(3) * y()]),
  )
  let pde_all = pdsolve(pde_source, func=Some(u(x(), y())), hint="all")
  inspect(expr_dict_len_text(pde_all), content="6")
  inspect(
    maybe_expr_text(expr_dict_get(pde_all, "default")),
    content="1st_linear_constant_coeff",
  )
  inspect(maybe_expr_text(expr_dict_get(pde_all, "order")), content="1")
  let actual_rhs = match
    expr_dict_get(pde_all, "1st_linear_constant_coeff").unwrap_or(
      @symcore.int(0),
    ) {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  inspect(
    @symprint.to_string(actual_rhs),
    content="exp(x/2 - y)*(exp(x/2 + 4*y)/15 + F(2*y + 4*x))",
  )
}

///|
test "pdsolve solvefun follows SymPy front door" {
  let eq1 = u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcalculus.diff(u(x(), y()), y())
  let default_sol = pdsolve(eq1, func=Some(u(x(), y())))
  let g_sol = pdsolve(
    eq1,
    func=Some(u(x(), y())),
    solvefun=Some(@symcore.Expr::UndefinedFunction("G")),
  )
  let h_sol = pdsolve(
    eq1,
    func=Some(u(x(), y())),
    solvefun=Some(@symcore.Expr::UndefinedFunction("H")),
  )
  inspect(
    @symprint.to_string(default_sol),
    content="Eq(u(x, y), F(x - y)*exp(-x/2 - y/2))",
  )
  inspect(
    @symprint.to_string(g_sol),
    content="Eq(u(x, y), G(x - y)*exp(-x/2 - y/2))",
  )
  inspect(
    @symprint.to_string(h_sol),
    content="Eq(u(x, y), H(x - y)*exp(-x/2 - y/2))",
  )
}

///|
test "pdsolve expanded constant coefficient hints follow SymPy source cases" {
  let pde_source = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcore.mul([@symcore.int(-2), @symcalculus.diff(u(x(), y()), x())]),
      @symcore.mul([@symcore.int(4), @symcalculus.diff(u(x(), y()), y())]),
      @symcore.mul([@symcore.int(5), u(x(), y())]),
    ]),
    @symcore.function("exp", [x() + @symcore.int(3) * y()]),
  )
  inspect(
    expr_list_text(
      classify_pde(pde_source, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff, 1st_linear_constant_coeff_Integral]",
  )
  let pde_source_sol = pdsolve(
    pde_source,
    func=Some(u(x(), y())),
    hint="1st_linear_constant_coeff",
  )
  let actual_rhs = match pde_source_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  inspect(
    @symprint.to_string(actual_rhs),
    content="exp(x/2 - y)*(exp(x/2 + 4*y)/15 + F(2*y + 4*x))",
  )
}

///|
test "pdsolve constant coefficient solution keeps explicit source term shape" {
  let pde_source = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcore.mul([@symcore.int(-2), @symcalculus.diff(u(x(), y()), x())]),
      @symcore.mul([@symcore.int(4), @symcalculus.diff(u(x(), y()), y())]),
      @symcore.mul([@symcore.int(5), u(x(), y())]),
    ]),
    @symcore.function("exp", [x() + @symcore.int(3) * y()]),
  )
  let pde_source_sol = pdsolve(
    pde_source,
    func=Some(u(x(), y())),
    hint="1st_linear_constant_coeff",
  )
  inspect(
    @symprint.to_string(pde_source_sol).has_prefix("Eq(u(x, y), ").to_string(),
    content="true",
  )
}

///|
test "pdsolve constant coefficient integral hint stays available" {
  let pde_source = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcore.mul([@symcore.int(-2), @symcalculus.diff(u(x(), y()), x())]),
      @symcore.mul([@symcore.int(4), @symcalculus.diff(u(x(), y()), y())]),
      @symcore.mul([@symcore.int(5), u(x(), y())]),
    ]),
    @symcore.function("exp", [x() + @symcore.int(3) * y()]),
  )
  let pde_source_sol_integral = pdsolve(
    pde_source,
    func=Some(u(x(), y())),
    hint="1st_linear_constant_coeff_Integral",
  )
  inspect(
    @symprint.to_string(pde_source_sol_integral)
    .has_prefix("Eq(u(x, y), Subs(")
    .to_string(),
    content="true",
  )
}

///|
test "pdsolve variable coefficient hint follows SymPy source case" {
  let pde_variable = @symcore.add([
    x() * @symcalculus.diff(u(x(), y()), x()),
    @symcore.mul([@symcore.int(-1), y(), @symcalculus.diff(u(x(), y()), y())]),
    (y() ^ @symcore.int(2)) * u(x(), y()),
    @symcore.mul([@symcore.int(-1), y() ^ @symcore.int(2)]),
  ])
  inspect(
    expr_list_text(
      classify_pde(pde_variable, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_variable_coeff]",
  )
  let pde_variable_sol = pdsolve(
    pde_variable,
    func=Some(u(x(), y())),
    hint="1st_linear_variable_coeff",
  )
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let expected_rhs = local_canonical_expr(
    @symcore.add([
      @symcore.mul([
        @symcore.applied_undefined_function("F", [x() * y()]),
        @symcore.function("exp", [half * (y() ^ @symcore.int(2))]),
      ]),
      @symcore.int(1),
    ]),
  )
  let actual_rhs = match pde_variable_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  assert_true(expr_semantically_equal(actual_rhs, expected_rhs))
}

///|
test "pdsolve mismatched hint raises ValueError instead of unsupported" {
  let pde_source = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcore.mul([@symcore.int(-2), @symcalculus.diff(u(x(), y()), x())]),
      @symcore.mul([@symcore.int(4), @symcalculus.diff(u(x(), y()), y())]),
      @symcore.mul([@symcore.int(5), u(x(), y())]),
    ]),
    @symcore.function("exp", [x() + @symcore.int(3) * y()]),
  )
  let mismatched_pde : Result[@symcore.Expr, SolverError] = try? pdsolve(
    pde_source,
    func=Some(u(x(), y())),
    hint="1st_linear_variable_coeff",
  )
  inspect(
    match mismatched_pde {
      Err(err) => err.to_string()
      Ok(_) => "ok"
    },
    content="ValueError(\"PDE Eq(-2*Derivative(u(x, y), x) + 4*Derivative(u(x, y), y) + 5*u(x, y), exp(3*y + x)) does not match hint 1st_linear_variable_coeff\")",
  )
}

///|
test "pde classify and checkpdesol match additional SymPy source cases" {
  let a_sym = @symcore.Expr::Symbol("a")
  let b_sym = @symcore.Expr::Symbol("b")
  let c_sym = @symcore.Expr::Symbol("c")
  let eq1 = a_sym * u(x(), y()) +
    b_sym * @symcalculus.diff(u(x(), y()), x()) +
    c_sym * @symcalculus.diff(u(x(), y()), y())
  let eq2 = @symcore.int(3) * u(x(), y()) +
    @symcore.int(2) * @symcalculus.diff(u(x(), y()), x()) +
    @symcalculus.diff(u(x(), y()), y())
  let eq3 = a_sym * u(x(), y()) +
    b_sym * @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(2) * @symcalculus.diff(u(x(), y()), y())
  let eq4 = x() * u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(3) * @symcalculus.diff(u(x(), y()), y())
  let eq5 = @symcore.int(2) * u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(3) * @symcalculus.diff(u(x(), y()), y())
  let eq6 = u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(3) * @symcalculus.diff(u(x(), y()), y())
  inspect(
    expr_list_text(
      classify_pde(eq1, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff_homogeneous]",
  )
  inspect(
    expr_list_text(
      classify_pde(eq2, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff_homogeneous]",
  )
  inspect(
    expr_list_text(
      classify_pde(eq3, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff_homogeneous]",
  )
  inspect(
    expr_list_text(
      classify_pde(eq4, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_variable_coeff]",
  )
  inspect(
    expr_list_text(
      classify_pde(eq5, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff_homogeneous]",
  )
  inspect(
    expr_list_text(
      classify_pde(eq6, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff_homogeneous]",
  )
  inspect(
    checkpdesol(
      eq4,
      pdsolve(eq5, func=Some(u(x(), y()))),
      func=Some(u(x(), y())),
    ).0.to_string(),
    content="false",
  )
  inspect(
    checkpdesol(
      eq4,
      pdsolve(eq6, func=Some(u(x(), y()))),
      func=Some(u(x(), y())),
    ).0.to_string(),
    content="false",
  )
  for eq in [eq1, eq2, eq3, eq4, eq5, eq6] {
    inspect(
      checkpdesol(
        eq,
        pdsolve(eq, func=Some(u(x(), y()))),
        func=Some(u(x(), y())),
      ).0.to_string(),
      content="true",
    )
  }
}

///|
test "pdsolve matches additional SymPy homogeneous and variable source cases" {
  let eq_h1 = @symcore.int(2) * u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcalculus.diff(u(x(), y()), y())
  let eq_h1_sol = pdsolve(eq_h1, func=Some(u(x(), y())))
  let eq_h1_rhs = match eq_h1_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  assert_true(
    expr_semantically_equal(
      eq_h1_rhs,
      @symcore.applied_undefined_function("F", [x() - y()]) *
      @symcore.function("exp", [@symcore.int(-1) * x() + @symcore.int(-1) * y()]),
    ),
  )
  inspect(
    checkpdesol(eq_h1, eq_h1_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )

  let eq_h3 = u(x(), y()) +
    @symcore.int(6) * @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(7) * @symcalculus.diff(u(x(), y()), y())
  let eq_h3_sol = pdsolve(eq_h3, func=Some(u(x(), y())))
  let eq_h3_rhs = match eq_h3_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  assert_true(
    expr_semantically_equal(
      eq_h3_rhs,
      @symcore.applied_undefined_function("F", [
        @symcore.int(7) * x() + @symcore.int(-6) * y(),
      ]) *
      @symcore.function("exp", [
        @symcore.mul([
          @symcore.rational_from_ints(-6, 85) catch {
            _ => fail("r1")
          },
          x(),
        ]) +
        @symcore.mul([
          @symcore.rational_from_ints(-7, 85) catch {
            _ => fail("r2")
          },
          y(),
        ]),
      ]),
    ),
  )
  inspect(
    checkpdesol(eq_h3, eq_h3_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )

  let eq_v1 = x() * @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(-1) * y() * @symcalculus.diff(u(x(), y()), y()) +
    (y() ^ @symcore.int(2)) * u(x(), y()) +
    @symcore.int(-1) * (y() ^ @symcore.int(2))
  let eq_v1_sol = pdsolve(
    eq_v1,
    func=Some(u(x(), y())),
    hint="1st_linear_variable_coeff",
  )
  let eq_v1_rhs = match eq_v1_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  assert_true(
    expr_semantically_equal(
      eq_v1_rhs,
      @symcore.applied_undefined_function("F", [x() * y()]) *
      @symcore.function("exp", [
        @symcore.mul([
          @symcore.rational_from_ints(1, 2) catch {
            _ => fail("r8")
          },
          y() ^ @symcore.int(2),
        ]),
      ]) +
      @symcore.int(1),
    ),
  )
  inspect(
    checkpdesol(eq_v1, eq_v1_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )

  let eq_v2 = (x() ^ @symcore.int(2)) * u(x(), y()) +
    x() * @symcalculus.diff(u(x(), y()), x()) +
    x() * y() * @symcalculus.diff(u(x(), y()), y())
  let eq_v2_sol = pdsolve(
    eq_v2,
    func=Some(u(x(), y())),
    hint="1st_linear_variable_coeff",
  )
  inspect(
    @symprint.to_string(eq_v2_sol),
    content="Eq(u(x, y), F(y*exp(-x))*exp(-x**2/2))",
  )
  inspect(
    checkpdesol(eq_v2, eq_v2_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )

  let eq_v3 = y() * (x() ^ @symcore.int(2)) * u(x(), y()) +
    y() * @symcalculus.diff(u(x(), y()), x()) +
    @symcalculus.diff(u(x(), y()), y())
  let eq_v3_sol = pdsolve(
    eq_v3,
    func=Some(u(x(), y())),
    hint="1st_linear_variable_coeff",
  )
  let eq_v3_rhs = match eq_v3_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  assert_true(
    expr_semantically_equal(
      eq_v3_rhs,
      @symcore.applied_undefined_function("F", [
        @symcore.int(-2) * x() + (y() ^ @symcore.int(2)),
      ]) *
      @symcore.function("exp", [
        @symcore.mul([
          @symcore.rational_from_ints(-1, 3) catch {
            _ => fail("r3")
          },
          x() ^ @symcore.int(3),
        ]),
      ]),
    ),
  )
  inspect(
    checkpdesol(eq_v3, eq_v3_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )

  let eq_v4 = (@symcore.function("exp", [x()]) ^ @symcore.int(2)) *
    @symcalculus.diff(u(x(), y()), x()) +
    y()
  let eq_v4_sol = pdsolve(
    eq_v4,
    func=Some(u(x(), y())),
    hint="1st_linear_variable_coeff",
  )
  inspect(
    @symprint.to_string(eq_v4_sol),
    content="Eq(u(x, y), y*exp(-2*x)/2 + F(y))",
  )
  inspect(
    checkpdesol(eq_v4, eq_v4_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )

  let eq_v5 = @symcore.function("exp", [@symcore.int(2) * x()]) *
    @symcalculus.diff(u(x(), y()), y()) +
    y() * u(x(), y()) +
    @symcore.int(-1) * u(x(), y())
  let eq_v5_sol = pdsolve(
    eq_v5,
    func=Some(u(x(), y())),
    hint="1st_linear_variable_coeff",
  )
  let eq_v5_rhs = match eq_v5_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => @symcore.int(0)
  }
  assert_true(
    expr_semantically_equal(
      eq_v5_rhs,
      @symcore.function("exp", [
        @symcore.mul([
          @symcore.rational_from_ints(1, 2) catch {
            _ => fail("r9")
          },
          @symcore.function("exp", [@symcore.int(-2) * x()]),
          @symcore.add([
            @symcore.int(-1) * (y() ^ @symcore.int(2)),
            @symcore.int(2) * y(),
            @symcore.int(2) * @symcore.applied_undefined_function("F", [x()]),
          ]),
        ]),
      ]),
    ),
  )
  inspect(
    checkpdesol(eq_v5, eq_v5_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )
}

///|
test "pdsolve matches additional SymPy constant coefficient source case eq_c1" {
  let eq_c1 = @symcore.int(-2) * @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(4) * @symcalculus.diff(u(x(), y()), y()) +
    @symcore.int(5) * u(x(), y()) +
    @symcore.int(-1) * @symcore.function("exp", [x() + @symcore.int(3) * y()])
  let eq_c1_sol = pdsolve(eq_c1, func=Some(u(x(), y())))
  inspect(
    expr_list_text(
      classify_pde(eq_c1, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff, 1st_linear_constant_coeff_Integral]",
  )
  inspect(
    checkpdesol(eq_c1, eq_c1_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )
}

///|
test "pdsolve matches additional SymPy constant coefficient source case eq_c2" {
  let uinv = u(x(), y()) ^ @symcore.int(-1)
  let eq_c2 = @symcalculus.diff(u(x(), y()), x()) * uinv +
    @symcalculus.diff(u(x(), y()), y()) * uinv +
    @symcore.int(1) +
    @symcore.int(-1) * @symcore.function("exp", [x() + y()]) * uinv
  let eq_c2_sol = pdsolve(eq_c2, func=Some(u(x(), y())))
  inspect(
    expr_list_text(
      classify_pde(eq_c2, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff, 1st_linear_constant_coeff_Integral]",
  )
  inspect(
    checkpdesol(eq_c2, eq_c2_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )
}

///|
test "pdsolve matches additional SymPy constant coefficient source case eq_c3" {
  let eq_c3 = @symcore.int(2) * u(x(), y()) +
    @symcore.int(-1) * @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(3) * @symcalculus.diff(u(x(), y()), y()) +
    @symcore.function("sin", [x()])
  let eq_c3_sol = pdsolve(eq_c3, func=Some(u(x(), y())))
  inspect(
    expr_list_text(
      classify_pde(eq_c3, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff, 1st_linear_constant_coeff_Integral]",
  )
  inspect(
    checkpdesol(eq_c3, eq_c3_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )
}

///|
test "pdsolve matches additional SymPy constant coefficient source cases eq_c4 and eq_c5" {
  let eq_c4 = u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcalculus.diff(u(x(), y()), y()) +
    x() * y()
  let eq_c4_sol = pdsolve(eq_c4, func=Some(u(x(), y())))
  inspect(
    expr_list_text(
      classify_pde(eq_c4, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff, 1st_linear_constant_coeff_Integral]",
  )
  inspect(
    checkpdesol(eq_c4, eq_c4_sol, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )

  let eq_c5 = u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcalculus.diff(u(x(), y()), y()) +
    @symcore.function("log", [x()])
  inspect(
    expr_list_text(
      classify_pde(eq_c5, func=Some(u(x(), y()))).map(name => {
        @symcore.Expr::Symbol(name)
      }),
    ),
    content="[1st_linear_constant_coeff, 1st_linear_constant_coeff_Integral]",
  )
}

///|
test "checkpdesol follows SymPy list input and solve_for_func behavior" {
  let eq4 = x() * u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(3) * @symcalculus.diff(u(x(), y()), y())
  let eq5 = @symcore.int(2) * u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(3) * @symcalculus.diff(u(x(), y()), y())
  let eq6 = u(x(), y()) +
    @symcalculus.diff(u(x(), y()), x()) +
    @symcore.int(3) * @symcalculus.diff(u(x(), y()), y())
  let checked = checkpdesols(
    eq4,
    [pdsolve(eq5, func=Some(u(x(), y()))), pdsolve(eq6, func=Some(u(x(), y())))],
    func=Some(u(x(), y())),
  )
  inspect(checked.length().to_string(), content="2")
  inspect(checked[0].0.to_string(), content="false")
  inspect(checked[1].0.to_string(), content="false")
  let expected0 = (x() + @symcore.int(-2)) *
    @symcore.applied_undefined_function("F", [
      @symcore.int(3) * x() + @symcore.int(-1) * y(),
    ]) *
    @symcore.function("exp", [
      @symcore.mul([
        @symcore.rational_from_ints(-1, 5) catch {
          _ => fail("r4")
        },
        x(),
      ]) +
      @symcore.mul([
        @symcore.rational_from_ints(-3, 5) catch {
          _ => fail("r5")
        },
        y(),
      ]),
    ])
  let expected1 = (x() + @symcore.int(-1)) *
    @symcore.applied_undefined_function("F", [
      @symcore.int(3) * x() + @symcore.int(-1) * y(),
    ]) *
    @symcore.function("exp", [
      @symcore.mul([
        @symcore.rational_from_ints(-1, 10) catch {
          _ => fail("r6")
        },
        x(),
      ]) +
      @symcore.mul([
        @symcore.rational_from_ints(-3, 10) catch {
          _ => fail("r7")
        },
        y(),
      ]),
    ])
  assert_true(expr_semantically_equal(checked[0].1, expected0))
  assert_true(expr_semantically_equal(checked[1].1, expected1))

  let implicit_sol = pdsolve(eq4, func=Some(u(x(), y())))
  let implicit_zero = match implicit_sol {
    @symcore.Expr::Relational(@symcore.RelOp::Eq, lhs, rhs) =>
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.add([lhs, @symcore.int(-1) * rhs]),
        @symcore.int(0),
      )
    _ => implicit_sol
  }
  inspect(
    checkpdesol(eq4, implicit_zero, func=Some(u(x(), y()))).0.to_string(),
    content="true",
  )
  let no_solve = try? checkpdesol(
    eq4,
    implicit_zero,
    func=Some(u(x(), y())),
    solve_for_func=false,
  )
  assert_true(no_solve is Err(SolverError::NotImplementedError(_)))
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
          (
            (
              @sympolys.Poly::from_expr_defaults(@symcore.int(1) - x(), gens=[
                "x",
              ]),
              one,
            ),
            ">=",
          ),
        ],
      ]),
    ),
    content="Union(Interval.open(-oo, 0), Interval.Lopen(0, 1))",
  )
  inspect(
    inequality_result_text(
      solve_univariate_inequality(
        @symcore.Expr::Relational(
          @symcore.RelOp::Ge,
          x() ^ @symcore.int(2),
          @symcore.int(4),
        ),
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
          @symcore.Expr::Relational(
            @symcore.RelOp::Ge,
            x() ^ @symcore.int(2),
            @symcore.int(4),
          ),
          x(),
        ),
      ),
    ),
    content="Relational(Or(x <= -2, 2 <= x))",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        reduce_abs_inequality(
          @symcore.function("Abs", [x() - @symcore.int(5)]) - @symcore.int(3),
          "<",
          x(),
        ),
      ),
    ),
    content="And(2 < x, x < 8)",
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        reduce_abs_inequality(
          @symcore.function("Abs", [x() - @symcore.int(5)]) - @symcore.int(3),
          "==",
          x(),
        ),
      ),
    ),
    content=(
      #|Or(Eq(x, 2), Eq(x, 8))
    ),
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        reduce_abs_inequality(
          @symcore.function("Abs", [x() - @symcore.int(5)]) - @symcore.int(3),
          "!=",
          x(),
        ),
      ),
    ),
    content=(
      #|Contains(x, Complement(Reals, {2, 8}))
    ),
  )
  inspect(
    normalize_text(
      @symprint.to_string(
        reduce_inequalities(
          [
            @symcore.Expr::Relational(
              @symcore.RelOp::Ge,
              x() ^ @symcore.int(2),
              @symcore.int(4),
            ),
          ],
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
    content=(
      #|And(1 < x, y < 2)
    ),
  )
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
    normalize_text(
      classify_diop_text(classify_diop(x() + y() - @symcore.int(3))),
    ),
    content="([x, y], {1: -3, x: 1, y: 1}, 'linear')",
  )
  inspect(
    normalize_text(
      diop_solve_result_text(diop_solve(x() + y() - @symcore.int(3))),
    ),
    content="(t_0, 3 - t_0)",
  )
  inspect(
    normalize_text(
      @symsets.to_string(diophantine((x() ^ @symcore.int(2)) - @symcore.int(1))),
    ),
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
    content=(
      #|{(3*t_0 + 4*t_1 - 5, -4*t_1 - 2*t_0 + 5, t_1)}
    ),
  )
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
      rsolve(recurrence, f(x()), init=Some(rsolve_init_list([@symcore.int(0)]))),
      expected_init,
    ),
    content="0",
  )
}

///|
test "solveset matches additional SymPy real set cases batch 29" {
  let cm = @symcore.Expr::Symbol("cm")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let p = @symcore.Expr::Symbol("p")
  let one_third = @symcore.rational_from_ints(1, 3) catch { _ => fail("third") }
  let real_domain = @symsets.reals()
  let rational_y_den = (y() ^ @symcore.int(2)) *
    sqrt(@symcore.int(1) + @symcore.int(-1) * (y() ^ @symcore.int(2)))
  let rational_y = (x() + @symcore.int(-1) * (y() ^ @symcore.int(3))) *
    (rational_y_den ^ @symcore.int(-1))

  inspect(
    @symsets.to_string(
      solveset(rational_y, symbol=Some(x()), domain=real_domain),
    ),
    content="Intersection({y**3}, Reals)",
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.int(2) * x() * ((x() + @symcore.int(2)) ^ @symcore.int(-1)) +
        @symcore.int(-1),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.int(2)]),
    ),
    0,
  )

  inspect(
    @symsets.to_string(
      solveset(
        sqrt((a ^ @symcore.int(2)) + @symcore.int(-1) * (b ^ @symcore.int(2))) +
        @symcore.int(-3),
        symbol=Some(a),
        domain=real_domain,
      ),
    ),
    content="Intersection({(b**2 + 9)**(1/2), -(b**2 + 9)**(1/2)}, Reals)",
  )

  inspect(
    @symsets.to_string(
      solveset(
        sqrt((a ^ @symcore.int(2)) + (b ^ @symcore.int(2))) + @symcore.int(-3),
        symbol=Some(a),
        domain=real_domain,
      ),
    ),
    content="Intersection({(9 - b**2)**(1/2), -(9 - b**2)**(1/2)}, Reals)",
  )

  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(-1)) +
        @symcore.int(-1) * ((@symcore.int(2) * cm) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="Intersection({2*cm}, Reals)",
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        x() * ((x() ^ one_third) + @symcore.int(-3)),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.finite_set([@symcore.int(0), @symcore.int(27)]),
    ),
    0,
  )

  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(2)) +
        @symcore.int(-1) *
        (y() ^ @symcore.int(2)) *
        (@symcore.function("exp", [x()]) ^ @symcore.int(-1)),
        symbol=Some(y()),
        domain=real_domain,
      ),
    ),
    content="Intersection({(x**2*exp(x))**(1/2), -(x**2*exp(x))**(1/2)}, Reals)",
  )

  inspect(
    @symsets.to_string(
      solveset(
        (@symcore.int(1) * (p ^ @symcore.int(-1)) + @symcore.int(1)) ^
        (p + @symcore.int(1)),
        symbol=Some(p),
        domain=real_domain,
      ),
    ),
    content="ConditionSet(p, Eq((p**-1 + 1)**(p + 1), 0), Reals)",
  )
}

///|
test "solveset matches additional SymPy set behavior cases batch 30" {
  let a = @symcore.Expr::Symbol("a")
  let real_domain = @symsets.reals()

  assert_eq(
    @symsets.compare_set(
      solveset(
        x() * (@symcore.function("log", [x()]) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.empty_set(),
    ),
    0,
  )

  inspect(
    @symsets.to_string(
      solveset(
        (x() ^ @symcore.int(2)) + a,
        symbol=Some(x()),
        domain=real_domain,
      ),
    ),
    content="Intersection({(-a)**(1/2), -(-a)**(1/2)}, Reals)",
  )

  assert_eq(
    @symsets.compare_set(
      solveset(
        @symcore.int(1) * (sqrt(x()) ^ @symcore.int(-1)),
        symbol=Some(x()),
        domain=real_domain,
      ),
      @symsets.empty_set(),
    ),
    0,
  )
}

///|
test "solveset finds rational linear roots via SymPy-style polynomial root enumeration" {
  let real_domain = @symsets.reals()
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("1/2") }
  let third = @symcore.rational_from_ints(1, 3) catch { _ => fail("1/3") }
  let expr = (@symcore.int(2) * x() + @symcore.int(-1)) *
    (@symcore.int(3) * x() + @symcore.int(1))
  assert_eq(
    @symsets.compare_set(
      solveset(expr, symbol=Some(x()), domain=real_domain),
      @symsets.finite_set([half, @symcore.int(-1) * third]),
    ),
    0,
  )
}
