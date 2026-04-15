///|
test "prelude constructors round trip through printers" {
  let expr = add([
    integer(1),
    mul([Expr::Symbol("x"), pow(Expr::Symbol("y"), integer(2))]),
  ])
  debug_inspect(expr, content="(+ (* sym:x (^ sym:y 2)) 1)")
  inspect(to_string(expr), content="x*y**2 + 1")
}

///|
test "rational helper" {
  let expr = rational(1, 3)
  debug_inspect(expr, content="1/3")
}

///|
test "matrix helpers are exported from root package" {
  let m = matrix([[integer(1), integer(2)], [integer(3), integer(4)]])
  inspect(m.to_string(), content="Matrix([[1, 2], [3, 4]])")
  inspect(eye(2).to_string(), content="Matrix([[1, 0], [0, 1]])")
}
