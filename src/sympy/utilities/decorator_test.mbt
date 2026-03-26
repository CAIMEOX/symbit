///|
test "decorator threaded and xthreaded behavior" {
  let square = (expr : @symcore.Expr) => @symcore.pow(expr, @symcore.int(2))
  let threaded_square = threaded(square)
  let xthreaded_square = xthreaded(square)
  let expr = threadable_scalar(
    @symcore.add([@symcore.Expr::Symbol("x"), @symcore.Expr::Symbol("y")]),
  )
  inspect(
    @symprint.to_string(
      match threaded_square(expr) {
        Threadable::Scalar(v) => v
        _ => @symcore.int(0)
      },
    ),
    content="x**2 + y**2",
  )
  inspect(
    @symprint.to_string(
      match xthreaded_square(expr) {
        Threadable::Scalar(v) => v
        _ => @symcore.int(0)
      },
    ),
    content="(x + y)**2",
  )
}

///|
test "decorator public and deprecated behavior" {
  let exports : Ref[Array[String]] = { val: [] }
  ignore(public(10, exports, "value"))
  assert_eq(exports.val, ["value"])

  let seen : Ref[String] = { val: "" }
  let wrapped = deprecated(
    "old function",
    "1.0",
    "active-deprecations",
    (x : Int) => x + 1,
    reporter=w => seen.val = w.message,
  )
  assert_eq(wrapped(4), 5)
  assert_eq(seen.val, "old function")
}
