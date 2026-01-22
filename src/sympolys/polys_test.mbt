///|
test "from_expr to_expr roundtrip" {
  let expr = @symcore.add([
    @symcore.mul([
      @symcore.int(2),
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
    ]),
    @symcore.symbol("y"),
  ])
  let poly = PolyBuilder::new(["x", "y"], Domain::ZZ).from_expr(expr) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  inspect(poly.to_string(), content="y + 2 * x^2")
}

///|
test "polynomial multiplication and degree" {
  let p = PolyBuilder::new(["x"], Domain::ZZ).from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(1)]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let prod = p.mul(p) catch { e => fail("unexpected error: \{e.to_string()}") }
  inspect(prod.to_string(), content="1 + x^2 + 2 * x")
  inspect("\{prod.degree(0)}", content="2")
}

///|
test "reject non-integer exponent" {
  let expr = @symcore.pow(
    @symcore.symbol("x"),
    @symcore.rational_from_ints(1, 2),
  )
  let status = try PolyBuilder::new(["x"], Domain::ZZ).from_expr(expr) catch {
    e => e.to_string()
  } noraise {
    _ => "Ok"
  }
  inspect(status, content="BadExponent")
}

///|
test "reject rational coefficient in ZZ domain" {
  let expr = @symcore.rational_from_ints(1, 2)
  let status = try PolyBuilder::new(["x"], Domain::ZZ).from_expr(expr) catch {
    e => e.to_string()
  } noraise {
    _ => "Ok"
  }
  inspect(status, content="CoefficientNotInteger")
}

///|
test "gcd univariate over QQ" {
  let builder = PolyBuilder::new(["x"], Domain::QQ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.mul([@symcore.int(-1), @symcore.symbol("x")]),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let q = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(-1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let g = p.gcd_univar(q) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  inspect(g.to_string(), content="-1 + x^2")
}

///|
test "term order grlex sorts by total degree" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ).order(TermOrder::Grlex)
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.symbol("y"),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  inspect(poly.to_string(), content="y + x^2")
}

///|
test "resultant over QQ univariate" {
  let builder = PolyBuilder::new(["x"], Domain::QQ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let q = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let res = try p.resultant(q, 0) catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    r => r
  }
  inspect(res, content="2")
}

///|
test "GF(p) arithmetic in factors" {
  let builder = PolyBuilder::new(["x"], Domain::GF(5))
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  inspect(poly.to_string(), content="1 + x^2")
  let factors = poly.factor() catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let repr = factors.map(pair => pair.0.to_string()).join(", ")
  inspect(repr, content="3 + x, 2 + x")
}

///|
test "square-free factorization over ZZ" {
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
  let factors = poly.factor() catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let repr = factors.map(pair => "\{pair.0.to_string()}^\{pair.1}").join(", ")
  inspect(repr, content="2 + x^1, -1 + x^2")
}

///|
test "multivariate division lex order" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f = builder.from_expr(
    @symcore.add([
      @symcore.mul([
        @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
        @symcore.symbol("y"),
      ]),
      @symcore.mul([
        @symcore.symbol("x"),
        @symcore.pow(@symcore.symbol("y"), @symcore.int(2)),
      ]),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let d = builder.from_expr(
    @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let (quotients, rem) = try f.divmod_multivar([d]) catch {
    e => fail("unexpected error: \{e.to_string()}")
  } noraise {
    v => v
  }
  inspect(rem.to_string(), content="0")
  inspect(quotients[0].to_string(), content="x + y")
}

///|
test "groebner basis simple lex" {
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
    b => b
  }
  let repr = basis.map(p => p.to_string()).join(" | ")
  inspect(repr, content="-1 + x | -1 + y")
}

///|
test "array push/pop mutates" {
  let arr : Array[Int] = Array::new()
  arr.push(1)
  let _ = arr.pop()
  inspect("\{arr.length()}", content="0")
}

///|
test "hensel+CRT factor over ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(4)),
      @symcore.int(-1),
    ]),
  ) catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let factors = poly.factor() catch {
    e => fail("unexpected error: \{e.to_string()}")
  }
  let parts = factors.map(pair => pair.0.to_string())
  parts.sort()
  let repr = parts.join(" | ")
  inspect(repr, content="1 + x | -1 + x | 1 + x^2")
}
