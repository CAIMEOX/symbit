///|
test "polyutils: dict_from_expr parity (basic)" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let c = @symcore.int(17)
  let ours_c = @sympolys.dict_from_expr(c, gens=["x"])
  let oracle_c = dict_from_expr(c, gens=["x"])
  assert_eq(ours_c, oracle_c)
  let mon = @symcore.int(17) * x
  let ours_mon = @sympolys.dict_from_expr(mon, gens=["x"])
  let oracle_mon = dict_from_expr(mon, gens=["x"])
  assert_eq(ours_mon, oracle_mon)
  let term = @symcore.int(17) * (x ^ @symcore.int(7)) * y
  let ours_term = @sympolys.dict_from_expr(term, gens=["x", "y"])
  let oracle_term = dict_from_expr(term, gens=["x", "y"])
  assert_eq(ours_term, oracle_term)
  let sum = x + @symcore.int(2) * y + @symcore.int(3) * z
  let ours_sum = @sympolys.dict_from_expr(sum, gens=["x", "y", "z"])
  let oracle_sum = dict_from_expr(sum, gens=["x", "y", "z"])
  assert_eq(ours_sum, oracle_sum)
  let mixed = x * y + @symcore.int(2) * x * z + @symcore.int(3) * y * z
  let ours_mixed = @sympolys.dict_from_expr(mixed, gens=["x", "y", "z"])
  let oracle_mixed = dict_from_expr(mixed, gens=["x", "y", "z"])
  assert_eq(ours_mixed, oracle_mixed)
}
