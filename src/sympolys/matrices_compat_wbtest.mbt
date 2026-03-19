///|
test "matrices wb: _linear_eq_to_dict produces sparse linear rows" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let eqs = [
    @symcore.function("Eq", [x + y, @symcore.int(1)]),
    @symcore.int(2) * (x + @symcore.int(1)) + @symcore.int(3) * y,
  ]
  let syms = ["x", "y"]
  let (coeffs, ind) = _linear_eq_to_dict(eqs, syms)
  guard coeffs.length() == 2 && ind.length() == 2 else {
    fail("_linear_eq_to_dict should return one sparse row per equation")
  }
  guard coeffs[0].get("x").map(@symprint.to_string) == Some("1") &&
    coeffs[0].get("y").map(@symprint.to_string) == Some("1") &&
    @symprint.to_string(ind[0]) == "-1" else {
    fail("Eq(x + y, 1) should become x:1, y:1 with constant -1")
  }
  guard coeffs[1].get("x").map(@symprint.to_string) == Some("2") &&
    coeffs[1].get("y").map(@symprint.to_string) == Some("3") &&
    @symprint.to_string(ind[1]) == "2" else {
    fail("2*(x + 1) + 3*y should become x:2, y:3 with constant 2")
  }
}

///|
test "matrices wb: _linear_eq_to_dict rejects nonlinear terms" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let nonlinear : Result[
    (Array[Map[String, @symcore.Expr]], Array[@symcore.Expr]),
    PolyError,
  ] = try? _linear_eq_to_dict([x * y], ["x", "y"])
  guard nonlinear is Err(PolyError::NonPolynomial) else {
    fail("expected nonlinear linsolve input to raise NonPolynomial")
  }
}

///|
test "matrices wb: _linsolve handles unique, under, and inconsistent systems" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let unique = [
    @symcore.function("Eq", [x + y, @symcore.int(1)]),
    @symcore.function("Eq", [x - y, @symcore.int(2)]),
  ]
  let under = [@symcore.function("Eq", [x + y, @symcore.int(0)])]
  let inconsistent = [
    @symcore.function("Eq", [x + y, @symcore.int(1)]),
    @symcore.function("Eq", [x + y, @symcore.int(2)]),
  ]
  let syms = ["x", "y"]

  let unique_sol = _linsolve(unique, syms)
  match unique_sol {
    Some(values) =>
      if values.get("x").map(@symprint.to_string) == Some("3/2") &&
        values.get("y").map(@symprint.to_string) == Some("-1/2") {
        ()
      } else {
        fail("_linsolve should solve the 2x2 system exactly over QQ")
      }
    None => fail("_linsolve should find a unique solution for the 2x2 system")
  }

  let under_sol = _linsolve(under, syms)
  match under_sol {
    Some(values) =>
      match (values.get("x"), values.get("y")) {
        (Some(x_expr), Some(y_expr)) => {
          let x_text = @symprint.to_string(x_expr)
          let y_text = @symprint.to_string(y_expr)
          guard y_text == "y" && x_text.contains("y") && x_text.contains("-") else {
            fail(
              "_linsolve should preserve the original free symbol name y in the solution",
            )
          }
        }
        _ =>
          fail("_linsolve should bind both x and y in the parametric solution")
      }
    None =>
      fail(
        "_linsolve should return a parametric solution for underdetermined input",
      )
  }

  let inconsistent_sol = _linsolve(inconsistent, syms)
  guard inconsistent_sol is None else {
    fail("_linsolve should return None for inconsistent systems")
  }
}
