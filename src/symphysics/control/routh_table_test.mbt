///|
test "physics.control.routh_table: generic and special cases" {
  let z = @symcore.symbol("z")
  let b0 = @symcore.symbol("b0")
  let b1 = @symcore.symbol("b1")
  let b2 = @symcore.symbol("b2")
  let b3 = @symcore.symbol("b3")
  let b4 = @symcore.symbol("b4")
  let p1 = b4 * (z ^ @symcore.int(4)) +
    b3 * (z ^ @symcore.int(3)) +
    b2 * (z ^ @symcore.int(2)) +
    b1 * z +
    b0

  let t1 = try! routh_hurwitz(p1, z)
  guard t1.rows() == 5 && t1.cols() == 3 else { fail("generic table shape") }
  inspect(@symprint.to_string(try! t1.get(0, 0)), content="b4")
  inspect(@symprint.to_string(try! t1.get(4, 0)), content="b0")
  guard !t1.zero_row_case() else {
    fail("generic table should not hit zero-row case")
  }
  guard t1.auxiliary_polynomials().is_empty() else {
    fail("generic table should not produce auxiliary polynomials")
  }

  let p2 = (z ^ @symcore.int(4)) +
    (z ^ @symcore.int(3)) +
    @symcore.int(3) * (z ^ @symcore.int(2)) +
    @symcore.int(3) * z +
    @symcore.int(3)
  let t2 = try! routh_hurwitz(p2, z)
  inspect(@symprint.to_string(try! t2.get(2, 0)), content="-3")
  inspect(@symprint.to_string(try! t2.get(3, 0)), content="4")
  guard t2.zero_col_infos() == [(2, 1)] else { fail("zero_col_infos mismatch") }
  guard !t2.zero_row_case() else {
    fail("zero-column case should not trigger zero-row case")
  }

  let p3 = (z ^ @symcore.int(6)) +
    @symcore.int(2) * (z ^ @symcore.int(5)) +
    @symcore.int(8) * (z ^ @symcore.int(4)) +
    @symcore.int(12) * (z ^ @symcore.int(3)) +
    @symcore.int(20) * (z ^ @symcore.int(2)) +
    @symcore.int(16) * z +
    @symcore.int(16)
  let t3 = try! routh_hurwitz(p3, z)
  inspect(@symprint.to_string(try! t3.get(5, 0)), content="8/3")
  guard t3.zero_row_case() else { fail("zero-row case should be flagged") }
  guard t3.auxiliary_polynomials().length() == 1 else {
    fail("expected one auxiliary polynomial")
  }
  inspect(
    @symprint.to_string(t3.auxiliary_polynomials()[0]),
    content="2*z**4 + 12*z**2 + 16",
  )
}
