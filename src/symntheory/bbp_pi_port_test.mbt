///|
test "ntheory bbp pi parity" {
  assert_eq(pi_hex_digits(0), @sympy_nt.pi_hex_digits_str(0))
  assert_eq(pi_hex_digits(0, prec=3), @sympy_nt.pi_hex_digits_str(0, prec=3))
  assert_eq(pi_hex_digits(1), @sympy_nt.pi_hex_digits_str(1))
  assert_eq(pi_hex_digits(13), @sympy_nt.pi_hex_digits_str(13))
  assert_eq(
    pi_hex_digits(100, prec=8),
    @sympy_nt.pi_hex_digits_str(100, prec=8),
  )
}

///|
test "ntheory bbp pi errors" {
  let neg_n : Result[String, Error] = try? pi_hex_digits(-1)
  guard neg_n is Err(_) else { fail("expected n negative error") }
  let neg_prec : Result[String, Error] = try? pi_hex_digits(0, prec=-1)
  guard neg_prec is Err(_) else { fail("expected prec negative error") }
}
