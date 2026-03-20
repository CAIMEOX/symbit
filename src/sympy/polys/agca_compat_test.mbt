///|
fn ag_norm(expr : @symcore.Expr) -> String raise {
  (sympy_normalize(@symprint.to_string(expr))
  .trim()
  .to_string()).replace_all(old=" ", new="")
}

///|
test "agca: ideal sum/product/contains basics" {
  let x = @symcore.symbol("x")
  let builder = PolyBuilder::new(["x"], Domain::QQ)

  let i = @sympolys.ideal([builder.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))])
  let j = @sympolys.ideal([builder.from_expr(x + @symcore.int(1))])

  let sum = i.sum(j)
  assert_eq(sum.gens.length(), 2)

  let prod = i.product(j)
  assert_eq(prod.gens.length(), 1)

  let p = builder.from_expr(
    ((x ^ @symcore.int(2)) + @symcore.int(1)) * (x + @symcore.int(3)),
  )
  assert_true(i.contains(p))
}

///|
test "agca: ring homomorphism applies substitutions" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let source = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(1),
  )

  let image : Map[String, @symcore.Expr] = { "x": y + @symcore.int(1) }
  let hom = @sympolys.ring_homomorphism(["x"], ["y"], Domain::QQ, image)
  let mapped = hom.apply_poly(source)

  let got = ag_norm(mapped.to_expr())
  let expected = ag_norm(
    (y ^ @symcore.int(2)) + @symcore.int(2) * y + @symcore.int(2),
  )
  assert_eq(got, expected)
}

///|
test "agca: groebner membership handles linear combinations and multivariate ideals" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")

  let qx = PolyBuilder::new(["x"], Domain::QQ)
  let i1 = @sympolys.ideal([
    qx.from_expr(x + @symcore.int(1)),
    qx.from_expr(x - @symcore.int(1)),
  ])
  assert_true(i1.contains(qx.from_expr(@symcore.int(3))))
  assert_eq(ag_norm(i1.reduce_element(qx.from_expr(@symcore.int(3))).to_expr()), "0")

  let qxy = PolyBuilder::new(["x", "y"], Domain::QQ)
  let i2 = @sympolys.ideal([
    qxy.from_expr((x ^ @symcore.int(2)) + y),
    qxy.from_expr((x ^ @symcore.int(2)) + x),
  ])
  assert_true(i2.contains(qxy.from_expr(x - y)))
}

///|
test "agca: intersection, union, powers, and whole-ring predicates" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)

  let i = @sympolys.ideal([builder.from_expr(x), builder.from_expr(y)])
  let sq = i.power(2)
  let xy_norm = ag_norm(builder.from_expr(x * y).to_expr())
  assert_true(sq.gens.any(g => ag_norm(g.to_expr()) == xy_norm))
  assert_eq(sq.gens.length(), 4)

  let j = @sympolys.ideal([builder.from_expr(x + @symcore.int(1))])
  let inter = @sympolys.ideal([builder.from_expr(x)]).intersect(j)
  assert_true(inter.contains(builder.from_expr(x * (x + @symcore.int(1)))))
  assert_true(!inter.contains(builder.from_expr(x)))

  let union = @sympolys.ideal([builder.from_expr(x)]).union(@sympolys.ideal([builder.from_expr(y)]))
  assert_true(union.contains(builder.from_expr(x + y)))

  assert_true(@sympolys.ideal([builder.from_expr(@symcore.int(1))]).is_whole_ring())
}
