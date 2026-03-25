///|
test "expr float constructor participates in add and mul folding" {
  let quarter = Float::from_str("0.25", prec=90) catch { _ => fail("float") }
  let sum_expr = add([int(1), float(quarter)])
  match sum_expr {
    Expr::Float(f) => assert_eq(f.to_rational(), (5N, 4N))
    _ => fail("expected float sum")
  }

  let prod_expr = mul([rational_from_ints(3, 2), float(quarter)])
  match prod_expr {
    Expr::Float(f) => assert_eq(f.to_rational(), (3N, 8N))
    _ => fail("expected float product")
  }
}

///|
test "evalf converts exact numeric expressions and constants" {
  let sqrt4 = evalf(function("sqrt", [int(4)]), prec=80)
  match sqrt4 {
    Expr::Float(f) => assert_eq(f.to_rational(), (2N, 1N))
    _ => fail("expected float sqrt")
  }

  let pi_expr = evalf(pi(), prec=90)
  match pi_expr {
    Expr::Float(f) => {
      assert_true(f.is_finite())
      assert_true(f.format().has_prefix("3.14159"))
    }
    _ => fail("expected float pi")
  }
}

///|
test "evalf numerically evaluates powers and unary functions" {
  let sqrt2 = evalf(pow(int(2), rational_from_ints(1, 2)), prec=120)
  match sqrt2 {
    Expr::Float(f) => assert_true(f.format(dps=16).has_prefix("1.414213562"))
    _ => fail("expected float sqrt(2)")
  }

  let exp0 = evalf(function("exp", [int(0)]), prec=80)
  match exp0 {
    Expr::Float(f) => assert_eq(f.to_rational(), (1N, 1N))
    _ => fail("expected float exp(0)")
  }
}

///|
test "evalf produces complex values for I and branch-cut functions" {
  let imag_unit = evalf(imag_unit(), prec=90)
  match imag_unit {
    Expr::ComplexFloat(z) => {
      assert_true(@symnum.is_zero(z.to_mpc().real))
      assert_true(@symnum.mpf_eq(z.to_mpc().imag, @symnum.fone))
    }
    _ => fail("expected complex I")
  }

  let sqrt_minus_one = evalf(function("sqrt", [int(-1)]), prec=90)
  match sqrt_minus_one {
    Expr::ComplexFloat(z) => {
      assert_true(@symnum.is_zero(z.to_mpc().real))
      assert_true(z.imag_part().format(dps=12).has_prefix("1.0"))
    }
    _ => fail("expected complex sqrt(-1)")
  }

  let log_minus_one = evalf(function("log", [int(-1)]), prec=90)
  match log_minus_one {
    Expr::ComplexFloat(z) => {
      assert_true(@symnum.is_zero(z.to_mpc().real))
      assert_true(z.imag_part().format(dps=10).has_prefix("3.14159"))
    }
    _ => fail("expected complex log(-1)")
  }
}

///|
test "evalf handles complex transcendental functions" {
  let z = add([int(1), imag_unit()])
  let gamma_z = evalf(function("gamma", [z]), prec=100)
  match gamma_z {
    Expr::ComplexFloat(value) => assert_true(value.is_finite())
    _ => fail("expected complex gamma")
  }

  let abs_expr = evalf(
    function("Abs", [add([int(1), mul([int(2), imag_unit()])])]),
    prec=100,
  )
  match abs_expr {
    Expr::Float(f) => assert_true(f.format(dps=12).has_prefix("2.236067977"))
    _ => fail("expected real abs")
  }

  let sin_i = evalf(function("sin", [imag_unit()]), prec=100)
  match sin_i {
    Expr::ComplexFloat(value) => {
      assert_true(@symnum.is_zero(value.to_mpc().real))
      assert_true(value.imag_part().format(dps=12).has_prefix("1.175201193"))
    }
    _ => fail("expected complex sin(I)")
  }
}
