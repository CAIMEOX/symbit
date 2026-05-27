///|
fn rx() -> @symcore.Expr {
  @symcore.Expr::Symbol("x")
}

///|
fn ry() -> @symcore.Expr {
  @symcore.Expr::Symbol("y")
}

///|
fn rp() -> @symcore.Expr {
  @symcore.Expr::Symbol("p")
}

///|
fn rq() -> @symcore.Expr {
  @symcore.Expr::Symbol("q")
}

///|
test "symunify rewrite handles simple and moderate cases" {
  let rl = rewriterule(
    @symcore.raw_function("Basic", [rp(), @symcore.int(1)]),
    @symcore.raw_function("Basic", [rp(), @symcore.int(2)]),
    variables=[rp()],
  )
  debug_inspect(
    rl
    .apply(@symcore.raw_function("Basic", [@symcore.int(3), @symcore.int(1)]))
    .map(@symprint.pretty_string),
    content="[\"Basic(3, 2)\"]",
  )

  let pow_rule = rewriterule(
    @symcore.raw_pow(rp(), @symcore.int(2)),
    @symcore.raw_pow(rp(), @symcore.int(3)),
    variables=[rp()],
  )
  debug_inspect(
    pow_rule
    .apply(@symcore.raw_pow(rx(), @symcore.int(2)))
    .map(@symprint.pretty_string),
    content="[\"x**3\"]",
  )

  let moderate = rewriterule(
    @symcore.raw_add([
      @symcore.raw_pow(rp(), @symcore.int(2)),
      @symcore.raw_pow(rq(), @symcore.int(3)),
    ]),
    @symcore.raw_pow(@symcore.raw_mul([rp(), rq()]), @symcore.int(4)),
    variables=[rp(), rq()],
  )
  debug_inspect(
    moderate
    .apply(
      @symcore.raw_add([
        @symcore.raw_pow(rx(), @symcore.int(2)),
        @symcore.raw_pow(ry(), @symcore.int(3)),
      ]),
    )
    .map(@symprint.pretty_string),
    content="[\"x**4*y**4\"]",
  )
}

///|
test "symunify rewrite handles conditions and assumptions" {
  let simple = rewriterule(
    rx(),
    @symcore.add([rx(), @symcore.int(1)]),
    variables=[rx()],
    condition=args => {
      match args {
        [@symcore.Expr::Number(value)] =>
          value.compare(@symnum.BigRational::from_int(10)) < 0
        _ => false
      }
    },
  )
  inspect(simple.apply(@symcore.int(15)).length(), content="0")
  debug_inspect(
    simple.apply(@symcore.int(5)).map(@symprint.pretty_string),
    content="[\"1 + 5\"]",
  )

  let assume_rule = rewriterule(
    @symcore.raw_add([rx(), ry()]),
    @symcore.raw_pow(rx(), ry()),
    variables=[rx(), ry()],
    assumption_query=Some(@symassume.q_integer(rx())),
  )
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  debug_inspect(
    assume_rule
    .apply(@symcore.raw_add([a, b]), assumptions=@symassume.q_integer(b))
    .map(@symprint.pretty_string),
    content="[\"b**a\"]",
  )
}
