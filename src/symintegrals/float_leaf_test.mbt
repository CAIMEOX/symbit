///|
fn integrals_exact_float_expr(num : Int, den : Int, prec? : Int = 90) -> Expr {
  let rat = @symnum.BigRational::from_ints(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
  let value = @symcore.Float::from_exact(rat, prec~) catch {
    _ => @symcore.Float::from_int(0, prec~)
  }
  @symcore.float(value)
}

///|
fn integrals_exact_complex_float_expr(
  real_num : Int,
  real_den : Int,
  imag_num : Int,
  imag_den : Int,
  prec? : Int = 90,
) -> Expr {
  let real = @symnum.BigRational::from_ints(real_num, real_den) catch {
    _ => @symnum.BigRational::zero()
  }
  let imag = @symnum.BigRational::from_ints(imag_num, imag_den) catch {
    _ => @symnum.BigRational::zero()
  }
  @symcore.complex_float(
    @symcore.ComplexFloat::from_exact_parts(real, imag, prec~),
  )
}

///|
fn integrals_contains_float_leaf(expr : Expr) -> Bool {
  match expr {
    @symcore.Expr::Float(_) | @symcore.Expr::ComplexFloat(_) => true
    _ => @symcore.children(expr).any(integrals_contains_float_leaf)
  }
}

///|
test "symintegrals laplace transform accepts rationalizable float rates" {
  let t = @symcore.symbol("t")
  let s = @symcore.symbol("s")
  let half = integrals_exact_float_expr(1, 2, prec=90)
  let expr = @symelem.exp(@symcore.mul([@symcore.int(-1), half, t]))
  let out = laplace_transform_eval(expr, t, s, noconds=true)
  assert_true(integrals_contains_float_leaf(out))
}

///|
test "symintegrals manual integration keeps float scalar terms" {
  let x = @symcore.symbol("x")
  let half = integrals_exact_float_expr(1, 2, prec=90)
  let expr = @symcore.add([@symcore.pow(x, @symcore.int(2)), half])
  let out = manualintegrate(expr, x)
  assert_true(integrals_contains_float_leaf(out))
}

///|
test "symintegrals quadrature evaluates symbolic parameters via evalf" {
  let alpha = @symelem.sqrt(@symcore.int(2)) * @symelem.sqrt(@symcore.int(2))
  let res = gauss_gen_laguerre(2, alpha, n_digits=10)
  assert_eq(res.0.length(), 2)
  assert_eq(res.1.length(), 2)
}

///|
test "symintegrals manual integration handles complex-float exponential powers" {
  let x = @symcore.symbol("x")
  let exponent = integrals_exact_complex_float_expr(1, 1, 1, 1, prec=100)
  let expr = @symcore.pow(@symelem.exp(x), exponent)
  let out = manualintegrate(expr, x)
  assert_true(integrals_contains_float_leaf(out))
}

///|
test "symintegrals laplace transform handles complex-float decay rates" {
  let t = @symcore.symbol("t")
  let s = @symcore.symbol("s")
  let rate = integrals_exact_complex_float_expr(1, 2, 1, 3, prec=100)
  let expr = @symelem.exp(@symcore.mul([@symcore.int(-1), rate, t]))
  let out = laplace_transform_eval(expr, t, s, noconds=true)
  assert_true(integrals_contains_float_leaf(out))
}
