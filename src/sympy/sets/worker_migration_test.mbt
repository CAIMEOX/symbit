///|
test "sets worker preserves punctuation-rich Symbol names" {
  let symbol = @symcore.Expr::Symbol("x y,z")
  assert_eq(set_str(@symsets.finite_set([symbol])), "{x y,z}")
  assert_eq(contains_str(@symsets.finite_set([symbol]), symbol), "True")
}

///|
test "sets worker reports invalid images and recovers" {
  let invalid = @symsets.Set::ImageSet(
    symbol=@symcore.int(1),
    expr=@symcore.int(2),
    base=@symsets.integers(),
  )
  let rejected = try {
    set_str(invalid) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(set_str(@symsets.integers()), "Integers")
}
