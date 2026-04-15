///|
fn expr_norm(expr : @symcore.Expr) -> String raise {
  sympy_normalize(@symprint.pretty_string(expr))
}

///|
fn symmetrize_to_string(res : SymmetrizeResult, formal : Bool) -> String raise {
  let sym_str = expr_norm(res.sym)
  let rem_str = expr_norm(res.rem)
  if !formal {
    "\{sym_str}||\{rem_str}"
  } else {
    let parts : Array[String] = Array::new()
    for pair in res.mapping {
      let lhs = expr_norm(pair.0)
      let rhs = expr_norm(pair.1)
      parts.push("(\{lhs}, \{rhs})")
    }
    let joined = parts.join(", ")
    let mapping_str = "[\{joined}]"
    "\{sym_str}||\{rem_str}||\{mapping_str}"
  }
}

///|
fn symmetrize_list_to_string(
  res : SymmetrizeListResult,
  formal : Bool,
) -> String raise {
  let parts : Array[String] = Array::new()
  for item in res.items {
    let sym_str = expr_norm(item.sym)
    let rem_str = expr_norm(item.rem)
    parts.push("(\{sym_str}, \{rem_str})")
  }
  let list_joined = parts.join(", ")
  let list_str = "[\{list_joined}]"
  if !formal {
    list_str
  } else {
    let mapping_parts : Array[String] = Array::new()
    for pair in res.mapping {
      let lhs = expr_norm(pair.0)
      let rhs = expr_norm(pair.1)
      mapping_parts.push("(\{lhs}, \{rhs})")
    }
    let mapping_joined = mapping_parts.join(", ")
    let mapping_str = "[\{mapping_joined}]"
    "\{list_str}||\{mapping_str}"
  }
}

///|
fn viete_to_string(
  pairs : Array[(@symcore.Expr, @symcore.Expr)],
) -> String raise {
  let parts : Array[String] = Array::new()
  for pair in pairs {
    let lhs = expr_norm(pair.0)
    let rhs = expr_norm(pair.1)
    parts.push("(\{lhs}, \{rhs})")
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn br_from_str(s : String) -> @symnum.BigRational {
  @symnum.BigRational::from_bigint(BigInt::from_string(s))
}

///|
test "polyfuncs: interpolate parity for quadratic data" {
  let pts = [
    (@symnum.BigRational::from_int(1), @symnum.BigRational::from_int(1)),
    (@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(4)),
    (@symnum.BigRational::from_int(3), @symnum.BigRational::from_int(9)),
  ]
  let p = @sympolys.interpolate(pts, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = interpolate(pts, x="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: interpolate parity for shifted quadratic" {
  let pts = [
    (@symnum.BigRational::from_int(1), @symnum.BigRational::from_int(2)),
    (@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(5)),
    (@symnum.BigRational::from_int(3), @symnum.BigRational::from_int(10)),
  ]
  let p = @sympolys.interpolate(pts, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = interpolate(pts, x="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: interpolate parity for values list" {
  let vals = [
    @symnum.BigRational::from_int(1),
    @symnum.BigRational::from_int(4),
    @symnum.BigRational::from_int(9),
    @symnum.BigRational::from_int(16),
  ]
  let p = @sympolys.interpolate_values(vals, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = interpolate_values(vals, x="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: interpolate parity for dict input" {
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = [
    (@symnum.BigRational::from_int(1), @symnum.BigRational::from_int(2)),
    (@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(5)),
    (@symnum.BigRational::from_int(3), @symnum.BigRational::from_int(10)),
  ]
  let map : Map[@symnum.BigRational, @symnum.BigRational] = Map::new()
  for pair in pts {
    map.set(pair.0, pair.1)
  }
  let p = @sympolys.interpolate_dict(map, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = interpolate_dict(pts, x="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: rational_interpolate parity (degnum=2)" {
  let xdata = [1, 2, 3, 4, 5, 6]
  let ydata = [120, 150, 200, 255, 312, 370]
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  for i in 0..<xdata.length() {
    pts.push(
      (
        @symnum.BigRational::from_int(xdata[i]),
        @symnum.BigRational::from_int(ydata[i]),
      ),
    )
  }
  let (num, den) = @sympolys.rational_interpolate(pts, 2, "x", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = rational_interpolate(pts, 2, x="x").trim().to_string()
  inspect(ours, content="60*x**2 + 60||x")
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: rational_interpolate parity (degnum=3)" {
  let xdata = [1, 2, 3, 4, 5, 6]
  let ydata = [120, 150, 200, 255, 312, 370]
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  for i in 0..<xdata.length() {
    pts.push(
      (
        @symnum.BigRational::from_int(xdata[i]),
        @symnum.BigRational::from_int(ydata[i]),
      ),
    )
  }
  let (num, den) = @sympolys.rational_interpolate(pts, 3, "x", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = rational_interpolate(pts, 3, x="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: rational_interpolate parity (degnum=5, larger data)" {
  let xdata = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  let ydata = [
    "-1923885361858460", "-5212158811973685", "-9838050145867125", "-15662936261217245",
    "-22469424125057910", "-30073793365223685", "-38332297297028735", "-47132954289530109",
    "-56387719094026320", "-66026548943876885",
  ]
  for i in 0..<xdata.length() {
    pts.push((@symnum.BigRational::from_int(xdata[i]), br_from_str(ydata[i])))
  }
  let (num, den) = @sympolys.rational_interpolate(pts, 5, "x", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = rational_interpolate(pts, 5, x="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: rational_interpolate parity (degnum=2, y)" {
  let xdata = [1, 2, 3, 4, 5, 6]
  let ydata = [-210, -35, 105, 231, 350, 465]
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  for i in 0..<xdata.length() {
    pts.push(
      (
        @symnum.BigRational::from_int(xdata[i]),
        @symnum.BigRational::from_int(ydata[i]),
      ),
    )
  }
  let (num, den) = @sympolys.rational_interpolate(pts, 2, "y", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = rational_interpolate(pts, 2, x="y").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity constants and simple cases" {
  let x = @symcore.Expr::Symbol("x")
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let res0 = @sympolys.symmetrize(zero, gens=["x", "y", "z"])
  let ours0 = symmetrize_to_string(res0, false).trim().to_string()
  let oracle0 = symmetrize(zero, gens=["x", "y", "z"]).trim().to_string()
  assert_eq(ours0, oracle0)
  let res1 = @sympolys.symmetrize(one, gens=["x", "y", "z"])
  let ours1 = symmetrize_to_string(res1, false).trim().to_string()
  let oracle1 = symmetrize(one, gens=["x", "y", "z"]).trim().to_string()
  assert_eq(ours1, oracle1)
  let resx = @sympolys.symmetrize(x, gens=["x", "y"])
  let oursx = symmetrize_to_string(resx, false).trim().to_string()
  let oraclex = symmetrize(x, gens=["x", "y"]).trim().to_string()
  assert_eq(oursx, oraclex)
  let resx1 = @sympolys.symmetrize(x + one, gens=["x", "y", "z"])
  let oursx1 = symmetrize_to_string(resx1, false).trim().to_string()
  let oraclex1 = symmetrize(x + one, gens=["x", "y", "z"]).trim().to_string()
  assert_eq(oursx1, oraclex1)
  let res_xy = @sympolys.symmetrize(x, gens=["x", "y"])
  let ours_xy = symmetrize_to_string(res_xy, false).trim().to_string()
  let oracle_xy = symmetrize(x, gens=["x", "y"]).trim().to_string()
  assert_eq(ours_xy, oracle_xy)
  let res_x1 = @sympolys.symmetrize(x + one, gens=["x", "y"])
  let ours_x1 = symmetrize_to_string(res_x1, false).trim().to_string()
  let oracle_x1 = symmetrize(x + one, gens=["x", "y"]).trim().to_string()
  assert_eq(ours_x1, oracle_x1)
  let res_xxyz = @sympolys.symmetrize(x, gens=["x", "y", "z"])
  let ours_xxyz = symmetrize_to_string(res_xxyz, false).trim().to_string()
  let oracle_xxyz = symmetrize(x, gens=["x", "y", "z"]).trim().to_string()
  assert_eq(ours_xxyz, oracle_xxyz)
  let res_x1xyz = @sympolys.symmetrize(x + one, gens=["x", "y", "z"])
  let ours_x1xyz = symmetrize_to_string(res_x1xyz, false).trim().to_string()
  let oracle_x1xyz = symmetrize(x + one, gens=["x", "y", "z"])
    .trim()
    .to_string()
  assert_eq(ours_x1xyz, oracle_x1xyz)
}

///|
test "polyfuncs: symmetrize formal mapping u0/u1/u2" {
  let x = @symcore.Expr::Symbol("x")
  let expr = x + @symcore.int(1)
  let res = @sympolys.symmetrize(expr, gens=["x", "y", "z"], formal=true, symbols=[
    "u0", "u1", "u2",
  ])
  let ours = symmetrize_to_string(res, true).trim().to_string()
  let oracle = symmetrize(expr, gens=["x", "y", "z"], formal=true, symbols=[
      "u0", "u1", "u2",
    ])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity higher-degree in 3 vars" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = x ^ @symcore.int(2)
  let res = @sympolys.symmetrize(expr, gens=["x", "y", "z"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = symmetrize(expr, gens=["x", "y", "z"]).trim().to_string()
  assert_eq(ours, oracle)
  let res_xy2 = @sympolys.symmetrize(
    (x ^ @symcore.int(2)) + (y ^ @symcore.int(2)),
    gens=["x", "y"],
  )
  let ours_xy2 = symmetrize_to_string(res_xy2, false).trim().to_string()
  let oracle_xy2 = symmetrize((x ^ @symcore.int(2)) + (y ^ @symcore.int(2)), gens=[
      "x", "y",
    ])
    .trim()
    .to_string()
  assert_eq(ours_xy2, oracle_xy2)
}

///|
test "polyfuncs: horner parity small cases" {
  let x = @symcore.Expr::Symbol("x")
  let cases = [
    @symcore.int(0),
    @symcore.int(1),
    x,
    x + @symcore.int(1),
    (x ^ @symcore.int(2)) + @symcore.int(1),
    (x ^ @symcore.int(2)) + x,
    (x ^ @symcore.int(2)) + x + @symcore.int(1),
  ]
  for expr in cases {
    let ours = @symprint.pretty_string(@sympolys.horner(expr, gens=["x"]))
    let oracle = horner(expr, gens=["x"])
    assert_true(expr_equal(ours, oracle))
  }
}

///|
test "polyfuncs: symmetrize parity x^2 + y^2" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = (x ^ @symcore.int(2)) + (y ^ @symcore.int(2))
  let res = @sympolys.symmetrize(expr, gens=["x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = symmetrize(expr, gens=["x", "y"]).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity x^2 - y^2" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = (x ^ @symcore.int(2)) - (y ^ @symcore.int(2))
  let res = @sympolys.symmetrize(expr, gens=["x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = symmetrize(expr, gens=["x", "y"]).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity mixed coefficients" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = (x ^ @symcore.int(3)) +
    (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) +
    @symcore.int(3) * (y ^ @symcore.int(3))
  let res = @sympolys.symmetrize(expr, gens=["x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = symmetrize(expr, gens=["x", "y"]).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity formal mapping" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = x + y
  let res = @sympolys.symmetrize(expr, gens=["x", "y"], formal=true, symbols=[
    "u0", "u1",
  ])
  let ours = symmetrize_to_string(res, true).trim().to_string()
  let oracle = symmetrize(expr, gens=["x", "y"], formal=true, symbols=[
      "u0", "u1",
    ])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity x^2 + y^2 + z^2" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let expr = (x ^ @symcore.int(2)) +
    (y ^ @symcore.int(2)) +
    (z ^ @symcore.int(2))
  let res = @sympolys.symmetrize(expr, gens=["x", "y", "z"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = symmetrize(expr, gens=["x", "y", "z"]).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity mixed ordering gens" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let expr = x + y + z
  let res = @sympolys.symmetrize(expr, gens=["z", "x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = symmetrize(expr, gens=["z", "x", "y"]).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity mixed ordering formal" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let expr = (x ^ @symcore.int(2)) + y + z
  let res = @sympolys.symmetrize(expr, gens=["y", "z", "x"], formal=true, symbols=[
    "t1", "t2", "t3",
  ])
  let ours = symmetrize_to_string(res, true).trim().to_string()
  let oracle = symmetrize(expr, gens=["y", "z", "x"], formal=true, symbols=[
      "t1", "t2", "t3",
    ])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: symmetrize parity list cases" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let list1 = [@symcore.int(1), @symcore.int(2), @symcore.int(3)]
  let res1 = @sympolys.symmetrize_list(list1, gens=["x", "y"])
  let ours1 = symmetrize_list_to_string(res1, false).trim().to_string()
  let oracle1 = symmetrize_list(list1, gens=["x", "y"]).trim().to_string()
  assert_eq(ours1, oracle1)
  let res1f = @sympolys.symmetrize_list(list1, gens=["x", "y"], formal=true)
  let ours1f = symmetrize_list_to_string(res1f, true).trim().to_string()
  let oracle1f = symmetrize_list(list1, gens=["x", "y"], formal=true)
    .trim()
    .to_string()
  assert_eq(ours1f, oracle1f)
  let list2 = [x + y, x - y]
  let res2 = @sympolys.symmetrize_list(list2, gens=["x", "y"])
  let ours2 = symmetrize_list_to_string(res2, false).trim().to_string()
  let oracle2 = symmetrize_list(list2, gens=["x", "y"]).trim().to_string()
  assert_eq(ours2, oracle2)
}

///|
test "polyfuncs: horner parity univariate" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.int(9) * (x ^ @symcore.int(4)) +
    @symcore.int(8) * (x ^ @symcore.int(3)) +
    @symcore.int(7) * (x ^ @symcore.int(2)) +
    @symcore.int(6) * x +
    @symcore.int(5)
  let ours = expr_norm(@sympolys.horner(expr, gens=["x"])).trim().to_string()
  let oracle = sympy_normalize(horner(expr, gens=["x"])).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: horner parity multivariate wrt=y" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.int(4) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) * y +
    @symcore.int(2) * x * (y ^ @symcore.int(2)) +
    x * y
  let ours = @symprint.pretty_string(
    @sympolys.horner(expr, gens=["x", "y"], wrt="y"),
  )
  let oracle = horner(expr, gens=["x", "y"], wrt="y")
  assert_true(expr_equal(ours, oracle))
}

///|
test "polyfuncs: horner parity multivariate wrt default" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.int(4) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) * y +
    @symcore.int(2) * x * (y ^ @symcore.int(2)) +
    x * y
  let ours = @symprint.pretty_string(@sympolys.horner(expr, gens=["x", "y"]))
  let oracle = horner(expr, gens=["x", "y"])
  assert_true(expr_equal(ours, oracle))
}

///|
test "polyfuncs: horner parity multivariate wrt" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.int(4) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) * y +
    @symcore.int(2) * x * (y ^ @symcore.int(2)) +
    x * y
  let ours = expr_norm(@sympolys.horner(expr, gens=["x", "y"], wrt="x"))
    .trim()
    .to_string()
  let oracle = sympy_normalize(horner(expr, gens=["x", "y"], wrt="x"))
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: viete parity quadratic" {
  let x = @symcore.Expr::Symbol("x")
  let expr = (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(3)
  let ours = viete_to_string(@sympolys.viete(expr, roots=["r1", "r2"], gen="x"))
    .trim()
    .to_string()
  let oracle = viete(expr, roots=["r1", "r2"], gen="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: viete parity cubic" {
  let x = @symcore.Expr::Symbol("x")
  let expr = (x ^ @symcore.int(3)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) +
    @symcore.int(3) * x +
    @symcore.int(4)
  let ours = viete_to_string(
      @sympolys.viete(expr, roots=["r1", "r2", "r3"], gen="x"),
    )
    .trim()
    .to_string()
  let oracle = viete(expr, roots=["r1", "r2", "r3"], gen="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polyfuncs: viete error cases" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let r0 : Result[Array[(@symcore.Expr, @symcore.Expr)], _] = try? @sympolys.viete(
    @symcore.int(1),
    roots=["r1"],
    gen="x",
  )
  assert_true(r0 is Err(_))
  let r1 : Result[Array[(@symcore.Expr, @symcore.Expr)], _] = try? @sympolys.viete(
    (x ^ @symcore.int(2)) + @symcore.int(1),
    roots=["r1"],
    gen="x",
  )
  assert_true(r1 is Err(_))
  let r2 : Result[Array[(@symcore.Expr, @symcore.Expr)], _] = try? @sympolys.viete(
    x + y,
    roots=["r1"],
  )
  assert_true(r2 is Err(_))
}
