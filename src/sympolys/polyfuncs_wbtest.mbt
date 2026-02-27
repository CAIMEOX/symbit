///|
test "polyfuncs: rational_interpolate reports bad degree early" {
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = [
    (@symnum.BigRational::from_int(1), @symnum.BigRational::from_int(1)),
    (@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(4)),
  ]
  let res : Result[(Poly, Poly), PolyError] = try? rational_interpolate(
    pts,
    3,
    "x",
    Domain::QQ,
  )
  match res {
    Err(PolyError::BadExponent) => ()
    _ => fail("expected BadExponent")
  }
}

///|
test "polyfuncs: viete errors are typed" {
  let x = @symcore.symbol("x")
  let const_res : Result[Array[(@symcore.Expr, @symcore.Expr)], PolyError] = try? viete(
    @symcore.int(5),
    roots=[],
    gen="x",
  )
  match const_res {
    Err(PolyError::BadExponent) => ()
    _ => fail("expected BadExponent for constant polynomial")
  }

  let roots_res : Result[Array[(@symcore.Expr, @symcore.Expr)], PolyError] = try? viete(
    (x ^ @symcore.int(2)) + @symcore.int(1),
    roots=["r1"],
    gen="x",
  )
  match roots_res {
    Err(PolyError::BadGenerator(name)) => inspect(name, content="roots")
    _ => fail("expected BadGenerator(\"roots\")")
  }
}
