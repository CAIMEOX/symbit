///|
fn plot_joined_lines(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
test "symplotting plot creates text backend over explicit range" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [plot_expr(x), plot_range(x, @symcore.int(0), @symcore.int(3))],
    show=false,
    backend="text",
  )
  let series = backend.series()
  assert_eq(series.length(), 1)
  assert_true(series[0].expr == x)
  assert_true(series[0].variable == x)
  assert_true(series[0].start == @symcore.int(0))
  assert_true(series[0].end == @symcore.int(3))
  assert_eq(
    plot_joined_lines(backend.render_lines()),
    plot_joined_lines(textplot_str(x, @symcore.int(0), @symcore.int(3))),
  )
}

///|
test "symplotting plot creates default range like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [plot_expr(@symcore.add([x, @symcore.int(1)]))],
    show=false,
  )
  let series = backend.series()
  assert_eq(series.length(), 1)
  assert_eq(backend.backend(), "matplotlib")
  assert_true(series[0].variable == x)
  assert_true(series[0].start == @symcore.int(-10))
  assert_true(series[0].end == @symcore.int(10))
  assert_eq(backend.xlabel, Some("x"))
  assert_eq(backend.ylabel, Some("f(x)"))
}

///|
test "symplotting plot supports multiple expressions over one range" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [
      plot_expr(@symcore.add([x, @symcore.int(1)])),
      plot_expr(@symcore.pow(x, @symcore.int(2))),
      plot_range(x, @symcore.int(0), @symcore.int(5)),
    ],
    show=false,
  )
  let series = backend.series()
  assert_eq(series.length(), 2)
  assert_true(series[0].start == @symcore.int(0))
  assert_true(series[1].end == @symcore.int(5))
}

///|
test "symplotting plot supports grouped per-expression ranges" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [
      plot_group([
        plot_expr(@symcore.pow(x, @symcore.int(2))),
        plot_range(x, @symcore.int(-5), @symcore.int(5)),
      ]),
      plot_group([
        plot_expr(@symcore.pow(x, @symcore.int(3))),
        plot_range(x, @symcore.int(-3), @symcore.int(3)),
      ]),
    ],
    show=false,
  )
  let series = backend.series()
  assert_eq(series.length(), 2)
  assert_true(series[0].start == @symcore.int(-5))
  assert_true(series[1].end == @symcore.int(3))
}

///|
test "symplotting text backend rejects multiple series like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [plot_expr(x), plot_expr(@symcore.pow(x, @symcore.int(2)))],
    show=false,
    backend="text",
  )
  ignore(
    try {
      ignore(backend.render_lines())
      fail("expected text backend error")
    } catch {
      PlottingError::ValueError(message) =>
        inspect(
          message,
          content="The TextBackend supports only one graph per Plot.",
        )
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting plot rejects incompatible free symbols" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  ignore(
    try {
      ignore(plot([plot_expr(x), plot_expr(y)], show=false))
      fail("expected incompatible free symbol error")
    } catch {
      PlottingError::ValueError(message) =>
        assert_true(message.contains("Too many free symbols."))
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting plot accepts matplotlib frontend and exposes uniform data" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [plot_expr(@symcore.function("sin", [x]))],
    show=false,
    backend="matplotlib",
    adaptive=false,
    n=30,
  )
  assert_eq(backend.backend(), "matplotlib")
  let (xs, ys) = backend.get_data(0)
  assert_eq(xs.length(), 30)
  assert_eq(ys.length(), 30)
}

///|
test "symplotting plot accepts text frontend and exposes uniform data" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [plot_expr(@symcore.function("sin", [x]))],
    show=false,
    backend="text",
    adaptive=false,
    n=30,
  )
  assert_eq(backend.backend(), "text")
  let (xs, ys) = backend.get_points(0)
  assert_eq(xs.length(), 30)
  assert_eq(ys.length(), 30)
}

///|
test "symplotting plot stores frontend metadata like SymPy plot kwargs" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [plot_expr(@symcore.function("sin", [x]))],
    show=false,
    backend="matplotlib",
    legend=true,
    aspect_ratio="1:1",
    axis_center="center",
    axis=false,
    xscale="log",
    yscale="log",
    autoscale=false,
    margin=3,
  )
  assert_eq(backend.backend(), "matplotlib")
  assert_true(backend.legend)
  assert_eq(backend.aspect_ratio, "1:1")
  assert_eq(backend.axis_center, "center")
  assert_false(backend.axis)
  assert_eq(backend.xscale, "log")
  assert_eq(backend.yscale, "log")
  assert_false(backend.autoscale)
  assert_eq(backend.margin, 3)
}
