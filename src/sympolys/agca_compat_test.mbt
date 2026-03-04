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
