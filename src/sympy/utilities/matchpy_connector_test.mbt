///|
test "wildcard srepr follows MatchPy-style names" {
  assert_eq(get_srepr(wild_dot("a_")), "a_")
  assert_eq(get_srepr(wild_plus("rest")), "*rest")
  assert_eq(get_srepr(wild_star("tail")), "*tail")
}

///|
test "replacer handles fixed-size wildcards" {
  let a_ = wild_dot("a_")
  let b_ = wild_dot("b_")
  let x = @symcore.Expr::Symbol("x")
  let r = replacer()
  r.add(@symcore.raw_add([@symcore.raw_mul([a_, x]), b_]), b_ - a_)
  let result = r.replace(
    @symcore.raw_add([@symcore.raw_mul([@symcore.int(3), x]), @symcore.int(4)]),
  )
  let fn0 = lambdify([], result)
  assert_eq(fn0.call([]), 1.0)
}

///|
test "replacer handles sequence wildcards in associative nodes" {
  let head = wild_dot("head")
  let tail = wild_star("tail")
  let r = replacer()
  r.add(@symcore.raw_add([head, tail]), @symcore.raw_add([tail, head]))
  let expr = @symcore.raw_add([
    @symcore.Expr::Symbol("a"),
    @symcore.Expr::Symbol("b"),
    @symcore.Expr::Symbol("c"),
  ])
  let result = r.replace(expr, max_count=1)
  inspect(@symprint.to_string(result), content="b + c + a")
}

///|
test "replace_with_info records applied rules" {
  let x = @symcore.Expr::Symbol("x")
  let r = replacer()
  r.add(x + @symcore.int(1), x, info=Some("drop-one"))
  let (result, infos) = r.replace_with_info(x + @symcore.int(1))
  inspect(@symprint.to_string(result), content="x")
  inspect(infos, content="[\"drop-one\"]")
}

///|
test "replacement info struct is usable" {
  let info = replacement_info(@symcore.int(1), "demo")
  assert_eq(info.info, "demo")
}
