///|
fn tsch_port_pair_text(
  poly : @sympolys.Poly,
) -> String raise @sympolys.PolyError {
  let (a, u) = @sympolys.tschirnhausen_transformation(poly, max_tries=10)
  "(\{a.to_string()}, \{u.to_string()})"
}

///|
test "numberfields galois: tschirnhausen transformation parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = @sympolys.PolyBuilder::new(["x"], @sympolys.Domain::ZZ)
  let cases = [
    b.from_expr((x ^ @symcore.int(3)) - @symcore.int(2)),
    b.from_expr((x ^ @symcore.int(4)) + x + @symcore.int(1)),
    b.from_expr(
      (x ^ @symcore.int(3)) -
      (x ^ @symcore.int(2)) -
      @symcore.int(2) * x +
      @symcore.int(1),
    ),
  ]
  for item in cases {
    assert_eq(
      remove_spaces(sympy_normalize(tsch_port_pair_text(item))),
      remove_spaces(
        sympy_normalize(
          tschirnhausen_transformation(item.to_expr(), gens=["x"], max_tries=10),
        ),
      ),
    )
  }
}

///|
fn resolvent_port_text(coeffs : Array[@sympolys.FieldElem]) -> String {
  "[" + coeffs.map(c => c.to_string()).join(", ") + "]"
}

///|
test "numberfields galois: resolvent lookup parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = @sympolys.PolyBuilder::new(["x"], @sympolys.Domain::ZZ)
  let cases = [
    b.from_expr((x ^ @symcore.int(4)) + x + @symcore.int(1)),
    b.from_expr((x ^ @symcore.int(4)) - @symcore.int(2)),
    b.from_expr(
      (x ^ @symcore.int(4)) +
      (x ^ @symcore.int(3)) +
      @symcore.int(2) * (x ^ @symcore.int(2)) +
      @symcore.int(3) * x +
      @symcore.int(4),
    ),
  ]
  for item in cases {
    assert_eq(
      resolvent_port_text(@sympolys.get_resolvent_by_lookup(item, 1)),
      get_resolvent_by_lookup(item.to_expr(), 1, gens=["x"]),
    )
  }
}

///|
fn resolvent_spec_port_summary(
  specs : Array[@sympolys.GaloisResolventSpec],
) -> String {
  specs
  .map(spec => {
    "(\{spec.degree},\{spec.number}):\{spec.variables.length()}:\{spec.permutations.length()}"
  })
  .join("|")
}

///|
test "numberfields galois: resolvent definitions parity" {
  let specs = @sympolys.define_resolvents()
  assert_eq(resolvent_spec_port_summary(specs), define_resolvents())
  assert_eq(
    @sympolys.sparse_symmetrize_resolvent_coeffs(specs[1]).join("|"),
    sparse_symmetrize_resolvent_coeffs(4, 1),
  )
}
