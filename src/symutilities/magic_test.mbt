///|
test "magic pollute updates explicit scope" {
  let scope : Ref[Map[String, Int]] = { val: {} }
  pollute(["x", "y"], [2, 3], scope)
  assert_eq(scope.val["x"], 2)
  assert_eq(scope.val["y"], 3)
}

///|
test "magic pollute rejects mismatched lengths" {
  let scope : Ref[Map[String, Int]] = { val: {} }
  assert_true((try? pollute(["x"], [1, 2], scope)) is Err(_))
}
