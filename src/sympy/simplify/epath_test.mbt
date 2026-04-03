///|
test "symsimplify epath select/apply basics" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let expr = @symcore.add([
    x,
    @symcore.function("sin", [@symcore.add([x, @symcore.int(1)])]),
    @symcore.function("cos", [@symcore.add([x, y, z])]),
  ])
  let path = EPath::new("/*/*/Symbol")
  let selected = path.select(expr)
  inspect(
    selected.map(@symprint.debug_repr),
    content="[\"sym:x\", \"sym:y\", \"sym:z\", \"sym:x\"]",
  )
  let doubled = path.apply(expr, item => @symcore.mul([@symcore.int(2), item]))
  inspect(
    @symprint.to_string(doubled),
    content="x + cos(2*x + 2*y + 2*z) + sin(2*x + 1)",
  )
}
