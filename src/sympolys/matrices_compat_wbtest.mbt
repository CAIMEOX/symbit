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
  assert_true(coeffs.length() == 2 && ind.length() == 2)
  assert_true(
    coeffs[0].get("x").map(@symprint.to_string) == Some("1") &&
    coeffs[0].get("y").map(@symprint.to_string) == Some("1") &&
    @symprint.to_string(ind[0]) == "-1",
  )
  assert_true(
    coeffs[1].get("x").map(@symprint.to_string) == Some("2") &&
    coeffs[1].get("y").map(@symprint.to_string) == Some("3") &&
    @symprint.to_string(ind[1]) == "2",
  )
}

///|
test "matrices wb: _linear_eq_to_dict rejects nonlinear terms" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let nonlinear : Result[
    (Array[Map[String, @symcore.Expr]], Array[@symcore.Expr]),
    PolyError,
  ] = try? _linear_eq_to_dict([x * y], ["x", "y"])
  assert_true(nonlinear is Err(PolyError::NonPolynomial))
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
          assert_true(
            y_text == "y" && x_text.contains("y") && x_text.contains("-"),
          )
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
  assert_true(inconsistent_sol is None)
}

///|
test "matrices wb: _linsolve uses numeric complex solve path for float coefficients" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let coeff = @symcore.complex_float(
    @symcore.ComplexFloat::from_exact_parts(
      @symnum.BigRational::from_int(1),
      @symnum.BigRational::from_int(1),
      prec=90,
    ),
  )
  let two_thirds = @symcore.float(
    @symcore.Float::from_exact(
      @symnum.BigRational::from_ints(2, 3) catch { _ => fail("two_thirds") },
      prec=90,
    ) catch {
      _ => fail("two_thirds")
    },
  )
  let system = [
    @symcore.function("Eq", [coeff * x, coeff]),
    @symcore.function("Eq", [y, two_thirds]),
  ]
  let sol = match _linsolve(system, ["x", "y"]) {
    Some(values) => values
    None => fail("numeric complex _linsolve")
  }
  match sol.get("x") {
    Some(@symcore.Expr::Float(value)) =>
      assert_true(value.format(dps=12).has_prefix("1.0"))
    Some(@symcore.Expr::ComplexFloat(value)) => {
      assert_true(value.real_part().format(dps=12).has_prefix("1.0"))
      assert_true(@symnum.is_zero(value.to_mpc().imag))
    }
    _ => fail("expected numeric x solution")
  }
  match sol.get("y") {
    Some(@symcore.Expr::Float(value)) =>
      assert_true(value.format(dps=12).has_prefix("0.666666666"))
    _ => fail("expected numeric y solution")
  }
}

///|
test "matrices wb: DomainMatrix infers CC from complex float entries" {
  let z = @symcore.ComplexFloat::from_exact_parts(
    @symnum.BigRational::from_int(1),
    @symnum.BigRational::from_int(2),
    prec=90,
  )
  let dm_res : Result[DomainMatrix, PolyError] = try? DomainMatrix::from_Matrix(
    [[@symcore.complex_float(z), @symcore.int(0)]],
    fmt="dense",
    field=true,
  )
  let dm = match dm_res {
    Ok(value) => value
    Err(_) => fail("domain matrix")
  }
  match dm.domain {
    Domain::CC => ()
    _ => fail("expected CC domain")
  }
}
