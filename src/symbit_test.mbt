///|
test "prelude constructors round trip through printers" {
  let expr = add([integer(1), mul([symbol("x"), pow(symbol("y"), integer(2))])])
  inspect(debug_repr(expr), content="(+ 1 (* sym:x (^ sym:y 2)))")
  inspect(to_string(expr), content="1 + x * y^2")
}

///|
test "rational helper" {
  let expr = try! rational(1, 3)
  inspect(debug_repr(expr), content="1/3")
}
