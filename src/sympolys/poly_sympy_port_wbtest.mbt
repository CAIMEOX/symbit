///|
test "from_expr_defaults infers gens and QQ domain" {
  let expr = @symcore.add([
    @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
    @symcore.rational_from_ints(1, 2),
  ])
  let poly = Poly::from_expr_defaults(expr) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  inspect(poly.gens.to_string(), content="[\"x\", \"y\"]")
  match poly.domain {
    Domain::QQ => ()
    _ => fail("expected QQ domain")
  }
  inspect(poly.to_string(), content="1/2 + x * y")
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
  let status = try
    resolve_domain(
      domain=Some(Domain::GF(3)),
      modulus=Some(5),
      gaussian=None,
      extension=None,
      gf_degree=None,
      expr=None,
    )
  catch {
    e => e.to_string()
  } noraise {
    _ => "Ok"
  }
  inspect(status, content="BadModulus")
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
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.mul([@symcore.int(2), @symcore.symbol("x")]),
      @symcore.int(1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let d = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(1)]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let (q, r) = try p.divmod_univar(d) catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    v => v
  }
  inspect(q.to_string(), content="1 + x")
  inspect(r.to_string(), content="0")
}

///|
test "total_degree and per-variable degree" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.mul([
        @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
        @symcore.pow(@symcore.symbol("y"), @symcore.int(3)),
      ]),
      @symcore.symbol("y"),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  inspect("\{poly.degree(0)}", content="2")
  inspect("\{poly.degree(1)}", content="3")
  inspect("\{poly.total_degree()}", content="5")
}
