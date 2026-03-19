///|
test "symseries O basic normalization" {
  let x = @symcore.symbol("x")
  let zero = big_o(@symcore.int(0))
  assert_eq(@symprint.debug_repr(zero), "0")
  let o1 = big_o(@symcore.int(5))
  assert_eq(@symprint.debug_repr(o1), "(call O 1)")
  let o2 = big_o(@symcore.mul([@symcore.int(3), x]))
  assert_eq(@symprint.debug_repr(o2), "(call O sym:x)")
}
