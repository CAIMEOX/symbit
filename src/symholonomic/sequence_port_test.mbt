///|
test "holonomic sequence: repr parity" {
  let n = @symcore.symbol("n")
  let (r, _) = recurrence_operators(symbol_var=n)
  let rec = recurrence_operator(
    [@symcore.int(-1), @symcore.add([n, @symcore.int(1)])],
    r,
  )
  let seq = holonomic_sequence(rec, u0=[@symcore.int(1)])
  let oracle = @sympy_holo.sequence_str(["-1", "n + 1"], u0=["1"])
  assert_eq(seq.to_sympy_str(), oracle)
}

///|
test "holonomic sequence: equality semantics" {
  let n = @symcore.symbol("n")
  let (r, _) = recurrence_operators(symbol_var=n)
  let rec = recurrence_operator([@symcore.int(1), n], r)
  let s1 = holonomic_sequence(rec, u0=[@symcore.int(2), @symcore.int(3)])
  let s2 = holonomic_sequence(rec, u0=[@symcore.int(2), @symcore.int(3)])
  let s3 = holonomic_sequence(rec, u0=[@symcore.int(2)])
  assert_true(s1 == s2)
  assert_true(s1 != s3)
}
