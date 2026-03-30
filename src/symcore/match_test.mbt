///|
test "wild helpers expose exclude and property payloads" {
  let x = Expr::Symbol("x")
  let wild = Expr::Wild("a", [x], [
    WildProperty::Integer,
    WildProperty::Positive,
  ])
  match wild_parts(wild) {
    Some((name, exclude, properties)) => {
      inspect(name, content="a")
      json_inspect(exclude.map(@symprint.to_string), content=["x"])
      json_inspect(properties.map(wild_property_name), content=[
        "integer", "positive",
      ])
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
  let p = Expr::Wild("p", [], [WildProperty::Positive, WildProperty::Integer])
  let s = Expr::Wild("s", [], [WildProperty::Symbol])
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
  assert_true(wild_matches(s, y) is Some(_))
  assert_false(wild_matches(s, int(3)) is Some(_))
  assert_false(
    wild_matches(s, Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit))
    is Some(_),
  )
  assert_false(
    wild_matches(p, Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity))
    is Some(_),
  )
  let seeded : MatchEnv = {}
  seeded.set(a, y)
  let overridden = wild_matches(a, x, repl_dict=seeded)
  match overridden {
    Some(env) =>
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="x")
    None => fail("expected direct wild match to override prior env entry")
  }
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
    expr_match(
      pattern,
      apply(Expr::FunctionHead("f"), [x, y]).unwrap_or(int(0)),
    )
    is Some(_),
  )
  let distinct_pattern = apply(Expr::FunctionHead("f"), [a, a_excluding_x]).unwrap_or(
    int(0),
  )
  match
    expr_match(
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
    )
    is Some(_),
  )
  let b_nested = Expr::Wild("b", [], [])
  let nested_pattern = apply(Expr::FunctionHead("f"), [a, add([a, b_nested])]).unwrap_or(
    int(0),
  )
  match
    expr_match(
      nested_pattern,
      apply(Expr::FunctionHead("f"), [x, add([x, y])]).unwrap_or(int(0)),
    ) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="x")
      inspect(
        @symprint.to_string(env.get(b_nested).unwrap_or(int(0))),
        content="y",
      )
    }
    None =>
      fail("expected recursive matching to xreplace current wild bindings")
  }
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

///|
test "expr_match follows SymPy source examples for add mul and powers" {
  let x = Expr::Symbol("x")
  let p = Expr::Wild("p", [], [])
  let q = Expr::Wild("q", [], [])
  let a_excluding_x = Expr::Wild("a", [x], [])

  match expr_match(add([mul([p, x]), q]), add([mul([int(4), x]), int(5)])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="4")
      inspect(@symprint.to_string(env.get(q).unwrap_or(int(0))), content="5")
    }
    None => fail("expected linear add match from SymPy source examples")
  }

  assert_false(
    expr_match(mul([a_excluding_x, x]), mul([int(3), pow(x, int(2))]))
    is Some(_),
  )

  match expr_match(pow(x, p), int(1)) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(99))), content="0")
    None => fail("expected 1 to match x**p with p = 0")
  }

  match
    expr_match(
      mul([p, function("cos", [mul([q, x])])]),
      function("cos", [mul([int(5), x])]),
    ) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="1")
      inspect(@symprint.to_string(env.get(q).unwrap_or(int(0))), content="5")
    }
    None => fail("expected cosine coefficient match from SymPy source examples")
  }
}

///|
test "expr_match covers more SymPy source add and mul examples" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let a = Expr::Symbol("a")
  let b = Expr::Symbol("b")
  let c = Expr::Symbol("c")
  let p = Expr::Wild("p", [], [])
  let q = Expr::Wild("q", [], [])
  let r = Expr::Wild("r", [], [])

  match expr_match(add([b, p]), add([a, b, c, x])) {
    Some(env) =>
      inspect(
        @symprint.to_string(env.get(p).unwrap_or(int(0))),
        content="a + c + x",
      )
    None => fail("expected additive remainder match from SymPy source")
  }

  match expr_match(add([a, p, c]), add([a, b, c, x])) {
    Some(env) =>
      inspect(
        @symprint.to_string(env.get(p).unwrap_or(int(0))),
        content="b + x",
      )
    None => fail("expected additive middle remainder match from SymPy source")
  }

  match expr_match(add([b, p, c]), add([a, b, c, x])) {
    Some(env) =>
      inspect(
        @symprint.to_string(env.get(p).unwrap_or(int(0))),
        content="a + x",
      )
    None => fail("expected additive mixed remainder match from SymPy source")
  }

  match
    expr_match(add([mul([p, x]), int(5)]), add([mul([int(4), x]), int(5)])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="4")
    None => fail("expected linear coefficient match from SymPy source")
  }

  match
    expr_match(add([mul([int(3), x]), p]), add([mul([int(4), x]), int(5)])) {
    Some(env) =>
      inspect(
        @symprint.to_string(env.get(p).unwrap_or(int(0))),
        content="x + 5",
      )
    None => fail("expected additive fallback match from SymPy source")
  }

  match expr_match(add([mul([int(4), x]), mul([p, y])]), mul([int(4), x])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="0")
    None => fail("expected additive embedding to expose zero coefficient")
  }

  match expr_match(mul([p, x]), x) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="1")
    None => fail("expected x to match p*x with p = 1")
  }

  match
    expr_match(
      mul([pow(x, p), function("exp", [mul([x, q])])]),
      function("exp", [x]),
    ) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(99))), content="0")
      inspect(@symprint.to_string(env.get(q).unwrap_or(int(99))), content="1")
    }
    None => fail("expected exponential source match with implicit x**0")
  }

  match
    expr_match(
      mul([p, pow(add([mul([q, x]), r]), int(-1))]),
      mul([int(3), pow(add([mul([int(4), x]), int(5)]), int(-1))]),
    ) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="3")
      inspect(@symprint.to_string(env.get(q).unwrap_or(int(0))), content="4")
      inspect(@symprint.to_string(env.get(r).unwrap_or(int(0))), content="5")
    }
    None => fail("expected reciprocal linear form match from SymPy source")
  }
}

///|
test "expr_match covers source function-head and complex wildcard examples" {
  let x = Expr::Symbol("x")
  let a = Expr::Symbol("a")
  let b = Expr::Symbol("b")
  let p = Expr::Wild("p", [], [])
  let q = Expr::Wild("q", [], [])
  let g = Expr::WildFunction("g", [])
  let w = Expr::Wild("w", [], [])
  let imag = Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)

  match
    expr_match(
      mul([p, Expr::Apply(g, [mul([q, x])])]),
      function("cos", [mul([int(5), x])]),
    ) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="1")
      inspect(@symprint.to_string(env.get(g).unwrap_or(int(0))), content="cos")
      inspect(@symprint.to_string(env.get(q).unwrap_or(int(0))), content="5")
    }
    None => fail("expected function-head wild match from SymPy source")
  }

  match expr_match(mul([p, g]), function("cos", [mul([int(5), x])])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="1")
      inspect(
        @symprint.to_string(env.get(g).unwrap_or(int(0))),
        content="cos(5*x)",
      )
    }
    None => fail("expected bare wild-function match from SymPy source")
  }

  match expr_match(g, g) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(g).unwrap_or(int(0))), content="g_")
    None => fail("expected WildFunction to match itself like SymPy source")
  }

  match expr_match(add([w, imag]), add([int(1), imag])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="1")
    None => fail("expected additive complex match from SymPy source")
  }

  match expr_match(mul([w, imag]), mul([int(2), imag])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="2")
    None => fail("expected multiplicative complex match from SymPy source")
  }

  let wr = Expr::Wild("wr", [], [])
  let wi = Expr::Wild("wi", [], [])
  match expr_match(add([wr, mul([wi, imag])]), add([a, mul([b, imag])])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(wr).unwrap_or(int(0))), content="a")
      inspect(@symprint.to_string(env.get(wi).unwrap_or(int(0))), content="b")
    }
    None => fail("expected cartesian complex decomposition match")
  }
}

///|
test "expr_match covers more SymPy source factorization and derivative examples" {
  let x = Expr::Symbol("x")
  let a = Expr::Symbol("a")
  let b = Expr::Symbol("b")
  let c = Expr::Symbol("c")
  let p = Expr::Wild("p", [], [])
  let ax = Expr::Wild("a", [x], [])
  let q = Expr::Wild("q", [], [])
  let fx = applied_undefined_function("f", [x])
  let dfx = derivative(fx, x)

  match
    expr_match(
      add([mul([p, pow(x, int(2))]), mul([p, x]), mul([int(2), p])]),
      add([mul([int(3), x]), int(3), mul([int(6), pow(x, int(-1))])]),
    ) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="3/x")
    None => fail("expected common-factor wild match from SymPy source")
  }

  assert_false(
    expr_match(
      add([mul([ax, pow(x, int(2))]), mul([ax, x]), mul([int(2), ax])]),
      add([mul([int(3), x]), int(3), mul([int(6), pow(x, int(-1))])]),
    )
    is Some(_),
  )

  match
    expr_match(mul([add([p, b]), add([p, c])]), mul([add([a, b]), add([a, c])])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="a")
    None => fail("expected repeated additive factor match from SymPy source")
  }

  match expr_match(mul([p, q]), add([mul([x, Expr::Symbol("y")]), int(1)])) {
    Some(env) => {
      let lhs = @symprint.to_string(env.get(p).unwrap_or(int(0)))
      let rhs = @symprint.to_string(env.get(q).unwrap_or(int(0)))
      let allowed = [("1", "x*y + 1"), ("x*y + 1", "1")]
      assert_true(allowed.contains((lhs, rhs)))
    }
    None => fail("expected interface-style wildcard product match")
  }

  match
    expr_match(add([mul([p, dfx]), q]), add([mul([int(3), dfx]), int(-1)])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="3")
      inspect(@symprint.to_string(env.get(q).unwrap_or(int(0))), content="-1")
    }
    None => fail("expected derivative wildcard coefficient match")
  }
}

///|
test "expr_match follows more SymPy source exclude and wild-on-wild examples" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let a = Expr::Symbol("a")
  let p = Expr::Wild("p", [int(1), x], [])
  let q = Expr::Wild("q", [], [])
  let r = Expr::Wild("r", [Expr::FunctionHead("sin"), y], [])

  guard expr_match(r, function("sin", [x])) is None else {
    fail("expected exclude=[sin, y] to reject sin(x)")
  }
  guard expr_match(r, function("cos", [y])) is None else {
    fail("expected exclude=[sin, y] to reject cos(y)")
  }

  match
    expr_match(
      add([mul([p, pow(x, int(2))]), mul([q, x]), r]),
      add([mul([int(3), pow(x, int(2))]), mul([y, x]), a]),
    ) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="3")
      inspect(@symprint.to_string(env.get(q).unwrap_or(int(0))), content="y")
      inspect(@symprint.to_string(env.get(r).unwrap_or(int(0))), content="a")
    }
    None => fail("expected source-style exclude match on quadratic polynomial")
  }

  guard expr_match(add([x, p]), add([x, int(1)])) is None else {
    fail("expected x + 1 not to match x + p when p excludes 1 and x")
  }
  guard expr_match(add([p, int(1)]), add([x, int(1)])) is None else {
    fail("expected x + 1 not to match p + 1 when p excludes 1 and x")
  }
  match expr_match(add([x, int(1), p]), add([x, int(1)])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(1))), content="0")
    None => fail("expected x + 1 + p to bind p=0 from SymPy source")
  }

  match expr_match(add([q, r]), p) {
    Some(env) => {
      let q_value = @symprint.to_string(env.get(q).unwrap_or(int(-1)))
      let r_value = @symprint.to_string(env.get(r).unwrap_or(int(-1)))
      let options = ["q_=p_|r_=0", "q_=0|r_=p_"]
      inspect(options.contains("q_=\{q_value}|r_=\{r_value}"), content="true")
    }
    None => fail("expected wild-on-wild additive match from SymPy source")
  }

  let q_excluding_p = Expr::Wild("q", [p], [])
  let r_plain = Expr::Wild("r", [], [])
  match expr_match(add([q_excluding_p, r_plain]), p) {
    Some(env) => {
      inspect(
        @symprint.to_string(env.get(q_excluding_p).unwrap_or(int(-1))),
        content="0",
      )
      inspect(
        @symprint.to_string(env.get(r_plain).unwrap_or(int(-1))),
        content="p_",
      )
    }
    None =>
      fail("expected source-style additive wild-on-wild match with exclude=[p]")
  }
  match expr_match(mul([q_excluding_p, r_plain]), p) {
    Some(env) => {
      inspect(
        @symprint.to_string(env.get(q_excluding_p).unwrap_or(int(-1))),
        content="1",
      )
      inspect(
        @symprint.to_string(env.get(r_plain).unwrap_or(int(-1))),
        content="p_",
      )
    }
    None =>
      fail(
        "expected source-style multiplicative wild-on-wild match with exclude=[p]",
      )
  }

  let r_excluding_p = Expr::Wild("r", [p], [])
  guard expr_match(add([q_excluding_p, r_excluding_p]), p) is None else {
    fail(
      "expected additive wild-on-wild match to fail when both wilds exclude p",
    )
  }
  guard expr_match(mul([q_excluding_p, r_excluding_p]), p) is None else {
    fail(
      "expected multiplicative wild-on-wild match to fail when both wilds exclude p",
    )
  }
}

///|
test "expr_match follows SymPy source derivative exclusion examples" {
  let x = Expr::Symbol("x")
  let f = Expr::UndefinedFunction("f")
  let fx = apply(f, [x]).unwrap_or(int(0))
  let d1 = derivative(fx, x)
  let d2 = Expr::Derivative(fx, [x, int(1), x, int(1)])
  let a = Expr::Wild("a", [f, x], [])
  let b = Expr::Wild("b", [f], [])

  assert_true(expr_match(d1, d1) is Some(_))
  assert_false(expr_match(d1, d2) is Some(_))
  assert_false(expr_match(d2, d1) is Some(_))

  match expr_match(add([mul([a, d1]), b]), add([d1, pow(x, int(2))])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="1")
      inspect(@symprint.to_string(env.get(b).unwrap_or(int(0))), content="x**2")
    }
    None => fail("expected first-derivative wildcard match from SymPy source")
  }

  assert_false(
    expr_match(add([mul([a, d2]), b]), add([d1, pow(x, int(2))])) is Some(_),
  )

  let seeded : MatchEnv = {}
  seeded.set(b, pow(x, int(2)))
  let substituted_pattern = xreplace(add([mul([a, d2]), b]), [
    (b, pow(x, int(2))),
  ])
  assert_false(
    expr_match(substituted_pattern, add([d1, pow(x, int(2))]), repl_dict=seeded)
    is Some(_),
  )
}

///|
test "expr_match follows more SymPy source derivative and coefficient bugs" {
  let x = Expr::Symbol("x")
  let f = Expr::UndefinedFunction("f")
  let fx = apply(f, [x]).unwrap_or(int(0))
  let dfx = derivative(fx, x)
  let a = Expr::Wild("a", [fx], [])
  let b = Expr::Wild("b", [fx], [])
  let p = Expr::Wild("p", [], [])

  match expr_match(add([mul([a, dfx]), b]), dfx) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="1")
      inspect(@symprint.to_string(env.get(b).unwrap_or(int(1))), content="0")
    }
    None => fail("expected derivative remainder-zero match from SymPy source")
  }

  match expr_match(mul([int(-1), p, x]), x) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="-1")
    None => fail("expected negative coefficient match bug4 from SymPy source")
  }

  match expr_match(mul([int(-1), p, x]), mul([int(-1), x])) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="1")
    None => fail("expected negative coefficient match bug5 from SymPy source")
  }

  match expr_match(mul([int(3), p, x]), x) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(p).unwrap_or(int(0))), content="1/3")
    None => fail("expected rational coefficient match bug6 from SymPy source")
  }
}

///|
test "expr_match follows SymPy source reciprocal wildcard examples" {
  let x = Expr::Symbol("x")
  let w = Expr::Wild("w", [x], [])
  let y = Expr::Wild("y", [], [])

  match expr_match(pow(y, int(-1)), pow(x, int(-1))) {
    Some(env) =>
      inspect(@symprint.to_string(env.get(y).unwrap_or(int(0))), content="x")
    None => fail("expected y**-1 to match x**-1 before reciprocal examples")
  }

  match expr_match(mul([w, pow(y, int(-1))]), mul([int(3), pow(x, int(-1))])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="3")
      inspect(@symprint.to_string(env.get(y).unwrap_or(int(0))), content="x")
    }
    None => fail("expected 3/x to match w/y from SymPy source")
  }

  match expr_match(mul([w, y]), mul([int(3), x])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="3")
      inspect(@symprint.to_string(env.get(y).unwrap_or(int(0))), content="x")
    }
    None => fail("expected 3*x to match w*y from SymPy source")
  }

  match expr_match(mul([y, pow(w, int(-1))]), mul([x, rational_from_ints(1, 3)])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="3")
      inspect(@symprint.to_string(env.get(y).unwrap_or(int(0))), content="x")
    }
    None => fail("expected x/3 to match y/w from SymPy source")
  }

  match expr_match(mul([y, pow(w, int(-1))]), mul([int(3), x])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="1/3")
      inspect(@symprint.to_string(env.get(y).unwrap_or(int(0))), content="x")
    }
    None => fail("expected 3*x to match y/w from SymPy source")
  }

  match expr_match(mul([w, pow(y, int(-1))]), mul([x, rational_from_ints(1, 3)])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="1/3")
      inspect(
        @symprint.to_string(env.get(y).unwrap_or(int(0))),
        content="x**-1",
      )
    }
    None => fail("expected x/3 to match w/y from SymPy source")
  }

  match expr_match(mul([w, pow(y, int(-1))]), mul([int(3), x])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="3")
      inspect(
        @symprint.to_string(env.get(y).unwrap_or(int(0))),
        content="x**-1",
      )
    }
    None => fail("expected 3*x to match w/y from SymPy source")
  }

  match expr_match(mul([w, y]), mul([int(3), pow(x, int(-1))])) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(w).unwrap_or(int(0))), content="3")
      inspect(
        @symprint.to_string(env.get(y).unwrap_or(int(0))),
        content="x**-1",
      )
    }
    None => fail("expected 3/x to match w*y from SymPy source")
  }

  let a = Expr::Wild("a", [], [])
  guard expr_match(pow(a, int(-1)), int(0)) is None else {
    fail("expected 0 not to match 1/a from SymPy source")
  }
  match expr_match(pow(a, int(-1)), int(3)) {
    Some(env) =>
      inspect(
        @symprint.to_string(env.get(a).unwrap_or(int(0))),
        content="1/3",
      )
    None => fail("expected 3 to match 1/a from SymPy source")
  }
  match expr_match(pow(a, int(-2)), int(3)) {
    Some(env) =>
      inspect(
        @symprint.to_string(env.get(a).unwrap_or(int(0))),
        content="3**(-1/2)",
      )
    None => fail("expected 3 to match 1/a**2 from SymPy source")
  }
}

///|
test "expr_match follows SymPy source implicit zero-power wildcard examples" {
  let x = Expr::Symbol("x")
  let f = Expr::UndefinedFunction("f")
  let fx = apply(f, [x]).unwrap_or(int(0))
  let a = Expr::Wild("a", [], [])
  let b = Expr::Wild("b", [], [])
  let c = Expr::Wild("c", [], [])

  match expr_match(mul([a, pow(fx, c)]), x) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="x")
      inspect(@symprint.to_string(env.get(c).unwrap_or(int(1))), content="0")
    }
    None => fail("expected x to match a*f(x)**c from SymPy source")
  }

  match expr_match(mul([a, b]), x) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="1")
      inspect(@symprint.to_string(env.get(b).unwrap_or(int(0))), content="x")
    }
    None => fail("expected x to match a*b from SymPy source")
  }

  match expr_match(mul([a, b, pow(fx, c)]), x) {
    Some(env) => {
      inspect(@symprint.to_string(env.get(a).unwrap_or(int(0))), content="1")
      inspect(@symprint.to_string(env.get(b).unwrap_or(int(0))), content="x")
      inspect(@symprint.to_string(env.get(c).unwrap_or(int(1))), content="0")
    }
    None => fail("expected x to match a*b*f(x)**c from SymPy source")
  }
}
