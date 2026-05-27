///|
test "float constructors roundtrip exact dyadics" {
  let dyadic = Float::from_str("0.125", prec=80) catch { _ => fail("parse") }
  assert_true(dyadic.to_rational() == (1N, 8N))
  assert_true(dyadic.precision() == 80)
  inspect(dyadic.to_string(), content="0.125")
}

///|
test "float can be built from exact rationals" {
  let exact = @symnum.BigRational::from_ints(3, 8) catch { _ => fail("rat") }
  let approx = Float::from_exact(exact, prec=100) catch { _ => fail("float") }
  assert_true(approx.to_rational() == (3N, 8N))
  assert_true(approx.is_finite())
}

///|
test "float double bridge uses symnum compat layer" {
  let quarter = Float::from_double(0.25, prec=90)
  assert_true(quarter.to_rational() == (1N, 4N))
  assert_true(quarter.to_double() == 0.25)
  inspect(float_from_double(0.5, prec=90).format(), content="0.5")
}

///|
test "float double bridge handles negative non-dyadic values" {
  let sample = Float::from_str("-3.991991991991992", prec=80) catch {
    _ => fail("parse")
  }
  assert_true((sample.to_double() - -3.991991991991992).abs() <= 1.0e-12)
}

///|
test "float double bridge handles decimal fractions beyond 32-bit mantissas" {
  let sample = Float::from_str("12345678.125", prec=80) catch {
    _ => fail("parse")
  }
  assert_true((sample.to_double() - 12345678.125).abs() <= 1.0e-9)
}
