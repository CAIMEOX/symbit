///|
test "tensor latex renders indexed heads products and partial derivatives" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let l = tensor_index_type("L")
  let i = tensor_index("i", l)
  let j = tensor_index("j", l, is_up=false)
  let a = tensor_head("A", [l, l])
  let expr = a.call([i, j]) catch { _ => fail("tensor") }
  inspect(expr.latex(), content="A{}^{i}{}_{j}")
  inspect(mul([scalar_expr(x), expr]).latex(), content="xA{}^{i}{}_{j}")
  inspect(
    partial_derivative(expr, [scalar_expr(x)]).latex(),
    content="\\frac{\\partial}{\\partial {x}}{A{}^{i}{}_{j}}",
  )
  inspect(
    partial_derivative(expr, [scalar_expr(x), scalar_expr(y)]).latex(),
    content="\\frac{\\partial^{2}}{\\partial {x} \\partial {y}}{A{}^{i}{}_{j}}",
  )
}
