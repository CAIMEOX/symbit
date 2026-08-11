///|
fn normalize_fps_expr(expr : @symcore.Expr) -> String raise {
  let s = @symprint.pretty_string(expr)
  sympy_normalize_str(s)
}

///|
fn normalize_fps_str(s : String) -> String raise {
  sympy_normalize_str(s)
}

///|
test "symseries fps truncate parity" {
  let x = @symcore.Expr::Symbol("x")
  let denom = @symcore.add([
    @symcore.int(1),
    @symcore.mul([@symcore.int(-1), x]),
  ])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let res = fps(expr, x~)
  match res {
    Series(fps_obj) => {
      let ours = fps_obj.truncate(n=5)
      let sympy = fps_truncate_str(expr, "x", @symcore.int(0), 5)
      assert_eq(normalize_fps_expr(ours), normalize_fps_str(sympy))
    }
    Expr(_) => fail("expected FormalPowerSeries")
  }
}

///|
test "symseries fps coeff parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.function("log", [@symcore.add([@symcore.int(1), x])])
  let res = fps(expr, x~)
  match res {
    Series(fps_obj) => {
      let ours = fps_obj.coeff(2)
      let sympy = fps_coeff_str(expr, "x", @symcore.int(0), 2)
      assert_eq(normalize_fps_expr(ours), normalize_fps_str(sympy))
    }
    Expr(_) => fail("expected FormalPowerSeries")
  }
}

///|
test "symseries fps multivar truncate parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.function("exp", [@symcore.add([x, y])])
  let res = fps(expr, x~)
  match res {
    Series(fps_obj) => {
      let ours = fps_obj.truncate(n=4)
      let sympy = fps_truncate_str(expr, "x", @symcore.int(0), 4)
      assert_eq(normalize_fps_expr(ours), normalize_fps_str(sympy))
    }
    Expr(_) => fail("expected FormalPowerSeries")
  }
}

///|
test "symseries fps_multivariate coeff basic" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.function("exp", [@symcore.add([x, y])])
  let fpsm = fps_multivariate(expr, [x, y], x0s=[
    @symcore.int(0),
    @symcore.int(0),
  ])
  let term11 = fpsm.coeff([1, 1])
  let expected11 = @symcore.mul([x, y])
  assert_true(
    sympy_equiv_str(
      @symprint.pretty_string(term11),
      @symprint.pretty_string(expected11),
    ),
  )
  let term20 = fpsm.coeff([2, 0])
  let expected20 = @symcore.rational_from_ints(1, 2)
  let expected_expr = @symcore.mul([
    expected20,
    @symcore.pow(x, @symcore.int(2)),
  ])
  assert_true(
    sympy_equiv_str(
      @symprint.pretty_string(term20),
      @symprint.pretty_string(expected_expr),
    ),
  )
}

///|
test "symseries fps_multivariate coeff nonzero centers" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.add([
    @symcore.mul([x, y]),
    @symcore.pow(x, @symcore.int(2)),
  ])
  let fpsm = fps_multivariate(expr, [x, y], x0s=[
    @symcore.int(1),
    @symcore.int(2),
  ])
  let term11 = fpsm.coeff([1, 1])
  let expected = @symcore.mul([
    @symcore.add([x, @symcore.int(-1)]),
    @symcore.add([y, @symcore.int(-2)]),
  ])
  assert_eq(normalize_fps_expr(term11), normalize_fps_expr(expected))
}
