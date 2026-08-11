///|
test "matrices wb: _linear_eq_to_dict produces sparse linear rows" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let eqs = [
    @symcore.function("Eq", [x + y, @symcore.int(1)]),
    @symcore.int(2) * (x + @symcore.int(1)) + @symcore.int(3) * y,
  ]
  let syms = ["x", "y"]
  let (coeffs, ind) = _linear_eq_to_dict(eqs, syms)
  assert_true(coeffs.length() == 2 && ind.length() == 2)
  assert_true(
    coeffs[0].get("x").map(@symprint.pretty_string) == Some("1") &&
    coeffs[0].get("y").map(@symprint.pretty_string) == Some("1") &&
    @symprint.pretty_string(ind[0]) == "-1",
  )
  assert_true(
    coeffs[1].get("x").map(@symprint.pretty_string) == Some("2") &&
    coeffs[1].get("y").map(@symprint.pretty_string) == Some("3") &&
    @symprint.pretty_string(ind[1]) == "2",
  )
}

///|
test "matrices wb: _linear_eq_to_dict rejects nonlinear terms" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  sympolys_assert_error(
    fn() raise PolyError { _linear_eq_to_dict([x * y], ["x", "y"]) },
    "NonPolynomial",
  )
}

///|
test "matrices wb: _linsolve handles unique, under, and inconsistent systems" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
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
      if values.get("x").map(@symprint.pretty_string) == Some("3/2") &&
        values.get("y").map(@symprint.pretty_string) == Some("-1/2") {
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
          let x_text = @symprint.pretty_string(x_expr)
          let y_text = @symprint.pretty_string(y_expr)
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
fn linsolve_solution_text(
  sol : Map[String, @symcore.Expr]?,
  syms : Array[String],
) -> String {
  match sol {
    None => "None"
    Some(values) => {
      let parts : Array[String] = Array::new()
      for sym in syms {
        match values.get(sym) {
          Some(expr) => parts.push("\{sym}:\{@symprint.pretty_string(expr)}")
          None => ()
        }
      }
      parts.join("|")
    }
  }
}

///|
test "matrices wb: polys.solvers front doors prepare and solve affine systems" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let syms = ["x", "y"]
  let coeffs : Array[Map[String, @symcore.Expr]] = [
    { "x": @symcore.int(1), "y": @symcore.int(1) },
    { "x": @symcore.int(1), "y": @symcore.int(-1) },
  ]
  let rhs = [@symcore.int(0), @symcore.int(-1)]
  let matrix = eqs_to_matrix(coeffs, rhs, syms, domain=ZZ)
  assert_true(matrix.to_matrix_string() == "Matrix([[1, 1, 0], [1, -1, 1]])")
  assert_true(domain_to_sympy_string(matrix.domain) == "ZZ")

  let system = sympy_eqs_to_ring([x - y, x + y - @symcore.int(2)], syms)
  assert_true(system.coeffs.length() == 2)
  assert_true(system.rhs.length() == 2)
  assert_true(linsolve_solution_text(solve_lin_sys(system), syms) == "x:1|y:1")

  let under = sympy_eqs_to_ring([x + y], syms)
  assert_true(linsolve_solution_text(solve_lin_sys(under), syms) == "x:-y")
}

///|
test "matrices wb: _linsolve uses numeric complex solve path for float coefficients" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let coeff = @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_exact_parts(
      @symnum.BigRational::from_int(1),
      @symnum.BigRational::from_int(1),
      prec=90,
    ),
  )
  let two_thirds = @symcore.Expr::Float(
    @symcore.Float::from_exact(
      @symnum.BigRational::from_ints(2, 3) catch {
        _ => fail("two_thirds")
      },
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
    Some(Float(value)) => assert_true(value.format(dps=12).has_prefix("1.0"))
    Some(ComplexFloat(value)) => {
      assert_true(value.real_part().format(dps=12).has_prefix("1.0"))
      assert_true(@symnum.is_zero(value.to_mpc().imag))
    }
    _ => fail("expected numeric x solution")
  }
  match sol.get("y") {
    Some(Float(value)) =>
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
  let dm = DomainMatrix::from_Matrix(
    [[ComplexFloat(z), @symcore.int(0)]],
    fmt="dense",
    field=true,
  )
  match dm.domain {
    CC => ()
    _ => fail("expected CC domain")
  }
}
