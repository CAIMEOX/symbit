///|
test "symsimplify cse reconstruction preserves semantics" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let xy = @symcore.mul([x, y])
  let exprs = [
    @symcore.add([xy, @symcore.function("sin", [xy])]),
    @symcore.add([@symcore.pow(xy, @symcore.int(2)), xy]),
  ]
  let result = cse(exprs)
  assert_true(result.replacement_count() >= 1)
  let rebuilt = cse_reconstruct(result)
  assert_eq(rebuilt.length(), exprs.length())
  for i in 0..<exprs.length() {
    assert_true(rebuilt[i] == exprs[i])
  }
}
