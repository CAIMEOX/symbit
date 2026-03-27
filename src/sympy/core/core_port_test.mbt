///|
test "symcore parity plain symbol names stay plain symbols" {
  inspect(core_expr_srepr(@symcore.Expr::Symbol("pi")), content="Symbol('pi')")
  inspect(core_expr_srepr(@symcore.Expr::Symbol("True")), content="Symbol('True')")
  inspect(core_expr_srepr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)), content="pi")
  inspect(core_expr_srepr(@symcore.Expr::Boolean(true)), content="True")
}

test "symcore parity number symbols render as SymPy core singletons" {
  inspect(core_expr_sstr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)), content="pi")
  inspect(core_expr_sstr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)), content="I")
  inspect(core_expr_sstr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)), content="oo")
  inspect(core_expr_sstr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ComplexInfinity)), content="zoo")
  inspect(core_expr_sstr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)), content="nan")
}

///|
test "symcore parity dummy wild and undefined-function heads" {
  inspect(core_expr_sstr(@symcore.dummy(name="x")), content="_x")
  inspect(core_expr_sstr(@symcore.Expr::Wild("x")), content="x_")
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
test "symcore parity formal application helpers" {
  let x = @symcore.Expr::Symbol("x")
  match @symcore.apply(@symcore.Expr::FunctionHead("sin"), [x]) {
    Some(expr) => {
      inspect(core_expr_sstr(expr), content="sin(x)")
      inspect(core_expr_sstr(@symcore.func(expr).unwrap_or(@symcore.int(0))), content="sin")
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
}

///|
test "symcore parity dict and tuple containers" {
  inspect(
    core_expr_sstr(@symcore.Expr::Tuple([@symcore.Expr::Symbol("x"), @symcore.int(2)])),
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
        (@symcore.SympifyInput::SymbolName("x"), @symcore.SympifyInput::FromInt(2)),
      ]),
    ),
    content="{x: 2}",
  )
}

///|
test "symcore parity free_symbols and atoms helpers" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.add([
    @symcore.function("f", [x]),
    @symcore.mul([@symcore.int(2), x]),
    @symcore.Expr::Tuple([y, @symcore.int(1)]),
  ])
  inspect(core_free_symbols_sstr(expr), content="('x', 'y')")
  inspect(core_atoms_sstr(expr), content="('1', '2', 'x', 'y')")
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
    core_evalf_sstr(@symcore.mod_expr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2))),
    content="1.14159265358979",
  )
  inspect(
    core_evalf_sstr(@symcore.Expr::Relational(@symcore.RelOp::Eq, @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), x)),
    content="Eq(3.14159265358979, x)",
  )
  inspect(
    core_evalf_sstr(@symcore.applied_undefined_function("f", [@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)])),
    content="f(pi)",
  )
}

///|
test "symcore parity numeric singleton predicates" {
  assert_true(@symcore.is_number_symbol(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)))
  assert_true(@symcore.is_number_symbol(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)))
  assert_true(@symcore.is_infinite(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)))
  assert_true(@symcore.is_infinite(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity)))
  assert_true(@symcore.is_infinite(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ComplexInfinity)))
  assert_false(@symcore.is_infinite(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)))
  assert_true(@symcore.is_nan(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)))
  assert_false(@symcore.is_nan(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)))
  assert_true(@symcore.is_zero(@symcore.int(0)))
  assert_true(@symcore.is_one(@symcore.int(1)))
  assert_true(@symcore.is_finite_number_atom(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)))
  assert_false(@symcore.is_finite_number_atom(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)))
  assert_false(@symcore.is_finite_number_atom(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)))
  assert_true(core_attr_bool(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity), "is_infinite"))
  assert_true(core_attr_bool(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN), "is_nan"))
  assert_false(core_attr_bool(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), "is_infinite"))
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
  inspect(core_free_symbols_sstr(@symcore.Expr::Wild("w")), content="('w_',)")
  inspect(
    core_free_symbols_sstr(@symcore.Expr::Dict([(x, y), (@symcore.int(1), z)])),
    content="('x', 'y', 'z')",
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
