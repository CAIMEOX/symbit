///|
fn ring_wb_domain_text(result : RingFactoryResult) -> String {
  domain_to_sympy_string(result.domain)
}

///|
test "ring factory frontdoors: typed polynomial rings and fields" {
  let r = ring(["x", "y"], Domain::ZZ)
  inspect(ring_wb_domain_text(r), content="ZZ[x,y]")
  debug_inspect(r.gens, content="[\"x\", \"y\"]")
  inspect(
    r.symbols.map(item => @symprint.pretty_string(item)).join(","),
    content="x,y",
  )

  let f = field(["x"], Domain::QQ)
  inspect(ring_wb_domain_text(f), content="QQ(x)")
  inspect(xring(["t"], Domain::QQ).order == TermOrder::Lex, content="true")
  debug_inspect(vfield(["t"], Domain::QQ).gens, content="[\"t\"]")
}

///|
test "ring factory frontdoors: inferred sring and sfield" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let r = sring([x * y + int(1)])
  debug_inspect(r.gens, content="[\"x\", \"y\"]")
  inspect(ring_wb_domain_text(r), content="ZZ[x,y]")
  let f = sfield([x + @symcore.rational_from_ints(1, 2)])
  debug_inspect(f.gens, content="[\"x\"]")
  inspect(ring_wb_domain_text(f), content="QQ(x)")
}
