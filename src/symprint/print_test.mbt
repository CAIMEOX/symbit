///|
test "debug repr uses s-expression order" {
  let expr = @symcore.symbol("b") * (@symcore.symbol("a") + @symcore.int(1))
  inspect(debug_repr(expr), content="(* sym:b (+ sym:a 1))")
}

///|
test "pretty to_string respects precedence" {
  let expr = (@symcore.symbol("x") + @symcore.int(1)) ^
    (@symcore.symbol("y") * @symcore.int(2))
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
  inspect(to_string(@symcore.float(exact)), content="0.125")
}

///|
test "pretty to_string wraps complex float leaves inside products" {
  let value = @symcore.ComplexFloat::from_exact_parts(
    @symnum.BigRational::from_int(1),
    @symnum.BigRational::from_int(2),
    prec=80,
  )
  let expr = @symcore.mul([@symcore.complex_float(value), @symcore.symbol("x")])
  inspect(to_string(expr), content="(1.0 + 2.0*I)*x")
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
