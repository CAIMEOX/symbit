///|
test "from_expr_defaults infers gens and QQ domain" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = x * y + @symcore.rational_from_ints(1, 2)
  let poly = Poly::from_expr_defaults(expr)
  inspect(poly.gens.to_string(), content="[\"x\", \"y\"]")
  match poly.domain {
    Domain::QQ => ()
    _ => fail("expected QQ domain")
  }
  inspect(poly.to_string(), content="x*y + 1/2")
}

///|
test "resolve_domain modulus and gaussian" {
  let x = @symcore.symbol("x")
  let d1 = resolve_domain(
    domain=None,
    modulus=Some(5),
    gaussian=None,
    extension=None,
    gf_degree=None,
    expr=Some(x),
  )
  match d1 {
    Domain::GF(p) => inspect("\{p}", content="5")
    _ => fail("expected GF(5)")
  }
  let d2 = resolve_domain(
    domain=None,
    modulus=None,
    gaussian=Some(true),
    extension=None,
    gf_degree=None,
    expr=Some(x),
  )
  match d2 {
    Domain::CC => ()
    _ => fail("expected CC")
  }
  let status : Result[Domain, PolyError] = try? resolve_domain(
    domain=Some(Domain::GF(3)),
    modulus=Some(5),
    gaussian=None,
    extension=None,
    gf_degree=None,
    expr=None,
  )
  guard status is Err(PolyError::BadModulus) else {
    fail("expected BadModulus error")
  }
}

///|
test "resolve_domain gf extension builds default modulus poly" {
  let d = resolve_domain(
    domain=None,
    modulus=Some(3),
    gaussian=None,
    extension=None,
    gf_degree=Some(2),
    expr=None,
  )
  match d {
    Domain::GFExt(p, k, poly) => {
      inspect("\{p}", content="3")
      inspect("\{k}", content="2")
      inspect(poly.to_string(), content="[1, 0, 1]")
    }
    _ => fail("expected GFExt")
  }
}

///|
test "resolve_domain builds algebraic extension" {
  let expr = @symcore.symbol("alpha")
  let d = resolve_domain(
    domain=Some(Domain::QQ),
    modulus=None,
    gaussian=None,
    extension=Some(["alpha"]),
    gf_degree=None,
    expr=Some(expr),
  )
  match d {
    Domain::AlgExt(base, gens, rels) => {
      match base {
        Domain::QQ => ()
        _ => fail("expected QQ base")
      }
      inspect(gens.to_string(), content="[\"alpha\"]")
      inspect("\{rels.length()}", content="1")
    }
    _ => fail("expected AlgExt")
  }
}

///|
test "integer polynomial division matches sympy" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let p = builder.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1),
  )
  let d = builder.from_expr(x + @symcore.int(1))
  let (q, r) = p.divmod_univar(d)
  inspect(q.to_string(), content="x + 1")
  inspect(r.to_string(), content="0")
}

///|
test "total_degree and per-variable degree" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let poly = builder.from_expr(
    (x ^ @symcore.int(2)) * (y ^ @symcore.int(3)) + y,
  )
  inspect("\{poly.degree(0)}", content="2")
  inspect("\{poly.degree(1)}", content="3")
  inspect("\{poly.total_degree()}", content="5")
}
