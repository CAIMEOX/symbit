///|
test "RR evalf_expr returns Expr::Float with requested precision" {
  let rr = Domain::RR
  let half_res : Result[@symcore.Expr, @symnum.RationalError] = try? @symcore.rational_from_ints(
    1, 2,
  )
  let half = match half_res {
    Ok(value) => value
    Err(_) => fail("half")
  }
  let evaled_res : Result[@symcore.Expr, PolyError] = try? rr.evalf_expr(
    half,
    prec=Some(90),
  )
  let evaled = match evaled_res {
    Ok(value) => value
    Err(_) => fail("evalf")
  }
  match evaled {
    @symcore.Expr::Float(f) => {
      assert_eq(f.precision(), 90)
      assert_eq(f.to_rational(), (1N, 2N))
    }
    _ => fail("expected float")
  }
}

///|
test "Poly::from_expr_defaults infers RR from float coefficients" {
  let half_res : Result[@symcore.Float, @symnum.MpfError] = try? @symcore.Float::from_str(
    "0.5",
    prec=100,
  )
  let half = match half_res {
    Ok(value) => value
    Err(_) => fail("float")
  }
  let expr = @symcore.add([@symcore.Expr::Symbol("x"), @symcore.Expr::Float(half)])
  let poly_res : Result[Poly, PolyError] = try? Poly::from_expr_defaults(expr)
  let poly = match poly_res {
    Ok(value) => value
    Err(_) => fail("poly")
  }
  match poly.domain {
    Domain::RR => ()
    _ => fail("expected RR domain")
  }
  inspect(@symprint.to_string(poly.to_expr()), content="x + 1/2")
}
