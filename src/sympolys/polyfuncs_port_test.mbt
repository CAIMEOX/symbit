///|
fn expr_norm(expr : @symcore.Expr) -> String {
  sympy_normalize(@symprint.to_string(expr))
}

///|
fn symmetrize_to_string(res : SymmetrizeResult, formal : Bool) -> String {
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
) -> String {
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
fn viete_to_string(pairs : Array[(@symcore.Expr, @symcore.Expr)]) -> String {
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
  let p = interpolate(pts, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = @sympy_polys.interpolate(pts, x="x").trim().to_string()
  guard ours == oracle else {
    fail("interpolate mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: interpolate parity for shifted quadratic" {
  let pts = [
    (@symnum.BigRational::from_int(1), @symnum.BigRational::from_int(2)),
    (@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(5)),
    (@symnum.BigRational::from_int(3), @symnum.BigRational::from_int(10)),
  ]
  let p = interpolate(pts, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = @sympy_polys.interpolate(pts, x="x").trim().to_string()
  guard ours == oracle else {
    fail("interpolate mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: interpolate parity for values list" {
  let vals = [
    @symnum.BigRational::from_int(1),
    @symnum.BigRational::from_int(4),
    @symnum.BigRational::from_int(9),
    @symnum.BigRational::from_int(16),
  ]
  let p = interpolate_values(vals, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = @sympy_polys.interpolate_values(vals, x="x").trim().to_string()
  guard ours == oracle else {
    fail("interpolate values mismatch: ours=\{ours}, oracle=\{oracle}")
  }
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
  let p = interpolate_dict(map, "x", Domain::QQ)
  let ours = poly_canon_str(p).trim().to_string()
  let oracle = @sympy_polys.interpolate_dict(pts, x="x").trim().to_string()
  guard ours == oracle else {
    fail("interpolate dict mismatch: ours=\{ours}, oracle=\{oracle}")
  }
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
  let (num, den) = rational_interpolate(pts, 2, "x", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = @sympy_polys.rational_interpolate(pts, 2, x="x")
    .trim()
    .to_string()
  inspect(ours, content="60*x**2 + 60||x")
  guard ours == oracle else {
    fail("rational_interpolate mismatch: ours=\{ours}, oracle=\{oracle}")
  }
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
  let (num, den) = rational_interpolate(pts, 3, "x", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = @sympy_polys.rational_interpolate(pts, 3, x="x")
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("rational_interpolate deg3 mismatch: ours=\{ours}, oracle=\{oracle}")
  }
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
  let (num, den) = rational_interpolate(pts, 5, "x", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = @sympy_polys.rational_interpolate(pts, 5, x="x")
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("rational_interpolate deg5 mismatch: ours=\{ours}, oracle=\{oracle}")
  }
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
  let (num, den) = rational_interpolate(pts, 2, "y", Domain::QQ)
  let ours = div_pair_to_string(num, den).trim().to_string()
  let oracle = @sympy_polys.rational_interpolate(pts, 2, x="y")
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("rational_interpolate mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity constants and simple cases" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let res0 = symmetrize(zero, gens=["x", "y", "z"])
  let ours0 = symmetrize_to_string(res0, false).trim().to_string()
  let oracle0 = @sympy_polys.symmetrize(zero, gens=["x", "y", "z"])
    .trim()
    .to_string()
  guard ours0 == oracle0 else {
    fail("symmetrize 0 mismatch: ours=\{ours0}, oracle=\{oracle0}")
  }
  let res1 = symmetrize(one, gens=["x", "y", "z"])
  let ours1 = symmetrize_to_string(res1, false).trim().to_string()
  let oracle1 = @sympy_polys.symmetrize(one, gens=["x", "y", "z"])
    .trim()
    .to_string()
  guard ours1 == oracle1 else {
    fail("symmetrize 1 mismatch: ours=\{ours1}, oracle=\{oracle1}")
  }
  let resx = symmetrize(x, gens=["x", "y"])
  let oursx = symmetrize_to_string(resx, false).trim().to_string()
  let oraclex = @sympy_polys.symmetrize(x, gens=["x", "y"]).trim().to_string()
  guard oursx == oraclex else {
    fail("symmetrize x mismatch: ours=\{oursx}, oracle=\{oraclex}")
  }
  let resx1 = symmetrize(x + one, gens=["x", "y", "z"])
  let oursx1 = symmetrize_to_string(resx1, false).trim().to_string()
  let oraclex1 = @sympy_polys.symmetrize(x + one, gens=["x", "y", "z"])
    .trim()
    .to_string()
  guard oursx1 == oraclex1 else {
    fail("symmetrize x+1 mismatch: ours=\{oursx1}, oracle=\{oraclex1}")
  }
  let res_xy = symmetrize(x, gens=["x", "y"])
  let ours_xy = symmetrize_to_string(res_xy, false).trim().to_string()
  let oracle_xy = @sympy_polys.symmetrize(x, gens=["x", "y"]).trim().to_string()
  guard ours_xy == oracle_xy else {
    fail("symmetrize x,x,y mismatch: ours=\{ours_xy}, oracle=\{oracle_xy}")
  }
  let res_x1 = symmetrize(x + one, gens=["x", "y"])
  let ours_x1 = symmetrize_to_string(res_x1, false).trim().to_string()
  let oracle_x1 = @sympy_polys.symmetrize(x + one, gens=["x", "y"])
    .trim()
    .to_string()
  guard ours_x1 == oracle_x1 else {
    fail("symmetrize x+1,x,y mismatch: ours=\{ours_x1}, oracle=\{oracle_x1}")
  }
  let res_xxyz = symmetrize(x, gens=["x", "y", "z"])
  let ours_xxyz = symmetrize_to_string(res_xxyz, false).trim().to_string()
  let oracle_xxyz = @sympy_polys.symmetrize(x, gens=["x", "y", "z"])
    .trim()
    .to_string()
  guard ours_xxyz == oracle_xxyz else {
    fail(
      "symmetrize x,x,y,z mismatch: ours=\{ours_xxyz}, oracle=\{oracle_xxyz}",
    )
  }
  let res_x1xyz = symmetrize(x + one, gens=["x", "y", "z"])
  let ours_x1xyz = symmetrize_to_string(res_x1xyz, false).trim().to_string()
  let oracle_x1xyz = @sympy_polys.symmetrize(x + one, gens=["x", "y", "z"])
    .trim()
    .to_string()
  guard ours_x1xyz == oracle_x1xyz else {
    fail(
      "symmetrize x+1,x,y,z mismatch: ours=\{ours_x1xyz}, oracle=\{oracle_x1xyz}",
    )
  }
}

///|
test "polyfuncs: symmetrize formal mapping u0/u1/u2" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let expr = x + @symcore.int(1)
  let res = symmetrize(expr, gens=["x", "y", "z"], formal=true, symbols=[
    "u0", "u1", "u2",
  ])
  let ours = symmetrize_to_string(res, true).trim().to_string()
  let oracle = @sympy_polys.symmetrize(
      expr,
      gens=["x", "y", "z"],
      formal=true,
      symbols=["u0", "u1", "u2"],
    )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize formal u0/u1/u2 mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity higher-degree in 3 vars" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = x ^ @symcore.int(2)
  let res = symmetrize(expr, gens=["x", "y", "z"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y", "z"])
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize x^2 mismatch: ours=\{ours}, oracle=\{oracle}")
  }
  let res_xy2 = symmetrize((x ^ @symcore.int(2)) + (y ^ @symcore.int(2)), gens=[
    "x", "y",
  ])
  let ours_xy2 = symmetrize_to_string(res_xy2, false).trim().to_string()
  let oracle_xy2 = @sympy_polys.symmetrize(
      (x ^ @symcore.int(2)) + (y ^ @symcore.int(2)),
      gens=["x", "y"],
    )
    .trim()
    .to_string()
  guard ours_xy2 == oracle_xy2 else {
    fail("symmetrize x^2+y^2 mismatch: ours=\{ours_xy2}, oracle=\{oracle_xy2}")
  }
}

///|
test "polyfuncs: horner parity small cases" {
  let x = @symcore.symbol("x")
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
    let ours = @symprint.to_string(horner(expr, gens=["x"]))
    let oracle = @sympy_polys.horner(expr, gens=["x"])
    guard expr_equal(ours, oracle) else {
      fail("horner small mismatch: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

///|
test "polyfuncs: symmetrize parity x^2 + y^2" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = (x ^ @symcore.int(2)) + (y ^ @symcore.int(2))
  let res = symmetrize(expr, gens=["x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y"]).trim().to_string()
  guard ours == oracle else {
    fail("symmetrize mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity x^2 - y^2" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = (x ^ @symcore.int(2)) - (y ^ @symcore.int(2))
  let res = symmetrize(expr, gens=["x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y"]).trim().to_string()
  guard ours == oracle else {
    fail("symmetrize mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity mixed coefficients" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = (x ^ @symcore.int(3)) +
    (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) +
    @symcore.int(3) * (y ^ @symcore.int(3))
  let res = symmetrize(expr, gens=["x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y"]).trim().to_string()
  guard ours == oracle else {
    fail("symmetrize mixed coeffs mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity formal mapping" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = x + y
  let res = symmetrize(expr, gens=["x", "y"], formal=true, symbols=["u0", "u1"])
  let ours = symmetrize_to_string(res, true).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y"], formal=true, symbols=[
      "u0", "u1",
    ])
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize formal mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity x^2 + y^2 + z^2" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let expr = (x ^ @symcore.int(2)) +
    (y ^ @symcore.int(2)) +
    (z ^ @symcore.int(2))
  let res = symmetrize(expr, gens=["x", "y", "z"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y", "z"])
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity mixed ordering gens" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let expr = x + y + z
  let res = symmetrize(expr, gens=["z", "x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["z", "x", "y"])
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity mixed ordering formal" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let expr = (x ^ @symcore.int(2)) + y + z
  let res = symmetrize(expr, gens=["y", "z", "x"], formal=true, symbols=[
    "t1", "t2", "t3",
  ])
  let ours = symmetrize_to_string(res, true).trim().to_string()
  let oracle = @sympy_polys.symmetrize(
      expr,
      gens=["y", "z", "x"],
      formal=true,
      symbols=["t1", "t2", "t3"],
    )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize formal mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity list cases" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let list1 = [@symcore.int(1), @symcore.int(2), @symcore.int(3)]
  let res1 = symmetrize_list(list1, gens=["x", "y"])
  let ours1 = symmetrize_list_to_string(res1, false).trim().to_string()
  let oracle1 = @sympy_polys.symmetrize_list(list1, gens=["x", "y"])
    .trim()
    .to_string()
  guard ours1 == oracle1 else {
    fail("symmetrize list mismatch: ours=\{ours1}, oracle=\{oracle1}")
  }
  let res1f = symmetrize_list(list1, gens=["x", "y"], formal=true)
  let ours1f = symmetrize_list_to_string(res1f, true).trim().to_string()
  let oracle1f = @sympy_polys.symmetrize_list(
      list1,
      gens=["x", "y"],
      formal=true,
    )
    .trim()
    .to_string()
  guard ours1f == oracle1f else {
    fail("symmetrize list formal mismatch: ours=\{ours1f}, oracle=\{oracle1f}")
  }
  let list2 = [x + y, x - y]
  let res2 = symmetrize_list(list2, gens=["x", "y"])
  let ours2 = symmetrize_list_to_string(res2, false).trim().to_string()
  let oracle2 = @sympy_polys.symmetrize_list(list2, gens=["x", "y"])
    .trim()
    .to_string()
  guard ours2 == oracle2 else {
    fail("symmetrize list x±y mismatch: ours=\{ours2}, oracle=\{oracle2}")
  }
}

///|
test "polyfuncs: horner parity univariate" {
  let x = @symcore.symbol("x")
  let expr = @symcore.int(9) * (x ^ @symcore.int(4)) +
    @symcore.int(8) * (x ^ @symcore.int(3)) +
    @symcore.int(7) * (x ^ @symcore.int(2)) +
    @symcore.int(6) * x +
    @symcore.int(5)
  let ours = expr_norm(horner(expr, gens=["x"])).trim().to_string()
  let oracle = sympy_normalize(@sympy_polys.horner(expr, gens=["x"]))
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("horner mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: horner parity multivariate wrt=y" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.int(4) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) * y +
    @symcore.int(2) * x * (y ^ @symcore.int(2)) +
    x * y
  let ours = @symprint.to_string(horner(expr, gens=["x", "y"], wrt="y"))
  let oracle = @sympy_polys.horner(expr, gens=["x", "y"], wrt="y")
  guard expr_equal(ours, oracle) else {
    fail("horner wrt=y mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: horner parity multivariate wrt default" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.int(4) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) * y +
    @symcore.int(2) * x * (y ^ @symcore.int(2)) +
    x * y
  let ours = @symprint.to_string(horner(expr, gens=["x", "y"]))
  let oracle = @sympy_polys.horner(expr, gens=["x", "y"])
  guard expr_equal(ours, oracle) else {
    fail("horner default mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: horner parity multivariate wrt" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.int(4) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(2)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) * y +
    @symcore.int(2) * x * (y ^ @symcore.int(2)) +
    x * y
  let ours = expr_norm(horner(expr, gens=["x", "y"], wrt="x"))
    .trim()
    .to_string()
  let oracle = sympy_normalize(
      @sympy_polys.horner(expr, gens=["x", "y"], wrt="x"),
    )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("horner mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: viete parity quadratic" {
  let x = @symcore.symbol("x")
  let expr = (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(3)
  let ours = viete_to_string(viete(expr, roots=["r1", "r2"], gen="x"))
    .trim()
    .to_string()
  let oracle = @sympy_polys.viete(expr, roots=["r1", "r2"], gen="x")
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("viete mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: viete parity cubic" {
  let x = @symcore.symbol("x")
  let expr = (x ^ @symcore.int(3)) +
    @symcore.int(2) * (x ^ @symcore.int(2)) +
    @symcore.int(3) * x +
    @symcore.int(4)
  let ours = viete_to_string(viete(expr, roots=["r1", "r2", "r3"], gen="x"))
    .trim()
    .to_string()
  let oracle = @sympy_polys.viete(expr, roots=["r1", "r2", "r3"], gen="x")
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("viete mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: viete error cases" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let r0 : Result[Array[(@symcore.Expr, @symcore.Expr)], _] = try? viete(
    @symcore.int(1),
    roots=["r1"],
    gen="x",
  )
  guard r0 is Err(_) else { fail("viete constant should error") }
  let r1 : Result[Array[(@symcore.Expr, @symcore.Expr)], _] = try? viete(
    (x ^ @symcore.int(2)) + @symcore.int(1),
    roots=["r1"],
    gen="x",
  )
  guard r1 is Err(_) else { fail("viete roots length should error") }
  let r2 : Result[Array[(@symcore.Expr, @symcore.Expr)], _] = try? viete(
    x + y,
    roots=["r1"],
  )
  guard r2 is Err(_) else { fail("viete multivariate should error") }
}
