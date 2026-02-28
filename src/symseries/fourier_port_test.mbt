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

///|
test "symseries fourier generic polynomial term parity" {
  let x = @symcore.symbol("x")
  let expr = x
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.term(2)
      let sympy = try! @sympy_series.fourier_term_str(
        expr,
        "x",
        minus_pi,
        @symcore.symbol("pi"),
        2,
      )
      assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))

      let an2 = try! fs.an(2)
      let bn2 = try! fs.bn(2)
      let w2 = @symcore.mul([@symcore.int(2), x])
      let reconstructed = @symcore.add([
        @symcore.mul([an2, @symcore.function("cos", [w2])]),
        @symcore.mul([bn2, @symcore.function("sin", [w2])]),
      ])
      assert_eq(
        normalize_series_expr(ours),
        normalize_series_expr(reconstructed),
      )
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}

///|
test "symseries fourier generic interval parity" {
  let x = @symcore.symbol("x")
  let expr = x
  let limits = [x, @symcore.int(0), @symcore.int(1)]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.truncate(n=3)
      let sympy = try! @sympy_series.fourier_truncate_str(
        expr,
        "x",
        @symcore.int(0),
        @symcore.int(1),
        3,
      )
      assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}

///|
test "symseries fourier shifted trig parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("sin", [
    @symcore.add([@symcore.mul([@symcore.int(2), x]), @symcore.int(1)]),
  ])
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.term(3)
      let sympy = try! @sympy_series.fourier_term_str(
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
test "symseries fourier poly shifted trig parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.mul([
    x,
    @symcore.function("cos", [
      @symcore.add([@symcore.mul([@symcore.int(2), x]), @symcore.int(1)]),
    ]),
  ])
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.term(2)
      let sympy = try! @sympy_series.fourier_term_str(
        expr,
        "x",
        minus_pi,
        @symcore.symbol("pi"),
        2,
      )
      assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}

///|
test "symseries fourier exp closed form parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("exp", [x])
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.term(2)
      let sympy = try! @sympy_series.fourier_term_str(
        expr,
        "x",
        minus_pi,
        @symcore.symbol("pi"),
        2,
      )
      assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}

///|
test "symseries fourier hyperbolic closed form parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("sinh", [x])
  let minus_pi = @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])
  let limits = [x, minus_pi, @symcore.symbol("pi")]
  let res = try! fourier_series(expr, limits~)
  match res {
    FourierSeriesResult::Series(fs) => {
      let ours = try! fs.term(2)
      let sympy = try! @sympy_series.fourier_term_str(
        expr,
        "x",
        minus_pi,
        @symcore.symbol("pi"),
        2,
      )
      let ours_s = try! @sympy_series.sympy_simplify_str(@symprint.to_string(ours))
      let sympy_s = try! @sympy_series.sympy_simplify_str(sympy)
      assert_eq(normalize_series_str(ours_s), normalize_series_str(sympy_s))
    }
    FourierSeriesResult::Expr(_) => fail("expected FourierSeries")
  }
}
