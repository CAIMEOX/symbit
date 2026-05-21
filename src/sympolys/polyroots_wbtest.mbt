///|
test "polyroots wb: arity and degree guard errors" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")

  let b2 = PolyBuilder::new(["x", "y"], Domain::QQ)
  let p2 = b2.from_expr(x + y)
  let non_uni_linear : Result[Array[@symcore.Expr], PolyError] = try? roots_linear(
    p2,
  )
  assert_true(non_uni_linear is Err(PolyError::NotUnivariate))

  let b1 = PolyBuilder::new(["x"], Domain::QQ)
  let lin = b1.from_expr(x + @symcore.int(1))
  let quad = b1.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let cubic = b1.from_expr((x ^ @symcore.int(3)) + x + @symcore.int(1))
  let quartic = b1.from_expr((x ^ @symcore.int(4)) + x + @symcore.int(1))

  let bad_linear : Result[Array[@symcore.Expr], PolyError] = try? roots_linear(
    quad,
  )
  assert_true(bad_linear is Err(PolyError::BadExponent))

  let bad_quad : Result[Array[@symcore.Expr], PolyError] = try? roots_quadratic(
    lin,
  )
  assert_true(bad_quad is Err(PolyError::BadExponent))

  let bad_cubic : Result[Array[@symcore.Expr], PolyError] = try? roots_cubic(
    quad,
  )
  assert_true(bad_cubic is Err(PolyError::BadExponent))

  let bad_quartic : Result[Array[@symcore.Expr], PolyError] = try? roots_quartic(
    cubic,
  )
  assert_true(bad_quartic is Err(PolyError::BadExponent))

  let _ = quartic
}

///|
test "polyroots wb: cubic/quartic mixed-factor quadratic branch" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)

  // Degree-3 polynomial with a linear and an irreducible quadratic factor.
  let cubic = b.from_expr(x * ((x ^ @symcore.int(2)) + @symcore.int(1)))
  let cubic_roots = roots_cubic(cubic)
  assert_eq(cubic_roots.length(), 3)

  // Degree-4 polynomial with a quadratic factor to force the quadratic branch.
  let quartic = b.from_expr(
    (x - @symcore.int(1)) *
    (x + @symcore.int(2)) *
    ((x ^ @symcore.int(2)) + @symcore.int(1)),
  )
  let quartic_roots = roots_quartic(quartic)
  assert_eq(quartic_roots.length(), 4)
}

///|
test "polyroots wb: roots_for_factor and zero-root handling" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)

  let const_poly = b.from_expr(@symcore.int(7))
  assert_eq(roots_for_factor(const_poly, true).length(), 0)

  let quadratic = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(2))
  assert_eq(roots_for_factor(quadratic, true).length(), 2)

  let cubic = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  assert_eq(roots_for_factor(cubic, true).length(), 3)

  let quartic = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  assert_eq(roots_for_factor(quartic, true).length(), 4)

  let zero = Poly::zero(["x"], Domain::QQ)
  assert_eq(roots(zero).length(), 0)
}

///|
test "polyroots wb: root_factors frontdoor" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let f = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(2)))
  let factors = root_factors(f).map(factor => @symprint.pretty_string(factor))
  inspect(factors.join(" | "), content="x + 2 | x - 1")
  let irreducible = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  inspect(root_factors(irreducible).length(), content="2")
  let zero = Poly::zero(["x"], Domain::QQ)
  inspect(@symprint.pretty_string(root_factors(zero)[0]), content="0")
}

///|
test "polyroots wb: binomial roots use ordered roots of unity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let quartic = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(16))
  let roots4 = roots_binomial(quartic).map(r => @symprint.pretty_string(r))
  inspect(roots4[0], content="-2")
  inspect(roots4[1], content="2")
  assert_eq(roots4.length(), 4)
  let quintic = b.from_expr((x ^ @symcore.int(5)) - @symcore.int(32))
  assert_eq(roots_binomial(quintic).length(), 5)
  let zero_roots = roots_binomial(b.from_expr(x ^ @symcore.int(3)))
  inspect(
    zero_roots.map(r => @symprint.pretty_string(r)).join(","),
    content="0,0,0",
  )
}

///|
test "polyroots wb: cyclotomic roots detect primitive roots" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let phi4 = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let roots4 = roots_cyclotomic(phi4).map(r => @symprint.pretty_string(r))
  assert_eq(roots4.length(), 2)
  assert_true(roots4[0].contains("sin"))
  let phi5 = Poly::from_expr(cyclotomic_poly(5), ["x"], Domain::QQ)
  assert_eq(roots_cyclotomic(phi5).length(), 4)
  let not_cyclotomic : Result[Array[@symcore.Expr], PolyError] = try? roots_cyclotomic(
    b.from_expr((x ^ @symcore.int(2)) + x + @symcore.int(2)),
  )
  assert_true(not_cyclotomic is Err(PolyError::BadExponent))
}
