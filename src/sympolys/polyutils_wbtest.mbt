///|
fn pu_wb_repr_strs(xs : Array[String]) -> String {
  let parts = xs.map(x => "\"\{x}\"").join(",")
  "[\{parts}]"
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
    fail("infer_gens_expr_local should collect symbols from add/mul/pow/function")
  }

  let auto_dict = try! dict_from_expr(x + y * @symcore.int(2))
  guard auto_dict.contains("\"x1\"") && auto_dict.contains("\"y2\"") else {
    fail("dict_from_expr should infer gens when omitted")
  }
}
