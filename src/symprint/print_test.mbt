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
