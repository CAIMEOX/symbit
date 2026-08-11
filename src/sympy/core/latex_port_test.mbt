///|
fn assert_latex_parity(expr : @symcore.Expr) -> Unit raise {
  assert_eq(@symprint.latex(expr), core_expr_latex(expr))
}

///|
fn assert_latex_parity_kwargs(
  expr : @symcore.Expr,
  actual : String,
  kwargs? : Map[String, @sympy.OracleArg] = {},
) -> Unit raise {
  assert_eq(actual, core_expr_latex_kwargs(expr, kwargs~))
}

///|
test "symprint latex parity arithmetic core nodes" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let three_fourths = @symcore.rational_from_ints(3, 4) catch {
    _ => fail("three_fourths")
  }
  let fxy = @symcore.applied_undefined_function("f", [x, y])
  assert_latex_parity(@symcore.add([x, @symcore.int(1)]))
  assert_latex_parity(@symcore.raw_mul([half, x + y]))
  assert_latex_parity(@symcore.pow(x + y, three_fourths))
  assert_latex_parity(@symcore.pow(x + y, @symcore.int(-1)))
  assert_latex_parity(@symcore.function("sqrt", [x + y]))
  assert_latex_parity(@symcore.function("sin", [x]) ^ @symcore.int(2))
  assert_latex_parity(@symcore.mod_expr(x + @symcore.int(1), @symcore.int(3)))
  assert_latex_parity(@symcore.derivative_constructor_expr(fxy, [x, y]))
}

///|
test "symprint latex parity symbol wrappers and structural forms" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  assert_latex_parity(Symbol("alpha_1"))
  assert_latex_parity(Symbol("alphahat"))
  assert_latex_parity(@symcore.dummy(name="x"))
  assert_latex_parity(Wild("x", [], []))
  assert_latex_parity(Relational(Ne, x, @symcore.int(2)))
  assert_latex_parity(Tuple([x, @symcore.int(2)]))
  assert_latex_parity(Subs(x + y, x, @symcore.int(1)))
  assert_latex_parity(@symcore.lambda_expr(Tuple([x]), x + @symcore.int(1)))
}

///|
test "symprint latex parity constants and generic function names" {
  let x = @symcore.Expr::Symbol("x")
  assert_latex_parity(NumberSymbol(Pi))
  assert_latex_parity(NumberSymbol(EulerGamma))
  assert_latex_parity(NumberSymbol(Infinity))
  assert_latex_parity(NumberSymbol(ComplexInfinity))
  assert_latex_parity(@symcore.applied_undefined_function("Li", [x]))
}

///|
test "symprint latex parity printer settings" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let one_third = @symcore.rational_from_ints(1, 3) catch {
    _ => fail("one_third")
  }
  let three_fourths = @symcore.rational_from_ints(3, 4) catch {
    _ => fail("three_fourths")
  }
  let fx = @symcore.applied_undefined_function("f", [x])
  assert_latex_parity_kwargs(
    @symcore.raw_mul([half, x]),
    @symprint.latex(@symcore.raw_mul([half, x]), fold_short_frac=Some(true)),
    kwargs={ "fold_short_frac": Bool(true) },
  )
  assert_latex_parity_kwargs(
    @symcore.pow(x + y, three_fourths),
    @symprint.latex(@symcore.pow(x + y, three_fourths), fold_frac_powers=true),
    kwargs={ "fold_frac_powers": Bool(true) },
  )
  assert_latex_parity_kwargs(
    @symcore.function("asin", [x]),
    @symprint.latex(@symcore.function("asin", [x]), inv_trig_style="full"),
    kwargs={ "inv_trig_style": Str("full") },
  )
  assert_latex_parity_kwargs(
    @symcore.function("asin", [@symcore.pow(x, @symcore.int(2))]),
    @symprint.latex(
      @symcore.function("asin", [@symcore.pow(x, @symcore.int(2))]),
      inv_trig_style="power",
      fold_func_brackets=true,
    ),
    kwargs={ "inv_trig_style": Str("power"), "fold_func_brackets": Bool(true) },
  )
  assert_latex_parity_kwargs(
    @symcore.function("log", [x]),
    @symprint.latex(@symcore.function("log", [x]), ln_notation=true),
    kwargs={ "ln_notation": Bool(true) },
  )
  assert_latex_parity_kwargs(
    @symcore.raw_mul([@symcore.int(2), x, y]),
    @symprint.latex(
      @symcore.raw_mul([@symcore.int(2), x, y]),
      mul_symbol=Some("times"),
    ),
    kwargs={ "mul_symbol": Str("times") },
  )
  assert_latex_parity_kwargs(
    NumberSymbol(ImaginaryUnit),
    @symprint.latex(NumberSymbol(ImaginaryUnit), imaginary_unit="j"),
    kwargs={ "imaginary_unit": Str("j") },
  )
  assert_latex_parity_kwargs(
    @symcore.derivative_constructor_expr(fx, [x]),
    @symprint.latex(
      @symcore.derivative_constructor_expr(fx, [x]),
      diff_operator="rd",
    ),
    kwargs={ "diff_operator": Str("rd") },
  )
  assert_latex_parity_kwargs(
    @symcore.pow(x, one_third),
    @symprint.latex(@symcore.pow(x, one_third), root_notation=false),
    kwargs={ "root_notation": Bool(false) },
  )
  assert_latex_parity_kwargs(
    @symcore.pow(Symbol("x^*"), @symcore.int(2)),
    @symprint.latex(
      @symcore.pow(Symbol("x^*"), @symcore.int(2)),
      parenthesize_super=false,
    ),
    kwargs={ "parenthesize_super": Bool(false) },
  )
}

///|
test "symprint latex parity integrals piecewise and transforms" {
  let x = @symcore.Expr::Symbol("x")
  let t = @symcore.Expr::Symbol("t")
  let k = @symcore.Expr::Symbol("k")
  let ft = @symcore.applied_undefined_function("f", [t])
  let fk = @symcore.applied_undefined_function("f", [k])
  assert_latex_parity(@symcore.function("Integral", [x, Tuple([x])]))
  assert_latex_parity(
    @symcore.function("Integral", [
      x,
      Tuple([x, @symcore.int(0), @symcore.int(1)]),
    ]),
  )
  assert_latex_parity(
    @symcore.function("Sum", [x, Tuple([x, @symcore.int(1), @symcore.int(3)])]),
  )
  assert_latex_parity(
    @symcore.function("Product", [
      x,
      Tuple([x, @symcore.int(1), @symcore.int(3)]),
    ]),
  )
  assert_latex_parity(
    @symcore.function("Piecewise", [
      x,
      Relational(Lt, x, @symcore.int(1)),
      @symcore.int(1),
      Boolean(true),
    ]),
  )
  assert_latex_parity(@symcore.function("Min", [@symcore.int(1), x]))
  assert_latex_parity(@symcore.function("Max", [@symcore.int(1), x]))
  assert_latex_parity(@symcore.function("floor", [x]))
  assert_latex_parity(@symcore.function("ceiling", [x]))
  assert_latex_parity(
    @symcore.function("re", [
      @symcore.raw_mul([x, @symcore.function("sin", [x])]),
    ]),
  )
  assert_latex_parity(@symcore.function("LaplaceTransform", [ft, t, k]))
  assert_latex_parity(
    @symcore.function("InverseLaplaceTransform", [fk, k, t, @symcore.int(0)]),
  )
  assert_latex_parity(
    @symcore.function("O", [@symcore.pow(x, @symcore.int(2))]),
  )
  assert_latex_parity(
    @symcore.function("O", [
      @symcore.pow(x + @symcore.int(-1), @symcore.int(2)),
      @symcore.function("Tuple", [x, @symcore.int(1)]),
    ]),
  )
}

///|
test "symprint latex parity logic sets and delta-style specials" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let reals = @symcore.Expr::Symbol("Reals")
  let integers = @symcore.Expr::Symbol("Integers")
  assert_latex_parity(
    @symcore.function("Not", [@symcore.function("Or", [x, y])]),
  )
  assert_latex_parity(
    @symcore.function("And", [@symcore.function("Or", [x, y]), z]),
  )
  assert_latex_parity(@symcore.function("Equivalent", [z, y, x]))
  assert_latex_parity(@symcore.function("Xor", [x, y]))
  assert_latex_parity(@symcore.function("DiracDelta", [x, @symcore.int(1)]))
  assert_latex_parity(@symcore.function("Heaviside", [x, @symcore.int(0)]))
  assert_latex_parity(@symcore.function("KroneckerDelta", [x, y]))
  assert_latex_parity(@symcore.function("LeviCivita", [x, y, @symcore.int(1)]))
  assert_latex_parity(reals)
  assert_latex_parity(Symbol("UniversalSet"))
  assert_latex_parity(@symcore.function("FiniteSet", [x, @symcore.int(1), y]))
  assert_latex_parity(
    @symcore.function("Interval", [
      @symcore.int(0),
      @symcore.int(1),
      Boolean(true),
      Boolean(true),
    ]),
  )
  assert_latex_parity(
    @symcore.function("Range", [
      @symcore.int(1),
      @symcore.int(10),
      @symcore.int(2),
    ]),
  )
  assert_latex_parity(@symcore.function("Union", [reals, integers]))
  assert_latex_parity(@symcore.function("Intersection", [reals, integers]))
  assert_latex_parity(
    @symcore.function("Complement", [
      reals,
      @symcore.function("Interval", [@symcore.int(0), @symcore.int(1)]),
    ]),
  )
  assert_latex_parity(@symcore.function("Contains", [x, reals]))
  assert_latex_parity(@symcore.function("ProductSet", [reals, reals]))
  assert_latex_parity(
    @symcore.function("ConditionSet", [
      x,
      Relational(Gt, x, @symcore.int(0)),
      reals,
    ]),
  )
  assert_latex_parity(
    @symcore.function("ImageSet", [
      @symcore.lambda_expr(x, x + @symcore.int(1)),
      integers,
    ]),
  )
  assert_latex_parity(@symcore.function("PowerSet", [integers]))
}
