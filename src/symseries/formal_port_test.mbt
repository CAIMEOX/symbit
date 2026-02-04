///|
fn normalize_fps_expr(expr : @symcore.Expr) -> String {
  let s = @symprint.to_string(expr)
  try! @sympy_series.sympy_normalize_str(s)
}

///|
fn normalize_fps_str(s : String) -> String {
  try! @sympy_series.sympy_normalize_str(s)
}

///|
test "symseries fps truncate parity" {
  let x = @symcore.symbol("x")
  let denom = @symcore.add([
    @symcore.int(1),
    @symcore.mul([@symcore.int(-1), x]),
  ])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let res = try! fps(expr, x~)
  match res {
    FpsResult::Series(fps_obj) => {
      let ours = try! fps_obj.truncate(n=5)
      let sympy = try! @sympy_series.fps_truncate_str(
        expr,
        "x",
        @symcore.int(0),
        5,
      )
      assert_eq(normalize_fps_expr(ours), normalize_fps_str(sympy))
    }
    FpsResult::Expr(_) => fail("expected FormalPowerSeries")
  }
}

///|
test "symseries fps coeff parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("log", [@symcore.add([@symcore.int(1), x])])
  let res = try! fps(expr, x~)
  match res {
    FpsResult::Series(fps_obj) => {
      let ours = try! fps_obj.coeff(2)
      let sympy = try! @sympy_series.fps_coeff_str(
        expr,
        "x",
        @symcore.int(0),
        2,
      )
      assert_eq(normalize_fps_expr(ours), normalize_fps_str(sympy))
    }
    FpsResult::Expr(_) => fail("expected FormalPowerSeries")
  }
}

///|
test "symseries fps multivar truncate parity" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.function("exp", [@symcore.add([x, y])])
  let res = try! fps(expr, x~)
  match res {
    FpsResult::Series(fps_obj) => {
      let ours = try! fps_obj.truncate(n=4)
      let sympy = try! @sympy_series.fps_truncate_str(
        expr,
        "x",
        @symcore.int(0),
        4,
      )
      assert_eq(normalize_fps_expr(ours), normalize_fps_str(sympy))
    }
    FpsResult::Expr(_) => fail("expected FormalPowerSeries")
  }
}
