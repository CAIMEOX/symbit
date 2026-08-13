///|
test "discrete worker preserves literal symbols" {
  let literal = @symcore.Expr::Symbol("x y,z")
  assert_true(fwht_equiv([literal], [literal]))
}

///|
test "discrete worker preserves shared expression identity" {
  let dummy = @symcore.Expr::Dummy("d", 1101)
  assert_true(fwht_equiv([dummy], [dummy]))
}

///|
test "discrete worker reports Python errors and recovers" {
  let rejected = try {
    ntt_equiv(
      [@symcore.int(1), @symcore.int(2)],
      [@symcore.int(1), @symcore.int(2)],
      8,
    )
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(convolution_int_equiv([1], [2], [2]))
}
