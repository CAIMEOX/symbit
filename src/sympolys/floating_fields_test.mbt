///|
test "CC evalf_expr returns complex float expressions" {
  let half = match
    (
      try? @symcore.rational_from_ints(1, 2) :
      Result[@symcore.Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => fail("half")
  }
  let three_quarters = match
    (
      try? @symcore.rational_from_ints(3, 4) :
      Result[@symcore.Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => fail("three_quarters")
  }
  let expr = @symcore.add([
    half,
    @symcore.mul([three_quarters, @symcore.symbol("I")]),
  ])
  let evaled = match
    (
      try? Domain::CC.evalf_expr(expr, prec=Some(110)) :
      Result[@symcore.Expr, PolyError]) {
    Ok(value) => value
    Err(_) => fail("cc evalf")
  }
  match evaled {
    @symcore.Expr::ComplexFloat(z) => assert_eq(z.precision(), 110)
    _ => fail("expected complex float")
  }
  assert_true(domain_almosteq_expr(Domain::CC, evaled, expr))
}

///|
test "RealField object carries precision and evaluates to float leaves" {
  let rr = RealField::new(precision=85)
  let expr = match
    (
      try? @symcore.rational_from_ints(1, 3) :
      Result[@symcore.Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => fail("third")
  }
  let evaled = match
    (try? rr.evalf_expr(expr) : Result[@symcore.Expr, PolyError]) {
    Ok(value) => value
    Err(_) => fail("rr evalf")
  }
  match rr.domain() {
    Domain::RR => ()
    _ => fail("expected RR domain")
  }
  match evaled {
    @symcore.Expr::Float(f) => {
      assert_eq(rr.precision(), 85)
      assert_eq(f.precision(), 85)
    }
    _ => fail("expected float")
  }
}

///|
test "ComplexField object evaluates gaussian rationals to complex float expressions" {
  let cc = ComplexField::new(precision=95)
  let quarter = match
    (
      try? @symcore.rational_from_ints(1, 4) :
      Result[@symcore.Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => fail("quarter")
  }
  let minus_half = match
    (
      try? @symcore.rational_from_ints(-1, 2) :
      Result[@symcore.Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => fail("minus_half")
  }
  let expr = @symcore.add([
    quarter,
    @symcore.mul([minus_half, @symcore.symbol("I")]),
  ])
  let evaled = match
    (try? cc.evalf_expr(expr) : Result[@symcore.Expr, PolyError]) {
    Ok(value) => value
    Err(_) => fail("cc field evalf")
  }
  match cc.domain() {
    Domain::CC => ()
    _ => fail("expected CC domain")
  }
  assert_eq(cc.precision(), 95)
  match evaled {
    @symcore.Expr::ComplexFloat(z) => assert_eq(z.precision(), 95)
    _ => fail("expected complex float")
  }
  assert_true(domain_almosteq_expr(Domain::CC, evaled, expr))
}

///|
test "floating field objects expose native coercion and arithmetic" {
  let rr = RealField::new(precision=80)
  let third = rr.from_exact(
    @symnum.BigRational::from_ints(1, 3) catch {
      _ => fail("third")
    },
  )
  let sum = rr.add(third, third) catch { _ => fail("rr add") }
  match sum {
    @symcore.Expr::Float(f) =>
      assert_true(f.format(dps=12).has_prefix("0.666666666"))
    _ => fail("expected float sum")
  }

  let cc = ComplexField::new(precision=90)
  let z = cc.from_exact_parts(
    @symnum.BigRational::from_ints(1, 2) catch {
      _ => fail("real")
    },
    @symnum.BigRational::from_ints(3, 4) catch {
      _ => fail("imag")
    },
  )
  let conj = cc.conjugate(z) catch { _ => fail("conjugate") }
  match conj {
    @symcore.Expr::ComplexFloat(value) => {
      assert_true(value.real_part().format(dps=8).has_prefix("0.5"))
      assert_true(value.imag_part().format(dps=8).has_prefix("-0.75"))
    }
    _ => fail("expected complex float conjugate")
  }
}
