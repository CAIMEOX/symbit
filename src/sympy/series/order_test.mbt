///|
test "symseries O basic normalization" {
  let x = @symcore.Expr::Symbol("x")
  let zero = big_o(@symcore.int(0))
  assert_eq(to_repr(zero).to_string(), "0")
  let o1 = big_o(@symcore.int(5))
  assert_eq(to_repr(o1).to_string(), "(call O 1)")
  let o2 = big_o(@symcore.mul([@symcore.int(3), x]))
  assert_eq(to_repr(o2).to_string(), "(call O sym:x)")
}
