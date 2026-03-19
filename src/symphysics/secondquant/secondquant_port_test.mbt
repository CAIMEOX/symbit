///|
fn sq_assert_string_equal(
  lhs : String,
  rhs : String,
  context : String,
) -> Unit raise {
  guard lhs == rhs else { fail("\{context}: ours=\{lhs}; oracle=\{rhs}") }
}

///|
fn sq_assert_matrix_oracle_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  context : String,
) -> Unit raise {
  guard lhs.height() == rows else {
    fail("\{context}: row mismatch ours=\{lhs.height()} oracle=\{rows}")
  }
  guard lhs.width() == cols else {
    fail("\{context}: col mismatch ours=\{lhs.width()} oracle=\{cols}")
  }
  let flat = try! @symquant.matrix_flat_strings(lhs)
  let expected = rhs.join("\u001f").split("\u001f").to_array()
  guard flat.length() == rows * cols else {
    fail("\{context}: bad matrix size ours=\{flat.length()}")
  }
  let mut idx = 0
  for row in expected {
    let inner = row[1:row.length() - 1].to_string().split(", ").to_array()
    for item in inner {
      guard (try! @sympy_physics.expr_equal(flat[idx], item.to_string())) else {
        fail("\{context}[\{idx}]: ours=\{flat[idx]}; oracle=\{item}")
      }
      idx += 1
    }
  }
}

///|
test "physics.secondquant: boson parity" {
  let n = @symcore.symbol("n")
  let m = @symcore.symbol("m")
  let b0 = boson_annihilator(@symcore.int(0))
  let bd0 = boson_creator(@symcore.int(0))
  let b1d = boson_creator(@symcore.int(1))

  inspect(
    @sympy_physics.secondquant_eval_str(
      @symprint.to_string(secondquant_dagger(boson_ket([n]))),
    ),
    content=@sympy_physics.secondquant_eval_str("Dagger(BKet([n]))"),
  )
  sq_assert_string_equal(
    @sympy_physics.secondquant_apply_str("B(0)*BKet([n])"),
    @sympy_physics.secondquant_eval_str(
      @symprint.to_string(
        secondquant_apply_operators(
          @symcore.raw_mul([b0.as_expr(), boson_ket([n])]),
        ),
      ),
    ),
    "boson annihilation parity",
  )
  sq_assert_string_equal(
    @sympy_physics.secondquant_apply_str("Bd(0)*BKet([n])"),
    @sympy_physics.secondquant_eval_str(
      @symprint.to_string(
        secondquant_apply_operators(
          @symcore.raw_mul([bd0.as_expr(), boson_ket([n])]),
        ),
      ),
    ),
    "boson creation parity",
  )
  sq_assert_string_equal(
    @sympy_physics.secondquant_apply_str("Bd(0)*B(0)*Bd(1)*B(0)*BKet([n, m])"),
    @sympy_physics.secondquant_eval_str(
      @symprint.to_string(
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
    @sympy_physics.secondquant_eval_str(
      "InnerProduct(BBra([i, j]), BKet([k, l]))",
    ),
    @sympy_physics.secondquant_eval_str(
      @symprint.to_string(
        secondquant_inner_product(
          boson_bra([@symcore.symbol("i"), @symcore.symbol("j")]),
          boson_ket([@symcore.symbol("k"), @symcore.symbol("l")]),
        ),
      ),
    ),
    "tuple inner product parity",
  )
  sq_assert_string_equal(
    @sympy_physics.secondquant_eval_str("Commutator(B(0), Bd(0))"),
    @sympy_physics.secondquant_eval_str(
      @symprint.to_string(secondquant_commutator(b0.as_expr(), bd0.as_expr())),
    ),
    "boson commutator parity",
  )
  inspect(
    @sympy_physics.secondquant_basis_str("VarBosonicBasis(5)"),
    content=variable_bosonic_basis(5).to_string(),
  )
  inspect(
    @sympy_physics.secondquant_basis_str("FixedBosonicBasis(2, 2)"),
    content=fixed_bosonic_basis(2, 2).to_string(),
  )
  sq_assert_matrix_oracle_equal(
    secondquant_matrix_rep(b0.as_expr(), variable_bosonic_basis(5).as_basis()),
    @sympy_physics.secondquant_matrix_rows("B(0)", "VarBosonicBasis(5)"),
    5,
    5,
    "matrix parity",
  )
}
