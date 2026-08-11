///|
test "wild helpers expose exclude and property payloads" {
  let x = Expr::Symbol("x")
  let wild = Expr::Wild("a", [x], [Integer, Positive])
  match wild_parts(wild) {
    Some((name, exclude, properties)) => {
      inspect(name, content="a")
      json_inspect(exclude.map(@symprint.pretty_string), content=["x"])
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
  let p = Expr::Wild("p", [], [Positive, Integer])
  let s = Expr::Wild("s", [], [Symbol])
  match wild_matches(a, function("sin", [x])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
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
  assert_false(wild_matches(s, NumberSymbol(ImaginaryUnit)) is Some(_))
  assert_false(wild_matches(p, NumberSymbol(NegativeInfinity)) is Some(_))
  let seeded : MatchEnv = Map([])
  seeded.set(a, y)
  let overridden = wild_matches(a, x, repl_dict=seeded)
  match overridden {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="x",
      )
    None => fail("expected direct wild match to override prior env entry")
  }
}

///|
test "expr_match uses full wild identity and structural recursion" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let a = Expr::Wild("a", [], [])
  let a_excluding_x = Expr::Wild("a", [x], [])
  let pattern = apply(FunctionHead("f"), [a, a]).unwrap_or(int(0))
  let match_expr = apply(FunctionHead("f"), [x, x]).unwrap_or(int(0))
  match expr_match(pattern, match_expr) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="x",
      )
    None => fail("expected repeated wild match")
  }
  assert_false(
    expr_match(pattern, apply(FunctionHead("f"), [x, y]).unwrap_or(int(0)))
    is Some(_),
  )
  let distinct_pattern = apply(FunctionHead("f"), [a, a_excluding_x]).unwrap_or(
    int(0),
  )
  match
    expr_match(
      distinct_pattern,
      apply(FunctionHead("f"), [y, y]).unwrap_or(int(0)),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="y",
      )
      inspect(
        @symprint.pretty_string(env.get(a_excluding_x).unwrap_or(int(0))),
        content="y",
      )
    }
    None => fail("expected distinct wild identities to coexist")
  }
  assert_false(
    expr_match(
      distinct_pattern,
      apply(FunctionHead("f"), [x, x]).unwrap_or(int(0)),
    )
    is Some(_),
  )
  let b_nested = Expr::Wild("b", [], [])
  let nested_pattern = apply(FunctionHead("f"), [a, add([a, b_nested])]).unwrap_or(
    int(0),
  )
  match
    expr_match(
      nested_pattern,
      apply(FunctionHead("f"), [x, add([x, y])]).unwrap_or(int(0)),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(b_nested).unwrap_or(int(0))),
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
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="3",
      )
    None => fail("expected a*x to match 3*x")
  }

  let pattern = add([a, mul([function("sin", [b]), c])])
  let match_expr = add([x, mul([function("sin", [y]), z])])
  match expr_match(pattern, match_expr) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="y",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(0))),
        content="z",
      )
    }
    None => fail("expected source-style commutative add match")
  }

  let a0 = Expr::Wild("a", [x, y, z], [])
  let b0 = Expr::Wild("b", [], [])
  match expr_match(mul([a0, b0]), mul([int(2), pow(x, int(3)), y, z])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a0).unwrap_or(int(0))),
        content="2",
      )
      inspect(
        @symprint.pretty_string(env.get(b0).unwrap_or(int(0))),
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
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="4",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="5",
      )
    }
    None => fail("expected linear add match from SymPy source examples")
  }

  assert_false(
    expr_match(mul([a_excluding_x, x]), mul([int(3), pow(x, int(2))]))
    is Some(_),
  )

  match expr_match(pow(x, p), int(1)) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(99))),
        content="0",
      )
    None => fail("expected 1 to match x**p with p = 0")
  }

  match
    expr_match(
      mul([p, function("cos", [mul([q, x])])]),
      function("cos", [mul([int(5), x])]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="5",
      )
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
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="a + c + x",
      )
    None => fail("expected additive remainder match from SymPy source")
  }

  match expr_match(add([a, p, c]), add([a, b, c, x])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="b + x",
      )
    None => fail("expected additive middle remainder match from SymPy source")
  }

  match expr_match(add([b, p, c]), add([a, b, c, x])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="a + x",
      )
    None => fail("expected additive mixed remainder match from SymPy source")
  }

  match
    expr_match(add([mul([p, x]), int(5)]), add([mul([int(4), x]), int(5)])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="4",
      )
    None => fail("expected linear coefficient match from SymPy source")
  }

  match
    expr_match(add([mul([int(3), x]), p]), add([mul([int(4), x]), int(5)])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="x + 5",
      )
    None => fail("expected additive fallback match from SymPy source")
  }

  match expr_match(add([mul([int(4), x]), mul([p, y])]), mul([int(4), x])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="0",
      )
    None => fail("expected additive embedding to expose zero coefficient")
  }

  match expr_match(mul([p, x]), x) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="1",
      )
    None => fail("expected x to match p*x with p = 1")
  }

  match
    expr_match(
      mul([pow(x, p), function("exp", [mul([x, q])])]),
      function("exp", [x]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(99))),
        content="0",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(99))),
        content="1",
      )
    }
    None => fail("expected exponential source match with implicit x**0")
  }

  match
    expr_match(
      mul([p, pow(add([mul([q, x]), r]), int(-1))]),
      mul([int(3), pow(add([mul([int(4), x]), int(5)]), int(-1))]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="4",
      )
      inspect(
        @symprint.pretty_string(env.get(r).unwrap_or(int(0))),
        content="5",
      )
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
  let imag = Expr::NumberSymbol(ImaginaryUnit)

  match
    expr_match(
      mul([p, Apply(g, [mul([q, x])])]),
      function("cos", [mul([int(5), x])]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(g).unwrap_or(int(0))),
        content="cos",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="5",
      )
    }
    None => fail("expected function-head wild match from SymPy source")
  }

  match expr_match(mul([p, g]), function("cos", [mul([int(5), x])])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(g).unwrap_or(int(0))),
        content="cos(5*x)",
      )
    }
    None => fail("expected bare wild-function match from SymPy source")
  }

  match expr_match(g, g) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(g).unwrap_or(int(0))),
        content="g_",
      )
    None => fail("expected WildFunction to match itself like SymPy source")
  }

  match expr_match(add([w, imag]), add([int(1), imag])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="1",
      )
    None => fail("expected additive complex match from SymPy source")
  }

  match expr_match(mul([w, imag]), mul([int(2), imag])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="2",
      )
    None => fail("expected multiplicative complex match from SymPy source")
  }

  let wr = Expr::Wild("wr", [], [])
  let wi = Expr::Wild("wi", [], [])
  match expr_match(add([wr, mul([wi, imag])]), add([a, mul([b, imag])])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(wr).unwrap_or(int(0))),
        content="a",
      )
      inspect(
        @symprint.pretty_string(env.get(wi).unwrap_or(int(0))),
        content="b",
      )
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
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="3/x",
      )
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
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="a",
      )
    None => fail("expected repeated additive factor match from SymPy source")
  }

  match expr_match(mul([p, q]), add([mul([x, Symbol("y")]), int(1)])) {
    Some(env) => {
      let lhs = @symprint.pretty_string(env.get(p).unwrap_or(int(0)))
      let rhs = @symprint.pretty_string(env.get(q).unwrap_or(int(0)))
      let allowed = [("1", "x*y + 1"), ("x*y + 1", "1")]
      assert_true(allowed.contains((lhs, rhs)))
    }
    None => fail("expected interface-style wildcard product match")
  }

  match
    expr_match(add([mul([p, dfx]), q]), add([mul([int(3), dfx]), int(-1)])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="-1",
      )
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
  let r = Expr::Wild("r", [FunctionHead("sin"), y], [])

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
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="y",
      )
      inspect(
        @symprint.pretty_string(env.get(r).unwrap_or(int(0))),
        content="a",
      )
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
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(1))),
        content="0",
      )
    None => fail("expected x + 1 + p to bind p=0 from SymPy source")
  }

  match expr_match(add([q, r]), p) {
    Some(env) => {
      let q_value = @symprint.pretty_string(env.get(q).unwrap_or(int(-1)))
      let r_value = @symprint.pretty_string(env.get(r).unwrap_or(int(-1)))
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
        @symprint.pretty_string(env.get(q_excluding_p).unwrap_or(int(-1))),
        content="0",
      )
      inspect(
        @symprint.pretty_string(env.get(r_plain).unwrap_or(int(-1))),
        content="p_",
      )
    }
    None =>
      fail("expected source-style additive wild-on-wild match with exclude=[p]")
  }
  match expr_match(mul([q_excluding_p, r_plain]), p) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(q_excluding_p).unwrap_or(int(-1))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(r_plain).unwrap_or(int(-1))),
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
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="x**2",
      )
    }
    None => fail("expected first-derivative wildcard match from SymPy source")
  }

  assert_false(
    expr_match(add([mul([a, d2]), b]), add([d1, pow(x, int(2))])) is Some(_),
  )

  let seeded : MatchEnv = Map([])
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
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected derivative remainder-zero match from SymPy source")
  }

  match expr_match(mul([int(-1), p, x]), x) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="-1",
      )
    None => fail("expected negative coefficient match bug4 from SymPy source")
  }

  match expr_match(mul([int(-1), p, x]), mul([int(-1), x])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="1",
      )
    None => fail("expected negative coefficient match bug5 from SymPy source")
  }

  match expr_match(mul([int(3), p, x]), x) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="1/3",
      )
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
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x",
      )
    None => fail("expected y**-1 to match x**-1 before reciprocal examples")
  }

  match expr_match(mul([w, pow(y, int(-1))]), mul([int(3), pow(x, int(-1))])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected 3/x to match w/y from SymPy source")
  }

  match expr_match(mul([w, y]), mul([int(3), x])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected 3*x to match w*y from SymPy source")
  }

  match
    expr_match(mul([y, pow(w, int(-1))]), mul([x, rational_from_ints(1, 3)])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected x/3 to match y/w from SymPy source")
  }

  match expr_match(mul([y, pow(w, int(-1))]), mul([int(3), x])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="1/3",
      )
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected 3*x to match y/w from SymPy source")
  }

  match
    expr_match(mul([w, pow(y, int(-1))]), mul([x, rational_from_ints(1, 3)])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="1/3",
      )
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x**-1",
      )
    }
    None => fail("expected x/3 to match w/y from SymPy source")
  }

  match expr_match(mul([w, pow(y, int(-1))]), mul([int(3), x])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x**-1",
      )
    }
    None => fail("expected 3*x to match w/y from SymPy source")
  }

  match expr_match(mul([w, y]), mul([int(3), pow(x, int(-1))])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(w).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
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
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1/3",
      )
    None => fail("expected 3 to match 1/a from SymPy source")
  }
  match expr_match(pow(a, int(-2)), int(3)) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="3**(-1/2)",
      )
    None => fail("expected 3 to match 1/a**2 from SymPy source")
  }
}

///|
test "expr_match follows SymPy source positive power wildcard examples" {
  let x = Expr::Symbol("x")
  let r = Expr::Symbol("r")
  let e = Expr::Symbol("e")
  let y = Expr::Wild("y", [], [])
  let a = Expr::Wild("a", [], [])

  match expr_match(pow(y, int(2)), pow(x, r)) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x**(r/2)",
      )
    None => fail("expected x**r to match y**2 from SymPy source")
  }

  match expr_match(pow(y, int(2)), pow(x, e)) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(y).unwrap_or(int(0))),
        content="x**(e/2)",
      )
    None => fail("expected x**e to match y**2 from SymPy source")
  }

  match expr_match(pow(a, int(2)), mul([int(-1), NumberSymbol(Pi)])) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="I*pi**(1/2)",
      )
    None => fail("expected -pi to match a**2 from SymPy source")
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
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected x to match a*f(x)**c from SymPy source")
  }

  match expr_match(mul([a, b]), x) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected x to match a*b from SymPy source")
  }

  match expr_match(mul([a, b, pow(fx, c)]), x) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected x to match a*b*f(x)**c from SymPy source")
  }
}

///|
test "expr_match follows SymPy source exclude cases around additive coefficients" {
  let x = Expr::Symbol("x")
  let f = Expr::UndefinedFunction("f")
  let fx = apply(f, [x]).unwrap_or(int(0))
  let a = Expr::Wild("a", [fx], [])
  let b = Expr::Wild("b", [fx], [])
  let pattern = add([mul([a, fx]), b])

  match expr_match(pattern, function("sin", [x])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="0",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="sin(x)",
      )
    }
    None => fail("expected sin(x) to match a*f(x) + b from SymPy source")
  }

  match expr_match(pattern, add([fx, function("sin", [x])])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="sin(x)",
      )
    }
    None => fail("expected f(x) + sin(x) to match a*f(x) + b from SymPy source")
  }

  match expr_match(pattern, add([fx, x, function("sin", [x])])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="x + sin(x)",
      )
    }
    None =>
      fail("expected f(x) + x + sin(x) to match a*f(x) + b from SymPy source")
  }

  match expr_match(pattern, add([x, function("sin", [x])])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="0",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="x + sin(x)",
      )
    }
    None => fail("expected x + sin(x) to match a*f(x) + b from SymPy source")
  }
}

///|
test "expr_match follows more SymPy source trig exclude and duplicate-function cases" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let p = Expr::Wild("p", [], [])
  let q = Expr::Wild("q", [], [])
  let c = Expr::Wild("c", [], [])
  let r = Expr::Wild("r", [FunctionHead("sin"), y], [])

  match
    expr_match(
      add([r, mul([p, function("sin", [q])])]),
      add([function("cos", [x]), mul([int(5), function("sin", [y])])]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="5",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="y",
      )
      inspect(
        @symprint.pretty_string(env.get(r).unwrap_or(int(0))),
        content="cos(x)",
      )
    }
    None => fail("expected source-driven exclude/trig match")
  }

  match
    expr_match(
      mul([function("sin", [p]), function("sin", [q]), c]),
      pow(function("sin", [x]), int(2)),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected repeated sine product match")
  }

  match
    expr_match(
      add([function("sin", [p]), function("sin", [q]), c]),
      mul([int(2), function("sin", [x])]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(0))),
        content="0",
      )
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected repeated sine additive match")
  }
}

///|
test "expr_match follows more SymPy source mixed additive term cases" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let xw = Expr::Wild("X", [], [])
  let yw = Expr::Wild("Y", [], [])

  match
    expr_match(
      add([mul([int(5), xw]), mul([int(-1), yw])]),
      add([mul([int(5), y]), mul([int(-1), x])]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(xw).unwrap_or(int(0))),
        content="y",
      )
      inspect(
        @symprint.pretty_string(env.get(yw).unwrap_or(int(0))),
        content="x",
      )
    }
    None => fail("expected source-driven 5*X - Y term match")
  }

  match
    expr_match(add([x, mul([xw, z])]), add([x, mul([add([y, int(-1)]), z])])) {
    Some(env) => {
      let matched = env.get(xw).unwrap_or(int(0))
      if compare_expr(matched, add([y, int(-1)])) != 0 {
        fail(
          "expected source-driven x + X*z term match to bind X to y - 1, got \{@symprint.pretty_string(matched)}",
        )
      }
    }
    None => fail("expected source-driven x + X*z term match")
  }

  match
    expr_match(
      add([
        x,
        mul([
          int(-1),
          function("log", [mul([xw, pow(y, int(-1))])]),
          add([
            int(1),
            mul([int(-1), function("exp", [mul([x, pow(y, int(-1))])])]),
          ]),
        ]),
      ]),
      add([
        x,
        mul([
          int(-1),
          function("log", [mul([x, pow(y, int(-1))])]),
          add([
            int(1),
            mul([int(-1), function("exp", [mul([x, pow(y, int(-1))])])]),
          ]),
        ]),
      ]),
    ) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(xw).unwrap_or(int(0))),
        content="x",
      )
    None => fail("expected source-driven logarithmic term match")
  }
}

///|
test "expr_match follows more SymPy source collected derivative coefficient cases" {
  let x = Expr::Symbol("x")
  let fx = function("f", [x])
  let d1 = Expr::Derivative(fx, [x, int(1)])
  let d2 = Expr::Derivative(fx, [x, int(2)])
  let a3 = Expr::Wild("a3", [fx, d1, d2], [])
  let b3 = Expr::Wild("b3", [fx, d1, d2], [])
  let c3 = Expr::Wild("c3", [fx, d1, d2], [])
  let pattern = add([mul([a3, d2]), mul([b3, d1]), mul([c3, fx])])

  match
    expr_match(
      pattern,
      add([
        mul([pow(add([x, int(-2)]), int(2)), d2]),
        mul([add([x, int(-2)]), d1]),
        mul([add([pow(add([x, int(-2)]), int(2)), int(-4)]), fx]),
      ]),
    ) {
    Some(env) => {
      let matched_a = env.get(a3).unwrap_or(int(0))
      let matched_b = env.get(b3).unwrap_or(int(0))
      let matched_c = env.get(c3).unwrap_or(int(0))
      if compare_expr(matched_a, pow(add([x, int(-2)]), int(2))) != 0 {
        fail(
          "expected a3 to match (x - 2)**2, got \{@symprint.pretty_string(matched_a)}",
        )
      }
      if compare_expr(matched_b, add([x, int(-2)])) != 0 {
        fail(
          "expected b3 to match x - 2, got \{@symprint.pretty_string(matched_b)}",
        )
      }
      if compare_expr(matched_c, add([pow(add([x, int(-2)]), int(2)), int(-4)])) !=
        0 {
        fail(
          "expected c3 to match (x - 2)**2 - 4, got \{@symprint.pretty_string(matched_c)}",
        )
      }
    }
    None => fail("expected collected derivative coefficient match")
  }

  match
    expr_match(
      pattern,
      add([
        mul([add([x, int(-4), mul([int(4), pow(x, int(-1))])]), d2]),
        mul([add([int(1), mul([int(-2), pow(x, int(-1))])]), d1]),
        mul([add([x, int(-4)]), fx]),
      ]),
    ) {
    Some(env) => {
      let matched_a = env.get(a3).unwrap_or(int(0))
      let matched_b = env.get(b3).unwrap_or(int(0))
      let matched_c = env.get(c3).unwrap_or(int(0))
      if compare_expr(
          matched_a,
          add([x, int(-4), mul([int(4), pow(x, int(-1))])]),
        ) !=
        0 {
        fail(
          "expected a3 to match x - 4 + 4/x, got \{@symprint.pretty_string(matched_a)}",
        )
      }
      if compare_expr(matched_b, add([int(1), mul([int(-2), pow(x, int(-1))])])) !=
        0 {
        fail(
          "expected b3 to match 1 - 2/x, got \{@symprint.pretty_string(matched_b)}",
        )
      }
      if compare_expr(matched_c, add([x, int(-4)])) != 0 {
        fail(
          "expected c3 to match x - 4, got \{@symprint.pretty_string(matched_c)}",
        )
      }
    }
    None => fail("expected collected rational derivative coefficient match")
  }
}

///|
test "expr_match follows more SymPy source float and derivative remainder cases" {
  let x = Expr::Symbol("x")
  let a = Expr::Wild("a", [], [])
  let b = Expr::Wild("b", [], [])
  let float_arg = Expr::Float(@symcore.Float::from_double(0.12345))
  match
    expr_match(
      mul([a, pow(function("cos", [b]), int(2))]),
      pow(function("cos", [float_arg]), int(2)),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      let matched_b = env.get(b).unwrap_or(int(0))
      if compare_expr(matched_b, float_arg) != 0 {
        fail(
          "expected source-driven float wildcard to bind exact float arg, got \{@symprint.pretty_string(matched_b)}",
        )
      }
    }
    None => fail("expected source-driven float wildcard match")
  }

  let f = Expr::UndefinedFunction("f")
  let fx = apply(f, [x]).unwrap_or(int(0))
  let dfx = derivative(fx, x)
  let aw = Expr::Wild("a", [fx], [])
  let bw = Expr::Wild("b", [fx], [])
  match expr_match(add([mul([aw, dfx]), bw]), dfx) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(aw).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(bw).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected source-driven derivative remainder match")
  }
}

///|
test "expr_match follows more SymPy source product-derivative coefficient cases" {
  let x = Expr::Symbol("x")
  let f = Expr::UndefinedFunction("f")
  let g = Expr::UndefinedFunction("g")
  let fx = apply(f, [x]).unwrap_or(int(0))
  let gx = apply(g, [x]).unwrap_or(int(0))
  let dgx = derivative(gx, x)
  let dfx = derivative(fx, x)
  let d2fx = Expr::Derivative(fx, [x, int(2)])
  let a = Expr::Wild("a", [fx, gx], [])
  let b = Expr::Wild("b", [fx, gx], [])
  let c = Expr::Wild("c", [fx, gx], [])
  let expr = add([mul([dgx, dfx]), mul([gx, d2fx])])
  match expr_match(add([mul([dgx, dfx]), mul([gx, d2fx]), c]), expr) {
    Some(env) =>
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(1))),
        content="0",
      )
    None =>
      fail("expected source-driven zero remainder product-derivative match")
  }
  match expr_match(add([mul([a, dgx, dfx]), mul([b, gx, d2fx]), c]), expr) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected source-driven coefficient product-derivative match")
  }
}

///|
test "expr_match follows more SymPy source multiplicative wildcard power cases" {
  let x = Expr::Symbol("x")
  let z = Expr::Symbol("z")
  let phi = Expr::Symbol("phi")
  let r = Expr::Symbol("r")
  let c = Expr::Wild("c", [], [])
  let aw = Expr::Wild("A", [], [])
  let bw = Expr::Wild("B", [], [])
  let nw = Expr::Wild("N", [], [])
  let lw = Expr::Wild("l", [int(0)], [])
  let eq = mul([z, function("sin", [mul([int(2), phi])]), pow(r, int(7))])
  let pattern = mul([
    c,
    pow(function("sin", [mul([phi, nw])]), lw),
    pow(r, aw),
    pow(function("log", [r]), bw),
  ])
  match expr_match(pattern, eq) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(0))),
        content="z",
      )
      inspect(
        @symprint.pretty_string(env.get(lw).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(nw).unwrap_or(int(0))),
        content="2",
      )
      inspect(
        @symprint.pretty_string(env.get(aw).unwrap_or(int(0))),
        content="7",
      )
      inspect(
        @symprint.pretty_string(env.get(bw).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected source-driven multiplicative wildcard power match")
  }
  match expr_match(pattern, mul([mul([int(-7), x]), eq])) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(0))),
        content="-7*x*z",
      )
      inspect(
        @symprint.pretty_string(env.get(lw).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(nw).unwrap_or(int(0))),
        content="2",
      )
      inspect(
        @symprint.pretty_string(env.get(aw).unwrap_or(int(0))),
        content="7",
      )
      inspect(
        @symprint.pretty_string(env.get(bw).unwrap_or(int(1))),
        content="0",
      )
    }
    None =>
      fail("expected source-driven scaled multiplicative wildcard power match")
  }
}

///|
test "expr_match follows more SymPy source additive exclude ambiguity cases" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let eighth = rational_from_ints(1, 8)
  let expr = mul([int(-1), x, add([eighth, mul([int(-1), y])])])
  let expected_rest = add([mul([int(-1), eighth]), y])
  let patterns : Array[Expr] = [
    add([mul([Wild("coeff", [x], []), x]), Wild("rest", [], [])]),
    add([mul([Wild("w", [x], []), x]), Wild("rest", [], [])]),
    add([mul([Wild("e", [x], []), x]), Wild("rest", [], [])]),
  ]
  for pattern in patterns {
    match expr_match(pattern, expr) {
      Some(env) => {
        let mut saw_zero = false
        let mut saw_rest = false
        for _, value in env {
          saw_zero = saw_zero || compare_expr(value, int(0)) == 0
          saw_rest = saw_rest || compare_expr(value, expected_rest) == 0
        }
        assert_true(saw_zero)
        assert_true(saw_rest)
      }
      None =>
        fail("expected additive exclude ambiguity match from SymPy source")
    }
  }
}

///|
test "expr_match follows more SymPy source trig and infinity wildcard cases" {
  let x = Expr::Symbol("x")
  let p = Expr::Wild("p", [], [])
  let q = Expr::Wild("q", [], [])
  let c = Expr::Wild("c", [], [])
  inspect(
    @symprint.pretty_string(
      expr_match(
        mul([function("sin", [p]), function("sin", [q]), c]),
        pow(function("sin", [x]), int(2)),
      )
      .unwrap_or({})
      .get(c)
      .unwrap_or(int(-1)),
    ),
    content="1",
  )
  match
    expr_match(
      add([function("sin", [p]), function("sin", [q]), c]),
      mul([int(2), function("sin", [x])]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(p).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(q).unwrap_or(int(0))),
        content="x",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected trig additive wildcard match from SymPy source")
  }
  let a = Expr::Wild("a", [], [])
  match
    expr_match(
      mul([NumberSymbol(ImaginaryUnit), a, NumberSymbol(Infinity)]),
      mul([int(-1), NumberSymbol(ImaginaryUnit), x, NumberSymbol(Infinity)]),
    ) {
    Some(env) =>
      assert_true(
        compare_expr(env.get(a).unwrap_or(int(0)), mul([int(-1), x])) == 0,
      )
    None =>
      fail("expected infinity coefficient wildcard match from SymPy source")
  }
}

///|
test "expr_match follows more SymPy source reciprocal edge cases" {
  let x = Expr::Symbol("x")
  let a = Expr::Wild("a", [], [])
  assert_false(
    expr_match(add([a, mul([int(-1), x])]), add([x, int(-2)])) is Some(_),
  )
  assert_false(
    expr_match(mul([a, x]), mul([int(6), pow(x, int(-1))])) is Some(_),
  )
  inspect(
    @symprint.pretty_string(
      expr_match(mul([a, pow(x, int(-1))]), mul([int(6), pow(x, int(-2))]))
      .unwrap_or({})
      .get(a)
      .unwrap_or(int(0)),
    ),
    content="6/x",
  )
}

///|
test "expr_match follows more SymPy source polynomial coefficient cases" {
  let x = Expr::Symbol("x")
  let a = Expr::Wild("a", [x], [])
  let b = Expr::Wild("b", [x], [])
  let c = Expr::Wild("c", [x], [])
  let d = Expr::Wild("d", [x], [])
  let pattern = add([
    mul([a, pow(x, int(3))]),
    mul([b, pow(x, int(2))]),
    mul([c, x]),
    d,
  ])
  let eq = add([
    mul([int(4), pow(x, int(3))]),
    mul([int(3), pow(x, int(2))]),
    mul([int(2), x]),
    int(1),
  ])
  match expr_match(pattern, eq) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="4",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="3",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(0))),
        content="2",
      )
      inspect(
        @symprint.pretty_string(env.get(d).unwrap_or(int(0))),
        content="1",
      )
    }
    None => fail("expected source-driven polynomial coefficient match")
  }
  match
    expr_match(
      pattern,
      add([mul([int(4), pow(x, int(3))]), mul([int(2), x]), int(1)]),
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="4",
      )
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(1))),
        content="0",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(0))),
        content="2",
      )
      inspect(
        @symprint.pretty_string(env.get(d).unwrap_or(int(0))),
        content="1",
      )
    }
    None => fail("expected source-driven polynomial coefficient zero fill")
  }
  let sqrt2 = function("sqrt", [int(2)])
  match
    expr_match(
      add([a, mul([b, x]), mul([c, pow(x, int(2))])]),
      add([x, sqrt2, int(3)]),
    ) {
    Some(env) => {
      let a_value = env.get(a).unwrap_or(int(0))
      if compare_expr(a_value, add([sqrt2, int(3)])) != 0 {
        fail(
          "expected constant coefficient to match sqrt(2) + 3, got \{@symprint.pretty_string(a_value)}",
        )
      }
      inspect(
        @symprint.pretty_string(env.get(b).unwrap_or(int(0))),
        content="1",
      )
      inspect(
        @symprint.pretty_string(env.get(c).unwrap_or(int(1))),
        content="0",
      )
    }
    None => fail("expected source-driven sparse polynomial coefficient match")
  }
}

///|
test "expr_match follows more SymPy source gamma collection cases" {
  let gamma = Expr::Symbol("gamma")
  let mu = Expr::Symbol("mu")
  let x = Expr::Symbol("x")
  let a = Expr::Wild("a", [gamma], [])
  let b = Expr::Wild("b", [gamma], [])
  let c = Expr::Wild("c", [gamma], [])
  let eq = mul([
    rational_from_ints(1, 2),
    add([
      mul([int(-1), gamma, pow(add([x, mul([int(-1), mu])]), int(2))]),
      mul([int(-1), function("log", [gamma])]),
      function("log", [mul([int(2), NumberSymbol(Pi)])]),
    ]),
  ])
  let pattern = add([mul([a, function("log", [gamma])]), mul([b, gamma]), c])
  match expr_match(pattern, eq) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="-1/2",
      )
      let b_value = env.get(b).unwrap_or(int(0))
      if compare_expr(
          b_value,
          mul([
            rational_from_ints(-1, 2),
            pow(add([x, mul([int(-1), mu])]), int(2)),
          ]),
        ) !=
        0 {
        fail(
          "expected gamma coefficient match, got \{@symprint.pretty_string(b_value)}",
        )
      }
      let c_value = env.get(c).unwrap_or(int(0))
      if compare_expr(
          c_value,
          mul([
            rational_from_ints(1, 2),
            function("log", [mul([int(2), NumberSymbol(Pi)])]),
          ]),
        ) !=
        0 {
        fail(
          "expected gamma remainder match, got \{@symprint.pretty_string(c_value)}",
        )
      }
    }
    None => fail("expected source-driven gamma collection match")
  }
}

///|
test "expr_match follows more SymPy source expanded gamma collection cases" {
  let gamma = Expr::Symbol("gamma")
  let mu = Expr::Symbol("mu")
  let x = Expr::Symbol("x")
  let a = Expr::Wild("a", [gamma], [])
  let b = Expr::Wild("b", [gamma], [])
  let c = Expr::Wild("c", [gamma], [])
  let g1 = Expr::Wild("g1", [gamma], [])
  let g2 = Expr::Wild("g2", [gamma], [])
  let g3 = Expr::Wild("g3", [gamma], [])
  let expanded = add([
    mul([rational_from_ints(-1, 2), function("log", [gamma])]),
    mul([
      gamma,
      add([
        mul([rational_from_ints(-1, 2), pow(mu, int(2))]),
        mul([mu, x]),
        mul([rational_from_ints(-1, 2), pow(x, int(2))]),
      ]),
    ]),
    mul([rational_from_ints(1, 2), function("log", [int(2)])]),
    mul([rational_from_ints(1, 2), function("log", [NumberSymbol(Pi)])]),
  ])

  let expected_gamma_coeff = add([
    mul([rational_from_ints(-1, 2), pow(mu, int(2))]),
    mul([mu, x]),
    mul([rational_from_ints(-1, 2), pow(x, int(2))]),
  ])
  let expected_const = add([
    mul([rational_from_ints(1, 2), function("log", [int(2)])]),
    mul([rational_from_ints(1, 2), function("log", [NumberSymbol(Pi)])]),
  ])

  match
    expr_match(
      add([mul([a, function("log", [gamma])]), mul([b, gamma]), c]),
      expanded,
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(a).unwrap_or(int(0))),
        content="-1/2",
      )
      let b_value = env.get(b).unwrap_or(int(0))
      if compare_expr(b_value, expected_gamma_coeff) != 0 {
        fail(
          "expected expanded gamma coefficient match, got \{@symprint.pretty_string(b_value)}",
        )
      }
      let c_value = env.get(c).unwrap_or(int(0))
      if compare_expr(c_value, expected_const) != 0 {
        fail(
          "expected expanded gamma constant match, got \{@symprint.pretty_string(c_value)}",
        )
      }
    }
    None => fail("expected source-driven expanded gamma match")
  }

  match
    expr_match(
      add([mul([g1, function("log", [gamma])]), mul([g2, gamma]), g3]),
      expanded,
    ) {
    Some(env) => {
      inspect(
        @symprint.pretty_string(env.get(g1).unwrap_or(int(0))),
        content="-1/2",
      )
      let g2_value = env.get(g2).unwrap_or(int(0))
      if compare_expr(g2_value, expected_gamma_coeff) != 0 {
        fail(
          "expected expanded excluded gamma coefficient match, got \{@symprint.pretty_string(g2_value)}",
        )
      }
      let g3_value = env.get(g3).unwrap_or(int(0))
      if compare_expr(g3_value, expected_const) != 0 {
        fail(
          "expected expanded excluded gamma constant match, got \{@symprint.pretty_string(g3_value)}",
        )
      }
    }
    None => fail("expected source-driven expanded gamma excluded match")
  }
}
