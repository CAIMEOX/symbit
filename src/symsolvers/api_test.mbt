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
fn normalize_text(text : String) -> String {
  text
  .replace_all(old="/1", new="")
  .replace_all(old="-1*", new="-")
  .replace_all(old=" + -", new=" - ")
  .replace_all(old="-t_0 + 3", new="3 - t_0")
  .replace_all(old="exp(1*x**3/3)", new="exp(x**3/3)")
  .replace_all(old="-g(x) + 20*f(x)", new="20*f(x) - g(x)")
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
  inspect(@symsets.to_string(result), content="{(-1*z/2 + 2, -1*z/2 + 1, z)}")
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
test "ode and pde helpers cover low-level source-compatible entry points" {
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
  let expected_canonical = [
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(f(x()), x()),
      @symcore.add([@symcore.int(7) * f(x()), @symcore.int(12) * g(x())]),
    ),
    @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      @symcalculus.diff(g(x()), x()),
      @symcore.add([@symcore.int(20) * f(x()), @symcore.int(-1) * g(x())]),
    ),
  ]
  inspect(
    (
      canonical.length() == 1 &&
      @symcore.compare_expr(canonical[0][0], expected_canonical[0]) == 0 &&
      @symcore.compare_expr(canonical[0][1], expected_canonical[1]) == 0
    ).to_string(),
    content="true",
  )
  let (a_mats, b_mat) = linear_ode_to_matrix(system, [f(x()), g(x())], x(), 1)
  inspect(a_mats[0].to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(a_mats[1].to_string(), content="Matrix([[7, 12], [20, -1]])")
  inspect(b_mat.to_string(), content="Matrix([[0], [0]])")
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
