///|
test "polyfuncs: rational_interpolate reports bad degree early" {
  let pts : Array[(@symnum.BigRational, @symnum.BigRational)] = [
    (@symnum.BigRational::from_int(1), @symnum.BigRational::from_int(1)),
    (@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(4)),
  ]
  sympolys_assert_error(
    fn() raise PolyError { rational_interpolate(pts, 3, "x", Domain::QQ) },
    "BadExponent",
  )
}

///|
test "polyfuncs: viete errors are typed" {
  let x = @symcore.Expr::Symbol("x")
  sympolys_assert_error(
    fn() raise PolyError { viete(@symcore.int(5), roots=[], gen="x") },
    "BadExponent",
  )

  sympolys_assert_error(
    fn() raise PolyError {
      viete((x ^ @symcore.int(2)) + @symcore.int(1), roots=["r1"], gen="x")
    },
    "BadGenerator(roots)",
  )
}
