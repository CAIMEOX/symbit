///|
test "construct_domain chooses ground and composite domains" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let ints = construct_domain([int(2), int(3), int(4)])
  inspect(domain_to_sympy_string(ints.domain), content="ZZ")
  inspect(
    ints.elements.map(item => @symprint.pretty_string(item)).join(" | "),
    content="2 | 3 | 4",
  )
  let poly = construct_domain([
    int(2) * x + int(1),
    @symcore.rational_from_ints(3, 4),
  ])
  inspect(domain_to_sympy_string(poly.domain), content="QQ[x]")
  let frac = construct_domain([y * (x ^ int(-1)), x * ((int(1) - y) ^ int(-1))])
  inspect(domain_to_sympy_string(frac.domain), content="ZZ(x,y)")
}

///|
test "inverse order frontdoors and root aliases are visible" {
  inspect(compare_exps_igrevlex([2, 0], [1, 1]), content="-1")
  inspect(ilex() == TermOrder::Ilex, content="true")
  inspect(igrlex() == TermOrder::Igrlex, content="true")
  inspect(igrevlex() == TermOrder::Igrevlex, content="true")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let root : CRootOf = rootof(b.from_expr((x ^ int(2)) + int(1)), 0)
  inspect(root.to_string(), content="CRootOf(x**2 + 1, 0)")
  inspect(
    root_sum(b.from_expr((x ^ int(2)) + int(1))).to_string(),
    content="RootSum(x**2 + 1)",
  )
}
