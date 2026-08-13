///|
test "rationaltools: P5a3 focused frontdoor parity with SymPy" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let builder = PolyBuilder::new(["x"], ZZ)
  let cubic = builder.from_expr(
    @symcore.int(2) * (x ^ @symcore.int(3)) -
    @symcore.int(7) * (x ^ @symcore.int(2)) +
    @symcore.int(4) * x +
    @symcore.int(4),
  )
  assert_eq(
    remove_spaces(polytools_port_expr_list_repr(@sympolys.real_roots(cubic))),
    remove_spaces(real_roots(cubic.to_expr())),
  )

  let approximate = builder.from_expr((x ^ @symcore.int(2)) - @symcore.int(3))
  assert_true(
    remove_spaces(polytools_port_expr_list_repr(@sympolys.nroots(approximate))).has_prefix(
      "[-1.732",
    ),
  )
  assert_true(
    remove_spaces(nroots(approximate.to_expr())).has_prefix("[-1.732"),
  )

  let powered = builder.from_expr(
    (x ^ @symcore.int(4)) - (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  assert_eq(
    remove_spaces(
      sympy_normalize(@sympolys.nth_power_roots_poly(powered, 2).to_string()),
    ),
    remove_spaces(nth_power_roots_poly(powered.to_expr(), 2)),
  )

  let bivariate = PolyBuilder::new(["x", "y"], QQ)
  let finite = [
    bivariate.from_expr((x ^ @symcore.int(2)) - @symcore.int(1)),
    bivariate.from_expr(y - x),
  ]
  assert_eq(
    @sympolys.is_zero_dimensional(finite).to_string(),
    if is_zero_dimensional(finite.map(item => item.to_expr())) == "True" {
      "true"
    } else {
      "false"
    },
  )

  let k = @symcore.Expr::Symbol("k")
  let stable = PolyBuilder::new(["x", "k"], ZZ).from_expr(
    (x ^ @symcore.int(3)) +
    (x ^ @symcore.int(2)) +
    @symcore.int(2) * k * x +
    @symcore.int(1) -
    k,
  )
  assert_eq(
    remove_spaces(
      polytools_port_expr_list_repr(@sympolys.hurwitz_conditions(stable)),
    ),
    remove_spaces(hurwitz_conditions(stable.to_expr(), gens=["x"])),
  )
  assert_eq(
    remove_spaces(
      polytools_port_expr_list_repr(@sympolys.schur_conditions(stable)),
    ),
    remove_spaces(schur_conditions(stable.to_expr(), gens=["x"])),
  )

  let fractions = (x ^ @symcore.int(-1)) +
    (y ^ @symcore.int(-1)) +
    ((x * y) ^ @symcore.int(-1))
  assert_eq(
    remove_spaces(
      sympy_normalize(@symprint.pretty_string(@sympolys.together(fractions))),
    ),
    remove_spaces(together(fractions)),
  )
  let nested = @symcore.function("exp", [
    (x ^ @symcore.int(-1)) + (y ^ @symcore.int(-1)),
  ])
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.together(nested, deep=true)),
      ),
    ),
    remove_spaces(together(nested, deep=true)),
  )

  let apart_expr = y *
    ((x + @symcore.int(2)) ^ @symcore.int(-1)) *
    ((x + @symcore.int(1)) ^ @symcore.int(-1))
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.apart(apart_expr, gen="x")),
      ),
    ),
    remove_spaces(apart(apart_expr, gen="x")),
  )

  let partfrac_builder = PolyBuilder::new(["x"], QQ)
  let p = partfrac_builder.from_expr(@symcore.int(1))
  let q = partfrac_builder.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  assert_true(
    expr_equal(
      @symprint.pretty_string(@sympolys.apart_undetermined_coeffs(p, q)),
      apart_undetermined_coeffs(p.to_expr(), q.to_expr(), "x"),
    ),
  )
  assert_true(
    expr_equal(
      @symprint.pretty_string(@sympolys.apart_full_decomposition(p, q)),
      apart_full_decomposition(p.to_expr(), q.to_expr(), "x"),
    ),
  )
  assert_eq(
    @sympolys.apart_list_full_decomposition(p, q).length(),
    apart_list_full_decomposition_count(p.to_expr(), q.to_expr(), "x"),
  )

  let a = @symcore.Expr::Symbol("a")
  let algebraic = Domain::AlgExt(QQ, ["a"], [
    (a ^ @symcore.int(2)) - @symcore.int(3),
  ])
  let algebraic_poly = PolyBuilder::new(["x"], algebraic).from_expr(
    (x ^ @symcore.int(2)) - @symcore.int(2),
  )
  let (shifts, shifted, norm) = @sympolys.sqf_norm(algebraic_poly)
  let ours_sqf = "(\{Repr(shifts).to_string()}, \{sympy_normalize(shifted.to_string())}, \{sympy_normalize(norm.to_string())})"
  let oracle_sqf = sqf_norm(
    (x ^ @symcore.int(2)) - @symcore.int(2),
    gens=["x"],
    extension="sqrt(3)",
  ).replace_all(old="sqrt(3)", new="a")
  assert_eq(
    remove_spaces(sympy_normalize(ours_sqf)),
    remove_spaces(sympy_normalize(oracle_sqf)),
  )

  let galois_poly = builder.from_expr((x ^ @symcore.int(3)) - @symcore.int(2))
  let ours_galois = @sympolys.galois_group(galois_poly)
  assert_eq(
    "(\{ours_galois.name}, \{ours_galois.is_alt})",
    galois_group(galois_poly.to_expr(), gens=["x"]),
  )
}
