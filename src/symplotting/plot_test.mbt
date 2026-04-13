///|
fn plot_joined_lines(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
fn unwrap_line_series(series : PlotSeries) -> LineOver1DRangeSeries {
  match series {
    PlotSeries::Line(line) => line
    PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) => abort("expected line series")
  }
}

///|
fn unwrap_parametric_series(series : PlotSeries) -> Parametric2DLineSeries {
  match series {
    PlotSeries::Parametric2D(line) => line
    PlotSeries::Line(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) => abort("expected parametric series")
  }
}

///|
fn unwrap_parametric3d_series(series : PlotSeries) -> Parametric3DLineSeries {
  match series {
    PlotSeries::Parametric3D(line) => line
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) => abort("expected 3d parametric series")
  }
}

///|
fn unwrap_surface_series(series : PlotSeries) -> SurfaceOver2DRangeSeries {
  match series {
    PlotSeries::Surface(surface) => surface
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) => abort("expected surface series")
  }
}

///|
fn unwrap_parametric_surface_series(
  series : PlotSeries,
) -> ParametricSurfaceSeries {
  match series {
    PlotSeries::ParametricSurface(surface) => surface
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) => abort("expected parametric surface series")
  }
}

///|
fn unwrap_contour_series(series : PlotSeries) -> ContourSeries {
  match series {
    PlotSeries::Contour(surface) => surface
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Implicit(_) => abort("expected contour series")
  }
}

///|
fn unwrap_implicit_series(series : PlotSeries) -> ImplicitSeries {
  match series {
    PlotSeries::Implicit(implicit) => implicit
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_) => abort("expected implicit series")
  }
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
  let line = unwrap_line_series(series[0])
  assert_true(line.expr == x)
  assert_true(line.variable == x)
  assert_true(line.start == @symcore.int(0))
  assert_true(line.end == @symcore.int(3))
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
  let line = unwrap_line_series(series[0])
  assert_eq(backend.backend(), "matplotlib")
  assert_true(line.variable == x)
  assert_true(line.start == @symcore.int(-10))
  assert_true(line.end == @symcore.int(10))
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
  let line0 = unwrap_line_series(series[0])
  let line1 = unwrap_line_series(series[1])
  assert_true(line0.start == @symcore.int(0))
  assert_true(line1.end == @symcore.int(5))
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
  let line0 = unwrap_line_series(series[0])
  let line1 = unwrap_line_series(series[1])
  assert_true(line0.start == @symcore.int(-5))
  assert_true(line1.end == @symcore.int(3))
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

///|
test "symplotting plot supports empty plot objects" {
  let backend = plot([], show=false)
  assert_eq(backend.backend(), "matplotlib")
  assert_eq(backend.series().length(), 0)
  assert_eq(backend.xlabel, Some("x"))
  assert_eq(backend.ylabel, Some("f(x)"))
}

///|
test "symplotting plot supports log-scaled uniform sampling frontdoor" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot(
    [
      plot_expr(x),
      plot_range(
        x,
        @symcore.Expr::Float(@symcore.Float::from_double(0.001, prec=80)),
        @symcore.int(100),
      ),
    ],
    show=false,
    xscale="log",
    n=30,
  )
  let (xs, ys) = backend.get_data(0)
  assert_eq(xs.length(), 30)
  assert_eq(ys.length(), 30)
  assert_true(xs[0] > 0.0)
  assert_true(xs[0] < 0.01)
  assert_true(xs[xs.length() - 1] > 90.0)
  assert_true(xs[xs.length() - 1] <= 100.0)
}

///|
test "symplotting plot supports additional SymPy uniform line families" {
  let x = @symcore.Expr::Symbol("x")
  let lambert = @symcore.function("LambertW", [x])
  let exponent = @symcore.function("Rational", [
    @symcore.int(3),
    @symcore.int(10),
  ])
  let family = @symcore.add([
    @symcore.pow(x, exponent),
    @symcore.mul([@symcore.int(-10), @symcore.pow(x, @symcore.int(3))]),
    @symcore.pow(x, @symcore.int(2)),
  ])
  let plot_lambert = plot([plot_expr(lambert)], show=false, n=30)
  let plot_family = plot(
    [plot_expr(family), plot_range(x, @symcore.int(-10), @symcore.int(10))],
    show=false,
    n=30,
  )
  let (lambert_xs, lambert_ys) = plot_lambert.get_data(0)
  let (family_xs, family_ys) = plot_family.get_data(0)
  assert_eq(lambert_xs.length(), 30)
  assert_eq(lambert_ys.length(), 30)
  assert_eq(family_xs.length(), 30)
  assert_eq(family_ys.length(), 30)
}

///|
test "symplotting plot adaptive frontdoor generates dense data across backends" {
  let x = @symcore.Expr::Symbol("x")
  let pm = plot(
    [plot_expr(@symcore.function("sin", [x]))],
    backend="matplotlib",
    show=false,
    adaptive=true,
    n=30,
  )
  let pt = plot(
    [plot_expr(@symcore.function("sin", [x]))],
    backend="text",
    show=false,
    adaptive=true,
    n=30,
  )
  let pd = plot(
    [plot_expr(@symcore.function("sin", [x]))],
    backend="default",
    show=false,
    adaptive=true,
    n=30,
  )
  let (pm_xs, _) = pm.get_data(0)
  let (pt_xs, _) = pt.get_data(0)
  let (pd_xs, _) = pd.get_data(0)
  assert_true(pm_xs.length() >= 30)
  assert_true(pt_xs.length() >= 30)
  assert_true(pd_xs.length() >= 30)
}

///|
test "symplotting plot_parametric creates default range like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot_parametric(
    [plot_parametric_expr(@symcore.add([x, @symcore.int(1)]), x)],
    show=false,
  )
  assert_eq(backend.backend(), "matplotlib")
  let series = unwrap_parametric_series(backend.series()[0])
  assert_true(series.expr_x == @symcore.add([x, @symcore.int(1)]))
  assert_true(series.expr_y == x)
  assert_true(series.variable == x)
  assert_true(series.start == @symcore.int(-10))
  assert_true(series.end == @symcore.int(10))
  assert_eq(series.get_label(), "x")
  assert_true(series.adaptive)
  assert_eq(backend.xlabel, Some("x"))
  assert_eq(backend.ylabel, Some("y"))
}

///|
test "symplotting plot_parametric supports shared ranges and grouped overrides" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let shared = plot_parametric(
    [
      plot_parametric_expr(
        @symcore.function("sin", [x]),
        @symcore.function("cos", [x]),
      ),
      plot_parametric_expr(
        @symcore.pow(x, @symcore.int(2)),
        @symcore.add([x, @symcore.int(1)]),
      ),
      plot_parametric_range(x, @symcore.int(-2), @symcore.int(2)),
    ],
    show=false,
    adaptive=false,
    n=10,
  )
  let shared0 = unwrap_parametric_series(shared.series()[0])
  let shared1 = unwrap_parametric_series(shared.series()[1])
  assert_true(shared0.start == @symcore.int(-2))
  assert_true(shared1.end == @symcore.int(2))

  let grouped = plot_parametric(
    [
      plot_parametric_group([
        plot_parametric_expr(@symcore.add([x, @symcore.int(1)]), x),
        plot_parametric_range(x, @symcore.int(-2), @symcore.int(2)),
        plot_parametric_label("test1"),
      ]),
      plot_parametric_group([
        plot_parametric_expr(
          @symcore.pow(y, @symcore.int(2)),
          @symcore.add([y, @symcore.int(1)]),
        ),
        plot_parametric_range(y, @symcore.int(-3), @symcore.int(3)),
        plot_parametric_label("test2"),
        plot_parametric_rendering_kw({ "cmap": "Reds" }),
      ]),
    ],
    show=false,
  )
  let group0 = unwrap_parametric_series(grouped.series()[0])
  let group1 = unwrap_parametric_series(grouped.series()[1])
  assert_true(group0.variable == x)
  assert_true(group1.variable == y)
  assert_eq(group0.get_label(), "test1")
  assert_eq(group1.get_label(), "test2")
  assert_eq(group1.rendering_kw, Some({ "cmap": "Reds" }))
}

///|
test "symplotting plot_parametric exposes uniform and adaptive public data" {
  let x = @symcore.Expr::Symbol("x")
  let uniform = plot_parametric(
    [
      plot_parametric_expr(
        @symcore.function("cos", [x]),
        @symcore.function("sin", [x]),
      ),
      plot_parametric_range(x, @symcore.int(1), @symcore.int(100)),
    ],
    show=false,
    adaptive=false,
    n=30,
    xscale="log",
  )
  let adaptive_plot = plot_parametric(
    [
      plot_parametric_expr(
        @symcore.function("cos", [x]),
        @symcore.function("sin", [x]),
      ),
      plot_parametric_range(x, @symcore.int(0), @symcore.int(10)),
    ],
    show=false,
    adaptive=true,
    n=30,
  )
  let (uxs, uys, uparams) = uniform.get_parametric_data(0)
  let (axs, ays, aparams) = adaptive_plot.get_parametric_data(0)
  assert_eq(uxs.length(), 30)
  assert_eq(uys.length(), 30)
  assert_eq(uparams.length(), 30)
  assert_true(
    uparams[1] - uparams[0] <
    uparams[uparams.length() - 1] - uparams[uparams.length() - 2],
  )
  assert_true(axs.length() >= 30)
  assert_eq(axs.length(), ays.length())
  assert_eq(axs.length(), aparams.length())
}

///|
test "symplotting plot_parametric rejects the text backend like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  ignore(
    try {
      ignore(
        plot_parametric(
          [
            plot_parametric_expr(
              @symcore.function("cos", [x]),
              @symcore.function("sin", [x]),
            ),
          ],
          show=false,
          backend="text",
        ),
      )
      fail("expected backend error")
    } catch {
      PlottingError::TypeError(message) =>
        assert_true(message.contains("plot_parametric only supports"))
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting plot3d_parametric_line creates default range like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot3d_parametric_line(
    [
      plot3d_parametric_line_expr(
        @symcore.function("cos", [x]),
        @symcore.function("sin", [x]),
        x,
      ),
    ],
    show=false,
  )
  assert_eq(backend.backend(), "matplotlib")
  assert_eq(backend.xlabel, Some("x"))
  assert_eq(backend.ylabel, Some("y"))
  assert_eq(backend.zlabel, Some("z"))
  let series = unwrap_parametric3d_series(backend.series()[0])
  assert_true(series.variable == x)
  assert_true(series.start == @symcore.int(-10))
  assert_true(series.end == @symcore.int(10))
  assert_false(series.adaptive)
  assert_eq(series.get_label(), "x")
}

///|
test "symplotting plot3d_parametric_line supports grouped overrides and shared ranges" {
  let x = @symcore.Expr::Symbol("x")
  let shared = plot3d_parametric_line(
    [
      plot3d_parametric_line_expr(
        @symcore.function("cos", [x]),
        @symcore.function("sin", [x]),
        x,
      ),
      plot3d_parametric_line_expr(
        @symcore.function("sin", [x]),
        x,
        @symcore.pow(x, @symcore.int(2)),
      ),
      plot3d_parametric_line_range(x, @symcore.int(-2), @symcore.int(2)),
    ],
    show=false,
    n=12,
  )
  let shared0 = unwrap_parametric3d_series(shared.series()[0])
  let shared1 = unwrap_parametric3d_series(shared.series()[1])
  assert_true(shared0.start == @symcore.int(-2))
  assert_true(shared1.end == @symcore.int(2))

  let grouped = plot3d_parametric_line(
    [
      plot3d_parametric_line_group([
        plot3d_parametric_line_expr(
          @symcore.function("cos", [x]),
          @symcore.function("sin", [x]),
          x,
        ),
        plot3d_parametric_line_range(x, @symcore.int(-3), @symcore.int(3)),
        plot3d_parametric_line_label("helix"),
      ]),
    ],
    show=false,
  )
  let series = unwrap_parametric3d_series(grouped.series()[0])
  assert_eq(series.get_label(), "helix")
}

///|
test "symplotting plot3d_parametric_line exposes uniform public data" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot3d_parametric_line(
    [
      plot3d_parametric_line_expr(
        @symcore.function("cos", [x]),
        @symcore.function("sin", [x]),
        x,
      ),
      plot3d_parametric_line_range(x, @symcore.int(1), @symcore.int(100)),
    ],
    show=false,
    n=20,
    xscale="log",
    adaptive=true,
  )
  let (xs, ys, zs, params) = backend.get_parametric3d_data(0)
  assert_eq(xs.length(), 20)
  assert_eq(xs.length(), ys.length())
  assert_eq(xs.length(), zs.length())
  assert_eq(xs.length(), params.length())
  assert_true(
    params[1] - params[0] <
    params[params.length() - 1] - params[params.length() - 2],
  )
}

///|
test "symplotting plot3d_parametric_line rejects the text backend like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  ignore(
    try {
      ignore(
        plot3d_parametric_line(
          [
            plot3d_parametric_line_expr(
              @symcore.function("cos", [x]),
              @symcore.function("sin", [x]),
              x,
            ),
          ],
          show=false,
          backend="text",
        ),
      )
      fail("expected backend error")
    } catch {
      PlottingError::TypeError(message) =>
        assert_true(message.contains("plot3d_parametric_line only supports"))
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting plot3d creates default ranges and labels like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let backend = plot3d([plot_expr(@symcore.add([x, y]))], show=false)
  assert_eq(backend.backend(), "matplotlib")
  assert_eq(backend.xlabel, Some("x"))
  assert_eq(backend.ylabel, Some("y"))
  assert_eq(backend.zlabel, Some("f(x, y)"))
  let series = unwrap_surface_series(backend.series()[0])
  let range_symbols = [series.variable_x, series.variable_y]
  assert_true(range_symbols.contains(x))
  assert_true(range_symbols.contains(y))
  assert_eq(series.get_label(), "x + y")
}

///|
test "symplotting plot3d supports shared ranges and grouped overrides" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let shared = plot3d(
    [
      plot_expr(@symcore.add([x, y])),
      plot_expr(@symcore.mul([x, y])),
      plot_range(x, @symcore.int(-2), @symcore.int(2)),
      plot_range(y, @symcore.int(-4), @symcore.int(4)),
    ],
    show=false,
    n=12,
  )
  let shared0 = unwrap_surface_series(shared.series()[0])
  let shared1 = unwrap_surface_series(shared.series()[1])
  assert_true(
    shared0.start_x == @symcore.int(-2) || shared0.start_y == @symcore.int(-2),
  )
  assert_true(
    shared1.end_x == @symcore.int(4) || shared1.end_y == @symcore.int(4),
  )

  let grouped = plot3d(
    [
      plot_group([
        plot_expr(@symcore.mul([x, y])),
        plot_range(x, @symcore.int(-3), @symcore.int(3)),
        plot_range(y, @symcore.int(-6), @symcore.int(6)),
        plot_label("surface"),
      ]),
    ],
    show=false,
  )
  let series = unwrap_surface_series(grouped.series()[0])
  assert_eq(series.get_label(), "surface")
}

///|
test "symplotting plot3d exposes uniform public surface data" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let backend = plot3d(
    [
      plot_expr(@symcore.mul([x, y])),
      plot_range(x, @symcore.int(1), @symcore.int(100)),
      plot_range(y, @symcore.int(1), @symcore.int(100)),
    ],
    show=false,
    n=5,
    xscale="log",
    yscale="log",
  )
  let (mesh_x, mesh_y, mesh_z) = backend.get_surface_data(0)
  assert_eq(mesh_x.length(), 5)
  assert_eq(mesh_y.length(), 5)
  assert_eq(mesh_z.length(), 5)
  assert_true(mesh_x[0][1] - mesh_x[0][0] < mesh_x[0][4] - mesh_x[0][3])
  assert_true(mesh_y[1][0] - mesh_y[0][0] < mesh_y[4][0] - mesh_y[3][0])
}

///|
test "symplotting plot3d rejects the text backend like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  ignore(
    try {
      ignore(
        plot3d([plot_expr(@symcore.add([x, y]))], show=false, backend="text"),
      )
      fail("expected backend error")
    } catch {
      PlottingError::TypeError(message) =>
        assert_true(message.contains("plot3d only supports"))
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting plot3d_parametric_surface creates default ranges like SymPy" {
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  let backend = plot3d_parametric_surface(
    [
      plot3d_parametric_surface_expr(
        @symcore.add([u, v]),
        @symcore.function("cos", [@symcore.add([u, v])]),
        @symcore.function("sin", [@symcore.add([u, v])]),
      ),
    ],
    show=false,
  )
  assert_eq(backend.backend(), "matplotlib")
  assert_eq(backend.xlabel, Some("x"))
  assert_eq(backend.ylabel, Some("y"))
  assert_eq(backend.zlabel, Some("z"))
  let series = unwrap_parametric_surface_series(backend.series()[0])
  let range_symbols = [series.variable_u, series.variable_v]
  assert_true(range_symbols.contains(u))
  assert_true(range_symbols.contains(v))
  assert_eq(series.get_label(), "(u + v, cos(u + v), sin(u + v))")
}

///|
test "symplotting plot3d_parametric_surface supports shared ranges and grouped overrides" {
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  let shared = plot3d_parametric_surface(
    [
      plot3d_parametric_surface_expr(u, v, @symcore.add([u, v])),
      plot3d_parametric_surface_expr(
        v,
        u,
        @symcore.add([u, @symcore.mul([@symcore.int(-1), v])]),
      ),
      plot3d_parametric_surface_range(u, @symcore.int(-2), @symcore.int(2)),
      plot3d_parametric_surface_range(v, @symcore.int(-4), @symcore.int(4)),
    ],
    show=false,
    n=6,
  )
  let shared0 = unwrap_parametric_surface_series(shared.series()[0])
  let shared1 = unwrap_parametric_surface_series(shared.series()[1])
  assert_true(
    shared0.start_u == @symcore.int(-2) || shared0.start_v == @symcore.int(-2),
  )
  assert_true(
    shared1.end_u == @symcore.int(4) || shared1.end_v == @symcore.int(4),
  )

  let grouped = plot3d_parametric_surface(
    [
      plot3d_parametric_surface_group([
        plot3d_parametric_surface_expr(u, v, @symcore.add([u, v])),
        plot3d_parametric_surface_range(u, @symcore.int(-3), @symcore.int(3)),
        plot3d_parametric_surface_range(v, @symcore.int(-6), @symcore.int(6)),
        plot3d_parametric_surface_label("psurface"),
      ]),
    ],
    show=false,
  )
  let series = unwrap_parametric_surface_series(grouped.series()[0])
  assert_eq(series.get_label(), "psurface")
}

///|
test "symplotting plot3d_parametric_surface exposes uniform public data" {
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  let backend = plot3d_parametric_surface(
    [
      plot3d_parametric_surface_expr(
        @symcore.function("cos", [u]),
        @symcore.function("sin", [v]),
        @symcore.add([u, v]),
      ),
      plot3d_parametric_surface_range(u, @symcore.int(1), @symcore.int(100)),
      plot3d_parametric_surface_range(v, @symcore.int(1), @symcore.int(100)),
    ],
    show=false,
    n=5,
    xscale="log",
    yscale="log",
  )
  let (mesh_x, mesh_y, mesh_z, mesh_u, mesh_v) = backend.get_parametric_surface_data(
    0,
  )
  assert_eq(mesh_x.length(), 5)
  assert_eq(mesh_y.length(), 5)
  assert_eq(mesh_z.length(), 5)
  assert_true(mesh_u[0][1] - mesh_u[0][0] < mesh_u[0][4] - mesh_u[0][3])
  assert_true(mesh_v[1][0] - mesh_v[0][0] < mesh_v[4][0] - mesh_v[3][0])
}

///|
test "symplotting plot3d_parametric_surface rejects the text backend like SymPy" {
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  ignore(
    try {
      ignore(
        plot3d_parametric_surface(
          [plot3d_parametric_surface_expr(u, v, @symcore.add([u, v]))],
          show=false,
          backend="text",
        ),
      )
      fail("expected backend error")
    } catch {
      PlottingError::TypeError(message) =>
        assert_true(message.contains("plot3d_parametric_surface only supports"))
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting plot_contour creates default ranges and labels like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let backend = plot_contour([plot_expr(@symcore.add([x, y]))], show=false)
  assert_eq(backend.backend(), "matplotlib")
  assert_eq(backend.xlabel, Some("x"))
  assert_eq(backend.ylabel, Some("y"))
  let series = unwrap_contour_series(backend.series()[0])
  let range_symbols = [series.variable_x, series.variable_y]
  assert_true(range_symbols.contains(x))
  assert_true(range_symbols.contains(y))
  assert_eq(series.get_label(), "x + y")
}

///|
test "symplotting plot_contour supports shared ranges and grouped overrides" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let shared = plot_contour(
    [
      plot_expr(@symcore.add([x, y])),
      plot_expr(@symcore.mul([x, y])),
      plot_range(x, @symcore.int(-2), @symcore.int(2)),
      plot_range(y, @symcore.int(-4), @symcore.int(4)),
    ],
    show=false,
    n=12,
  )
  let shared0 = unwrap_contour_series(shared.series()[0])
  let shared1 = unwrap_contour_series(shared.series()[1])
  assert_true(
    shared0.start_x == @symcore.int(-2) || shared0.start_y == @symcore.int(-2),
  )
  assert_true(
    shared1.end_x == @symcore.int(4) || shared1.end_y == @symcore.int(4),
  )

  let grouped = plot_contour(
    [
      plot_group([
        plot_expr(@symcore.mul([x, y])),
        plot_range(x, @symcore.int(-3), @symcore.int(3)),
        plot_range(y, @symcore.int(-6), @symcore.int(6)),
        plot_label("contour"),
      ]),
    ],
    show=false,
  )
  let series = unwrap_contour_series(grouped.series()[0])
  assert_eq(series.get_label(), "contour")
}

///|
test "symplotting plot_contour exposes uniform public contour data" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let backend = plot_contour(
    [
      plot_expr(@symcore.mul([x, y])),
      plot_range(x, @symcore.int(1), @symcore.int(100)),
      plot_range(y, @symcore.int(1), @symcore.int(100)),
    ],
    show=false,
    n=5,
    xscale="log",
    yscale="log",
  )
  let (mesh_x, mesh_y, mesh_z) = backend.get_contour_data(0)
  assert_eq(mesh_x.length(), 5)
  assert_eq(mesh_y.length(), 5)
  assert_eq(mesh_z.length(), 5)
  assert_true(mesh_x[0][1] - mesh_x[0][0] < mesh_x[0][4] - mesh_x[0][3])
  assert_true(mesh_y[1][0] - mesh_y[0][0] < mesh_y[4][0] - mesh_y[3][0])
}

///|
test "symplotting plot_contour rejects the text backend like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  ignore(
    try {
      ignore(
        plot_contour(
          [plot_expr(@symcore.add([x, y]))],
          show=false,
          backend="text",
        ),
      )
      fail("expected backend error")
    } catch {
      PlottingError::TypeError(message) =>
        assert_true(message.contains("plot_contour only supports"))
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting plot_implicit creates default ranges like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.Expr::Relational(
    @symcore.RelOp::Eq,
    @symcore.add([
      @symcore.pow(x, @symcore.int(2)),
      @symcore.pow(y, @symcore.int(2)),
    ]),
    @symcore.int(1),
  )
  let backend = plot_implicit(expr, show=false)
  assert_eq(backend.backend(), "matplotlib")
  let series = unwrap_implicit_series(backend.series()[0])
  let range_symbols = [series.variable_x, series.variable_y]
  assert_true(range_symbols.contains(x))
  assert_true(range_symbols.contains(y))
  assert_eq(series.get_label(), "Eq(x**2 + y**2, 1)")
  assert_eq(backend.xlabel, Some(@symprint.to_string(series.variable_x)))
  assert_eq(backend.ylabel, Some(@symprint.to_string(series.variable_y)))
}

///|
test "symplotting plot_implicit supports explicit ranges and mesh data" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let backend = plot_implicit(
    @symcore.Expr::Relational(@symcore.RelOp::Gt, y, x),
    x_var=Some(@symcore.Expr::Tuple([x, @symcore.int(-2), @symcore.int(2)])),
    y_var=Some(@symcore.Expr::Tuple([y, @symcore.int(-4), @symcore.int(4)])),
    adaptive=false,
    depth=5,
    n=5,
    line_color="green",
    show=false,
  )
  let series = unwrap_implicit_series(backend.series()[0])
  assert_eq(series.line_color, "green")
  assert_eq(series.depth, 8)
  match backend.get_implicit_data(0) {
    ImplicitPlotData::Mesh(mesh_x, mesh_y, mesh_z, plot_type) => {
      assert_eq(plot_type, "contourf")
      assert_eq(mesh_x.length(), 5)
      assert_eq(mesh_y.length(), 5)
      assert_eq(mesh_z.length(), 5)
    }
    ImplicitPlotData::Fill(_) =>
      fail("expected mesh data")
  }
}

///|
test "symplotting plot_implicit handles one-variable expressions like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let backend = plot_implicit(
    @symcore.add([@symcore.pow(x, @symcore.int(2)), @symcore.int(-1)]),
    x_var=Some(@symcore.Expr::Tuple([x, @symcore.int(-5), @symcore.int(5)])),
    show=false,
  )
  let series = unwrap_implicit_series(backend.series()[0])
  assert_true(series.variable_x == x || series.variable_y == x)
  match backend.get_implicit_data(0) {
    ImplicitPlotData::Mesh(mesh_x, mesh_y, mesh_z, plot_type) => {
      assert_eq(plot_type, "contour")
      assert_eq(mesh_x.length(), 300)
      assert_eq(mesh_y.length(), 300)
      assert_eq(mesh_z.length(), 300)
    }
    ImplicitPlotData::Fill(rectangles) =>
      assert_true(rectangles.length() > 0)
  }
}

///|
test "symplotting plot_implicit auto-switches boolean combinations to adaptive fill" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let backend = plot_implicit(
    @symcore.Expr::Function("Or", [
      @symcore.Expr::Relational(@symcore.RelOp::Gt, y, x),
      @symcore.Expr::Relational(
        @symcore.RelOp::Gt,
        y,
        @symcore.mul([@symcore.int(-1), x]),
      ),
    ]),
    adaptive=false,
    show=false,
  )
  let series = unwrap_implicit_series(backend.series()[0])
  assert_eq(series.adaptive, true)
  match backend.get_implicit_data(0) {
    ImplicitPlotData::Fill(rectangles) =>
      assert_true(rectangles.length() > 0)
    ImplicitPlotData::Mesh(_, _, _, _) =>
      fail("expected adaptive fill data")
  }
}

///|
test "symplotting plot_implicit supports n1 n2 and log scales like SymPy series" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let backend = plot_implicit(
    @symcore.Expr::Relational(
      @symcore.RelOp::Gt,
      @symcore.function(
        "cos",
        [
          @symcore.add([
            @symcore.pow(x, @symcore.int(2)),
            @symcore.pow(y, @symcore.int(2)),
          ]),
        ],
      ),
      @symcore.int(0),
    ),
    x_var=Some(@symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(100)])),
    y_var=Some(@symcore.Expr::Tuple([y, @symcore.int(1), @symcore.int(100)])),
    adaptive=false,
    n1=Some(3),
    n2=Some(3),
    xscale="log",
    yscale="log",
    show=false,
  )
  let series = unwrap_implicit_series(backend.series()[0])
  assert_eq(series.n1, 3)
  assert_eq(series.n2, 3)
  match backend.get_implicit_data(0) {
    ImplicitPlotData::Mesh(mesh_x, mesh_y, _, plot_type) => {
      assert_eq(plot_type, "contourf")
      assert_true((mesh_x[0][0] - 1.0).abs() <= 1.0e-12)
      assert_true((mesh_x[0][1] - 10.0).abs() <= 1.0e-10)
      assert_true((mesh_y[0][0] - 1.0).abs() <= 1.0e-12)
      assert_true((mesh_y[1][0] - 10.0).abs() <= 1.0e-10)
    }
    ImplicitPlotData::Fill(_) =>
      fail("expected mesh data")
  }
}

///|
test "symplotting plot_implicit rejects the text backend like SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  ignore(
    try {
      ignore(
        plot_implicit(
          @symcore.Expr::Relational(@symcore.RelOp::Gt, y, x),
          show=false,
          backend="text",
        ),
      )
      fail("expected backend error")
    } catch {
      PlottingError::TypeError(message) =>
        assert_true(message.contains("plot_implicit only supports"))
      _ => fail("unexpected error")
    },
  )
}
