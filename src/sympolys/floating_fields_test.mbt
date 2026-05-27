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
    @symcore.mul([
      three_quarters,
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
    ]),
  ])
  let evaled = match
    (
      try? Domain::CC.evalf_expr(expr, prec=Some(110)) :
      Result[@symcore.Expr, PolyError]) {
    Ok(value) => value
    Err(_) => fail("cc evalf")
  }
  match evaled {
    @symcore.Expr::ComplexFloat(z) => assert_true(z.precision() == 110)
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
      assert_true(rr.precision() == 85)
      assert_true(f.precision() == 85)
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
    @symcore.mul([
      minus_half,
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
    ]),
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
  assert_true(cc.precision() == 95)
  match evaled {
    @symcore.Expr::ComplexFloat(z) => assert_true(z.precision() == 95)
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

///|
fn floating_pair_text(pair : (BigInt, BigInt)) -> String {
  let (num, den) = pair
  "(\{num}, \{den})"
}

///|
test "to_rational limits dyadic float denominators" {
  let pi5 = @symcore.Float::from_str("3.14159") catch { _ => fail("float") }
  inspect(floating_pair_text(to_rational(pi5, 10N)), content="(22, 7)")
  inspect(floating_pair_text(to_rational(pi5, 100N)), content="(311, 99)")
  inspect(floating_pair_text(to_rational(pi5, 1000N)), content="(355, 113)")
  inspect(
    floating_pair_text(to_rational(pi5, 10N, limit=false)),
    content="(3537115888337719, 1125899906842624)",
  )
}

///|
test "to_rational handles signs and field precision caps" {
  let neg = @symcore.Float::from_str("-0.3333333333333333") catch {
    _ => fail("negative")
  }
  inspect(floating_pair_text(to_rational(neg, 10N)), content="(-1, 3)")
  let rr = RealField::new()
  let third = @symcore.Float::from_str("0.3333333333333333") catch {
    _ => fail("third")
  }
  inspect(floating_pair_text(rr.to_rational(third)), content="(1, 3)")
}

///|
test "to_rational rejects non-positive denominator caps" {
  let value = @symcore.Float::from_int(1)
  let zero_cap : Result[(BigInt, BigInt), PolyError] = try? to_rational(
    value, 0N,
  )
  assert_true(zero_cap is Err(PolyError::DivisionByZero))
}
