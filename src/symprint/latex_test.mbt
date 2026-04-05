///|
test "latex renders arithmetic and function powers like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let half = @symcore.rational_from_ints(1, 2) catch { _ => fail("half") }
  let three_fourths = @symcore.rational_from_ints(3, 4) catch {
    _ => fail("three_fourths")
  }
  inspect(latex(x + @symcore.int(1)), content="x + 1")
  inspect(latex(@symcore.raw_mul([half, x + y])), content="\\frac{x + y}{2}")
  inspect(
    latex(@symcore.pow(x + y, three_fourths)),
    content="\\left(x + y\\right)^{\\frac{3}{4}}",
  )
  inspect(
    latex(@symcore.pow(x + y, @symcore.int(-1))),
    content="\\frac{1}{x + y}",
  )
  inspect(latex(@symcore.function("sqrt", [x + y])), content="\\sqrt{x + y}")
  inspect(
    latex(@symcore.function("sin", [x]) ^ @symcore.int(2)),
    content="\\sin^{2}{\\left(x \\right)}",
  )
}

///|
test "latex renders symbolic names constants and wrappers" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(latex(@symcore.Expr::Symbol("alpha_1")), content="\\alpha_{1}")
  inspect(latex(@symcore.Expr::Symbol("alphahat")), content="\\hat{\\alpha}")
  inspect(
    latex(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)),
    content="\\pi",
  )
  inspect(
    latex(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Exp1)),
    content="e",
  )
  inspect(
    latex(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma)),
    content="\\gamma",
  )
  inspect(
    latex(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ComplexInfinity),
    ),
    content="\\tilde{\\infty}",
  )
  inspect(latex(@symcore.dummy(name="x")), content="x")
  inspect(latex(@symcore.Expr::Wild("x", [], [])), content="x")
  inspect(
    latex(@symcore.Expr::Tuple([x, @symcore.int(2)])),
    content="\\left( x, \\  2\\right)",
  )
  inspect(
    latex(@symcore.Expr::Subs(x + y, x, @symcore.int(1))),
    content="\\left. x + y \\right|_{\\substack{ x=1 }}",
  )
  inspect(
    latex(@symcore.lambda_expr(@symcore.Expr::Tuple([x]), x + @symcore.int(1))),
    content="\\left( x \\mapsto x + 1 \\right)",
  )
}

///|
test "latex supports mode wrappers and relationals" {
  let x = @symcore.Expr::Symbol("x")
  inspect(latex(x, mode="inline"), content="$x$")
  inspect(
    latex(
      @symcore.Expr::Relational(@symcore.RelOp::Le, x, @symcore.int(2)),
      mode="equation",
    ),
    content="\\begin{equation}x \\leq 2\\end{equation}",
  )
}

///|
test "latex supports SymPy-style printer settings" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let one_third = @symcore.rational_from_ints(1, 3) catch {
    _ => fail("one_third")
  }
  let three_fourths = @symcore.rational_from_ints(3, 4) catch {
    _ => fail("three_fourths")
  }
  let fx = @symcore.applied_undefined_function("f", [x])
  inspect(
    latex(
      @symcore.raw_mul([
        @symcore.rational_from_ints(1, 2) catch {
          _ => fail("half")
        },
        x,
      ]),
      fold_short_frac=Some(true),
    ),
    content="x / 2",
  )
  inspect(
    latex(@symcore.pow(x + y, three_fourths), fold_frac_powers=true),
    content="\\left(x + y\\right)^{3/4}",
  )
  inspect(
    latex(@symcore.function("asin", [x]), inv_trig_style="full"),
    content="\\arcsin{\\left(x \\right)}",
  )
  inspect(
    latex(
      @symcore.function("asin", [@symcore.pow(x, @symcore.int(2))]),
      inv_trig_style="power",
      fold_func_brackets=true,
    ),
    content="\\sin^{-1} {x^{2}}",
  )
  inspect(
    latex(@symcore.function("log", [x]), ln_notation=true),
    content="\\ln{\\left(x \\right)}",
  )
  inspect(
    latex(@symcore.raw_mul([@symcore.int(2), x, y]), mul_symbol=Some("times")),
    content="2 \\times x \\times y",
  )
  inspect(
    latex(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
      imaginary_unit="j",
    ),
    content="j",
  )
  inspect(
    latex(@symcore.derivative_constructor_expr(fx, [x]), diff_operator="rd"),
    content="\\frac{\\mathrm{d}}{\\mathrm{d} x} f{\\left(x \\right)}",
  )
  inspect(
    latex(@symcore.pow(x, one_third), root_notation=false),
    content="x^{\\frac{1}{3}}",
  )
  inspect(
    latex(
      @symcore.pow(@symcore.Expr::Symbol("x^*"), @symcore.int(2)),
      parenthesize_super=false,
    ),
    content="{x^{*}}^{2}",
  )
  inspect(
    latex(@symcore.pow(x, @symcore.int(2)), symbol_names={ "x": "x_i" }),
    content="x_i^{2}",
  )
}

///|
test "latex renders integrals big operators piecewise and transforms" {
  let x = @symcore.Expr::Symbol("x")
  let t = @symcore.Expr::Symbol("t")
  let k = @symcore.Expr::Symbol("k")
  let fx = @symcore.applied_undefined_function("f", [x])
  let ft = @symcore.applied_undefined_function("f", [t])
  let fk = @symcore.applied_undefined_function("f", [k])
  inspect(
    latex(@symcore.function("Integral", [x, @symcore.Expr::Tuple([x])])),
    content="\\int x\\, dx",
  )
  inspect(
    latex(
      @symcore.function("Integral", [
        x,
        @symcore.Expr::Tuple([x, @symcore.int(0), @symcore.int(1)]),
      ]),
    ),
    content="\\int\\limits_{0}^{1} x\\, dx",
  )
  inspect(
    latex(
      @symcore.function("Sum", [
        x,
        @symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(3)]),
      ]),
    ),
    content="\\sum_{x=1}^{3} x",
  )
  inspect(
    latex(
      @symcore.function("Product", [
        x,
        @symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(3)]),
      ]),
    ),
    content="\\prod_{x=1}^{3} x",
  )
  inspect(
    latex(
      @symcore.function("Piecewise", [
        x,
        @symcore.Expr::Relational(@symcore.RelOp::Lt, x, @symcore.int(1)),
        @symcore.int(1),
        @symcore.Expr::Boolean(true),
      ]),
    ),
    content="\\begin{cases} x & \\text{for}\\: x < 1 \\\\1 & \\text{otherwise} \\end{cases}",
  )
  inspect(
    latex(@symcore.function("Min", [@symcore.int(1), x])),
    content="\\min\\left(1, x\\right)",
  )
  inspect(
    latex(@symcore.function("Max", [@symcore.int(1), x])),
    content="\\max\\left(1, x\\right)",
  )
  inspect(
    latex(@symcore.function("floor", [x])),
    content="\\left\\lfloor{x}\\right\\rfloor",
  )
  inspect(
    latex(@symcore.function("ceiling", [x])),
    content="\\left\\lceil{x}\\right\\rceil",
  )
  inspect(
    latex(
      @symcore.function("re", [
        @symcore.raw_mul([x, @symcore.function("sin", [x])]),
      ]),
    ),
    content="\\operatorname{re}{\\left(x \\sin{\\left(x \\right)}\\right)}",
  )
  inspect(
    latex(@symcore.function("LaplaceTransform", [ft, t, k])),
    content="\\mathcal{L}_{t}\\left[f{\\left(t \\right)}\\right]\\left(k\\right)",
  )
  inspect(
    latex(
      @symcore.function("InverseLaplaceTransform", [fk, k, t, @symcore.int(0)]),
    ),
    content="\\mathcal{L}^{-1}_{k}\\left[f{\\left(k \\right)}\\right]\\left(t\\right)",
  )
  inspect(
    latex(@symcore.function("O", [@symcore.pow(x, @symcore.int(2))])),
    content="O\\left(x^{2}\\right)",
  )
  inspect(
    latex(
      @symcore.function("O", [
        @symcore.pow(x + @symcore.int(-1), @symcore.int(2)),
        @symcore.function("Tuple", [x, @symcore.int(1)]),
      ]),
    ),
    content="O\\left(\\left(x - 1\\right)^{2}; x\\rightarrow 1\\right)",
  )
  ignore(fx)
}

///|
test "latex renders logic set notation and delta-like special functions" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let reals = @symcore.Expr::Symbol("Reals")
  let integers = @symcore.Expr::Symbol("Integers")
  inspect(
    latex(@symcore.function("Not", [@symcore.function("Or", [x, y])])),
    content="\\neg \\left(x \\vee y\\right)",
  )
  inspect(
    latex(@symcore.function("And", [@symcore.function("Or", [x, y]), z])),
    content="z \\wedge \\left(x \\vee y\\right)",
  )
  inspect(
    latex(@symcore.function("Equivalent", [z, y, x])),
    content="x \\Leftrightarrow y \\Leftrightarrow z",
  )
  inspect(latex(@symcore.function("Xor", [x, y])), content="x \\veebar y")
  inspect(
    latex(@symcore.function("DiracDelta", [x, @symcore.int(1)])),
    content="\\delta^{\\left( 1 \\right)}\\left( x \\right)",
  )
  inspect(
    latex(@symcore.function("Heaviside", [x, @symcore.int(0)])),
    content="\\theta\\left(x, 0\\right)",
  )
  inspect(
    latex(@symcore.function("KroneckerDelta", [x, y])),
    content="\\delta_{x y}",
  )
  inspect(
    latex(@symcore.function("LeviCivita", [x, y, @symcore.int(1)])),
    content="\\varepsilon_{x y 1}",
  )
  inspect(latex(reals), content="\\mathbb{R}")
  inspect(latex(@symcore.Expr::Symbol("UniversalSet")), content="\\mathbb{U}")
  inspect(
    latex(@symcore.function("FiniteSet", [x, @symcore.int(1), y])),
    content="\\left\\{1, x, y\\right\\}",
  )
  inspect(
    latex(
      @symcore.function("Interval", [
        @symcore.int(0),
        @symcore.int(1),
        @symcore.Expr::Boolean(true),
        @symcore.Expr::Boolean(true),
      ]),
    ),
    content="\\left(0, 1\\right)",
  )
  inspect(
    latex(
      @symcore.function("Range", [
        @symcore.int(1),
        @symcore.int(10),
        @symcore.int(2),
      ]),
    ),
    content="\\left\\{1, 3, \\ldots, 9\\right\\}",
  )
  inspect(
    latex(@symcore.function("Union", [reals, integers])),
    content="\\mathbb{Z} \\cup \\mathbb{R}",
  )
  inspect(
    latex(@symcore.function("Intersection", [reals, integers])),
    content="\\mathbb{Z} \\cap \\mathbb{R}",
  )
  inspect(
    latex(
      @symcore.function("Complement", [
        reals,
        @symcore.function("Interval", [@symcore.int(0), @symcore.int(1)]),
      ]),
    ),
    content="\\mathbb{R} \\setminus \\left[0, 1\\right]",
  )
  inspect(
    latex(@symcore.function("Contains", [x, reals])),
    content="x \\in \\mathbb{R}",
  )
  inspect(
    latex(@symcore.function("ProductSet", [reals, reals])),
    content="\\mathbb{R}^{2}",
  )
  inspect(
    latex(
      @symcore.function("ConditionSet", [
        x,
        @symcore.Expr::Relational(@symcore.RelOp::Gt, x, @symcore.int(0)),
        reals,
      ]),
    ),
    content="\\left\\{x\\; \\middle|\\; x \\in \\mathbb{R} \\wedge x > 0 \\right\\}",
  )
  inspect(
    latex(
      @symcore.function("ImageSet", [
        @symcore.lambda_expr(x, x + @symcore.int(1)),
        integers,
      ]),
    ),
    content="\\left\\{x + 1\\; \\middle|\\; x \\in \\mathbb{Z}\\right\\}",
  )
  inspect(
    latex(@symcore.function("PowerSet", [integers])),
    content="\\mathcal{P}\\left(\\mathbb{Z}\\right)",
  )
}
