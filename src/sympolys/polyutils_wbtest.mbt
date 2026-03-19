///|
fn pu_wb_repr_strs(xs : Array[String]) -> String {
  let parts = xs.map(x => "\"\{x}\"").join(",")
  "[\{parts}]"
}

///|
fn pu_wb_repr_int_list(xs : Array[Int]) -> String {
  let parts = xs.map(x => x.to_string()).join(",")
  "[\{parts}]"
}

///|
fn pu_wb_repr_int_lists(xs : Array[Array[Int]]) -> String {
  let parts : Array[String] = Array::new()
  for item in xs {
    parts.push(pu_wb_repr_int_list(item))
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
fn pu_wb_repr_int_list_pairs(xs : Array[(Array[Int], Int)]) -> String {
  let parts : Array[String] = Array::new()
  for item in xs {
    parts.push("(\{pu_wb_repr_int_list(item.0)},\{item.1})")
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
test "polyutils wb: parity for internal helper APIs" {
  let gens = ["x", "p", "q"]
  let ours_base = _sort_gens(gens)
  guard pu_wb_repr_strs(ours_base) == "[\"x\",\"p\",\"q\"]" else {
    fail("_sort_gens should keep the default x/p/q ordering")
  }

  let ours_wrt = _sort_gens(gens, wrt=["q"])
  guard pu_wb_repr_strs(ours_wrt) == "[\"q\",\"x\",\"p\"]" else {
    fail("_sort_gens should move wrt gens to the front in the given order")
  }

  let ours_sort = _sort_gens(gens, wrt=["q"], sort="p > x")
  guard pu_wb_repr_strs(ours_sort) == "[\"q\",\"p\",\"x\"]" else {
    fail("_sort_gens should respect explicit sort ranks after wrt entries")
  }

  let ours_wrt_str = _sort_gens_wrt(gens, "q, x")
  guard pu_wb_repr_strs(ours_wrt_str) == "[\"q\",\"x\",\"p\"]" else {
    fail("_sort_gens_wrt should parse wrt strings consistently")
  }

  let suffix_gens = ["x0", "x1", "x2", "x10", "x11", "x12", "x20", "x21", "x22"]
  let suffix_ours = _sort_gens(suffix_gens)
  guard pu_wb_repr_strs(suffix_ours) ==
    "[\"x0\",\"x1\",\"x2\",\"x10\",\"x11\",\"x12\",\"x20\",\"x21\",\"x22\"]" else {
    fail("numeric suffix order mismatch")
  }

  let a = ["x", "y", "z"]
  let b = ["t", "x", "p", "q", "z"]
  let unified = _unify_gens(a, b)
  guard pu_wb_repr_strs(unified) == "[\"t\",\"x\",\"y\",\"p\",\"q\",\"z\"]" else {
    fail(
      "_unify_gens should respect both order constraints with deterministic ties",
    )
  }

  let flat = ["x", "y", "z"]
  let flat_ours = _analyze_gens(flat)
  guard pu_wb_repr_strs(flat_ours) == "[\"x\",\"y\",\"z\"]" else {
    fail("_analyze_gens should preserve flat generator lists")
  }

  let nested = [["x", "y", "z"]]
  let nested_ours = _analyze_gens_nested(nested)
  guard pu_wb_repr_strs(nested_ours) == "[\"x\",\"y\",\"z\"]" else {
    fail("_analyze_gens_nested should unwrap single nested generator groups")
  }

  let factors = [[1, 2, 3], [1, 2], [1]]
  let factors_ours = _sort_factors(factors)
  guard pu_wb_repr_int_lists(factors_ours) == "[[1],[1,2],[1,2,3]]" else {
    fail("_sort_factors should sort by length then lexicographically")
  }

  let factors_multi = [([2, 2], 1), ([1, 2, 3], 1), ([1, 2], 2), ([1], 1)]
  let factors_multi_ours = _sort_factors_multiple(factors_multi)
  guard pu_wb_repr_int_list_pairs(factors_multi_ours) ==
    "[([1],1),([2,2],1),([1,2],2),([1,2,3],1)]" else {
    fail("_sort_factors_multiple should use the documented tie ordering")
  }
}

///|
test "polyutils wb: sorting and unify edge branches" {
  guard pu_wb_repr_strs(_sort_gens([])) == "[]" else {
    fail("_sort_gens([]) should return []")
  }

  let wrt_blank = _sort_gens_wrt(["x", "y"], "   ")
  guard pu_wb_repr_strs(wrt_blank) == "[\"x\",\"y\"]" else {
    fail("_sort_gens_wrt should treat blank wrt as empty")
  }

  guard gens_rank("y10").0 == 1 else { fail("gens_rank(y*) should rank to 1") }
  guard gens_rank("z3").0 == 2 else { fail("gens_rank(z*) should rank to 2") }

  guard compare_gens("x1", "x10") < 0 else {
    fail("compare_gens should compare numeric suffixes")
  }
  guard compare_gens("x1", "x01") != 0 else {
    fail("compare_gens should use raw name tie-breaker")
  }

  let sorted_unknown = _sort_gens(["y10", "y2", "z11", "z3"], sort="x > p")
  guard pu_wb_repr_strs(sorted_unknown) == "[\"y2\",\"y10\",\"z3\",\"z11\"]" else {
    fail("sort-list fallback ordering mismatch")
  }

  guard pu_wb_repr_strs(_unify_gens([], ["u", "v"])) == "[\"u\",\"v\"]" else {
    fail("_unify_gens should return b when a is empty")
  }
  guard pu_wb_repr_strs(_unify_gens(["u", "v"], [])) == "[\"u\",\"v\"]" else {
    fail("_unify_gens should return a when b is empty")
  }

  let cycle = _unify_gens(["x", "y"], ["y", "x"])
  guard pu_wb_repr_strs(cycle) == "[\"x\",\"y\"]" else {
    fail("_unify_gens cycle fallback should return first list")
  }
}

///|
test "polyutils wb: nested gens and factor tie ordering" {
  let nested = _analyze_gens_nested([["x", "y"], ["z"]])
  guard pu_wb_repr_strs(nested) == "[\"x\",\"y\",\"z\"]" else {
    fail("_analyze_gens_nested flatten mismatch")
  }

  let sorted = _sort_factors_multiple([([2, 1], 1), ([1, 2], 1), ([9], 3)])
  guard sorted[0].0.length() == 1 && sorted[1].0[0] == 1 && sorted[2].0[0] == 2 else {
    fail("_sort_factors_multiple tie ordering mismatch")
  }
}

///|
test "polyutils wb: symbol collection and inferred gens" {
  let x = @symcore.symbol("x1")
  let y = @symcore.symbol("y2")
  let composite = @symcore.add([
    x * (y ^ @symcore.int(2)),
    @symcore.function("f", [x]),
    @symcore.int(3),
  ])

  let inferred = infer_gens_expr_local(composite)
  guard pu_wb_repr_strs(inferred) == "[\"x1\",\"y2\"]" else {
    fail(
      "infer_gens_expr_local should collect symbols from add/mul/pow/function",
    )
  }

  let auto_dict = try! dict_from_expr(x + y * @symcore.int(2))
  guard auto_dict.contains("\"x1\"") && auto_dict.contains("\"y2\"") else {
    fail("dict_from_expr should infer gens when omitted")
  }
}
