///|
test "physics.quantum.qexpr/state/operator: local core forms" {
  let base = qexpr([@symcore.int(0), @symcore.int(1)])
  inspect(Show::to_string(base), content="01")
  inspect(base.repr(), content="QExpr(Integer(0),Integer(1))")

  let k = ket([Symbol("k")])
  let b = bra([Symbol("b")])
  let t = time_dep_ket([@symcore.int(0)], time=Symbol("t"))
  let t_default = time_dep_ket([])
  inspect(Show::to_string(k), content="|k>")
  inspect(Show::to_string(b), content="<b|")
  inspect(Show::to_string(t), content="|0;t>")
  inspect(Show::to_string(t_default), content="|psi;t>")
  inspect(Show::to_string(k.dual()), content="<k|")
  inspect(Show::to_string(t.dual()), content="<0;t|")

  let a = operator([Symbol("A")])
  let h = hermitian_operator([Symbol("Hh")])
  let u = unitary_operator([Symbol("Uu")])
  let id = identity_operator(dimension=@symcore.int(3))
  let ok = orthogonal_ket([Symbol("n")])
  inspect(Show::to_string(a), content="A")
  inspect(h.repr(), content="HermitianOperator(Symbol('Hh'))")
  inspect(
    @symprint.pretty_string(u.inverse()),
    content="UnitaryOperator(Uu)**-1",
  )
  inspect(Show::to_string(id), content="I")
  inspect(Show::to_string(ok.dual()), content="<n|")
  inspect(@symprint.pretty_string(dagger(a.as_expr())), content="Dagger(A)")
}

///|
test "physics.quantum.innerproduct: local evaluation families" {
  let generic = inner_product(
    bra([Symbol("b")]).as_expr(),
    ket([Symbol("k")]).as_expr(),
  )
  inspect(
    @symprint.pretty_string(generic),
    content="InnerProduct(Bra(b), Ket(k))",
  )

  let bf = inner_product(
    boson_fock_bra(@symcore.int(1)),
    boson_fock_ket(@symcore.int(1)),
  )
  inspect(@symprint.pretty_string(bf), content="1")
  let ff = inner_product(
    fermion_fock_bra(@symcore.int(0)),
    fermion_fock_ket(@symcore.int(1)),
  )
  inspect(@symprint.pretty_string(ff), content="KroneckerDelta(0, 1)")
}

///|
test "physics.quantum.operator/state: defaults and outer product semantics" {
  let k = ket([])
  let b = bra([])
  let op = operator([])
  let tket = time_dep_ket([])
  let tbra = time_dep_bra([])
  inspect(Show::to_string(k), content="|psi>")
  inspect(Show::to_string(b), content="<psi|")
  inspect(Show::to_string(op), content="O")
  inspect(Show::to_string(tket), content="|psi;t>")
  inspect(Show::to_string(tbra), content="<psi;t|")

  let k1 = ket([Symbol("k1")]).as_expr()
  let k2 = ket([Symbol("k2")]).as_expr()
  let b1 = bra([Symbol("b1")]).as_expr()
  let b2 = bra([Symbol("b2")]).as_expr()
  quantum_test_assert_expr_equal(
    outer_product(@symcore.int(2) * k1, b1),
    "2*OuterProduct(Ket(k1), Bra(b1))",
    "outer product pulls ket scalar",
  )
  quantum_test_assert_expr_equal(
    outer_product(k1, @symcore.int(3) * b1),
    "3*OuterProduct(Ket(k1), Bra(b1))",
    "outer product pulls bra scalar",
  )
  quantum_test_assert_expr_equal(
    outer_product(k1 + k2, b1),
    "OuterProduct(Ket(k1), Bra(b1)) + OuterProduct(Ket(k2), Bra(b1))",
    "outer product distributes over ket sums",
  )
  quantum_test_assert_expr_equal(
    outer_product(k1, b1 + b2),
    "OuterProduct(Ket(k1), Bra(b1)) + OuterProduct(Ket(k1), Bra(b2))",
    "outer product distributes over bra sums",
  )
  quantum_test_assert_expr_equal(
    outer_product(
      k1 + @symcore.int(2) * k2,
      @symcore.int(3) * b1 + @symcore.int(4) * b2,
    ),
    "3*OuterProduct(Ket(k1), Bra(b1)) + 4*OuterProduct(Ket(k1), Bra(b2)) + 6*OuterProduct(Ket(k2), Bra(b1)) + 8*OuterProduct(Ket(k2), Bra(b2))",
    "outer product distributes across both sums",
  )
}

///|
test "physics.quantum.operator/state: operator simplification hooks" {
  let a = operator([Symbol("A")]).as_expr()
  let u = unitary_operator([Symbol("U")]).as_expr()
  let id3 = identity_operator(dimension=@symcore.int(3)).as_expr()
  quantum_test_assert_expr_equal(
    quantum_canonical_mul(
      @symcore.raw_mul([a, @symcore.raw_pow(a, @symcore.int(-1))]),
    ),
    "1",
    "canonical inverse cancellation",
  )
  quantum_test_assert_expr_equal(
    quantum_canonical_mul(@symcore.raw_mul([u, dagger(u)])),
    "1",
    "canonical unitary cancellation",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(qapply(@symcore.raw_mul([id3, a]))),
    ),
    "A",
    "qapply removes left identity on operators",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(qapply(@symcore.raw_mul([a, id3]))),
    ),
    "A",
    "qapply removes right identity on operators",
  )
  inspect(
    Show::to_string(represent(id3)),
    content="[[1, 0, 0], [0, 1, 0], [0, 0, 1]]",
  )
}

///|
test "physics.quantum.operator/state: outer product trace" {
  let one = @symcore.int(1)
  let op = outer_product(jz_ket(one, one).as_expr(), jz_bra(one, one).as_expr())
  quantum_test_assert_expr_equal(
    tr_doit(tr(op)),
    "1",
    "trace of rank-1 projector",
  )
}
