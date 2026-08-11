///|
fn sq_assert_string_equal(
  lhs : String,
  rhs : String,
  _context : String,
) -> Unit raise {
  assert_eq(lhs, rhs)
}

///|
fn sq_assert_matrix_oracle_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  _context : String,
) -> Unit raise {
  assert_eq(lhs.height(), rows)
  assert_eq(lhs.width(), cols)
  let flat = @symquant.matrix_flat_strings(lhs)
  let expected = rhs.join("\u001f").split("\u001f").to_array()
  assert_eq(flat.length(), rows * cols)
  let mut idx = 0
  for row in expected {
    let inner = row[1:row.length() - 1].to_owned().split(", ").to_array()
    for item in inner {
      assert_true(expr_equal(flat[idx], item.to_owned()))
      idx += 1
    }
  }
}

///|
test "physics.secondquant: boson parity" {
  let n = @symcore.Expr::Symbol("n")
  let m = @symcore.Expr::Symbol("m")
  let b0 = boson_annihilator(@symcore.int(0))
  let bd0 = boson_creator(@symcore.int(0))
  let b1d = boson_creator(@symcore.int(1))

  inspect(
    secondquant_eval_str(
      @symprint.pretty_string(secondquant_dagger(boson_ket([n]))),
    ),
    content=secondquant_eval_str("Dagger(BKet([n]))"),
  )
  sq_assert_string_equal(
    secondquant_apply_str("B(0)*BKet([n])"),
    secondquant_eval_str(
      @symprint.pretty_string(
        secondquant_apply_operators(
          @symcore.raw_mul([b0.as_expr(), boson_ket([n])]),
        ),
      ),
    ),
    "boson annihilation parity",
  )
  sq_assert_string_equal(
    secondquant_apply_str("Bd(0)*BKet([n])"),
    secondquant_eval_str(
      @symprint.pretty_string(
        secondquant_apply_operators(
          @symcore.raw_mul([bd0.as_expr(), boson_ket([n])]),
        ),
      ),
    ),
    "boson creation parity",
  )
  sq_assert_string_equal(
    secondquant_apply_str("Bd(0)*B(0)*Bd(1)*B(0)*BKet([n, m])"),
    secondquant_eval_str(
      @symprint.pretty_string(
        secondquant_apply_operators(
          @symcore.raw_mul([
            bd0.as_expr(),
            b0.as_expr(),
            b1d.as_expr(),
            b0.as_expr(),
            boson_ket([n, m]),
          ]),
        ),
      ),
    ),
    "composed boson apply parity",
  )
  sq_assert_string_equal(
    secondquant_eval_str("InnerProduct(BBra([i, j]), BKet([k, l]))"),
    secondquant_eval_str(
      @symprint.pretty_string(
        secondquant_inner_product(
          boson_bra([@symcore.Expr::Symbol("i"), @symcore.Expr::Symbol("j")]),
          boson_ket([@symcore.Expr::Symbol("k"), @symcore.Expr::Symbol("l")]),
        ),
      ),
    ),
    "tuple inner product parity",
  )
  sq_assert_string_equal(
    secondquant_eval_str("Commutator(B(0), Bd(0))"),
    secondquant_eval_str(
      @symprint.pretty_string(
        secondquant_commutator(b0.as_expr(), bd0.as_expr()),
      ),
    ),
    "boson commutator parity",
  )
  inspect(
    secondquant_basis_str("VarBosonicBasis(5)"),
    content=variable_bosonic_basis(5).to_string(),
  )
  inspect(
    secondquant_basis_str("FixedBosonicBasis(2, 2)"),
    content=fixed_bosonic_basis(2, 2).to_string(),
  )
  sq_assert_matrix_oracle_equal(
    secondquant_matrix_rep(b0.as_expr(), variable_bosonic_basis(5).as_basis()),
    secondquant_matrix_rows("B(0)", "VarBosonicBasis(5)"),
    5,
    5,
    "matrix parity",
  )
}
