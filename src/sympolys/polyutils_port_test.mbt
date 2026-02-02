///|
fn repr_str_list(xs : Array[String]) -> String {
  let parts = xs.map(x => "\"\{x}\"").join(",")
  "[\{parts}]"
}

///|
fn repr_int_list(xs : Array[Int]) -> String {
  let parts = xs.map(x => x.to_string()).join(",")
  "[\{parts}]"
}

///|
fn repr_int_lists(xs : Array[Array[Int]]) -> String {
  let parts : Array[String] = Array::new()
  for item in xs {
    parts.push(repr_int_list(item))
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
fn repr_int_list_pairs(xs : Array[(Array[Int], Int)]) -> String {
  let parts : Array[String] = Array::new()
  for item in xs {
    parts.push("(\{repr_int_list(item.0)},\{item.1})")
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
test "polyutils: _sort_gens parity (basic/wrt/sort)" {
  let gens = ["x", "p", "q"]

  let ours_base = _sort_gens(gens)
  let oracle_base = @sympy.sort_gens(gens)
  guard repr_str_list(ours_base) == repr_str_list(oracle_base) else {
    fail("_sort_gens base mismatch: ours=\{repr_str_list(ours_base)} oracle=\{repr_str_list(oracle_base)}")
  }

  let ours_wrt = _sort_gens(gens, wrt=["q"])
  let oracle_wrt = @sympy.sort_gens(gens, wrt=["q"])
  guard repr_str_list(ours_wrt) == repr_str_list(oracle_wrt) else {
    fail("_sort_gens wrt mismatch: ours=\{repr_str_list(ours_wrt)} oracle=\{repr_str_list(oracle_wrt)}")
  }

  let ours_sort = _sort_gens(gens, wrt=["q"], sort="p > x")
  let oracle_sort = @sympy.sort_gens(gens, wrt=["q"], sort="p > x")
  guard repr_str_list(ours_sort) == repr_str_list(oracle_sort) else {
    fail("_sort_gens sort mismatch: ours=\{repr_str_list(ours_sort)} oracle=\{repr_str_list(oracle_sort)}")
  }

  let ours_wrt_str = _sort_gens_wrt(gens, "q, x")
  let oracle_wrt_str = @sympy.sort_gens(gens, wrt=["q", "x"])
  guard repr_str_list(ours_wrt_str) == repr_str_list(oracle_wrt_str) else {
    fail("_sort_gens_wrt mismatch: ours=\{repr_str_list(ours_wrt_str)} oracle=\{repr_str_list(oracle_wrt_str)}")
  }
}

///|
test "polyutils: _sort_gens parity (numeric suffix ordering)" {
  let gens = ["x0", "x1", "x2", "x10", "x11", "x12", "x20", "x21", "x22"]
  let ours = _sort_gens(gens)
  let oracle = @sympy.sort_gens(gens)
  guard repr_str_list(ours) == repr_str_list(oracle) else {
    fail("numeric suffix order mismatch: ours=\{repr_str_list(ours)} oracle=\{repr_str_list(oracle)}")
  }
}

///|
test "polyutils: _unify_gens parity" {
  let a = ["x", "y", "z"]
  let b = ["t", "x", "p", "q", "z"]
  let ours = _unify_gens(a, b)
  let oracle = @sympy.unify_gens(a, b)
  guard repr_str_list(ours) == repr_str_list(oracle) else {
    fail("_unify_gens mismatch: ours=\{repr_str_list(ours)} oracle=\{repr_str_list(oracle)}")
  }
}

///|
test "polyutils: _analyze_gens parity (flat + nested)" {
  let flat = ["x", "y", "z"]
  let ours_flat = _analyze_gens(flat)
  let oracle_flat = @sympy.analyze_gens(flat)
  guard repr_str_list(ours_flat) == repr_str_list(oracle_flat) else {
    fail("_analyze_gens flat mismatch: ours=\{repr_str_list(ours_flat)} oracle=\{repr_str_list(oracle_flat)}")
  }

  let nested = [["x", "y", "z"]]
  let ours_nested = _analyze_gens_nested(nested)
  let oracle_nested = @sympy.analyze_gens_nested(nested)
  guard repr_str_list(ours_nested) == repr_str_list(oracle_nested) else {
    fail("_analyze_gens nested mismatch: ours=\{repr_str_list(ours_nested)} oracle=\{repr_str_list(oracle_nested)}")
  }
}

///|
test "polyutils: _sort_factors parity" {
  let factors = [[1, 2, 3], [1, 2], [1]]
  let ours = _sort_factors(factors)
  let oracle = @sympy.sort_factors(factors)
  guard repr_int_lists(ours) == oracle else {
    fail("_sort_factors mismatch: ours=\{repr_int_lists(ours)} oracle=\{oracle}")
  }

  let factors_multi = [([2, 2], 1), ([1, 2, 3], 1), ([1, 2], 2), ([1], 1)]
  let ours_multi = _sort_factors_multiple(factors_multi)
  let oracle_multi = @sympy.sort_factors_multiple(factors_multi)
  guard repr_int_list_pairs(ours_multi) == oracle_multi else {
    fail("_sort_factors multiple mismatch: ours=\{repr_int_list_pairs(ours_multi)} oracle=\{oracle_multi}")
  }
}

///|
test "polyutils: dict_from_expr parity (basic)" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")

  let c = @symcore.int(17)
  let ours_c = dict_from_expr(c, gens=["x"])
  let oracle_c = @sympy.dict_from_expr(c, gens=["x"])
  guard ours_c == oracle_c else {
    fail("dict_from_expr constant mismatch: ours=\{ours_c} oracle=\{oracle_c}")
  }

  let mon = @symcore.int(17) * x
  let ours_mon = dict_from_expr(mon, gens=["x"])
  let oracle_mon = @sympy.dict_from_expr(mon, gens=["x"])
  guard ours_mon == oracle_mon else {
    fail("dict_from_expr monomial mismatch: ours=\{ours_mon} oracle=\{oracle_mon}")
  }

  let term = @symcore.int(17) * (x ^ @symcore.int(7)) * y
  let ours_term = dict_from_expr(term, gens=["x", "y"])
  let oracle_term = @sympy.dict_from_expr(term, gens=["x", "y"])
  guard ours_term == oracle_term else {
    fail("dict_from_expr term mismatch: ours=\{ours_term} oracle=\{oracle_term}")
  }

  let sum = x + @symcore.int(2) * y + @symcore.int(3) * z
  let ours_sum = dict_from_expr(sum, gens=["x", "y", "z"])
  let oracle_sum = @sympy.dict_from_expr(sum, gens=["x", "y", "z"])
  guard ours_sum == oracle_sum else {
    fail("dict_from_expr sum mismatch: ours=\{ours_sum} oracle=\{oracle_sum}")
  }

  let mixed =
    (x * y) + (@symcore.int(2) * x * z) + (@symcore.int(3) * y * z)
  let ours_mixed = dict_from_expr(mixed, gens=["x", "y", "z"])
  let oracle_mixed = @sympy.dict_from_expr(mixed, gens=["x", "y", "z"])
  guard ours_mixed == oracle_mixed else {
    fail("dict_from_expr mixed mismatch: ours=\{ours_mixed} oracle=\{oracle_mixed}")
  }
}
