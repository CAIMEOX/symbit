///|
test "polyutils: dict_from_expr parity (basic)" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let c = @symcore.int(17)
  let ours_c = dict_from_expr(c, gens=["x"])
  let oracle_c = @sympy_polys.dict_from_expr(c, gens=["x"])
  guard ours_c == oracle_c else {
    fail("dict_from_expr constant mismatch: ours=\{ours_c} oracle=\{oracle_c}")
  }
  let mon = @symcore.int(17) * x
  let ours_mon = dict_from_expr(mon, gens=["x"])
  let oracle_mon = @sympy_polys.dict_from_expr(mon, gens=["x"])
  guard ours_mon == oracle_mon else {
    fail(
      "dict_from_expr monomial mismatch: ours=\{ours_mon} oracle=\{oracle_mon}",
    )
  }
  let term = @symcore.int(17) * (x ^ @symcore.int(7)) * y
  let ours_term = dict_from_expr(term, gens=["x", "y"])
  let oracle_term = @sympy_polys.dict_from_expr(term, gens=["x", "y"])
  guard ours_term == oracle_term else {
    fail(
      "dict_from_expr term mismatch: ours=\{ours_term} oracle=\{oracle_term}",
    )
  }
  let sum = x + @symcore.int(2) * y + @symcore.int(3) * z
  let ours_sum = dict_from_expr(sum, gens=["x", "y", "z"])
  let oracle_sum = @sympy_polys.dict_from_expr(sum, gens=["x", "y", "z"])
  guard ours_sum == oracle_sum else {
    fail("dict_from_expr sum mismatch: ours=\{ours_sum} oracle=\{oracle_sum}")
  }
  let mixed = x * y + @symcore.int(2) * x * z + @symcore.int(3) * y * z
  let ours_mixed = dict_from_expr(mixed, gens=["x", "y", "z"])
  let oracle_mixed = @sympy_polys.dict_from_expr(mixed, gens=["x", "y", "z"])
  guard ours_mixed == oracle_mixed else {
    fail(
      "dict_from_expr mixed mismatch: ours=\{ours_mixed} oracle=\{oracle_mixed}",
    )
  }
}
