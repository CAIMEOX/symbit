///|
test "strategies worker preserves literal Symbol names" {
  let symbol = @symcore.Expr::Symbol("x y,z")
  assert_eq(rl_rebuild(symbol), "x y,z")
}

///|
test "strategies worker shares Dummy identity across rule arguments" {
  let dummy = @symcore.Expr::Dummy("d", 1001)
  assert_eq(rl_subs(dummy, dummy, @symcore.int(7)), "7")
}

///|
test "strategies worker contains an oracle exception and recovers" {
  let rejected = try {
    rl_flatten(Symbol("plain")) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(core_exhaust_posdec(4), 0)
}
