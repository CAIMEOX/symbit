///|
fn series_exact_float_expr(
  num : Int,
  den : Int,
  prec? : Int = 90,
) -> @symcore.Expr {
  let rat = @symnum.BigRational::from_ints(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
  let value = @symcore.Float::from_exact(rat, prec=prec) catch {
    _ => @symcore.Float::from_int(0, prec=prec)
  }
  @symcore.float(value)
}

///|
fn series_exact_complex_float_expr(
  real_num : Int,
  real_den : Int,
  imag_num : Int,
  imag_den : Int,
  prec? : Int = 90,
) -> @symcore.Expr {
  let real = @symnum.BigRational::from_ints(real_num, real_den) catch {
    _ => @symnum.BigRational::zero()
  }
  let imag = @symnum.BigRational::from_ints(imag_num, imag_den) catch {
    _ => @symnum.BigRational::zero()
  }
  @symcore.complex_float(
    @symcore.ComplexFloat::from_exact_parts(real, imag, prec=prec),
  )
}

///|
fn series_contains_float_leaf(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Float(_) | @symcore.Expr::ComplexFloat(_) => true
    _ => @symcore.children(expr).any(series_contains_float_leaf)
  }
}

///|
fn series_contains_function_named(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Function(found, _) if found == name => true
    _ => @symcore.children(expr).any(child => series_contains_function_named(child, name))
  }
}

fn series_eval_finite(
  expr : @symcore.Expr,
  var_name : String,
  sample : @symcore.Expr,
  prec? : Int = 120,
) -> Bool {
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = sample
  match @symcore.evalf(@symcore.subst(expr, env), prec=prec) {
    @symcore.Expr::Number(_) => true
    @symcore.Expr::Float(value) => value.is_finite()
    @symcore.Expr::ComplexFloat(value) => value.is_finite()
    _ => false
  }
}

///|
test "symseries series keeps float leaves in polynomial expansions" {
  let x = @symcore.symbol("x")
  let half = series_exact_float_expr(1, 2, prec=80)
  let out = series(@symcore.add([x, half]), x~, n=5)
  assert_true(series_contains_float_leaf(out))
}

///|
test "symseries fps handles float geometric coefficients" {
  let x = @symcore.symbol("x")
  let half = series_exact_float_expr(1, 2, prec=80)
  let expr = @symcore.pow(
    @symcore.add([
      @symcore.int(1),
      @symcore.mul([@symcore.int(-1), half, x]),
    ]),
    @symcore.int(-1),
  )
  let res = fps(expr, x~)
  match res {
    FpsResult::Series(fps_obj) => {
      let truncated = fps_obj.truncate(n=4)
      assert_true(series_contains_float_leaf(truncated))
    }
    FpsResult::Expr(_) => fail("expected FormalPowerSeries")
  }
}

///|
test "symseries series numerically expands constant complex shifts" {
  let x = @symcore.symbol("x")
  let shift = series_exact_complex_float_expr(0, 1, 1, 1, prec=100)
  let out = series(
    @symcore.function("sin", [@symcore.add([shift, x])]),
    x~,
    n=4,
  )
  assert_true(series_contains_float_leaf(out))
  assert_false(series_contains_function_named(out, "sin"))
}

///|
test "symseries pade approximant handles complex float rates" {
  let x = @symcore.symbol("x")
  let rate = series_exact_complex_float_expr(1, 1, 1, 1, prec=100)
  let expr = @symcore.function("exp", [@symcore.mul([rate, x])])
  let approx = pade_approximant(expr, x, m=1, n=1)
  let approx_ser = series(approx, x~, n=3)
  assert_true(series_contains_float_leaf(approx_ser))
  assert_true(series_eval_finite(approx, "x", series_exact_float_expr(1, 10, prec=120)))
  assert_true(series_eval_finite(approx, "x", series_exact_float_expr(-1, 10, prec=120)))
}

///|
test "symseries sequence coeff evaluates numeric transcendental forms to complex float" {
  let n = @symcore.symbol("n")
  let rate = series_exact_complex_float_expr(1, 1, 1, 1, prec=100)
  let seq = sequence(
    @symcore.function("exp", [@symcore.mul([rate, n])]),
    var_name="n",
    start=0,
    stop=5,
  )
  match seq.coeff(2) {
    @symcore.Expr::ComplexFloat(value) => assert_true(value.is_finite())
    _ => fail("expected complex float sequence value")
  }
}
