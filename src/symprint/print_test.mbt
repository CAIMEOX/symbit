///|
test "debug repr uses s-expression order" {
  let expr = @symcore.Expr::Symbol("b") * (Symbol("a") + @symcore.int(1))
  debug_inspect(expr, content="(* sym:b (+ sym:a 1))")
}

///|
test "pretty to_string respects precedence" {
  let expr = (@symcore.Expr::Symbol("x") + @symcore.int(1)) ^
    (Symbol("y") * @symcore.int(2))
  inspect(pretty_string(expr), content="(x + 1)**(2*y)")
}

///|
test "sympy printing text front doors are wired" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.pow(x, @symcore.int(2)) + @symcore.int(1)
  inspect(sstr(expr), content="x**2 + 1")
  inspect(sstrrepr(expr), content="x**2 + 1")
  inspect(srepr(expr), content="Add(Pow(Symbol('x'), Integer(2)), Integer(1))")
  inspect(pretty(expr), content="x**2 + 1")
  inspect(pretty_print(expr), content="x**2 + 1")
  inspect(pager_print(expr), content="x**2 + 1")
  inspect(print_latex(expr), content="x^{2} + 1")
  inspect(
    multiline_latex(x, expr),
    content="\\begin{align*}x &= x^{2} + 1\\end{align*}",
  )
}

///|
test "sympy printing code front doors are wired" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.pow(x, @symcore.int(2)) + @symcore.int(1)
  inspect(pycode(expr), content="x**2 + 1")
  inspect(python(expr), content="x = Symbol('x')\ne = x**2 + 1")
  inspect(print_python(expr), content="x = Symbol('x')\ne = x**2 + 1")
  inspect(ccode(expr), content="pow(x, 2.0) + 1.0")
  inspect(
    ccode(expr, assign_to=Some("out")),
    content="out = pow(x, 2.0) + 1.0;",
  )
  inspect(print_ccode(expr), content="pow(x, 2.0) + 1.0")
  inspect(cxxcode(expr), content="pow(x, 2.0) + 1.0")
  inspect(fcode(expr), content="x**2.0 + 1.0")
  inspect(print_fcode(expr), content="x**2.0 + 1.0")
  inspect(rcode(expr), content="x^2 + 1")
  inspect(print_rcode(expr), content="x^2 + 1")
  inspect(jscode(expr), content="pow(x, 2.0) + 1.0")
  inspect(print_jscode(expr), content="pow(x, 2.0) + 1.0")
  inspect(julia_code(expr), content="x^2 + 1")
  inspect(octave_code(expr), content="x^2 + 1")
  inspect(rust_code(expr), content="x.powf(2.0) + 1.0")
  inspect(glsl_code(expr), content="pow(x, 2.0) + 1.0")
  inspect(print_glsl(expr), content="pow(x, 2.0) + 1.0")
  inspect(mathematica_code(expr), content="x^2 + 1")
  inspect(maple_code(expr), content="x^2 + 1")
  inspect(print_maple_code(expr), content="x^2 + 1")
  inspect(smtlib_code(expr), content="(assert (+ (^ x 2) 1))")
}

///|
test "sympy printing markup tree and graph front doors are wired" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.function("sin", [x + @symcore.int(1)])
  assert_true(mathml(expr).contains("<apply><sin/>"))
  assert_true(print_mathml(expr, printer="presentation").contains("<mrow>"))
  inspect(print_gtk(expr), content="<mrow><mi>sin(x + 1)</mi></mrow>")
  inspect(preview(expr), content="\\sin{\\left(x + 1 \\right)}")
  assert_true(print_tree(expr).contains("sin(x + 1)\n  x + 1"))
  let dot = dotprint(expr)
  assert_true(dot.contains("digraph{"))
  assert_true(dot.contains("->"))
}

///|
test "pretty to_string wraps multiplicative denominator" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.mul([
    x + y,
    @symcore.pow(
      @symcore.mul([x ^ @symcore.int(2), y ^ @symcore.int(2)]),
      @symcore.int(-1),
    ),
  ])
  inspect(pretty_string(expr), content="(x + y)/(x**2*y**2)")
}

///|
test "pretty to_string prints exp negative powers in numerator form" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    pretty_string(
      @symcore.mul([
        y,
        @symcore.pow(@symcore.function("exp", [x]), @symcore.int(-1)),
      ]),
    ),
    content="y*exp(-x)",
  )
  inspect(
    pretty_string(
      @symcore.mul([
        y,
        @symcore.rational_from_ints(1, 2) catch {
          _ => fail("half")
        },
        @symcore.pow(@symcore.function("exp", [x]), @symcore.int(-2)),
      ]),
    ),
    content="y*exp(-2*x)/2",
  )
}

///|
test "pretty to_string normalizes subtraction and unit coefficients" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  inspect(
    pretty_string(
      @symcore.add([
        @symcore.mul([@symcore.int(6), x ^ @symcore.int(2)]),
        @symcore.int(-5),
      ]),
    ),
    content="6*x**2 - 5",
  )
  inspect(
    pretty_string(
      @symcore.add([
        @symcore.mul([@symcore.int(-1), x]),
        @symcore.mul([@symcore.int(-1), y]),
      ]),
    ),
    content="-x - y",
  )
  inspect(
    pretty_string(
      @symcore.add([@symcore.mul([@symcore.int(-1), x]), @symcore.int(3)]),
    ),
    content="3 - x",
  )
  inspect(pretty_string(@symcore.add([y, @symcore.int(-1)])), content="y - 1")
  inspect(pretty_string(@symcore.mul([@symcore.int(-1), x])), content="-x")
}

///|
test "pretty to_string prints Float leaves" {
  let exact = @symcore.Float::from_str("0.125", prec=90) catch {
    _ => fail("float")
  }
  inspect(pretty_string(Float(exact)), content="0.125")
}

///|
test "pretty to_string wraps complex float leaves inside products" {
  let value = @symcore.ComplexFloat::from_exact_parts(
    @symnum.BigRational::from_int(1),
    @symnum.BigRational::from_int(2),
    prec=80,
  )
  let expr = @symcore.mul([ComplexFloat(value), Symbol("x")])
  inspect(pretty_string(expr), content="(1.0 + 2.0*I)*x")
}

///|
test "pretty printers understand relational tuple and lambda wrappers" {
  let rel = @symcore.Expr::Relational(Le, Symbol("x"), @symcore.int(2))
  let tup = @symcore.Expr::Tuple([Symbol("x"), @symcore.int(2)])
  let lam = @symcore.lambda_expr(
    tup,
    @symcore.add([Symbol("x"), @symcore.int(1)]),
  )
  debug_inspect(rel, content="(call Le sym:x 2)")
  inspect(pretty_string(rel), content="x <= 2")
  inspect(pretty_string(tup), content="(x, 2)")
  inspect(pretty_string(lam), content="Lambda((x, 2), x + 1)")
}

///|
test "pretty printers understand number symbols" {
  debug_inspect(@symcore.Expr::NumberSymbol(Pi), content="const:pi")
  inspect(pretty_string(NumberSymbol(ImaginaryUnit)), content="I")
  inspect(pretty_string(NumberSymbol(Infinity)), content="oo")
}

///|
test "pretty printers render dummy and wild names like SymPy" {
  let d = @symcore.dummy(name="x")
  let w = @symcore.Expr::Wild("x", [], [])
  inspect(pretty_string(d), content="_x")
  assert_true(Repr(d).to_string().has_prefix("dummy:_x#"))
  inspect(pretty_string(w), content="x_")
  debug_inspect(w, content="wild:x_")
}

///|
test "pretty printers distinguish undefined function heads" {
  let f = @symcore.Expr::UndefinedFunction("f")
  let sin_head = @symcore.Expr::FunctionHead("sin")
  inspect(pretty_string(f), content="f")
  debug_inspect(f, content="ufunc:f")
  inspect(pretty_string(sin_head), content="sin")
  debug_inspect(sin_head, content="fhead:sin")
}

///|
test "pretty printers render dict containers" {
  let expr = @symcore.Expr::Dict([
    (Symbol("x"), Symbol("y")),
    (@symcore.int(1), Symbol("z")),
  ])
  debug_inspect(
    expr,
    content="(call Dict (call Tuple sym:x sym:y) (call Tuple 1 sym:z))",
  )
  inspect(pretty_string(expr), content="{1: z, x: y}")
}

///|
test "pretty printers render Mod as a structured core node" {
  let expr = @symcore.mod_expr(
    @symcore.add([Symbol("x"), @symcore.int(1)]),
    @symcore.int(3),
  )
  inspect(pretty_string(expr), content="Mod(x + 1, 3)")
  debug_inspect(expr, content="(call Mod (+ sym:x 1) 3)")
}

///|
test "arbitarary polys" {
  let gen = @symcore.arbitrary_polys()
  let exprs = gen.samples(size=5, seed=42)
  debug_inspect(
    exprs.map(pretty_string),
    content=(
      #|["y", "w", "b**8", "z", "(b) + w"]
    ),
  )
  debug_inspect(
    gen.samples(size=10, seed=99).map(pretty_string),
    content=(
      #|[
      #|  "89*z*z**50 + b**91 + c + z + c + 59 + 34 + 95 + z + a",
      #|  "87",
      #|  "y**78",
      #|  "z",
      #|  "y**80",
      #|  "9",
      #|  "a**56",
      #|  "46",
      #|  "x*94*87*w*a**90",
      #|  "z**63",
      #|]
    ),
  )
}
