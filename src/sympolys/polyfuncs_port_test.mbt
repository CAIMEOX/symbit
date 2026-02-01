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
