///|
fn nf_resolvent_wb_text(coeffs : Array[FieldElem]) -> String {
  "[" + coeffs.map(c => c.to_string()).join(", ") + "]"
}

///|
test "numberfields galois: degree four resolvent lookup" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  inspect(
    nf_resolvent_wb_text(
      get_resolvent_by_lookup(b.from_expr((x ^ int(4)) + x + int(1)), 1),
    ),
    content="[1, 0, -4, -1]",
  )
  inspect(
    nf_resolvent_wb_text(
      get_resolvent_by_lookup(
        b.from_expr(
          (x ^ int(4)) +
          (x ^ int(3)) +
          int(2) * (x ^ int(2)) +
          int(3) * x +
          int(4),
        ),
        1,
      ),
    ),
    content="[1, -2, -13, 19]",
  )
  sympolys_assert_error(
    fn() raise PolyError {
      get_resolvent_by_lookup(b.from_expr((x ^ int(3)) - int(2)), 1)
    },
    "BadGenerator",
  )
}

///|
fn nf_resolvent_spec_summary(specs : Array[GaloisResolventSpec]) -> String {
  specs
  .map(spec => {
    "(\{spec.degree},\{spec.number}):\{spec.variables.length()}:\{spec.permutations.length()}"
  })
  .join("|")
}

///|
test "numberfields galois: resolvent definitions and symmetrized coefficients" {
  let specs = define_resolvents()
  inspect(
    nf_resolvent_spec_summary(specs),
    content="(4,0):4:6|(4,1):4:3|(5,1):5:6|(6,1):6:6|(6,2):6:10",
  )
  inspect(specs[1].form, content="X0*X2 + X1*X3")
  let coeffs40 = sparse_symmetrize_resolvent_coeffs(specs[0])
  inspect(coeffs40.length(), content="6")
  inspect(coeffs40[0], content="-2*s1*s2 + 6*s3")
  inspect(
    sparse_symmetrize_resolvent_coeffs(specs[1]).join("|"),
    content="-s2|s1*s3 - 4*s4|-s1**2*s4 + 4*s2*s4 - s3**2",
  )
  sympolys_assert_error(
    fn() raise PolyError { sparse_symmetrize_resolvent_coeffs(specs[2]) },
    "BadGenerator",
  )
}

///|
test "numberfields galois: generate lambda lookup trial table" {
  let table = generate_lambda_lookup(trial_run=true)
  assert_true(table.contains("resolvent_coeff_lambdas = {"))
  assert_true(table.contains("(4, 0): ["))
  assert_true(table.contains("lambda s1, s2, s3, s4: (-2*s1*s2 + 6*s3)"))
  assert_false(table.contains("(4, 1): ["))
  sympolys_assert_error(
    fn() raise PolyError { generate_lambda_lookup() },
    "BadGenerator",
  )
}
