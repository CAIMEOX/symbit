///|
test "debug repr uses s-expression order" {
  let expr = @symcore.mul([
    @symcore.symbol("b"),
    @symcore.add([@symcore.symbol("a"), @symcore.int(1)]),
  ])
  inspect(debug_repr(expr), content="(* sym:b (+ 1 sym:a))")
}

///|
test "pretty to_string respects precedence" {
  let expr = @symcore.pow(
    @symcore.add([@symcore.symbol("x"), @symcore.int(1)]),
    @symcore.mul([@symcore.symbol("y"), @symcore.int(2)]),
  )
  inspect(to_string(expr), content="(1 + x)^(2 * y)")
}
