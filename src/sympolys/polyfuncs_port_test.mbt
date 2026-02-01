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
test "polyfuncs: rational_interpolate parity (degnum=2)" {
  let xdata = [1, 2, 3, 4, 5, 6]
  let ydata = [120, 150, 200, 255, 312, 370]
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  for i in 0..<xdata.length() {
    pts.push((
      @symnum.BigRational::from_int(xdata[i]),
      @symnum.BigRational::from_int(ydata[i]),
    ))
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
test "polyfuncs: rational_interpolate parity (degnum=2, y)" {
  let xdata = [1, 2, 3, 4, 5, 6]
  let ydata = [-210, -35, 105, 231, 350, 465]
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  for i in 0..<xdata.length() {
    pts.push((
      @symnum.BigRational::from_int(xdata[i]),
      @symnum.BigRational::from_int(ydata[i]),
    ))
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
test "polyfuncs: symmetrize parity x^2 + y^2" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = (x ^ @symcore.int(2)) + (y ^ @symcore.int(2))
  let res = symmetrize(expr, gens=["x", "y"])
  let ours = symmetrize_to_string(res, false).trim().to_string()
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y"])
    .trim()
    .to_string()
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
  let oracle = @sympy_polys.symmetrize(expr, gens=["x", "y"])
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: symmetrize parity formal mapping" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = x + y
  let res = symmetrize(expr, gens=["x", "y"], formal=true, symbols=["u0", "u1"])
  let ours = symmetrize_to_string(res, true).trim().to_string()
  let oracle = @sympy_polys.symmetrize(
    expr,
    gens=["x", "y"],
    formal=true,
    symbols=["u0", "u1"],
  )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("symmetrize formal mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "polyfuncs: horner parity univariate" {
  let x = @symcore.symbol("x")
  let expr =
    (@symcore.int(9) * (x ^ @symcore.int(4))) +
    (@symcore.int(8) * (x ^ @symcore.int(3))) +
    (@symcore.int(7) * (x ^ @symcore.int(2))) +
    (@symcore.int(6) * x) +
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
test "polyfuncs: horner parity multivariate wrt" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr =
    (@symcore.int(4) * (x ^ @symcore.int(2)) * (y ^ @symcore.int(2))) +
    (@symcore.int(2) * (x ^ @symcore.int(2)) * y) +
    (@symcore.int(2) * x * (y ^ @symcore.int(2))) +
    (x * y)
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
  let expr = (x ^ @symcore.int(2)) + (@symcore.int(2) * x) + @symcore.int(3)
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
