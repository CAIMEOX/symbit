///|
fn local_args_sstr(expr : @symcore.Expr) -> String raise {
  let items : Array[String] = []
  for arg in @symcore.args(expr) {
    items.push("'" + core_expr_sstr(arg) + "'")
  }
  if items.length() == 1 {
    "(" + items[0] + ",)"
  } else {
    "(" + items.join(", ") + ")"
  }
}

///|
fn local_preorder_sstr(expr : @symcore.Expr) -> String raise {
  let items : Array[String] = []
  for item in @symcore.preorder(expr) {
    items.push("'" + core_expr_sstr(item) + "'")
  }
  "(" + items.join(", ") + ")"
}

///|
fn local_postorder_sstr(expr : @symcore.Expr) -> String raise {
  let items : Array[String] = []
  for item in @symcore.postorder(expr) {
    items.push("'" + core_expr_sstr(item) + "'")
  }
  "(" + items.join(", ") + ")"
}

///|
fn local_func_name(expr : @symcore.Expr) -> String {
  match @symcore.func(expr) {
    Some(head) =>
      match @symcore.function_head_name(head) {
        Some(name) => name
        None => @symcore.head_name(head)
      }
    None => "None"
  }
}

///|
fn local_sorted_sstr(exprs : Array[@symcore.Expr]) -> String raise {
  let items = exprs.copy()
  items.sort_by(@symcore.compare_expr)
  let out : Array[String] = []
  for expr in items {
    out.push("'" + core_expr_sstr(expr) + "'")
  }
  "(" + out.join(", ") + ")"
}

///|
test "symcore parity plain symbol names stay plain symbols" {
  inspect(core_expr_srepr(@symcore.Expr::Symbol("pi")), content="Symbol('pi')")
  inspect(
    core_expr_srepr(@symcore.Expr::Symbol("True")),
    content="Symbol('True')",
  )
  inspect(
    core_expr_srepr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)),
    content="pi",
  )
  inspect(core_expr_srepr(@symcore.Expr::Boolean(true)), content="True")
}

///|
test "symcore parity number symbols render as SymPy core singletons" {
  inspect(
    core_expr_sstr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)),
    content="pi",
  )
  inspect(
    core_expr_sstr(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
    ),
    content="I",
  )
  inspect(
    core_expr_sstr(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
    ),
    content="oo",
  )
  inspect(
    core_expr_sstr(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ComplexInfinity),
    ),
    content="zoo",
  )
  inspect(
    core_expr_sstr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)),
    content="nan",
  )
}

///|
test "symcore parity dummy wild and undefined-function heads" {
  inspect(core_expr_sstr(@symcore.dummy(name="x")), content="_x")
  inspect(core_expr_sstr(@symcore.Expr::Wild("x", [], [])), content="x_")
  inspect(core_expr_sstr(@symcore.Expr::FunctionHead("sin")), content="sin")
  inspect(core_expr_sstr(@symcore.Expr::UndefinedFunction("f")), content="f")
  inspect(
    core_expr_sstr(
      @symcore.applied_undefined_function("f", [@symcore.Expr::Symbol("x")]),
    ),
    content="f(x)",
  )
}

///|
test "symcore parity wild match exclude and properties" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let a = @symcore.Expr::Wild("a", [], [])
  let b = @symcore.Expr::Wild("b", [x], [])
  let p = @symcore.Expr::Wild("p", [], [@symcore.WildProperty::Positive])
  let s = @symcore.Expr::Wild("s", [], [@symcore.WildProperty::Symbol])
  let seeded : Map[@symcore.Expr, @symcore.Expr] = {}
  seeded.set(a, y)
  inspect(
    core_match_sstr(a, @symcore.mul([@symcore.int(2), y])),
    content="a_=2*y",
  )
  inspect(
    core_match_sstr(b, @symcore.mul([@symcore.int(2), y])),
    content="b_=2*y",
  )
  inspect(
    core_match_sstr(b, @symcore.mul([@symcore.int(2), x])),
    content="None",
  )
  inspect(core_match_sstr(p, @symcore.int(2)), content="p_=2")
  inspect(core_match_sstr(p, @symcore.int(-2)), content="None")
  inspect(core_match_sstr(s, y), content="s_=y")
  inspect(core_match_sstr(s, @symcore.int(3)), content="None")
  inspect(
    @symcore.wild_matches(a, x, repl_dict=seeded)
    .map(env => env.get(a).map(core_expr_sstr).unwrap_or(""))
    .unwrap_or("None"),
    content="x",
  )
}

///|
test "symcore source-driven commutative wildcard matching examples" {
  let a = @symcore.Expr::Wild("a", [], [])
  let b = @symcore.Expr::Wild("b", [], [])
  let c = @symcore.Expr::Wild("c", [], [])
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  inspect(
    core_match_sstr(@symcore.mul([a, x]), @symcore.mul([@symcore.int(3), x])),
    content="a_=3",
  )
  inspect(
    core_match_sstr(
      @symcore.add([a, @symcore.mul([@symcore.function("sin", [b]), c])]),
      @symcore.add([x, @symcore.mul([@symcore.function("sin", [y]), z])]),
    ),
    content="a_=x|b_=y|c_=z",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([
        @symcore.Expr::Wild("a", [x, y, z], []),
        @symcore.Expr::Wild("b", [], []),
      ]),
      @symcore.mul([@symcore.int(2), @symcore.pow(x, @symcore.int(3)), y, z]),
    ),
    content="a_=2|b_=x**3*y*z",
  )
  inspect(
    core_match_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("f"), [a, @symcore.add([a, b])]).unwrap_or(
        @symcore.int(0),
      ),
      @symcore.apply(@symcore.Expr::FunctionHead("f"), [x, @symcore.add([x, y])]).unwrap_or(
        @symcore.int(0),
      ),
    ),
    content="a_=x|b_=y",
  )
  inspect(
    core_match_sstr(
      @symcore.add([@symcore.mul([a, x]), b]),
      @symcore.add([@symcore.mul([@symcore.int(4), x]), @symcore.int(5)]),
    ),
    content="a_=4|b_=5",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([@symcore.Expr::Wild("a", [x], []), x]),
      @symcore.mul([@symcore.int(3), @symcore.pow(x, @symcore.int(2))]),
    ),
    content="None",
  )
  inspect(core_match_sstr(@symcore.pow(x, a), @symcore.int(1)), content="a_=0")
  inspect(
    core_match_sstr(
      @symcore.mul([a, @symcore.function("cos", [@symcore.mul([b, x])])]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(5), x])]),
    ),
    content="a_=1|b_=5",
  )
  inspect(
    core_match_sstr(
      @symcore.add([@symcore.mul([@symcore.int(3), x]), a]),
      @symcore.add([@symcore.mul([@symcore.int(4), x]), @symcore.int(5)]),
    ),
    content="a_=x + 5",
  )
  inspect(
    core_match_sstr(
      @symcore.add([
        @symcore.mul([@symcore.int(4), x]),
        @symcore.mul([a, @symcore.Expr::Symbol("y")]),
      ]),
      @symcore.mul([@symcore.int(4), x]),
    ),
    content="a_=0",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([
        a,
        @symcore.pow(@symcore.add([@symcore.mul([b, x]), c]), @symcore.int(-1)),
      ]),
      @symcore.mul([
        @symcore.int(3),
        @symcore.pow(
          @symcore.add([@symcore.mul([@symcore.int(4), x]), @symcore.int(5)]),
          @symcore.int(-1),
        ),
      ]),
    ),
    content="a_=3|b_=4|c_=5",
  )
}

///|
test "symcore source-driven factorization and derivative wildcard examples" {
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let p = @symcore.Expr::Wild("p", [], [])
  let ax = @symcore.Expr::Wild("a", [x], [])
  let q = @symcore.Expr::Wild("q", [], [])
  let g = @symcore.Expr::WildFunction("g", [])
  let fx = @symcore.applied_undefined_function("f", [x])
  let dfx = @symcore.derivative(fx, x)

  inspect(
    core_match_sstr(
      @symcore.add([
        @symcore.mul([p, @symcore.pow(x, @symcore.int(2))]),
        @symcore.mul([p, x]),
        @symcore.mul([@symcore.int(2), p]),
      ]),
      @symcore.add([
        @symcore.mul([@symcore.int(3), x]),
        @symcore.int(3),
        @symcore.mul([@symcore.int(6), @symcore.pow(x, @symcore.int(-1))]),
      ]),
    ),
    content="p_=3/x",
  )
  inspect(
    core_match_sstr(
      @symcore.add([
        @symcore.mul([ax, @symcore.pow(x, @symcore.int(2))]),
        @symcore.mul([ax, x]),
        @symcore.mul([@symcore.int(2), ax]),
      ]),
      @symcore.add([
        @symcore.mul([@symcore.int(3), x]),
        @symcore.int(3),
        @symcore.mul([@symcore.int(6), @symcore.pow(x, @symcore.int(-1))]),
      ]),
    ),
    content="None",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([@symcore.add([p, b]), @symcore.add([p, c])]),
      @symcore.mul([@symcore.add([a, b]), @symcore.add([a, c])]),
    ),
    content="p_=a",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([p, g]),
      @symcore.function("cos", [@symcore.mul([@symcore.int(5), x])]),
    ),
    content="g_=cos(5*x)|p_=1",
  )
  inspect(core_match_sstr(g, g), content="g_=g_")
  inspect(
    core_match_sstr(
      @symcore.add([@symcore.mul([p, dfx]), q]),
      @symcore.add([@symcore.mul([@symcore.int(3), dfx]), @symcore.int(-1)]),
    ),
    content="p_=3|q_=-1",
  )
}

///|
test "symcore source-driven derivative exclusion examples" {
  let x = @symcore.Expr::Symbol("x")
  let f = @symcore.Expr::UndefinedFunction("f")
  let fx = @symcore.apply(f, [x]).unwrap_or(@symcore.int(0))
  let d1 = @symcore.derivative(fx, x)
  let d2 = @symcore.Expr::Derivative(fx, [
    x,
    @symcore.int(1),
    x,
    @symcore.int(1),
  ])
  let a = @symcore.Expr::Wild("a", [f, x], [])
  let b = @symcore.Expr::Wild("b", [f], [])

  inspect(core_match_sstr(d1, d1), content="")
  inspect(core_match_sstr(d1, d2), content="None")
  inspect(core_match_sstr(d2, d1), content="None")
  inspect(
    core_match_sstr(
      @symcore.add([@symcore.mul([a, d1]), b]),
      @symcore.add([d1, @symcore.pow(x, @symcore.int(2))]),
    ),
    content="a_=1|b_=x**2",
  )
  inspect(
    core_match_sstr(
      @symcore.add([@symcore.mul([a, d2]), b]),
      @symcore.add([d1, @symcore.pow(x, @symcore.int(2))]),
    ),
    content="None",
  )
  let seeded : @symcore.MatchEnv = {}
  seeded.set(b, @symcore.pow(x, @symcore.int(2)))
  inspect(
    match
      @symcore.expr_match(
        @symcore.xreplace(@symcore.add([@symcore.mul([a, d2]), b]), [
          (b, @symcore.pow(x, @symcore.int(2))),
        ]),
        @symcore.add([d1, @symcore.pow(x, @symcore.int(2))]),
        repl_dict=seeded,
      ) {
      Some(_) => "Some"
      None => "None"
    },
    content="None",
  )
}

///|
test "symcore source-driven derivative remainder and coefficient bug examples" {
  let x = @symcore.Expr::Symbol("x")
  let f = @symcore.Expr::UndefinedFunction("f")
  let fx = @symcore.apply(f, [x]).unwrap_or(@symcore.int(0))
  let dfx = @symcore.derivative(fx, x)
  let a = @symcore.Expr::Wild("a", [fx], [])
  let b = @symcore.Expr::Wild("b", [fx], [])
  let p = @symcore.Expr::Wild("p", [], [])

  inspect(
    core_match_sstr(@symcore.add([@symcore.mul([a, dfx]), b]), dfx),
    content="a_=1|b_=0",
  )
  inspect(
    core_match_sstr(@symcore.mul([@symcore.int(-1), p, x]), x),
    content="p_=-1",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([@symcore.int(-1), p, x]),
      @symcore.mul([@symcore.int(-1), x]),
    ),
    content="p_=1",
  )
  inspect(
    core_match_sstr(@symcore.mul([@symcore.int(3), p, x]), x),
    content="p_=1/3",
  )
}

///|
test "symcore source-driven reciprocal wildcard examples" {
  let x = @symcore.Expr::Symbol("x")
  let w = @symcore.Expr::Wild("w", [x], [])
  let y = @symcore.Expr::Wild("y", [], [])

  inspect(
    core_match_sstr(
      @symcore.mul([w, @symcore.pow(y, @symcore.int(-1))]),
      @symcore.mul([@symcore.int(3), @symcore.pow(x, @symcore.int(-1))]),
    ),
    content="w_=3|y_=x",
  )
  inspect(
    core_match_sstr(@symcore.mul([w, y]), @symcore.mul([@symcore.int(3), x])),
    content="w_=3|y_=x",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([y, @symcore.pow(w, @symcore.int(-1))]),
      @symcore.mul([x, @symcore.rational_from_ints(1, 3)]),
    ),
    content="w_=3|y_=x",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([y, @symcore.pow(w, @symcore.int(-1))]),
      @symcore.mul([@symcore.int(3), x]),
    ),
    content="w_=1/3|y_=x",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([w, @symcore.pow(y, @symcore.int(-1))]),
      @symcore.mul([x, @symcore.rational_from_ints(1, 3)]),
    ),
    content="w_=1/3|y_=1/x",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([w, @symcore.pow(y, @symcore.int(-1))]),
      @symcore.mul([@symcore.int(3), x]),
    ),
    content="w_=3|y_=1/x",
  )
  inspect(
    core_match_sstr(
      @symcore.mul([w, y]),
      @symcore.mul([@symcore.int(3), @symcore.pow(x, @symcore.int(-1))]),
    ),
    content="w_=3|y_=1/x",
  )
  let a = @symcore.Expr::Wild("a", [], [])
  inspect(
    core_match_sstr(@symcore.pow(a, @symcore.int(-1)), @symcore.int(0)),
    content="None",
  )
  inspect(
    core_match_sstr(@symcore.pow(a, @symcore.int(-1)), @symcore.int(3)),
    content="a_=1/3",
  )
  inspect(
    core_match_sstr(@symcore.pow(a, @symcore.int(-2)), @symcore.int(3)),
    content="a_=sqrt(3)/3",
  )
}

///|
test "symcore source-driven positive power wildcard examples" {
  let x = @symcore.Expr::Symbol("x")
  let r = @symcore.Expr::Symbol("r")
  let e = @symcore.Expr::Symbol("e")
  let y = @symcore.Expr::Wild("y", [], [])
  let a = @symcore.Expr::Wild("a", [], [])

  inspect(
    core_match_sstr(@symcore.pow(y, @symcore.int(2)), @symcore.pow(x, r)),
    content="y_=sqrt(x**r)",
  )
  inspect(
    core_match_sstr(@symcore.pow(y, @symcore.int(2)), @symcore.pow(x, e)),
    content="y_=sqrt(x**e)",
  )
  inspect(
    core_match_sstr(
      @symcore.pow(a, @symcore.int(2)),
      @symcore.mul([
        @symcore.int(-1),
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      ]),
    ),
    content="a_=I*sqrt(pi)",
  )
}

///|
test "symcore source-driven implicit zero-power wildcard examples" {
  let x = @symcore.Expr::Symbol("x")
  let f = @symcore.Expr::UndefinedFunction("f")
  let fx = @symcore.apply(f, [x]).unwrap_or(@symcore.int(0))
  let a = @symcore.Expr::Wild("a", [], [])
  let b = @symcore.Expr::Wild("b", [], [])
  let c = @symcore.Expr::Wild("c", [], [])

  inspect(
    core_match_sstr(@symcore.mul([a, @symcore.pow(fx, c)]), x),
    content="a_=x|c_=0",
  )
  inspect(core_match_sstr(@symcore.mul([a, b]), x), content="a_=1|b_=x")
  inspect(
    core_match_sstr(@symcore.mul([a, b, @symcore.pow(fx, c)]), x),
    content="a_=1|b_=x|c_=0",
  )
}

///|
test "symcore source-driven exclude and wild-on-wild examples" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let a = @symcore.Expr::Symbol("a")
  let p = @symcore.Expr::Wild("p", [@symcore.int(1), x], [])
  let q = @symcore.Expr::Wild("q", [], [])
  let r = @symcore.Expr::Wild("r", [@symcore.Expr::FunctionHead("sin"), y], [])

  inspect(core_match_sstr(r, @symcore.function("sin", [x])), content="None")
  inspect(core_match_sstr(r, @symcore.function("cos", [y])), content="None")
  inspect(
    core_match_sstr(
      @symcore.add([
        @symcore.mul([p, @symcore.pow(x, @symcore.int(2))]),
        @symcore.mul([q, x]),
        r,
      ]),
      @symcore.add([
        @symcore.mul([@symcore.int(3), @symcore.pow(x, @symcore.int(2))]),
        @symcore.mul([y, x]),
        a,
      ]),
    ),
    content="p_=3|q_=y|r_=a",
  )
  inspect(
    core_match_sstr(@symcore.add([x, p]), @symcore.add([x, @symcore.int(1)])),
    content="None",
  )
  inspect(
    core_match_sstr(
      @symcore.add([p, @symcore.int(1)]),
      @symcore.add([x, @symcore.int(1)]),
    ),
    content="None",
  )
  inspect(
    core_match_sstr(
      @symcore.add([x, @symcore.int(1), p]),
      @symcore.add([x, @symcore.int(1)]),
    ),
    content="p_=0",
  )
  let q_excluding_p = @symcore.Expr::Wild("q", [p], [])
  let r_plain = @symcore.Expr::Wild("r", [], [])
  inspect(
    core_match_sstr(@symcore.add([q_excluding_p, r_plain]), p),
    content="q_=0|r_=p_",
  )
  inspect(
    core_match_sstr(@symcore.mul([q_excluding_p, r_plain]), p),
    content="q_=1|r_=p_",
  )
  let r_excluding_p = @symcore.Expr::Wild("r", [p], [])
  inspect(
    core_match_sstr(@symcore.add([q_excluding_p, r_excluding_p]), p),
    content="None",
  )
  inspect(
    core_match_sstr(@symcore.mul([q_excluding_p, r_excluding_p]), p),
    content="None",
  )
}

///|
test "symcore source-driven exclude cases around additive coefficients" {
  let x = @symcore.Expr::Symbol("x")
  let f = @symcore.Expr::UndefinedFunction("f")
  let fx = @symcore.apply(f, [x]).unwrap_or(@symcore.int(0))
  let a = @symcore.Expr::Wild("a", [fx], [])
  let b = @symcore.Expr::Wild("b", [fx], [])
  let pattern = @symcore.add([@symcore.mul([a, fx]), b])

  inspect(
    core_match_sstr(pattern, @symcore.function("sin", [x])),
    content="a_=0|b_=sin(x)",
  )
  inspect(
    core_match_sstr(pattern, @symcore.add([fx, @symcore.function("sin", [x])])),
    content="a_=1|b_=sin(x)",
  )
  inspect(
    core_match_sstr(
      pattern,
      @symcore.add([fx, x, @symcore.function("sin", [x])]),
    ),
    content="a_=1|b_=x + sin(x)",
  )
  inspect(
    core_match_sstr(pattern, @symcore.add([x, @symcore.function("sin", [x])])),
    content="a_=0|b_=x + sin(x)",
  )
}

///|
test "symcore parity formal application helpers" {
  let x = @symcore.Expr::Symbol("x")
  match @symcore.apply(@symcore.Expr::FunctionHead("sin"), [x]) {
    Some(expr) => {
      inspect(core_expr_sstr(expr), content="sin(x)")
      inspect(
        core_expr_sstr(@symcore.func(expr).unwrap_or(@symcore.int(0))),
        content="sin",
      )
      inspect(core_func_sstr(expr), content="sin")
      inspect(core_args_sstr(expr), content="('x',)")
    }
    None => fail("expected named application")
  }
  match @symcore.apply(@symcore.Expr::UndefinedFunction("f"), [x]) {
    Some(expr) =>
      match @symcore.application_parts(expr) {
        Some((head, [arg])) => {
          inspect(core_expr_sstr(head), content="f")
          inspect(core_expr_sstr(arg), content="x")
        }
        _ => fail("expected application parts")
      }
    None => fail("expected undefined application")
  }
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Integer"), [
        @symcore.rational_from_ints(5, 2),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="2",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Integer"), [
        @symcore.rational_from_ints(-2, 3),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="0",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Rational"), [
        @symcore.int(2),
        @symcore.int(3),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="2/3",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Rational"), [
        @symcore.Expr::Float(@symcore.Float::from_double(2.5)),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="5/2",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Float"), [@symcore.int(2)]).unwrap_or(
        @symcore.int(0),
      ),
    ),
    content="2.00000000000000",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Float"), [
        @symcore.rational_from_ints(2, 3),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="0.666666666666667",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Tuple"), [x, @symcore.int(1)]).unwrap_or(
        @symcore.int(0),
      ),
    ),
    content="(x, 1)",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Rational"), [
        @symcore.Expr::Boolean(true),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="1",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Rational"), [
        @symcore.int(1),
        @symcore.Expr::Boolean(false),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="zoo",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("Rational"), [
        @symcore.Expr::Boolean(false),
        @symcore.Expr::Boolean(false),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="nan",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("S"), [
        @symcore.Expr::Boolean(true),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="True",
  )
}

///|
test "symcore parity application constructors canonicalize legacy children" {
  let x = @symcore.Expr::Symbol("x")
  let legacy_derivative = @symcore.Expr::Function("Derivative", [x, x])
  inspect(
    core_expr_sstr(@symcore.function("sin", [legacy_derivative])),
    content="sin(Derivative(x, x))",
  )
  match
    @symcore.apply(@symcore.Expr::FunctionHead("sin"), [legacy_derivative]) {
    Some(expr) => inspect(core_expr_sstr(expr), content="sin(Derivative(x, x))")
    None => fail("expected apply result")
  }
  inspect(
    core_expr_sstr(
      @symcore.applied_undefined_function("f", [legacy_derivative]),
    ),
    content="f(Derivative(x, x))",
  )
  inspect(
    core_expr_sstr(@symcore.normalize_legacy_expr(@symcore.Expr::Lambda(x, x))),
    content="Lambda(_x, _x)",
  )
  inspect(
    core_expr_sstr(
      @symcore.normalize_legacy_expr(@symcore.Expr::Derivative(x, [x])),
    ),
    content="Derivative(x, x)",
  )
}

///|
test "symcore parity function constructors follow SymPy core semantics" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(core_expr_sstr(@symcore.function("Eq", [x, x])), content="True")
  inspect(core_expr_sstr(@symcore.function("Ne", [x, x])), content="False")
  inspect(
    core_expr_sstr(@symcore.function("Lt", [@symcore.int(1), @symcore.int(2)])),
    content="True",
  )
  inspect(
    core_expr_sstr(@symcore.function("Ge", [@symcore.int(1), @symcore.int(2)])),
    content="False",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Derivative", [
        @symcore.function("sin", [x]),
        x,
        @symcore.int(2),
      ]),
    ),
    content="Derivative(sin(x), (x, 2))",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Derivative", [@symcore.function("sin", [x]), x, y]),
    ),
    content="Derivative(sin(x), x, y)",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Derivative", [
        @symcore.function("sin", [x]),
        @symcore.Expr::Tuple([x, @symcore.int(0)]),
      ]),
    ),
    content="sin(x)",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Derivative", [
        @symcore.function("sin", [x]),
        x,
        y,
        @symcore.int(2),
      ]),
    ),
    content="Derivative(sin(x), x, (y, 2))",
  )
}

///|
test "symcore parity args for derivative and lambda follow SymPy shapes" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    local_args_sstr(@symcore.derivative(@symcore.function("f", [x]), x)),
    content=core_args_sstr(@symcore.derivative(@symcore.function("f", [x]), x)),
  )
  inspect(
    local_args_sstr(@symcore.lambda_expr(x, @symcore.add([x, y]))),
    content=core_args_sstr(@symcore.lambda_expr(x, @symcore.add([x, y]))),
  )
}

///|
test "symcore parity func and args for containers relationals and Subs" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    local_func_name(@symcore.Expr::Tuple([x, y])),
    content=core_func_sstr(@symcore.Expr::Tuple([x, y])),
  )
  inspect(
    local_func_name(@symcore.Expr::Dict([(x, y)])),
    content=core_func_sstr(@symcore.Expr::Dict([(x, y)])),
  )
  inspect(
    local_func_name(@symcore.Expr::Relational(@symcore.RelOp::Eq, x, y)),
    content=core_func_sstr(@symcore.Expr::Relational(@symcore.RelOp::Eq, x, y)),
  )
  inspect(
    local_func_name(
      @symcore.subs_expr(@symcore.add([x, y]), x, @symcore.int(1)),
    ),
    content=core_func_sstr(
      @symcore.subs_expr(@symcore.add([x, y]), x, @symcore.int(1)),
    ),
  )
  inspect(core_func_sstr(@symcore.Expr::Tuple([x, y])), content="Tuple")
  inspect(core_func_sstr(@symcore.Expr::Dict([(x, y)])), content="Dict")
  inspect(
    core_func_sstr(@symcore.Expr::Relational(@symcore.RelOp::Eq, x, y)),
    content="Equality",
  )
  inspect(
    core_func_sstr(@symcore.subs_expr(@symcore.add([x, y]), x, @symcore.int(1))),
    content="Subs",
  )
  inspect(
    local_args_sstr(@symcore.Expr::Dict([(x, y), (@symcore.int(1), x)])),
    content=core_args_sstr(@symcore.Expr::Dict([(x, y), (@symcore.int(1), x)])),
  )
  inspect(
    local_args_sstr(@symcore.Expr::Relational(@symcore.RelOp::Eq, x, y)),
    content=core_args_sstr(@symcore.Expr::Relational(@symcore.RelOp::Eq, x, y)),
  )
  inspect(
    local_args_sstr(
      @symcore.subs_expr(@symcore.add([x, y]), x, @symcore.int(1)),
    ),
    content=core_args_sstr(
      @symcore.subs_expr(@symcore.add([x, y]), x, @symcore.int(1)),
    ),
  )
}

///|
test "symcore parity displayed func heads for atomic core nodes" {
  inspect(
    core_expr_sstr(@symcore.func(@symcore.int(2)).unwrap_or(@symcore.int(0))),
    content="<class 'sympy.core.numbers.Integer'>",
  )
  inspect(
    core_expr_sstr(
      @symcore.func(@symcore.rational_from_ints(1, 2)).unwrap_or(
        @symcore.int(0),
      ),
    ),
    content="<class 'sympy.core.numbers.Half'>",
  )
  inspect(
    core_expr_sstr(
      @symcore.func(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)).unwrap_or(
        @symcore.int(0),
      ),
    ),
    content="<class 'sympy.core.numbers.Pi'>",
  )
  inspect(
    core_expr_sstr(
      @symcore.func(@symcore.Expr::Boolean(true)).unwrap_or(@symcore.int(0)),
    ),
    content="<class 'sympy.logic.boolalg.BooleanTrue'>",
  )
  inspect(
    core_expr_sstr(
      @symcore.func(@symcore.Expr::Symbol("x")).unwrap_or(@symcore.int(0)),
    ),
    content="<class 'sympy.core.symbol.Symbol'>",
  )
}

///|
test "symcore source-driven kinds distinguish logical applications" {
  let x = @symcore.Expr::Symbol("x")
  inspect(
    @symcore.kind_name(
      @symcore.expr_kind(
        @symcore.function("And", [@symcore.Expr::Boolean(true), x]),
      ),
    ),
    content="BooleanKind",
  )
  inspect(
    @symcore.kind_name(@symcore.expr_kind(@symcore.function("sin", [x]))),
    content="UndefinedKind",
  )
  inspect(
    @symcore.kind_name(
      @symcore.expr_kind(@symcore.applied_undefined_function("f", [x])),
    ),
    content="UndefinedKind",
  )
}

///|
test "symcore parity func for atomic core nodes" {
  inspect(local_func_name(@symcore.int(2)), content="Integer")
  inspect(local_func_name(@symcore.rational_from_ints(1, 2)), content="Half")
  inspect(
    local_func_name(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)),
    content="Pi",
  )
  inspect(local_func_name(@symcore.Expr::Symbol("x")), content="Symbol")
  inspect(local_func_name(@symcore.dummy(name="x")), content="Dummy")
  inspect(local_func_name(@symcore.Expr::Wild("x", [], [])), content="Wild")
  inspect(local_func_name(@symcore.Expr::Boolean(true)), content="BooleanTrue")
}

///|
test "symcore source-driven S constructor semantics stay canonical" {
  let x = @symcore.Expr::Symbol("x")
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("S"), [
        @symcore.function("sin", [x]),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="sin(x)",
  )
  inspect(
    local_func_name(
      @symcore.apply(@symcore.Expr::FunctionHead("S"), []).unwrap_or(
        @symcore.int(0),
      ),
    ),
    content="S",
  )
  inspect(
    local_args_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("S"), []).unwrap_or(
        @symcore.int(0),
      ),
    ),
    content="()",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(@symcore.Expr::FunctionHead("S"), [
        x,
        @symcore.Expr::Symbol("y"),
      ]).unwrap_or(@symcore.int(0)),
    ),
    content="x",
  )
}

///|
test "symcore source-driven Integer and Rational constructor semantics" {
  inspect(
    core_expr_sstr(
      @symcore.function("Integer", [
        @symcore.Expr::Float(@symcore.Float::from_double(0.9)),
      ]),
    ),
    content="0",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Integer", [
        @symcore.Expr::Float(@symcore.Float::from_double(10.5)),
      ]),
    ),
    content="10",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Integer", [
        @symcore.Expr::Float(@symcore.Float::from_double(-3.8)),
      ]),
    ),
    content="-3",
  )
  inspect(
    core_expr_sstr(@symcore.function("Integer", [@symcore.Expr::Boolean(true)])),
    content="1",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Integer", [@symcore.Expr::Boolean(false)]),
    ),
    content="0",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Rational", [
        @symcore.Expr::Float(@symcore.Float::from_double(1.0)),
        @symcore.int(3),
      ]),
    ),
    content="1/3",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Rational", [
        @symcore.int(1),
        @symcore.Expr::Float(@symcore.Float::from_double(3.0)),
      ]),
    ),
    content="1/3",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Rational", [
        @symcore.rational_from_ints(1, 2),
        @symcore.rational_from_ints(1, 3),
      ]),
    ),
    content="3/2",
  )
  inspect(
    core_expr_sstr(
      @symcore.function("Rational", [
        @symcore.int(1),
        @symcore.rational_from_ints(1, 3),
      ]),
    ),
    content="3",
  )
}

///|
test "symcore parity dict and tuple containers" {
  inspect(
    core_expr_sstr(
      @symcore.Expr::Tuple([@symcore.Expr::Symbol("x"), @symcore.int(2)]),
    ),
    content="(x, 2)",
  )
  inspect(
    core_expr_sstr(
      @symcore.Expr::Dict([
        (@symcore.Expr::Symbol("x"), @symcore.Expr::Symbol("y")),
        (@symcore.int(1), @symcore.Expr::Symbol("z")),
      ]),
    ),
    content="{1: z, x: y}",
  )
}

///|
test "symcore parity add combines repeated identical terms" {
  let x = @symcore.Expr::Symbol("x")
  inspect(core_expr_sstr(@symcore.add([x, x])), content="2*x")
}

///|
test "symcore parity sympify typed inputs" {
  inspect(
    core_expr_sstr(
      @symcore.sympify_tuple([
        @symcore.SympifyInput::FromInt(1),
        @symcore.SympifyInput::SymbolName("x"),
      ]),
    ),
    content="(1, x)",
  )
  inspect(
    core_expr_sstr(
      @symcore.sympify_dict([
        (
          @symcore.SympifyInput::SymbolName("x"),
          @symcore.SympifyInput::FromInt(2),
        ),
      ]),
    ),
    content="{x: 2}",
  )
  inspect(
    core_expr_sstr(
      @symcore.sympify(
        @symcore.SympifyInput::Application(
          @symcore.SympifyInput::FunctionHeadName("sin"),
          [@symcore.SympifyInput::SymbolName("x")],
        ),
      ),
    ),
    content="sin(x)",
  )
  inspect(
    core_expr_sstr(
      @symcore.sympify(
        @symcore.SympifyInput::Application(
          @symcore.SympifyInput::UndefinedFunctionName("f"),
          [
            @symcore.SympifyInput::DummyName("x"),
            @symcore.SympifyInput::WildName("y"),
          ],
        ),
      ),
    ),
    content="f(_x, y_)",
  )
  inspect(
    core_expr_sstr(
      @symcore.sympify(
        @symcore.SympifyInput::FromExpr(
          @symcore.Expr::Function("sin", [@symcore.Expr::Symbol("x")]),
        ),
      ),
    ),
    content="sin(x)",
  )
  inspect(
    core_expr_sstr(
      @symcore.sympify(
        @symcore.SympifyInput::FromExpr(
          @symcore.Expr::Function("Derivative", [
            @symcore.Expr::Symbol("x"),
            @symcore.Expr::Symbol("x"),
          ]),
        ),
      ),
    ),
    content="Derivative(x, x)",
  )
}

///|
test "symcore parity free_symbols and atoms helpers" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let expr = @symcore.Expr::Tuple([
    @symcore.add([
      @symcore.function("f", [x]),
      @symcore.mul([@symcore.int(2), x]),
    ]),
    @symcore.Expr::Tuple([y, @symcore.int(1)]),
  ])
  inspect(core_free_symbols_sstr(expr), content="('x', 'y')")
  inspect(core_atoms_sstr(expr), content="('1', '2', 'x', 'y')")
  let subs_multi = @symcore.subs_expr(
    @symcore.add([x, y]),
    @symcore.Expr::Tuple([x, y]),
    @symcore.Expr::Tuple([y, z]),
  )
  inspect(core_free_symbols_sstr(subs_multi), content="('y', 'z')")
}

///|
test "symcore parity has sees callable heads in applications" {
  let x = @symcore.Expr::Symbol("x")
  let dfx = @symcore.derivative(
    @symcore.applied_undefined_function("f", [x]),
    x,
  )
  inspect(
    @symcore.has(
      @symcore.function("sin", [x]),
      @symcore.Expr::FunctionHead("sin"),
    ),
    content=core_has_bool(
      @symcore.function("sin", [x]),
      @symcore.Expr::FunctionHead("sin"),
    ).to_string(),
  )
  inspect(
    @symcore.has(
      @symcore.applied_undefined_function("f", [x]),
      @symcore.Expr::UndefinedFunction("f"),
    ),
    content=core_has_bool(
      @symcore.applied_undefined_function("f", [x]),
      @symcore.Expr::UndefinedFunction("f"),
    ).to_string(),
  )
  inspect(
    @symcore.has(dfx, @symcore.Expr::FunctionHead("Derivative")).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.pow(x, @symcore.int(2)),
      @symcore.Expr::FunctionHead("Symbol"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.pow(x, @symcore.int(2)),
      @symcore.Expr::FunctionHead("Wild"),
    ).to_string(),
    content="false",
  )
  inspect(
    @symcore.has(
      @symcore.mul([@symcore.int(2), @symcore.Expr::Wild("p", [], [])]),
      @symcore.Expr::FunctionHead("Wild"),
    ).to_string(),
    content="true",
  )
}

///|
test "symcore parity has follows source-driven class-head and subset semantics" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")

  inspect(
    @symcore.has(@symcore.int(1), @symcore.Expr::FunctionHead("Integer")).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(@symcore.int(1), @symcore.Expr::FunctionHead("Rational")).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.rational_from_ints(1, 2),
      @symcore.Expr::FunctionHead("Rational"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.rational_from_ints(1, 2),
      @symcore.Expr::FunctionHead("Integer"),
    ).to_string(),
    content="false",
  )
  inspect(
    @symcore.has(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      @symcore.Expr::FunctionHead("NumberSymbol"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.Expr::Dummy("d", 1),
      @symcore.Expr::FunctionHead("Symbol"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.Expr::Wild("p", [], []),
      @symcore.Expr::FunctionHead("Symbol"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(@symcore.int(1), @symcore.Expr::FunctionHead("Atom")).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(@symcore.int(1), @symcore.Expr::FunctionHead("Expr")).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(x, @symcore.Expr::FunctionHead("AtomicExpr")).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.function("sin", [x]),
      @symcore.Expr::FunctionHead("Application"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.function("sin", [x]),
      @symcore.Expr::FunctionHead("Function"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(@symcore.add([x, y]), @symcore.Expr::FunctionHead("Expr")).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.mod_expr(x, @symcore.int(2)),
      @symcore.Expr::FunctionHead("Function"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.subs_expr(x, x, @symcore.int(0)),
      @symcore.Expr::FunctionHead("Expr"),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(
      @symcore.Expr::Tuple([@symcore.Expr::Boolean(true)]),
      @symcore.Expr::FunctionHead("Expr"),
    ).to_string(),
    content="false",
  )
  inspect(
    @symcore.has(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.Expr::Boolean(true),
        @symcore.Expr::Boolean(false),
      ),
      @symcore.Expr::FunctionHead("Expr"),
    ).to_string(),
    content="false",
  )
  inspect(
    @symcore.has(
      @symcore.add([x, y, @symcore.int(1)]),
      @symcore.add([x, @symcore.int(1)]),
    ).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(@symcore.add([x, y]), @symcore.add([x, z])).to_string(),
    content="false",
  )
  inspect(
    @symcore.has(@symcore.mul([x, y, z]), @symcore.mul([x, y])).to_string(),
    content="true",
  )
  inspect(
    @symcore.has(@symcore.mul([x, y]), @symcore.mul([x, z])).to_string(),
    content="false",
  )
}

///|
test "symcore parity xreplace exact structural replacement" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let fx = @symcore.function("f", [x])
  let expr = @symcore.add([fx, x, y])
  inspect(
    core_xreplace_sstr(expr, fx, @symcore.Expr::Symbol("z")),
    content="x + y + z",
  )
  inspect(core_xreplace_sstr(expr, x, @symcore.int(2)), content="y + f(2) + 2")
}

///|
test "symcore legacy compatibility normalizes against canonical needles and parameters" {
  let x = @symcore.Expr::Symbol("x")
  let legacy_sinx = @symcore.Expr::Function("sin", [x])
  inspect(
    @symcore.has(@symcore.function("sin", [x]), legacy_sinx).to_string(),
    content="true",
  )
  inspect(
    core_expr_sstr(
      @symcore.xreplace(@symcore.function("sin", [x]), [(legacy_sinx, x)]),
    ),
    content="x",
  )
  inspect(
    core_expr_sstr(
      @symcore.with_evaluate(false, fn() {
        @symcore.normalize_legacy_expr(@symcore.Expr::Function("Eq", [x, x]))
      }),
    ),
    content="True",
  )
  inspect(
    core_expr_sstr(
      @symcore.with_exp_is_pow(true, fn() {
        @symcore.normalize_legacy_expr(@symcore.Expr::Function("exp", [x]))
      }),
    ),
    content="exp(x)",
  )
}

///|
test "symcore parity replace rewrites named applications preorder" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.add([
    @symcore.function("sin", [x]),
    @symcore.function("sin", [y]),
  ])
  inspect(
    core_expr_sstr(
      @symcore.replace(
        expr,
        fn(node : @symcore.Expr) -> Bool {
          @symcore.application_has_name(node, "sin", arity=1)
        },
        fn(node : @symcore.Expr) -> @symcore.Expr {
          match @symcore.application_args(node) {
            Some([arg]) => @symcore.function("cos", [arg])
            _ => node
          }
        },
      ),
    ),
    content=core_replace_sin_with_cos_sstr(expr),
  )
}

///|
test "symcore parity Mod is a first-class core node" {
  inspect(
    core_expr_sstr(
      @symcore.mod_expr(
        @symcore.add([@symcore.Expr::Symbol("x"), @symcore.int(1)]),
        @symcore.int(3),
      ),
    ),
    content="Mod(x + 1, 3)",
  )
}

///|
test "symcore parity subst respects lambda and Subs binders" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let w = @symcore.Expr::Symbol("w")
  inspect(
    core_subst_symbol_sstr(
      @symcore.lambda_expr(x, @symcore.add([x, y])),
      "y",
      @symcore.int(3),
    ),
    content="Lambda(x, x + 3)",
  )
  inspect(
    core_subst_symbol_sstr(
      @symcore.lambda_expr(x, @symcore.add([x, y])),
      "x",
      z,
    ),
    content="Lambda(z, y + z)",
  )
  inspect(
    core_subst_symbol_sstr(
      @symcore.lambda_expr(x, @symcore.add([x, y])),
      "x",
      y,
    ),
    content="Lambda(y, 2*y)",
  )
  inspect(
    core_subst_symbol_sstr(
      @symcore.subs_expr(@symcore.add([x, y]), x, z),
      "x",
      @symcore.int(2),
    ),
    content="Subs(x + y, x, z)",
  )
  inspect(
    core_subst_symbol_sstr(
      @symcore.subs_expr(@symcore.add([x, y]), x, z),
      "z",
      @symcore.int(4),
    ),
    content="Subs(x + y, x, 4)",
  )
  let multi = @symcore.subs_expr(
    @symcore.add([x, y]),
    @symcore.Expr::Tuple([x, y]),
    @symcore.Expr::Tuple([y, z]),
  )
  inspect(
    core_subst_symbol_sstr(multi, "x", w),
    content="Subs(w + y, (w, y), (y, z))",
  )
  inspect(
    core_subst_symbol_sstr(multi, "y", w),
    content="Subs(w + x, (x, w), (w, z))",
  )
  inspect(
    core_expr_sstr(
      @symcore.subs_expr(
        @symcore.add([x, y]),
        @symcore.Expr::Tuple([]),
        @symcore.Expr::Tuple([]),
      ),
    ),
    content="x + y",
  )
  inspect(
    core_expr_sstr(
      @symcore.subs_expr(
        @symcore.subs_expr(x, x, @symcore.int(0)),
        y,
        @symcore.int(1),
      ),
    ),
    content="Subs(x, (x, y), (0, 1))",
  )
  inspect(
    @symcore.subs_signature_error(
      @symcore.Expr::Tuple([x, x]),
      @symcore.Expr::Tuple([@symcore.int(0), @symcore.int(1)]),
    ).unwrap_or(""),
    content="The following expressions appear more than once: x",
  )
}

///|
test "symcore parity subst respects derivative binding and capture" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let fx = @symcore.function("f", [x])
  inspect(
    core_subst_symbol_sstr(@symcore.derivative(fx, x), "x", z),
    content="Derivative(f(z), z)",
  )
  inspect(
    core_subst_symbol_sstr(
      @symcore.derivative(@symcore.add([fx, y]), x),
      "x",
      @symcore.int(2),
    ),
    content="Subs(Derivative(y + f(x), x), x, 2)",
  )
  inspect(
    core_subst_symbol_sstr(
      @symcore.derivative(@symcore.add([fx, y]), x),
      "y",
      x,
    ),
    content="Subs(Derivative(y + f(x), x), y, x)",
  )
}

///|
test "symcore parity Subs equality is canonical in bound variables" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  inspect(
    (@symcore.subs_expr(x, x, @symcore.int(0)) ==
    @symcore.subs_expr(y, y, @symcore.int(0))).to_string(),
    content="true",
  )
  inspect(
    @symcore.compare_expr(
      @symcore.subs_expr(
        @symcore.function("f", [x, y]),
        @symcore.Expr::Tuple([x, y]),
        @symcore.Expr::Tuple([@symcore.int(0), @symcore.int(1)]),
      ),
      @symcore.subs_expr(
        @symcore.function("f", [x, y]),
        @symcore.Expr::Tuple([y, x]),
        @symcore.Expr::Tuple([@symcore.int(1), @symcore.int(0)]),
      ),
    ),
    content="0",
  )
  inspect(
    (@symcore.subs_expr(x, y, @symcore.int(0)) ==
    @symcore.subs_expr(x, z, @symcore.int(0))).to_string(),
    content="false",
  )
}

///|
test "symcore parity default sort order around functions symbols and mod" {
  let x = @symcore.Expr::Symbol("x")
  inspect(
    core_sorted_sstr([
      x,
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      @symcore.applied_undefined_function("f", [x]),
      @symcore.Expr::UndefinedFunction("f"),
      @symcore.dummy(name="x"),
      @symcore.mod_expr(x, @symcore.int(2)),
    ]),
    content="('f', '_x', 'pi', 'x', 'f(x)', 'Mod(x, 2)')",
  )
}

///|
test "symcore parity evalf for mod relationals and undefined applications" {
  let x = @symcore.Expr::Symbol("x")
  inspect(
    core_evalf_sstr(
      @symcore.mod_expr(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        @symcore.int(2),
      ),
    ),
    content="1.14159265358979",
  )
  inspect(
    core_evalf_sstr(
      @symcore.Expr::Relational(
        @symcore.RelOp::Eq,
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        x,
      ),
    ),
    content="Eq(3.14159265358979, x)",
  )
  inspect(
    core_evalf_sstr(
      @symcore.applied_undefined_function("f", [
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      ]),
    ),
    content="f(pi)",
  )
}

///|
test "symcore parity numeric singleton predicates" {
  assert_true(
    @symcore.is_number_symbol(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
    ),
  )
  assert_true(
    @symcore.is_number_symbol(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
    ),
  )
  assert_true(
    @symcore.is_infinite(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
    ),
  )
  assert_true(
    @symcore.is_infinite(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity),
    ),
  )
  assert_true(
    @symcore.is_infinite(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ComplexInfinity),
    ),
  )
  assert_false(
    @symcore.is_infinite(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
    ),
  )
  assert_true(
    @symcore.is_nan(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)),
  )
  assert_false(
    @symcore.is_nan(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)),
  )
  assert_true(@symcore.is_zero(@symcore.int(0)))
  assert_true(@symcore.is_one(@symcore.int(1)))
  assert_true(
    @symcore.is_finite_number_atom(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
    ),
  )
  assert_false(
    @symcore.is_finite_number_atom(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
    ),
  )
  assert_false(
    @symcore.is_finite_number_atom(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
    ),
  )
  assert_true(
    core_attr_bool(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
      "is_infinite",
    ),
  )
  assert_true(
    core_attr_bool(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
      "is_nan",
    ),
  )
  assert_false(
    core_attr_bool(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      "is_infinite",
    ),
  )
  assert_true(core_attr_bool(@symcore.int(0), "is_zero"))
  assert_true(core_attr_bool(@symcore.int(1), "is_one"))
}

///|
test "symcore parity free_symbols for wild undefined applications and dict" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  inspect(
    core_free_symbols_sstr(@symcore.Expr::UndefinedFunction("f")),
    content="()",
  )
  inspect(
    core_free_symbols_sstr(@symcore.applied_undefined_function("f", [x])),
    content="('x',)",
  )
  inspect(
    core_free_symbols_sstr(@symcore.Expr::Wild("w", [], [])),
    content="('w_',)",
  )
  inspect(
    core_free_symbols_sstr(@symcore.Expr::Dict([(x, y), (@symcore.int(1), z)])),
    content="('x', 'y', 'z')",
  )
}

///|
test "symcore parity derivative free_symbols are not bound" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    core_free_symbols_sstr(
      @symcore.derivative(
        @symcore.add([@symcore.function("sin", [x]), y]),
        x,
        order=y,
      ),
    ),
    content="('x', 'y')",
  )
}

///|
test "symcore parity free_symbols through apply lambda and Subs" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  inspect(
    core_free_symbols_sstr(
      @symcore.applied_undefined_function("f", [@symcore.add([x, y])]),
    ),
    content="('x', 'y')",
  )
  inspect(
    core_free_symbols_sstr(
      @symcore.lambda_expr(
        x,
        @symcore.add([@symcore.applied_undefined_function("f", [x]), y]),
      ),
    ),
    content="('y',)",
  )
  inspect(
    core_free_symbols_sstr(@symcore.subs_expr(@symcore.add([x, y]), x, z)),
    content="('y', 'z')",
  )
  inspect(
    core_free_symbols_sstr(
      @symcore.lambda_expr(@symcore.Expr::Tuple([]), @symcore.int(42)),
    ),
    content="()",
  )
  inspect(
    core_free_symbols_sstr(
      @symcore.lambda_expr(@symcore.Expr::Tuple([]), @symcore.mul([x, y])),
    ),
    content="('x', 'y')",
  )
  let subs_structural = @symcore.subs_expr(x, x, @symcore.int(0))
  inspect(@symcore.has(subs_structural, x).to_string(), content="true")
  inspect(core_free_symbols_sstr(subs_structural), content="()")
  let subs_env : Map[String, @symcore.Expr] = {}
  subs_env.set("x", y)
  inspect(
    @symcore.has(
      @symcore.subst(@symcore.subs_expr(x, x, @symcore.int(1)), subs_env),
      y,
    ).to_string(),
    content="true",
  )
}

///|
test "symcore parity xreplace through apply and binders" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  inspect(
    core_xreplace_sstr(@symcore.function("sin", [x]), x, y),
    content="sin(y)",
  )
  inspect(
    core_xreplace_sstr(@symcore.lambda_expr(x, @symcore.add([x, y])), x, z),
    content="Lambda(z, y + z)",
  )
  inspect(
    core_xreplace_sstr(@symcore.lambda_expr(x, @symcore.add([x, y])), y, z),
    content="Lambda(x, x + z)",
  )
  inspect(
    core_xreplace_sstr(@symcore.subs_expr(@symcore.add([x, y]), x, z), z, y),
    content="Subs(x + y, x, y)",
  )
}

///|
test "symcore parity preorder and postorder traversals" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([
    @symcore.derivative(@symcore.function("f", [x]), x),
    @symcore.mod_expr(x, @symcore.int(2)),
  ])
  inspect(
    core_preorder_sstr(expr),
    content="('Mod(x, 2) + Derivative(f(x), x)', 'Derivative(f(x), x)', 'f(x)', 'x', '(x, 1)', 'x', '1', 'Mod(x, 2)', 'x', '2')",
  )
  inspect(
    core_postorder_sstr(expr),
    content="('x', 'f(x)', 'x', '1', '(x, 1)', 'Derivative(f(x), x)', 'x', '2', 'Mod(x, 2)', 'Mod(x, 2) + Derivative(f(x), x)')",
  )
}

///|
test "symcore parity traversal wraps lambda and Subs binders canonically" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.Expr::Tuple([
    @symcore.subs_expr(@symcore.add([x, y]), x, @symcore.int(1)),
    @symcore.lambda_expr(x, @symcore.add([x, y])),
  ])
  inspect(local_preorder_sstr(expr), content=core_preorder_sstr(expr))
  inspect(local_postorder_sstr(expr), content=core_postorder_sstr(expr))
}

///|
test "symcore parity evalf on Subs and Lambda" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    core_evalf_sstr(
      @symcore.subs_expr(
        @symcore.add([
          y,
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ]),
        y,
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      ),
    ),
    content="6.28318530717959",
  )
  inspect(
    core_evalf_sstr(
      @symcore.lambda_expr(
        x,
        @symcore.add([
          x,
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ]),
      ),
    ),
    content="Lambda(x, x + 3.14159265358979)",
  )
}

///|
test "symcore parity multi-Subs args and derivative xreplace" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  inspect(
    local_args_sstr(
      @symcore.subs_expr(
        @symcore.add([x, y]),
        @symcore.Expr::Tuple([x, y]),
        @symcore.Expr::Tuple([y, z]),
      ),
    ),
    content="('x + y', '(x, y)', '(y, z)')",
  )
  inspect(
    core_xreplace_sstr(
      @symcore.derivative(@symcore.add([@symcore.function("sin", [x]), y]), x),
      y,
      z,
    ),
    content="Derivative(z + sin(x), x)",
  )
  inspect(
    core_xreplace_sstr(
      @symcore.derivative(@symcore.add([@symcore.function("sin", [x]), y]), x),
      x,
      z,
    ),
    content="Derivative(y + sin(z), z)",
  )
}

///|
test "symcore parity default sort order across binders and containers" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    local_sorted_sstr([
      @symcore.Expr::Tuple([x, y]),
      @symcore.Expr::Dict([(x, y)]),
      @symcore.Expr::Relational(@symcore.RelOp::Eq, x, y),
      @symcore.lambda_expr(x, @symcore.add([x, y])),
      @symcore.subs_expr(@symcore.add([x, y]), x, @symcore.int(1)),
      @symcore.derivative(@symcore.function("sin", [x]), x),
      @symcore.function("sin", [x]),
      @symcore.applied_undefined_function("f", [x]),
      @symcore.Expr::UndefinedFunction("f"),
      @symcore.Expr::FunctionHead("sin"),
    ]),
    content="('sin', 'f', 'f(x)', 'sin(x)', 'Derivative(sin(x), x)', '{x: y}', 'Eq(x, y)', 'Lambda(x, x + y)', 'Subs(x + y, x, 1)', '(x, y)')",
  )
}

///|
test "symcore parity subst rewrites callable heads but not non-callables" {
  let x = @symcore.Expr::Symbol("x")
  inspect(
    core_expr_sstr(
      @symcore.subst(@symcore.function("sin", [x]), {
        "sin": @symcore.Expr::FunctionHead("cos"),
      }),
    ),
    content=core_subst_expr_sstr(
      @symcore.function("sin", [x]),
      @symcore.Expr::FunctionHead("sin"),
      @symcore.Expr::FunctionHead("cos"),
    ),
  )
  inspect(
    core_expr_sstr(
      @symcore.subst(@symcore.applied_undefined_function("f", [x]), {
        "f": @symcore.Expr::UndefinedFunction("g"),
      }),
    ),
    content=core_subst_expr_sstr(
      @symcore.applied_undefined_function("f", [x]),
      @symcore.Expr::UndefinedFunction("f"),
      @symcore.Expr::UndefinedFunction("g"),
    ),
  )
  inspect(
    core_expr_sstr(
      @symcore.subst(@symcore.applied_undefined_function("f", [x]), {
        "f": @symcore.Expr::Symbol("z"),
      }),
    ),
    content=core_subst_expr_sstr(
      @symcore.applied_undefined_function("f", [x]),
      @symcore.Expr::UndefinedFunction("f"),
      @symcore.Expr::Symbol("z"),
    ),
  )
}

///|
test "symcore parity subst beta-reduces callable heads to lambda" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    core_expr_sstr(
      @symcore.subst(@symcore.function("sin", [x]), {
        "sin": @symcore.lambda_expr(x, @symcore.add([x, @symcore.int(1)])),
      }),
    ),
    content=core_subst_expr_sstr(
      @symcore.function("sin", [x]),
      @symcore.Expr::FunctionHead("sin"),
      @symcore.lambda_expr(x, @symcore.add([x, @symcore.int(1)])),
    ),
  )
  inspect(
    core_expr_sstr(
      @symcore.subst(@symcore.applied_undefined_function("f", [x, y]), {
        "f": @symcore.lambda_expr(
          @symcore.Expr::Tuple([x, y]),
          @symcore.add([x, y]),
        ),
      }),
    ),
    content=core_subst_expr_sstr(
      @symcore.applied_undefined_function("f", [x, y]),
      @symcore.Expr::UndefinedFunction("f"),
      @symcore.lambda_expr(@symcore.Expr::Tuple([x, y]), @symcore.add([x, y])),
    ),
  )
}

///|
test "symcore parity lambda identity and application stay canonical" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let id = @symcore.lambda_expr(x, x)
  inspect(core_expr_sstr(id), content="Lambda(_x, _x)")
  inspect(
    core_expr_sstr(@symcore.lambda_expr(@symcore.Expr::Tuple([x]), x)),
    content="Lambda(_x, _x)",
  )
  inspect(core_func_sstr(id), content="IdentityFunction")
  inspect(core_args_sstr(id), content="()")
  inspect(@symcore.has(id, x), content="false")
  inspect(core_xreplace_sstr(id, x, y), content="Lambda(_x, _x)")
  inspect(
    core_expr_sstr(@symcore.subst(id, { "x": y })),
    content="Lambda(_x, _x)",
  )
  inspect(
    core_expr_sstr(@symcore.apply(id, [y]).unwrap_or(@symcore.int(0))),
    content="y",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(
        @symcore.lambda_expr(@symcore.Expr::Tuple([x, y]), @symcore.add([x, y])),
        [@symcore.int(1), @symcore.int(2)],
      ).unwrap_or(@symcore.int(0)),
    ),
    content="3",
  )
  inspect(
    core_expr_sstr(
      @symcore.apply(
        @symcore.lambda_expr(
          @symcore.Expr::Tuple([@symcore.Expr::Tuple([x, y]), z]),
          @symcore.add([x, y, z]),
        ),
        [
          @symcore.Expr::Tuple([@symcore.int(1), @symcore.int(2)]),
          @symcore.int(3),
        ],
      ).unwrap_or(@symcore.int(0)),
    ),
    content="6",
  )
  let invalid = @symcore.lambda_expr(
    @symcore.Expr::WildFunction("f", []),
    @symcore.add([x, @symcore.int(1)]),
  )
  inspect(@symcore.application_name(invalid).unwrap_or(""), content="Lambda")
  json_inspect(
    @symcore.application_args(invalid).unwrap_or([]).map(@symcore.expr_display),
    content=["f_", "(x + 1)"],
  )
}

///|
test "symcore parity tuple binders rename safely under substitution" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let w = @symcore.Expr::Symbol("w")
  inspect(
    core_expr_sstr(
      @symcore.subst(
        @symcore.lambda_expr(@symcore.Expr::Tuple([x, y]), @symcore.add([x, y])),
        { "y": z },
      ),
    ),
    content=core_subst_expr_sstr(
      @symcore.lambda_expr(@symcore.Expr::Tuple([x, y]), @symcore.add([x, y])),
      y,
      z,
    ),
  )
  inspect(
    core_expr_sstr(
      @symcore.subst(
        @symcore.lambda_expr(@symcore.Expr::Tuple([x, y]), @symcore.add([x, y])),
        { "x": z },
      ),
    ),
    content=core_subst_expr_sstr(
      @symcore.lambda_expr(@symcore.Expr::Tuple([x, y]), @symcore.add([x, y])),
      x,
      z,
    ),
  )
  inspect(
    core_expr_sstr(
      @symcore.subst(
        @symcore.subs_expr(
          @symcore.add([x, y]),
          @symcore.Expr::Tuple([x, y]),
          @symcore.Expr::Tuple([y, z]),
        ),
        { "y": w },
      ),
    ),
    content=core_subst_expr_sstr(
      @symcore.subs_expr(
        @symcore.add([x, y]),
        @symcore.Expr::Tuple([x, y]),
        @symcore.Expr::Tuple([y, z]),
      ),
      y,
      w,
    ),
  )
  inspect(
    core_expr_sstr(
      @symcore.subst(
        @symcore.subs_expr(
          @symcore.add([x, y]),
          @symcore.Expr::Tuple([x, y]),
          @symcore.Expr::Tuple([y, z]),
        ),
        { "x": w },
      ),
    ),
    content=core_subst_expr_sstr(
      @symcore.subs_expr(
        @symcore.add([x, y]),
        @symcore.Expr::Tuple([x, y]),
        @symcore.Expr::Tuple([y, z]),
      ),
      x,
      w,
    ),
  )
}

///|
test "symcore parity multi-variable derivative substitution stays canonical" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let expr = @symcore.Expr::Derivative(
    @symcore.add([@symcore.function("sin", [x]), y]),
    [x, @symcore.int(1), y, @symcore.int(1)],
  )
  inspect(
    core_expr_sstr(@symcore.subst(expr, { "y": z })),
    content=core_subst_expr_sstr(expr, y, z),
  )
  inspect(
    core_expr_sstr(@symcore.subst(expr, { "x": z })),
    content=core_subst_expr_sstr(expr, x, z),
  )
}

///|
test "symcore parity parameters control exp and distribution" {
  let x = @symcore.Expr::Symbol("x")
  inspect(
    core_expr_sstr(
      @symcore.with_exp_is_pow(true, fn() { @symcore.function("exp", [x]) }),
    ),
    content=core_parameters_sstr("sympy.exp(x)", exp_is_pow=true),
  )
  inspect(
    core_expr_sstr(
      @symcore.mul([@symcore.int(2), @symcore.add([x, @symcore.int(1)])]),
    ),
    content=core_parameters_sstr("sympy.Integer(2)*(x + 1)", distribute=true),
  )
  inspect(
    core_expr_sstr(
      @symcore.with_distribute(false, fn() {
        @symcore.mul([@symcore.int(2), @symcore.add([x, @symcore.int(1)])])
      }),
    ),
    content=core_parameters_sstr("sympy.Integer(2)*(x + 1)", distribute=false),
  )
}
