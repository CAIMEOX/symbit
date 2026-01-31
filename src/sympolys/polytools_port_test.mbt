///|
test "factor_list x^4 - 1 over ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(4)),
      @symcore.int(-1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let (content, factors) = try poly.factor_list() catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    v => v
  }
  inspect(content.to_string(), content="1")
  let reprs = factors.map(pair => "(\{pair.0.to_string()}, \{pair.1})")
  reprs.sort()
  let joined = reprs.join(" | ")
  inspect(joined, content="(1 + x, 1) | (-1 + x, 1) | (1 + x**2, 1)")
}

///|
test "factor over GF(5) splits x^2 + 1" {
  let builder = PolyBuilder::new(["x"], Domain::GF(5))
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let factors = try poly.factor() catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    v => v
  }
  let reprs = factors.map(pair => "(\{pair.0.to_string()}, \{pair.1})")
  reprs.sort()
  let joined = reprs.join(" | ")
  inspect(joined, content="(2 + x, 1) | (3 + x, 1)")
}

///|
test "gcd_univar matches x^2-1 and x^2-x" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(-1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let q = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.mul([@symcore.int(-1), @symcore.symbol("x")]),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let g = try p.gcd_univar(q) catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    v => v
  }
  inspect(g.to_string(), content="-1 + x")
}

///|
test "divmod_univar gives quotient and remainder in ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
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
  inspect(q.to_string(), content="-1 + x")
  inspect(r.to_string(), content="2")
}

///|
test "sqf_part removes repeated factors" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = builder.from_expr(
    @symcore.mul([
      @symcore.pow(
        @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
        @symcore.int(2),
      ),
      @symcore.add([@symcore.symbol("x"), @symcore.int(2)]),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let sqf = try poly.sqf_part() catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    v => v
  }
  inspect(sqf.to_string(), content="-2 + x + x**2")
}

///|
test "groebner simple elimination aligns with SymPy expectation" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f1 = builder.from_expr(
    @symcore.add([
      @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
      @symcore.int(-1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let f2 = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let basis = try Poly::groebner([f1, f2], order=TermOrder::Lex) catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    v => v
  }
  let repr = basis.map(p => p.to_string()).join(" | ")
  inspect(repr, content="-1 + x | -1 + y")
}
