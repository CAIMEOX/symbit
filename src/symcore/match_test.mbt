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
