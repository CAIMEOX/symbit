///|
fn order_to_sympy(order : TermOrder) -> String {
  match order {
    TermOrder::Lex => "lex"
    TermOrder::Grlex => "grlex"
    TermOrder::Grevlex => "grevlex"
    _ => "lex"
  }
}

///|
fn normalize_basis_str(s : String) -> String {
  let parts : Array[String] = Array::new()
  for part in s.split("|") {
    let raw = part.to_string()
    let monic = try sympy_oracle_call("monic_expr_str", [OracleArg::Str(raw)]) catch { _ => raw } noraise {
      v => v
    }
    let normalized = try sympy_normalize(monic) catch { _ => monic } noraise { v => v }
    parts.push(canonical_cmp(normalized))
  }
  parts.sort()
  parts.join("|")
}

///|
fn expect_groebner_same(polys : Array[Poly], order : TermOrder) -> Unit raise {
  let basis = try Poly::groebner(polys, order=order) catch { e => fail(e.to_string()) } noraise { v => v }
  let ours = normalize_basis_str(groebner_to_string(basis) catch { e => fail(e.to_string()) })
  let exprs = polys.map(p => p.to_string())
  let kwargs : Map[String, OracleArg] = {}
  kwargs["order"] = OracleArg::Str(order_to_sympy(order))
  let oracle = normalize_basis_str(sympy_oracle_call(
    "groebner_str",
    [OracleArg::StrList(exprs)],
    kwargs=kwargs,
  ))
  guard ours == oracle else {
    fail("groebner mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "groebnertools: simple lex pair" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f1 = b.from_expr(
    @symcore.add([
      @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
      @symcore.int(-1),
    ]),
  ) catch { e => fail(e.to_string()) }
  let f2 = b.from_expr(@symcore.add([@symcore.symbol("x"), @symcore.int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_groebner_same([f1, f2], TermOrder::Lex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: grevlex ordering changes basis" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ).order(TermOrder::Grevlex)
  let f1 = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.symbol("y"),
    ]),
  ) catch { e => fail(e.to_string()) }
  let f2 = b.from_expr(@symcore.add([@symcore.symbol("x"), @symcore.int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_groebner_same([f1, f2], TermOrder::Grevlex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: lex basis for x^2 + 2*x*y^2, x*y + 2*y^3 - 1" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.mul([
        @symcore.int(2),
        @symcore.symbol("x"),
        @symcore.pow(@symcore.symbol("y"), @symcore.int(2)),
      ]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
      @symcore.mul([
        @symcore.int(2),
        @symcore.pow(@symcore.symbol("y"), @symcore.int(3)),
      ]),
      @symcore.int(-1),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Lex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: grlex basis for x^3-2*x*y, x^2*y + x - 2*y^2" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ).order(TermOrder::Grlex)
  let f = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.mul([
        @symcore.int(-2),
        @symcore.symbol("x"),
        @symcore.symbol("y"),
      ]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.mul([
        @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
        @symcore.symbol("y"),
      ]),
      @symcore.symbol("x"),
      @symcore.mul([@symcore.int(-2), @symcore.pow(@symcore.symbol("y"), @symcore.int(2))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Grlex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: lex basis for x - z^2, y - z^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let f = b.from_expr(
    @symcore.add([
      @symcore.symbol("x"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("z"), @symcore.int(2))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.symbol("y"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("z"), @symcore.int(3))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Lex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: grlex basis for x - z^2, y - z^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let f = b.from_expr(
    @symcore.add([
      @symcore.symbol("x"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("z"), @symcore.int(2))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.symbol("y"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("z"), @symcore.int(3))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Grlex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: lex basis for y - x^2, z - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let f = b.from_expr(
    @symcore.add([
      @symcore.symbol("y"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("x"), @symcore.int(2))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.symbol("z"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("x"), @symcore.int(3))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Lex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: grlex basis for y - x^2, z - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let f = b.from_expr(
    @symcore.add([
      @symcore.symbol("y"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("x"), @symcore.int(2))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.symbol("z"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("x"), @symcore.int(3))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Grlex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: lex basis for z - x^2, y - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let f = b.from_expr(
    @symcore.add([
      @symcore.symbol("z"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("x"), @symcore.int(2))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.symbol("y"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("x"), @symcore.int(3))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Lex) catch { e => fail(e.to_string()) }
}

///|
test "groebnertools: grlex basis for x - y^2, z - y^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let f = b.from_expr(
    @symcore.add([
      @symcore.symbol("x"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("y"), @symcore.int(2))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let g = b.from_expr(
    @symcore.add([
      @symcore.symbol("z"),
      @symcore.mul([@symcore.int(-1), @symcore.pow(@symcore.symbol("y"), @symcore.int(3))]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_groebner_same([f, g], TermOrder::Grlex) catch { e => fail(e.to_string()) }
}
