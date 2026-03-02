///|
test "polyroots wb: arity and degree guard errors" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")

  let b2 = PolyBuilder::new(["x", "y"], Domain::QQ)
  let p2 = b2.from_expr(x + y)
  let non_uni_linear : Result[Array[@symcore.Expr], PolyError] = try? roots_linear(p2)
  guard non_uni_linear is Err(PolyError::NotUnivariate) else {
    fail("roots_linear should reject multivariate polynomials")
  }

  let b1 = PolyBuilder::new(["x"], Domain::QQ)
  let lin = b1.from_expr(x + @symcore.int(1))
  let quad = b1.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let cubic = b1.from_expr((x ^ @symcore.int(3)) + x + @symcore.int(1))
  let quartic = b1.from_expr((x ^ @symcore.int(4)) + x + @symcore.int(1))

  let bad_linear : Result[Array[@symcore.Expr], PolyError] = try? roots_linear(quad)
  guard bad_linear is Err(PolyError::BadExponent) else {
    fail("roots_linear should require degree 1")
  }

  let bad_quad : Result[Array[@symcore.Expr], PolyError] = try? roots_quadratic(lin)
  guard bad_quad is Err(PolyError::BadExponent) else {
    fail("roots_quadratic should require degree 2")
  }

  let bad_cubic : Result[Array[@symcore.Expr], PolyError] = try? roots_cubic(quad)
  guard bad_cubic is Err(PolyError::BadExponent) else {
    fail("roots_cubic should require degree 3")
  }

  let bad_quartic : Result[Array[@symcore.Expr], PolyError] = try? roots_quartic(cubic)
  guard bad_quartic is Err(PolyError::BadExponent) else {
    fail("roots_quartic should require degree 4")
  }

  let _ = quartic
}

///|
test "polyroots wb: cubic/quartic mixed-factor quadratic branch" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)

  // Degree-3 polynomial with a linear and an irreducible quadratic factor.
  let cubic = b.from_expr(x * ((x ^ @symcore.int(2)) + @symcore.int(1)))
  let cubic_roots = try! roots_cubic(cubic)
  guard cubic_roots.length() == 3 else {
    fail("roots_cubic should return three roots with multiplicity")
  }

  // Degree-4 polynomial with a quadratic factor to force the quadratic branch.
  let quartic = b.from_expr(
    (x - @symcore.int(1)) * (x + @symcore.int(2)) * ((x ^ @symcore.int(2)) + @symcore.int(1)),
  )
  let quartic_roots = try! roots_quartic(quartic)
  guard quartic_roots.length() == 4 else {
    fail("roots_quartic should return four roots with multiplicity")
  }
}

///|
test "polyroots wb: roots_for_factor and zero-root handling" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)

  let const_poly = b.from_expr(@symcore.int(7))
  guard (try! roots_for_factor(const_poly, true)).length() == 0 else {
    fail("roots_for_factor should return [] for constants")
  }

  let quadratic = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(2))
  guard (try! roots_for_factor(quadratic, true)).length() == 2 else {
    fail("roots_for_factor degree-2 branch mismatch")
  }

  let cubic = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  guard (try! roots_for_factor(cubic, true)).length() == 3 else {
    fail("roots_for_factor degree-3 radicals branch mismatch")
  }

  let quartic = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  guard (try! roots_for_factor(quartic, true)).length() == 4 else {
    fail("roots_for_factor degree-4 radicals branch mismatch")
  }

  let zero = Poly::zero(["x"], Domain::QQ)
  guard (try! roots(zero)).length() == 0 else {
    fail("roots(0) should return []")
  }
}
