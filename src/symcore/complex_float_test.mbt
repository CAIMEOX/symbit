///|
test "complex float constructors preserve rational parts" {
  let real = @symnum.BigRational::from_ints(3, 2) catch { _ => fail("rat") }
  let imag = @symnum.BigRational::from_ints(-5, 4) catch { _ => fail("rat") }
  let value = ComplexFloat::from_exact_parts(real, imag, prec=95)
  let parts = value.to_rational_parts() catch { _ => fail("rational parts") }
  assert_eq(parts.0, (3N, 2N))
  assert_eq(parts.1, (-5N, 4N))
  assert_eq(value.precision(), 95)
}

///|
test "complex float formatting keeps cartesian form" {
  let real = Float::from_str("1.25", prec=80) catch { _ => fail("real") }
  let imag = Float::from_str("-0.5", prec=80) catch { _ => fail("imag") }
  let value = ComplexFloat::from_real(real, imag~)
  inspect(value.format(dps=6), content="1.25 - 0.5*I")
}
