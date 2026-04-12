///|
test "symplotting line series samples uniformly on a linear range" {
  let x = @symcore.Expr::Symbol("x")
  let series = line_over_1d_range_series(
    x,
    @symcore.Expr::Tuple([x, @symcore.int(0), @symcore.int(4)]),
    n=5,
  )
  let (xs, ys) = series.get_points()
  assert_eq(xs.length(), 5)
  assert_eq(xs[0], 0.0)
  assert_eq(xs[2], 2.0)
  assert_eq(xs[4], 4.0)
  assert_eq(ys[0], Some(0.0))
  assert_eq(ys[2], Some(2.0))
  assert_eq(ys[4], Some(4.0))
}

///|
test "symplotting line series supports integer-only discretization" {
  let x = @symcore.Expr::Symbol("x")
  let series = line_over_1d_range_series(
    x,
    @symcore.Expr::Tuple([x, @symcore.int(-1), @symcore.int(2)]),
    only_integers=true,
  )
  let (xs, ys) = series.get_data()
  assert_eq(xs, [-1.0, 0.0, 1.0, 2.0])
  assert_eq(ys, [Some(-1.0), Some(0.0), Some(1.0), Some(2.0)])
}

///|
test "symplotting line series supports logarithmic discretization" {
  let x = @symcore.Expr::Symbol("x")
  let series = line_over_1d_range_series(
    x,
    @symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(100)]),
    n=3,
    xscale="log",
  )
  let (xs, _) = series.get_points()
  assert_true((xs[0] - 1.0).abs() <= 1.0e-12)
  assert_true((xs[1] - 10.0).abs() <= 1.0e-10)
  assert_true((xs[2] - 100.0).abs() <= 1.0e-8)
}

///|
test "symplotting line series supports complex return modes on uniform data" {
  let x = @symcore.Expr::Symbol("x")
  let imag = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let expr = @symcore.mul([imag, x])
  let series = line_over_1d_range_series(
    expr,
    @symcore.Expr::Tuple([x, @symcore.int(0), @symcore.int(2)]),
    n=3,
    return_mode=Some("imag"),
  )
  let (_, ys) = series.get_data()
  assert_eq(ys, [Some(0.0), Some(1.0), Some(2.0)])
}
