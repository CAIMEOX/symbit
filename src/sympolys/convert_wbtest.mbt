///|
fn conv_wb_rat(num : Int, den : Int) -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
}

///|
fn conv_wb_qq(num : Int, den : Int) -> FieldElem {
  FieldElem::QQ(conv_wb_rat(num, den))
}

///|
test "convert wb: fe_to_expr_const covers CC branch variants" {
  let pure_real = fe_to_expr_const(
    FieldElem::CC(conv_wb_rat(2, 1), conv_wb_rat(0, 1)),
  )
  inspect(@symprint.to_string(pure_real), content="2")

  let pure_imag = fe_to_expr_const(
    FieldElem::CC(conv_wb_rat(0, 1), conv_wb_rat(3, 1)),
  )
  let pure_imag_s = @symprint.to_string(pure_imag)
  guard pure_imag_s.contains("I") && pure_imag_s.contains("3") else {
    fail("pure imaginary rendering mismatch: \{pure_imag_s}")
  }

  let full = fe_to_expr_const(
    FieldElem::CC(conv_wb_rat(2, 1), conv_wb_rat(3, 1)),
  )
  let full_s = @symprint.to_string(full)
  guard full_s.contains("I") && full_s.contains("2") && full_s.contains("3") else {
    fail("complex rendering mismatch: \{full_s}")
  }
}

///|
test "convert wb: fe_ext_to_expr handles empty/sparse/mixed terms" {
  let mod_poly = [1, 0, 2]
  inspect(@symprint.to_string(fe_ext_to_expr(5, [0, 0, 0], mod_poly)), content="0")
  inspect(@symprint.to_string(fe_ext_to_expr(5, [0, 2], mod_poly)), content="2*alpha_p5_m1_0_2")
  inspect(@symprint.to_string(fe_ext_to_expr(5, [0, 0, 1], mod_poly)), content="alpha_p5_m1_0_2**2")
  let mix = @symprint.to_string(fe_ext_to_expr(5, [0, 1, 3, 0], mod_poly))
  guard mix.contains("alpha_p5_m1_0_2") &&
    mix.contains("3*alpha_p5_m1_0_2**2") else {
    fail("GFExt mixed rendering mismatch: \{mix}")
  }
}

///|
test "convert wb: fe_algext_to_expr and AlgExt constant rendering" {
  let a = @symcore.symbol("a")
  let minpoly = PolyBuilder::new(["a"], Domain::QQ).from_expr(
    (a ^ @symcore.int(2)) + @symcore.int(1),
  )

  inspect(
    @symprint.to_string(
      fe_algext_to_expr(Domain::QQ, [conv_wb_qq(0, 1)], minpoly, "a"),
    ),
    content="0",
  )
  inspect(
    @symprint.to_string(
      fe_algext_to_expr(
        Domain::QQ,
        [conv_wb_qq(3, 1), conv_wb_qq(1, 1), conv_wb_qq(2, 1)],
        minpoly,
        "a",
      ),
    ),
    content="2*a**2 + a + 3",
  )

  let coeff = FieldElem::AlgExt(
    Domain::QQ,
    [conv_wb_qq(1, 1), conv_wb_qq(1, 1), conv_wb_qq(2, 1)],
    minpoly,
    "a",
  )
  inspect(@symprint.to_string(fe_to_expr_const(coeff)), content="2*a**2 + a + 1")

  // Single non-zero term exercises the `terms.length() == 1` return path.
  inspect(
    @symprint.to_string(
      fe_algext_to_expr(Domain::QQ, [conv_wb_qq(0, 1), conv_wb_qq(1, 1)], minpoly, "a"),
    ),
    content="a",
  )

  // Nested AlgExt coefficient exercises `fe_cast_to_base` AlgExt arm.
  let nested = FieldElem::AlgExt(
    Domain::QQ,
    [conv_wb_qq(2, 1)],
    minpoly,
    "a",
  )
  inspect(
    @symprint.to_string(
      fe_algext_to_expr(Domain::QQ, [nested], minpoly, "a"),
    ),
    content="2",
  )
}
