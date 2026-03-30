///|
test "debug repr uses s-expression order" {
  let expr = @symcore.Expr::Symbol("b") *
    (@symcore.Expr::Symbol("a") + @symcore.int(1))
  inspect(debug_repr(expr), content="(* sym:b (+ sym:a 1))")
}

///|
test "pretty to_string respects precedence" {
  let expr = (@symcore.Expr::Symbol("x") + @symcore.int(1)) ^
    (@symcore.Expr::Symbol("y") * @symcore.int(2))
  inspect(to_string(expr), content="(x + 1)**(2*y)")
}

///|
test "pretty to_string prints Float leaves" {
  let exact_res : Result[@symcore.Float, @symnum.MpfError] = try? @symcore.Float::from_str(
    "0.125",
    prec=90,
  )
  let exact = match exact_res {
    Ok(value) => value
    Err(_) => fail("float")
  }
  inspect(to_string(@symcore.Expr::Float(exact)), content="0.125")
}

///|
test "pretty to_string wraps complex float leaves inside products" {
  let value = @symcore.ComplexFloat::from_exact_parts(
    @symnum.BigRational::from_int(1),
    @symnum.BigRational::from_int(2),
    prec=80,
  )
  let expr = @symcore.mul([
    @symcore.Expr::ComplexFloat(value),
    @symcore.Expr::Symbol("x"),
  ])
  inspect(to_string(expr), content="(1.0 + 2.0*I)*x")
}

///|
test "pretty printers understand relational tuple and lambda wrappers" {
  let rel = @symcore.Expr::Relational(
    @symcore.RelOp::Le,
    @symcore.Expr::Symbol("x"),
    @symcore.int(2),
  )
  let tup = @symcore.Expr::Tuple([@symcore.Expr::Symbol("x"), @symcore.int(2)])
  let lam = @symcore.lambda_expr(
    tup,
    @symcore.add([@symcore.Expr::Symbol("x"), @symcore.int(1)]),
  )
  inspect(debug_repr(rel), content="(call Le sym:x 2)")
  inspect(to_string(rel), content="x <= 2")
  inspect(to_string(tup), content="(x, 2)")
  inspect(to_string(lam), content="Lambda((x, 2), x + 1)")
}

///|
test "pretty printers understand number symbols" {
  inspect(
    debug_repr(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)),
    content="const:pi",
  )
  inspect(
    to_string(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
    ),
    content="I",
  )
  inspect(
    to_string(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)),
    content="oo",
  )
}

///|
test "pretty printers render dummy and wild names like SymPy" {
  let d = @symcore.dummy(name="x")
  let w = @symcore.Expr::Wild("x", [], [])
  inspect(to_string(d), content="_x")
  assert_true(debug_repr(d).has_prefix("dummy:_x#"))
  inspect(to_string(w), content="x_")
  inspect(debug_repr(w), content="wild:x_")
}

///|
test "pretty printers distinguish undefined function heads" {
  let f = @symcore.Expr::UndefinedFunction("f")
  let sin_head = @symcore.Expr::FunctionHead("sin")
  inspect(to_string(f), content="f")
  inspect(debug_repr(f), content="ufunc:f")
  inspect(to_string(sin_head), content="sin")
  inspect(debug_repr(sin_head), content="fhead:sin")
}

///|
test "pretty printers render dict containers" {
  let expr = @symcore.Expr::Dict([
    (@symcore.Expr::Symbol("x"), @symcore.Expr::Symbol("y")),
    (@symcore.int(1), @symcore.Expr::Symbol("z")),
  ])
  inspect(
    debug_repr(expr),
    content="(call Dict (call Tuple sym:x sym:y) (call Tuple 1 sym:z))",
  )
  inspect(to_string(expr), content="{1: z, x: y}")
}

///|
test "pretty printers render Mod as a structured core node" {
  let expr = @symcore.mod_expr(
    @symcore.add([@symcore.Expr::Symbol("x"), @symcore.int(1)]),
    @symcore.int(3),
  )
  inspect(to_string(expr), content="Mod(x + 1, 3)")
  inspect(debug_repr(expr), content="(call Mod (+ sym:x 1) 3)")
}

///|
test "arbitarary polys" {
  let gen = @symcore.arbitrary_polys()
  let exprs = gen.samples(size=5, seed=42)
  inspect(
    exprs.map(to_string),
    content=(
      #|["y", "w", "b**8", "z", "(b) + w"]
    ),
  )
  inspect(
    gen.samples(size=10, seed=99).map(to_string),
    content=(
      #|["89*z*z**50 + b**91 + c + z + c + 59 + 34 + 95 + z + a", "87", "y**78", "z", "y**80", "9", "a**56", "46", "x*94*87*w*a**90", "z**63"]
    ),
  )
}
