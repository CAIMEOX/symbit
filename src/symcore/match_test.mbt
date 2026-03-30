///|
test "wild helpers expose exclude and property payloads" {
  let x = Expr::Symbol("x")
  let wild = Expr::Wild("a", [x], [WildProperty::Integer, WildProperty::Positive])
  match wild_parts(wild) {
    Some((name, exclude, properties)) => {
      inspect(name, content="a")
      json_inspect(exclude.map(@symprint.to_string), content=["x"])
      json_inspect(
        properties.map(wild_property_name),
        content=["integer", "positive"],
      )
    }
    None => fail("expected wild parts")
  }
}

///|
test "wild_matches respects exclude and direct properties" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let a = Expr::Wild("a", [], [])
  let b = Expr::Wild("b", [x], [])
  let p = Expr::Wild(
    "p",
    [],
    [WildProperty::Positive, WildProperty::Integer],
  )
  match wild_matches(a, function("sin", [x])) {
    Some(env) =>
      inspect(
        @symprint.to_string(env.get(a).unwrap_or(int(0))),
        content="sin(x)",
      )
    None => fail("expected unconstrained wild to match")
  }
  assert_true(wild_matches(b, y) is Some(_))
  assert_false(wild_matches(b, function("sin", [x])) is Some(_))
  assert_true(wild_matches(p, int(2)) is Some(_))
  assert_false(wild_matches(p, rational_from_ints(1, 2)) is Some(_))
  assert_false(
    wild_matches(
      p,
      Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity),
    ) is Some(_),
  )
}

///|
test "expr_match uses full wild identity and structural recursion" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let a = Expr::Wild("a", [], [])
  let a_excluding_x = Expr::Wild("a", [x], [])
  let pattern = apply(Expr::FunctionHead("f"), [a, a]).unwrap_or(int(0))
  let match_expr = apply(Expr::FunctionHead("f"), [x, x]).unwrap_or(int(0))
  match expr_match(pattern, match_expr) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="x")
    None => fail("expected repeated wild match")
  }
  assert_false(
    expr_match(pattern, apply(Expr::FunctionHead("f"), [x, y]).unwrap_or(int(0))) is
    Some(_),
  )
  let distinct_pattern = apply(
    Expr::FunctionHead("f"),
    [a, a_excluding_x],
  ).unwrap_or(int(0))
  match expr_match(
    distinct_pattern,
    apply(Expr::FunctionHead("f"), [y, y]).unwrap_or(int(0)),
  ) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="y")
      inspect(
        @symprint.to_string(env.get(a_excluding_x).unwrap_or(int(0))),
        content="y",
      )
    }
    None => fail("expected distinct wild identities to coexist")
  }
  assert_false(
    expr_match(
      distinct_pattern,
      apply(Expr::FunctionHead("f"), [x, x]).unwrap_or(int(0)),
    ) is Some(_),
  )
}

///|
test "expr_match handles source-style commutative wildcard matching" {
  let a = Expr::Wild("a", [], [])
  let b = Expr::Wild("b", [], [])
  let c = Expr::Wild("c", [], [])
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")

  match expr_match(mul([a, x]), mul([int(3), x])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="3")
    None => fail("expected a*x to match 3*x")
  }

  let pattern = add([a, mul([function("sin", [b]), c])])
  let match_expr = add([x, mul([function("sin", [y]), z])])
  match expr_match(pattern, match_expr) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="x")
      inspect(@symprint.to_string(env.get(b).unwrap_or(int(0))), content="y")
      inspect(@symprint.to_string(env.get(c).unwrap_or(int(0))), content="z")
    }
    None => fail("expected source-style commutative add match")
  }

  let a0 = Expr::Wild("a", [x, y, z], [])
  let b0 = Expr::Wild("b", [], [])
  match expr_match(mul([a0, b0]), mul([int(2), pow(x, int(3)), y, z])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a0).unwrap_or(int(0))), content="2")
      inspect(
        @symprint.to_string(env.get(b0).unwrap_or(int(0))),
        content="x**3*y*z",
      )
    }
    None => fail("expected excluded wild to isolate scalar factor")
  }
}
