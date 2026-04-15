///|
test "physics.control.routh_table: generic and special cases" {
  let z = @symcore.Expr::Symbol("z")
  let b0 = @symcore.Expr::Symbol("b0")
  let b1 = @symcore.Expr::Symbol("b1")
  let b2 = @symcore.Expr::Symbol("b2")
  let b3 = @symcore.Expr::Symbol("b3")
  let b4 = @symcore.Expr::Symbol("b4")
  let p1 = b4 * (z ^ @symcore.int(4)) +
    b3 * (z ^ @symcore.int(3)) +
    b2 * (z ^ @symcore.int(2)) +
    b1 * z +
    b0

  let t1 = routh_hurwitz(p1, z)
  assert_true(t1.rows() == 5 && t1.cols() == 3)
  inspect(@symprint.pretty_string(t1.get(0, 0)), content="b4")
  inspect(@symprint.pretty_string(t1.get(4, 0)), content="b0")
  assert_true(!t1.zero_row_case())
  assert_true(t1.auxiliary_polynomials().is_empty())

  let p2 = (z ^ @symcore.int(4)) +
    (z ^ @symcore.int(3)) +
    @symcore.int(3) * (z ^ @symcore.int(2)) +
    @symcore.int(3) * z +
    @symcore.int(3)
  let t2 = routh_hurwitz(p2, z)
  inspect(@symprint.pretty_string(t2.get(2, 0)), content="-3")
  inspect(@symprint.pretty_string(t2.get(3, 0)), content="4")
  assert_eq(t2.zero_col_infos(), [(2, 1)])
  assert_true(!t2.zero_row_case())

  let p3 = (z ^ @symcore.int(6)) +
    @symcore.int(2) * (z ^ @symcore.int(5)) +
    @symcore.int(8) * (z ^ @symcore.int(4)) +
    @symcore.int(12) * (z ^ @symcore.int(3)) +
    @symcore.int(20) * (z ^ @symcore.int(2)) +
    @symcore.int(16) * z +
    @symcore.int(16)
  let t3 = routh_hurwitz(p3, z)
  inspect(@symprint.pretty_string(t3.get(5, 0)), content="8/3")
  assert_true(t3.zero_row_case())
  assert_eq(t3.auxiliary_polynomials().length(), 1)
  inspect(
    @symprint.pretty_string(t3.auxiliary_polynomials()[0]),
    content="2*z**4 + 12*z**2 + 16",
  )
}
