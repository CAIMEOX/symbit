///|
test "polys P5a4 treats a hostile GF extension generator as literal data" {
  let x = @symcore.Expr::Symbol("x")
  let p = ((x + @symcore.int(1)) ^ @symcore.int(2)) * (x + @symcore.int(2))
  let q = x + @symcore.int(1)
  let hostile = "(__import__('builtins').print('P5A4_EXECUTED') or a)"
  assert_eq(
    gcd(p, q, modulus=5, gfext_modulus=[1, 0, 1], gfext_gen=hostile),
    "x + 1",
  )
  assert_eq(gcd(p, q), "x + 1")
}

///|
test "polys P5a4 preserves factor formatting and incompatible options" {
  let x = @symcore.Expr::Symbol("x")
  assert_eq(
    factor_list((x ^ @symcore.int(2)) - @symcore.int(2), extension=["sqrt(2)"]),
    "(1, [(x + sqrt(2), 1),(x - sqrt(2), 1)])",
  )
  assert_eq(
    factor_list((x ^ @symcore.int(2)) + @symcore.int(1), modulus=5),
    "(1, [(x + 2, 1),(x + 3, 1)])",
  )
  let unsupported_gfext = try {
    factor_list((x + @symcore.int(1)) ^ @symcore.int(2), modulus=5, gfext_modulus=[
      1, 0, 1,
    ])
    |> ignore
    false
  } catch {
    _ => true
  }
  let incompatible_options = try {
    factor_list(
      (x ^ @symcore.int(2)) - @symcore.int(2),
      modulus=5,
      extension=["sqrt(2)"],
      gfext_modulus=[1, 0, 1],
    )
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(unsupported_gfext)
  assert_true(incompatible_options)
  assert_eq(factor_list(x + @symcore.int(1)), "(1, [(x + 1, 1)])")
}

///|
test "polys P5a4 preserves monic and square-free branches" {
  let x = @symcore.Expr::Symbol("x")
  let repeated = ((x + @symcore.int(1)) ^ @symcore.int(2)) *
    (x + @symcore.int(2))
  assert_eq(monic(@symcore.int(2) * x + @symcore.int(4)), "x + 2")
  assert_eq(monic(@symcore.int(2) * x + @symcore.int(4), modulus=5), "x + 2")
  assert_eq(sqf_list(repeated), "(1, [(x + 1, 2),(x + 2, 1)])")
  assert_eq(
    sqf_list(repeated, modulus=5, gfext_modulus=[1, 0, 1], gfext_gen="a"),
    "(1, [(x + 1, 2),(x + 2, 1)])",
  )
  assert_eq(sqf_part(repeated), "x**2 + 3*x + 2")
}

///|
test "polys P5a4 rejects invalid GF extension moduli and recovers" {
  let x = @symcore.Expr::Symbol("x")
  let expression = (x + @symcore.int(1)) ^ @symcore.int(2)
  let missing_modulus = try {
    sqf_list(expression, gfext_modulus=[1, 0, 1]) |> ignore
    false
  } catch {
    _ => true
  }
  let invalid_modulus = try {
    sqf_list(expression, modulus=1, gfext_modulus=[1, 0, 1]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(missing_modulus)
  assert_true(invalid_modulus)
  assert_eq(sqf_list(expression), "(1, [(x + 1, 2)])")
}

///|
test "polys P5a4 shares Expr identity and preserves bare versus Poly paths" {
  let dummy = @symcore.Expr::Dummy("d", 1801)
  assert_eq(gcd(dummy, dummy), "_d")
  assert_eq(div(dummy, dummy), "1||0")
  let x = @symcore.Expr::Symbol("x")
  let p = (x ^ @symcore.int(2)) - @symcore.int(1)
  let q = x - @symcore.int(1)
  assert_eq(gcd(p, q), "x - 1")
  assert_eq(gcd(p, q, gens=["x"], domain="QQ"), "x - 1")
  assert_eq(div(p, q), "x + 1||0")
  assert_eq(div(p, q, gens=["x"], domain="QQ"), "x + 1||0")
  assert_eq(resultant(p, q, x="x"), "0")
  assert_eq(resultant(p, q, x="x", gens=["x"], domain="QQ"), "0")
}

///|
test "polys P5a4 covers all five GF extension frontdoors" {
  let x = @symcore.Expr::Symbol("x")
  let p = ((x + @symcore.int(1)) ^ @symcore.int(2)) * (x + @symcore.int(2))
  let q = x + @symcore.int(1)
  let factor_rejected = try {
    factor_list(p, modulus=5, gfext_modulus=[1, 0, 1]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(factor_rejected)
  assert_eq(
    sqf_list(p, modulus=5, gfext_modulus=[1, 0, 1]),
    "(1, [(x + 1, 2),(x + 2, 1)])",
  )
  assert_eq(gcd(p, q, modulus=5, gfext_modulus=[1, 0, 1]), "x + 1")
  assert_eq(resultant(p, q, modulus=5, gfext_modulus=[1, 0, 1]), "0")
  assert_eq(div(p, q, modulus=5, gfext_modulus=[1, 0, 1]), "x**2 - 2*x + 2||0")
}

///|
test "polys P5a4 reads GF extension coefficients in ascending powers" {
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  assert_eq(
    div(
      x + (a ^ @symcore.int(2)),
      @symcore.int(1),
      gens=["x"],
      modulus=5,
      gfext_modulus=[2, 1, 1],
      gfext_gen="a",
    ),
    "-a + x - 2||0",
  )
}

///|
test "polys P5a4 keeps resultant variable punctuation literal" {
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  assert_eq(
    resultant(
      (x ^ @symcore.int(2)) + @symcore.int(1),
      x + @symcore.int(1),
      x=literal,
    ),
    "2",
  )
}

///|
test "polys P5a4 shares identity in lists and preserves terms gcd" {
  let dummy = @symcore.Expr::Dummy("d", 1802)
  assert_eq(gcd_list([dummy, dummy]), "_d")
  assert_eq(lcm_list([dummy, dummy]), "_d")
  let literal = "x y,z"
  let x = @symcore.Expr::Symbol(literal)
  let expression = @symcore.int(2) * (x ^ @symcore.int(3)) +
    @symcore.int(4) * (x ^ @symcore.int(2))
  assert_eq(terms_gcd(expression, gens=[literal]), "2*x y,z**2")
  assert_eq(
    gcd_list([x ^ @symcore.int(2), x ^ @symcore.int(3)], gens=[literal]),
    "x y,z**2",
  )
  assert_eq(
    lcm_list([x ^ @symcore.int(2), x ^ @symcore.int(3)], gens=[literal]),
    "x y,z**3",
  )
}
