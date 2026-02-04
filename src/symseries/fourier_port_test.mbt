///|
test "symseries fourier truncate parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("sin", [x])
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.truncate(n=3)
      let sympy = try! @sympy_series.fourier_truncate_str(
        expr,
        "x",
        minus_pi,
        @symcore.symbol("pi"),
        3,
      )
      assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}

///|
test "symseries fourier term parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("sin", [x])
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.term(1)
      let sympy = try! @sympy_series.fourier_term_str(
        expr,
        "x",
        minus_pi,
        @symcore.symbol("pi"),
        1,
      )
      assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}

///|
test "symseries fourier sigma parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("sin", [x])
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.sigma_approximation(3)
      let sympy = try! @sympy_series.fourier_sigma_str(
        expr,
        "x",
        minus_pi,
        @symcore.symbol("pi"),
        3,
      )
      assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}

///|
test "symseries fourier constant expr" {
  let expr = @symcore.int(1)
  let res = try! fourier_series(expr)
  match res {
    FourierSeriesResult::Expr(value) =>
      assert_eq(normalize_series_expr(value), normalize_series_str("1"))
    FourierSeriesResult::Series(_) => fail("expected Expr for constant")
  }
}
