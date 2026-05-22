///|
fn floating_port_pair_text(pair : (BigInt, BigInt)) -> String {
  let (num, den) = pair
  "(\{num}, \{den})"
}

///|
test "floating fields: to_rational parity" {
  let pi5 = @symcore.Float::from_str("3.14159") catch { _ => fail("float") }
  for cap in [10, 100, 1000] {
    assert_eq(
      floating_port_pair_text(@sympolys.to_rational(pi5, BigInt::from_int(cap))),
      to_rational("3.14159", cap.to_string()),
    )
  }
  assert_eq(
    floating_port_pair_text(@sympolys.to_rational(pi5, 10N, limit=false)),
    to_rational("3.14159", "10", limit=false),
  )
}

///|
test "floating fields: to_rational signed parity" {
  let neg = @symcore.Float::from_str("-0.3333333333333333") catch {
    _ => fail("negative")
  }
  assert_eq(
    floating_port_pair_text(@sympolys.to_rational(neg, 10N)),
    to_rational("-0.3333333333333333", "10"),
  )
}
