///|
test "symseries sequence formula coeff" {
  let n = @symcore.symbol("n")
  let expr = @symcore.pow(n, @symcore.int(2))
  let seq = sequence(expr, var_name="n", start=0, stop=5)
  let c = try! seq.coeff(3)
  assert_eq(@symprint.debug_repr(c), "9")
}

///|
test "symseries sequence periodic coeff" {
  let seq = seq_per(
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    start=0,
    stop=6,
  )
  let c = try! seq.coeff(4)
  assert_eq(@symprint.debug_repr(c), "2")
}

///|
test "symseries sequence add/mul coeff" {
  let n = @symcore.symbol("n")
  let seq1 = sequence(n, var_name="n", start=0, stop=5)
  let seq2 = sequence(@symcore.int(1), var_name="n", start=0, stop=5)
  let seq_add = seq_add(seq1, seq2)
  let seq_mul = seq_mul(seq1, seq2)
  let c_add = try! seq_add.coeff(2)
  let c_mul = try! seq_mul.coeff(2)
  assert_eq(@symprint.debug_repr(c_add), "3")
  assert_eq(@symprint.debug_repr(c_mul), "2")
}
