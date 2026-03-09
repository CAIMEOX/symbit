///|
fn ag_norm(expr : @symcore.Expr) -> String {
  (try! @sympy_polys.sympy_normalize(@symprint.to_string(expr)).trim().to_string())
    .replace_all(old=" ", new="")
}

///|
test "agca: ideal sum/product/contains basics" {
  let x = @symcore.symbol("x")
  let builder = PolyBuilder::new(["x"], Domain::QQ)

  let i = ideal([builder.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))])
  let j = ideal([builder.from_expr(x + @symcore.int(1))])

  let sum = i.sum(j)
  guard sum.gens.length() == 2 else {
    fail("ideal sum should union generators")
  }

  let prod = i.product(j)
  guard prod.gens.length() == 1 else {
    fail("single-generator ideals should produce one product generator")
  }

  let p = builder.from_expr(((x ^ @symcore.int(2)) + @symcore.int(1)) * (x + @symcore.int(3)))
  guard i.contains(p) else {
    fail("membership by exact divisibility failed")
  }
}

///|
test "agca: ring homomorphism applies substitutions" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let source = PolyBuilder::new(["x"], Domain::QQ).from_expr((x ^ @symcore.int(2)) + @symcore.int(1))

  let image : Map[String, @symcore.Expr] = { "x": y + @symcore.int(1) }
  let hom = ring_homomorphism(["x"], ["y"], Domain::QQ, image)
  let mapped = hom.apply_poly(source)

  let got = ag_norm(mapped.to_expr())
  let expected = ag_norm((y ^ @symcore.int(2)) + @symcore.int(2) * y + @symcore.int(2))
  guard got == expected else {
    fail("ring hom image mismatch: got=\{got}, expected=\{expected}")
  }
}

///|
test "agca: groebner membership handles linear combinations and multivariate ideals" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")

  let qx = PolyBuilder::new(["x"], Domain::QQ)
  let i1 = ideal([qx.from_expr(x + @symcore.int(1)), qx.from_expr(x - @symcore.int(1))])
  guard i1.contains(qx.from_expr(@symcore.int(3))) else {
    fail("ideal <x+1, x-1> should contain 3")
  }
  guard ag_norm(i1.reduce_element(qx.from_expr(@symcore.int(3))).to_expr()) == "0" else {
    fail("ideal reduction should eliminate constant combination")
  }

  let qxy = PolyBuilder::new(["x", "y"], Domain::QQ)
  let i2 = ideal([
    qxy.from_expr((x ^ @symcore.int(2)) + y),
    qxy.from_expr((x ^ @symcore.int(2)) + x),
  ])
  guard i2.contains(qxy.from_expr(x - y)) else {
    fail("multivariate groebner membership mismatch")
  }
}

///|
test "agca: intersection, union, powers, and whole-ring predicates" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)

  let i = ideal([builder.from_expr(x), builder.from_expr(y)])
  let sq = i.power(2)
  let xy_norm = ag_norm(builder.from_expr(x * y).to_expr())
  guard sq.gens.any(g => ag_norm(g.to_expr()) == xy_norm) else {
    fail("<x, y>^2 should expose x*y among pairwise product generators")
  }
  guard sq.gens.length() == 4 else {
    fail("<x, y>^2 should keep pairwise product generators")
  }

  let j = ideal([builder.from_expr(x + @symcore.int(1))])
  let inter = ideal([builder.from_expr(x)]).intersect(j)
  guard inter.contains(builder.from_expr(x * (x + @symcore.int(1)))) else {
    fail("intersection should contain product generator")
  }
  guard !inter.contains(builder.from_expr(x)) else {
    fail("intersection should not contain x")
  }

  let union = ideal([builder.from_expr(x)]).union(ideal([builder.from_expr(y)]))
  guard union.contains(builder.from_expr(x + y)) else {
    fail("ideal union should contain sums of generators")
  }

  guard ideal([builder.from_expr(@symcore.int(1))]).is_whole_ring() else {
    fail("<1> should be the whole ring")
  }
}
