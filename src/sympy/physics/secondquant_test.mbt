///|
fn sq_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = try! secondquant_eval_str(@symprint.to_string(lhs))
  let expected = try! secondquant_eval_str(rhs)
  assert_eq(ours, expected)
}

///|
fn sq_assert_matrix_expr_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  _context : String,
) -> Unit raise {
  assert_eq(lhs.height(), rows)
  assert_eq(lhs.width(), cols)
  let flat = try! @symquant.matrix_flat_strings(lhs)
  assert_eq(flat.length(), rhs.length())
  for idx in 0..<flat.length() {
    assert_true((try! expr_equal(flat[idx], rhs[idx])))
  }
}

///|
test "physics.secondquant: boson dagger, apply, basis, matrix" {
  let n = @symcore.symbol("n")
  let m = @symcore.symbol("m")
  let b0 = boson_annihilator(@symcore.int(0))
  let bd0 = boson_creator(@symcore.int(0))
  let b1d = boson_creator(@symcore.int(1))

  inspect(b0.to_string(), content="b(0)")
  inspect(bd0.to_string(), content="b+(0)")
  inspect(b0.dagger().repr(), content="CreateBoson(0)")

  let state = boson_state([
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  inspect(state.len(), content="5")
  inspect(state.repr(), content="FockState((0, 1, 2, 3, 4))")
  inspect(state.get(3) |> @symprint.to_string, content="3")
  inspect(state.up(0).repr(), content="FockState((1, 1, 2, 3, 4))")
  inspect(
    match state.down(4) {
      Some(v) => v.repr()
      None => "0"
    },
    content="FockState((0, 1, 2, 3, 3))",
  )
  inspect(
    match state.down(0) {
      Some(v) => v.repr()
      None => "0"
    },
    content="0",
  )

  inspect(
    @symprint.to_string(secondquant_dagger(boson_ket([n]))),
    content="FockStateBosonBra(Tuple(n))",
  )
  sq_assert_expr_equal(
    secondquant_apply_operators(
      @symcore.raw_mul([b0.as_expr(), boson_ket([n])]),
    ),
    "sqrt(n)*FockStateBosonKet((n - 1,))",
    "single annihilation apply",
  )
  sq_assert_expr_equal(
    secondquant_apply_operators(
      @symcore.raw_mul([bd0.as_expr(), boson_ket([n])]),
    ),
    "sqrt(n + 1)*FockStateBosonKet((n + 1,))",
    "single creation apply",
  )
  sq_assert_expr_equal(
    secondquant_apply_operators(
      @symcore.raw_mul([
        bd0.as_expr(),
        b0.as_expr(),
        b1d.as_expr(),
        b0.as_expr(),
        boson_ket([n, m]),
      ]),
    ),
    "sqrt(m + 1)*sqrt(n)*(n - 1)*FockStateBosonKet((n - 1, m + 1))",
    "composed boson apply",
  )
  sq_assert_expr_equal(
    secondquant_inner_product(
      boson_bra([@symcore.int(0)]),
      boson_ket([@symcore.int(1)]),
    ),
    "0",
    "orthogonal inner product",
  )
  sq_assert_expr_equal(
    secondquant_inner_product(
      boson_bra([@symcore.symbol("i"), @symcore.symbol("j")]),
      boson_ket([@symcore.symbol("k"), @symcore.symbol("l")]),
    ),
    "KroneckerDelta(i, k)*KroneckerDelta(j, l)",
    "tuple inner product",
  )
  sq_assert_expr_equal(
    secondquant_commutator(b0.as_expr(), bd0.as_expr()),
    "1",
    "boson commutator",
  )
  sq_assert_expr_equal(
    secondquant_normal_ordered_form(
      @symcore.raw_mul([b0.as_expr(), bd0.as_expr()]),
    ),
    "1 + CreateBoson(0)*AnnihilateBoson(0)",
    "normal ordered boson pair",
  )

  let variable = variable_bosonic_basis(5)
  inspect(
    variable.to_string(),
    content="[FockState((0,)), FockState((1,)), FockState((2,)), FockState((3,)), FockState((4,))]",
  )
  let matrix_a = secondquant_matrix_rep(b0.as_expr(), variable.as_basis())
  sq_assert_matrix_expr_equal(
    matrix_a,
    [
      "0", "1", "0", "0", "0", "0", "0", "sqrt(2)", "0", "0", "0", "0", "0", "sqrt(3)",
      "0", "0", "0", "0", "0", "2", "0", "0", "0", "0", "0",
    ],
    5,
    5,
    "annihilator matrix",
  )
  let matrix_ad = secondquant_matrix_rep(bd0.as_expr(), variable.as_basis())
  sq_assert_matrix_expr_equal(
    matrix_ad,
    [
      "0", "0", "0", "0", "0", "1", "0", "0", "0", "0", "0", "sqrt(2)", "0", "0",
      "0", "0", "0", "sqrt(3)", "0", "0", "0", "0", "0", "2", "0",
    ],
    5,
    5,
    "creator matrix",
  )

  let fixed = fixed_bosonic_basis(2, 2)
  inspect(
    fixed.to_string(),
    content="[FockState((2, 0)), FockState((1, 1)), FockState((0, 2))]",
  )
  inspect(
    @symprint.to_string(fixed.state(1)),
    content="FockStateBosonKet(Tuple(1, 1))",
  )
  inspect(
    fixed.index(boson_ket([@symcore.int(1), @symcore.int(1)])).to_string(),
    content="1",
  )
}
