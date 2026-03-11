///|
test "physics.quantum.qexpr/state/operator: local core forms" {
  let base = qexpr([@symcore.int(0), @symcore.int(1)])
  inspect(base.to_string(), content="01")
  inspect(base.repr(), content="QExpr(Integer(0),Integer(1))")

  let k = ket([@symcore.symbol("k")])
  let b = bra([@symcore.symbol("b")])
  let t = time_dep_ket([@symcore.int(0)], @symcore.symbol("t"))
  inspect(k.to_string(), content="|k>")
  inspect(b.to_string(), content="<b|")
  inspect(t.to_string(), content="|0;t>")
  inspect(k.dual().to_string(), content="<k|")
  inspect(t.dual().to_string(), content="<0;t|")

  let a = operator([@symcore.symbol("A")])
  let h = hermitian_operator([@symcore.symbol("Hh")])
  let u = unitary_operator([@symcore.symbol("Uu")])
  let id = identity_operator(dimension=@symcore.int(3))
  inspect(a.to_string(), content="A")
  inspect(h.repr(), content="HermitianOperator(Symbol('Hh'))")
  inspect(@symprint.to_string(u.inverse()), content="UnitaryOperator(Uu)**-1")
  inspect(id.to_string(), content="I")
}

///|
test "physics.quantum.innerproduct: local evaluation families" {
  let generic = inner_product(bra([@symcore.symbol("b")]).as_expr(), ket([@symcore.symbol("k")]).as_expr())
  inspect(@symprint.to_string(generic), content="InnerProduct(Bra(b), Ket(k))")

  let bf = inner_product(boson_fock_bra(@symcore.int(1)), boson_fock_ket(@symcore.int(1)))
  inspect(@symprint.to_string(bf), content="1")
  let ff = inner_product(try! fermion_fock_bra(@symcore.int(0)), try! fermion_fock_ket(@symcore.int(1)))
  inspect(@symprint.to_string(ff), content="KroneckerDelta(0, 1)")
}
