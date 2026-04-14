///|
fn plot_complex_float(real : Double, imag : Double) -> @symcore.Expr {
  @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_real(
      @symcore.Float::from_double(real, prec=80),
      imag=@symcore.Float::from_double(imag, prec=80),
    ),
  )
}

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
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
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

///|
test "symplotting line series supports complex ranges with constant imaginary part" {
  let x = @symcore.Expr::Symbol("x")
  let series = line_over_1d_range_series(
    x,
    @symcore.Expr::Tuple([
      x,
      plot_complex_float(-1.0, -2.0),
      plot_complex_float(1.0, -2.0),
    ]),
    n=3,
    return_mode=Some("imag"),
  )
  let (xs, ys) = series.get_data()
  assert_eq(xs, [-1.0, 0.0, 1.0])
  assert_eq(ys, [Some(-2.0), Some(-2.0), Some(-2.0)])
}

///|
test "symplotting line series samples polynomial curves across interior points" {
  let x = @symcore.Expr::Symbol("x")
  let series = line_over_1d_range_series(
    @symcore.add([
      @symcore.pow(x, @symcore.int(3)),
      @symcore.mul([@symcore.int(-3), x]),
    ]),
    @symcore.Expr::Tuple([x, @symcore.int(-4), @symcore.int(4)]),
    n=5,
  )
  let (xs, ys) = series.get_data()
  assert_eq(xs, [-4.0, -2.0, 0.0, 2.0, 4.0])
  let expected = [-52.0, -2.0, 0.0, 2.0, 52.0]
  for i in 0..<expected.length() {
    match ys[i] {
      Some(value) => assert_true((value - expected[i]).abs() <= 1.0e-9)
      None => fail("expected numeric cubic sample")
    }
  }
}

///|
test "symplotting line series samples non-integer polynomial points correctly" {
  let x = @symcore.Expr::Symbol("x")
  let series = line_over_1d_range_series(
    @symcore.add([
      @symcore.pow(x, @symcore.int(3)),
      @symcore.mul([@symcore.int(-3), x]),
    ]),
    @symcore.Expr::Tuple([x, @symcore.int(-4), @symcore.int(4)]),
    n=1000,
  )
  let (xs, ys) = series.get_data()
  let sample_indices = [1, 127, 500, 872, 998]
  for index in sample_indices {
    let expected = xs[index] * xs[index] * xs[index] - 3.0 * xs[index]
    match ys[index] {
      Some(value) => assert_true((value - expected).abs() <= 1.0e-8)
      None => fail("expected numeric non-integer cubic sample")
    }
  }
}

///|
test "symplotting line series rejects complex ranges with mismatched imaginary part" {
  let x = @symcore.Expr::Symbol("x")
  ignore(
    try {
      ignore(
        line_over_1d_range_series(
          x,
          @symcore.Expr::Tuple([
            x,
            plot_complex_float(-1.0, -2.0),
            plot_complex_float(1.0, 2.0),
          ]),
          n=3,
        ).get_data(),
      )
      fail("expected complex range mismatch error")
    } catch {
      PlottingError::ValueError(message) =>
        assert_true(
          message.contains("imaginary part of the start and end values"),
        )
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting line series adaptive sampling generates dense public data" {
  let x = @symcore.Expr::Symbol("x")
  let series = line_over_1d_range_series(
    @symcore.function("sin", [x]),
    @symcore.Expr::Tuple([x, @symcore.int(-10), @symcore.int(10)]),
    adaptive=true,
    n=30,
  )
  let (xs, ys) = series.get_data()
  assert_true(xs.length() >= 30)
  assert_eq(xs.length(), ys.length())
}

///|
test "symplotting parametric series samples uniformly on a linear range" {
  let x = @symcore.Expr::Symbol("x")
  let series = parametric_2d_line_series(
    x,
    @symcore.pow(x, @symcore.int(2)),
    @symcore.Expr::Tuple([x, @symcore.int(0), @symcore.int(4)]),
    adaptive=false,
    n=5,
  )
  let (xs, ys, params) = series.get_data()
  assert_eq(params.length(), 5)
  assert_eq(params[0], 0.0)
  assert_eq(params[2], 2.0)
  assert_eq(params[4], 4.0)
  assert_eq(xs[2], Some(2.0))
  assert_eq(ys[2], Some(4.0))
}

///|
test "symplotting parametric series supports logarithmic parameter spacing" {
  let x = @symcore.Expr::Symbol("x")
  let series = parametric_2d_line_series(
    @symcore.function("cos", [x]),
    @symcore.function("sin", [x]),
    @symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(100)]),
    adaptive=false,
    n=3,
    xscale="log",
  )
  let (_, _, params) = series.get_data()
  assert_true((params[0] - 1.0).abs() <= 1.0e-12)
  assert_true((params[1] - 10.0).abs() <= 1.0e-10)
  assert_true((params[2] - 100.0).abs() <= 1.0e-8)
}

///|
test "symplotting parametric series adaptive sampling generates dense public data" {
  let x = @symcore.Expr::Symbol("x")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let series = parametric_2d_line_series(
    @symcore.function("cos", [x]),
    @symcore.function("sin", [x]),
    @symcore.Expr::Tuple([
      x,
      @symcore.int(0),
      @symcore.mul([@symcore.int(2), pi]),
    ]),
    adaptive=true,
    n=30,
  )
  let (xs, ys, params) = series.get_data()
  assert_true(xs.length() >= 30)
  assert_eq(xs.length(), ys.length())
  assert_eq(xs.length(), params.length())
}

///|
test "symplotting 3d parametric series samples uniformly on a linear range" {
  let x = @symcore.Expr::Symbol("x")
  let series = parametric_3d_line_series(
    x,
    @symcore.pow(x, @symcore.int(2)),
    @symcore.pow(x, @symcore.int(3)),
    @symcore.Expr::Tuple([x, @symcore.int(0), @symcore.int(4)]),
    n=5,
  )
  let (xs, ys, zs, params) = series.get_data()
  assert_eq(params.length(), 5)
  assert_eq(params[2], 2.0)
  assert_eq(xs[2], Some(2.0))
  assert_eq(ys[2], Some(4.0))
  assert_eq(zs[2], Some(8.0))
  assert_false(series.adaptive)
}

///|
test "symplotting 3d parametric series supports logarithmic parameter spacing" {
  let x = @symcore.Expr::Symbol("x")
  let series = parametric_3d_line_series(
    @symcore.function("cos", [x]),
    @symcore.function("sin", [x]),
    x,
    @symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(100)]),
    n=3,
    xscale="log",
  )
  let (_, _, _, params) = series.get_data()
  assert_true((params[0] - 1.0).abs() <= 1.0e-12)
  assert_true((params[1] - 10.0).abs() <= 1.0e-10)
  assert_true((params[2] - 100.0).abs() <= 1.0e-8)
}

///|
test "symplotting surface series samples uniformly on linear ranges" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let series = surface_over_2d_range_series(
    @symcore.add([x, y]),
    @symcore.Expr::Tuple([x, @symcore.int(0), @symcore.int(2)]),
    @symcore.Expr::Tuple([y, @symcore.int(0), @symcore.int(4)]),
    n1=3,
    n2=5,
  )
  let (mesh_x, mesh_y, mesh_z) = series.get_data()
  assert_eq(mesh_x.length(), 5)
  assert_eq(mesh_y.length(), 5)
  assert_eq(mesh_z.length(), 5)
  assert_eq(mesh_x[0].length(), 3)
  assert_eq(mesh_x[0][1], 1.0)
  assert_eq(mesh_y[2][0], 2.0)
  assert_eq(mesh_z[2][1], Some(3.0))
}

///|
test "symplotting surface series supports logarithmic discretization on both axes" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let series = surface_over_2d_range_series(
    @symcore.mul([x, y]),
    @symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(100)]),
    @symcore.Expr::Tuple([y, @symcore.int(1), @symcore.int(100)]),
    n1=3,
    n2=3,
    xscale="log",
    yscale="log",
  )
  let (mesh_x, mesh_y, _) = series.get_data()
  assert_true((mesh_x[0][0] - 1.0).abs() <= 1.0e-12)
  assert_true((mesh_x[0][1] - 10.0).abs() <= 1.0e-10)
  assert_true((mesh_x[0][2] - 100.0).abs() <= 1.0e-8)
  assert_true((mesh_y[0][0] - 1.0).abs() <= 1.0e-12)
  assert_true((mesh_y[1][0] - 10.0).abs() <= 1.0e-10)
  assert_true((mesh_y[2][0] - 100.0).abs() <= 1.0e-8)
}

///|
test "symplotting parametric surface series samples uniformly on linear ranges" {
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  let series = parametric_surface_series(
    u,
    v,
    @symcore.add([u, v]),
    @symcore.Expr::Tuple([u, @symcore.int(0), @symcore.int(2)]),
    @symcore.Expr::Tuple([v, @symcore.int(0), @symcore.int(4)]),
    n1=3,
    n2=5,
  )
  let (mesh_x, mesh_y, mesh_z, mesh_u, mesh_v) = series.get_data()
  assert_eq(mesh_x.length(), 5)
  assert_eq(mesh_x[0].length(), 3)
  assert_eq(mesh_u[0][1], 1.0)
  assert_eq(mesh_v[2][0], 2.0)
  assert_eq(mesh_x[2][1], Some(1.0))
  assert_eq(mesh_y[2][1], Some(2.0))
  assert_eq(mesh_z[2][1], Some(3.0))
}

///|
test "symplotting parametric surface series supports logarithmic parameter spacing" {
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  let series = parametric_surface_series(
    @symcore.function("cos", [u]),
    @symcore.function("sin", [v]),
    @symcore.add([u, v]),
    @symcore.Expr::Tuple([u, @symcore.int(1), @symcore.int(100)]),
    @symcore.Expr::Tuple([v, @symcore.int(1), @symcore.int(100)]),
    n1=3,
    n2=3,
    xscale="log",
    yscale="log",
  )
  let (_, _, _, mesh_u, mesh_v) = series.get_data()
  assert_true((mesh_u[0][0] - 1.0).abs() <= 1.0e-12)
  assert_true((mesh_u[0][1] - 10.0).abs() <= 1.0e-10)
  assert_true((mesh_u[0][2] - 100.0).abs() <= 1.0e-8)
  assert_true((mesh_v[0][0] - 1.0).abs() <= 1.0e-12)
  assert_true((mesh_v[1][0] - 10.0).abs() <= 1.0e-10)
  assert_true((mesh_v[2][0] - 100.0).abs() <= 1.0e-8)
}

///|
test "symplotting implicit series samples a cartesian mesh for equalities" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let series = implicit_series(
    @symcore.Relational(
      @symcore.RelOp::Eq,
      @symcore.add([x, y]),
      @symcore.int(0),
    ),
    @symcore.Expr::Tuple([x, @symcore.int(-1), @symcore.int(1)]),
    @symcore.Expr::Tuple([y, @symcore.int(-2), @symcore.int(2)]),
    adaptive=false,
    n=3,
  )
  match series.get_data() {
    ImplicitPlotData::Mesh(mesh_x, mesh_y, mesh_z, plot_type) => {
      assert_eq(plot_type, "contour")
      assert_eq(mesh_x.length(), 3)
      assert_eq(mesh_x[0].length(), 3)
      assert_eq(mesh_x[0][1], 0.0)
      assert_eq(mesh_y[1][0], 0.0)
      assert_eq(mesh_z[1][1], Some(0.0))
    }
    ImplicitPlotData::Fill(_) => fail("expected mesh data")
  }
}

///|
test "symplotting implicit series adaptive path returns fill rectangles" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let series = implicit_series(
    @symcore.Relational(@symcore.RelOp::Gt, y, x),
    @symcore.Expr::Tuple([x, @symcore.int(-1), @symcore.int(1)]),
    @symcore.Expr::Tuple([y, @symcore.int(-1), @symcore.int(1)]),
    adaptive=true,
    n=3,
  )
  match series.get_data() {
    ImplicitPlotData::Fill(rectangles) => {
      assert_true(rectangles.length() > 0)
      assert_true(rectangles.any(rect => rect.y_end > rect.x_start))
    }
    ImplicitPlotData::Mesh(_, _, _, _) => fail("expected adaptive fill data")
  }
  assert_eq(series.depth, 4)
  assert_eq(series.line_color, "blue")
}

///|
test "symplotting implicit series auto-switches boolean expressions to adaptive" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let series = implicit_series(
    @symcore.Expr::Function("And", [
      @symcore.Expr::Relational(@symcore.RelOp::Gt, y, x),
      @symcore.Expr::Relational(
        @symcore.RelOp::Gt,
        y,
        @symcore.mul([@symcore.int(-1), x]),
      ),
    ]),
    @symcore.Expr::Tuple([x, @symcore.int(-2), @symcore.int(2)]),
    @symcore.Expr::Tuple([y, @symcore.int(-2), @symcore.int(2)]),
    adaptive=false,
  )
  assert_eq(series.adaptive, true)
}

///|
test "symplotting implicit series supports independent discretization and log scales" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let series = implicit_series(
    @symcore.Expr::Relational(
      @symcore.RelOp::Gt,
      @symcore.function("cos", [
        @symcore.add([
          @symcore.pow(x, @symcore.int(2)),
          @symcore.pow(y, @symcore.int(2)),
        ]),
      ]),
      @symcore.int(0),
    ),
    @symcore.Expr::Tuple([x, @symcore.int(1), @symcore.int(100)]),
    @symcore.Expr::Tuple([y, @symcore.int(1), @symcore.int(100)]),
    adaptive=false,
    n1=Some(3),
    n2=Some(3),
    xscale="log",
    yscale="log",
  )
  match series.get_data() {
    ImplicitPlotData::Mesh(mesh_x, mesh_y, _, plot_type) => {
      assert_eq(plot_type, "contourf")
      assert_true((mesh_x[0][0] - 1.0).abs() <= 1.0e-12)
      assert_true((mesh_x[0][1] - 10.0).abs() <= 1.0e-10)
      assert_true((mesh_x[0][2] - 100.0).abs() <= 1.0e-8)
      assert_true((mesh_y[0][0] - 1.0).abs() <= 1.0e-12)
      assert_true((mesh_y[1][0] - 10.0).abs() <= 1.0e-10)
      assert_true((mesh_y[2][0] - 100.0).abs() <= 1.0e-8)
    }
    ImplicitPlotData::Fill(_) => fail("expected mesh data")
  }
}

///|
test "symplotting implicit series adaptive path handles SymPy pi over x family and Ne" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let oscillatory = implicit_series(
    @symcore.add([
      y,
      @symcore.mul([
        @symcore.int(-1),
        @symcore.function("cos", [
          @symcore.mul([pi, @symcore.pow(x, @symcore.int(-1))]),
        ]),
      ]),
    ]),
    @symcore.Expr::Tuple([x, @symcore.int(-5), @symcore.int(5)]),
    @symcore.Expr::Tuple([y, @symcore.int(-2), @symcore.int(2)]),
    adaptive=true,
  )
  match oscillatory.get_data() {
    ImplicitPlotData::Fill(rectangles) => assert_true(rectangles.length() > 0)
    ImplicitPlotData::Mesh(_, _, _, _) => fail("expected adaptive fill data")
  }

  let not_equal = implicit_series(
    @symcore.Expr::Relational(@symcore.RelOp::Ne, y, x),
    @symcore.Expr::Tuple([x, @symcore.int(-1), @symcore.int(1)]),
    @symcore.Expr::Tuple([y, @symcore.int(-1), @symcore.int(1)]),
    adaptive=false,
  )
  assert_eq(not_equal.adaptive, true)
  match not_equal.get_data() {
    ImplicitPlotData::Fill(rectangles) => assert_true(rectangles.length() > 0)
    ImplicitPlotData::Mesh(_, _, _, _) => fail("expected adaptive fill data")
  }
}

///|
test "symplotting implicit series adaptive path handles SymPy Not and Xor regions" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let base = @symcore.Expr::Relational(
    @symcore.RelOp::Lt,
    @symcore.add([
      @symcore.pow(@symcore.add([x, @symcore.int(-1)]), @symcore.int(2)),
      @symcore.pow(y, @symcore.int(2)),
    ]),
    @symcore.int(2),
  )
  let other = @symcore.Expr::Relational(
    @symcore.RelOp::Lt,
    @symcore.add([
      @symcore.pow(@symcore.add([x, @symcore.int(1)]), @symcore.int(2)),
      @symcore.pow(y, @symcore.int(2)),
    ]),
    @symcore.int(2),
  )
  let inverted = implicit_series(
    @symcore.Expr::Function("Not", [base]),
    @symcore.Expr::Tuple([x, @symcore.int(-3), @symcore.int(3)]),
    @symcore.Expr::Tuple([y, @symcore.int(-3), @symcore.int(3)]),
    adaptive=true,
  )
  match inverted.get_data() {
    ImplicitPlotData::Fill(rectangles) => assert_true(rectangles.length() > 0)
    ImplicitPlotData::Mesh(_, _, _, _) => fail("expected adaptive fill data")
  }

  let exclusive = implicit_series(
    @symcore.Expr::Function("Xor", [base, other]),
    @symcore.Expr::Tuple([x, @symcore.int(-3), @symcore.int(3)]),
    @symcore.Expr::Tuple([y, @symcore.int(-3), @symcore.int(3)]),
    adaptive=true,
  )
  match exclusive.get_data() {
    ImplicitPlotData::Fill(rectangles) => assert_true(rectangles.length() > 0)
    ImplicitPlotData::Mesh(_, _, _, _) => fail("expected adaptive fill data")
  }
}
