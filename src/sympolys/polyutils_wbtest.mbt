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
  assert_eq(pu_wb_repr_strs(ours_base), "[\"x\",\"p\",\"q\"]")

  let ours_wrt = _sort_gens(gens, wrt=["q"])
  assert_eq(pu_wb_repr_strs(ours_wrt), "[\"q\",\"x\",\"p\"]")

  let ours_sort = _sort_gens(gens, wrt=["q"], sort="p > x")
  assert_eq(pu_wb_repr_strs(ours_sort), "[\"q\",\"p\",\"x\"]")

  let ours_wrt_str = _sort_gens_wrt(gens, "q, x")
  assert_eq(pu_wb_repr_strs(ours_wrt_str), "[\"q\",\"x\",\"p\"]")

  let suffix_gens = ["x0", "x1", "x2", "x10", "x11", "x12", "x20", "x21", "x22"]
  let suffix_ours = _sort_gens(suffix_gens)
  assert_eq(
    pu_wb_repr_strs(suffix_ours),
    "[\"x0\",\"x1\",\"x2\",\"x10\",\"x11\",\"x12\",\"x20\",\"x21\",\"x22\"]",
  )

  let a = ["x", "y", "z"]
  let b = ["t", "x", "p", "q", "z"]
  let unified = _unify_gens(a, b)
  assert_eq(pu_wb_repr_strs(unified), "[\"t\",\"x\",\"y\",\"p\",\"q\",\"z\"]")

  let flat = ["x", "y", "z"]
  let flat_ours = _analyze_gens(flat)
  assert_eq(pu_wb_repr_strs(flat_ours), "[\"x\",\"y\",\"z\"]")

  let nested = [["x", "y", "z"]]
  let nested_ours = _analyze_gens_nested(nested)
  assert_eq(pu_wb_repr_strs(nested_ours), "[\"x\",\"y\",\"z\"]")

  let factors = [[1, 2, 3], [1, 2], [1]]
  let factors_ours = _sort_factors(factors)
  assert_eq(pu_wb_repr_int_lists(factors_ours), "[[1],[1,2],[1,2,3]]")

  let factors_multi = [([2, 2], 1), ([1, 2, 3], 1), ([1, 2], 2), ([1], 1)]
  let factors_multi_ours = _sort_factors_multiple(factors_multi)
  assert_eq(
    pu_wb_repr_int_list_pairs(factors_multi_ours),
    "[([1],1),([2,2],1),([1,2],2),([1,2,3],1)]",
  )
}

///|
test "polyutils wb: sorting and unify edge branches" {
  assert_eq(pu_wb_repr_strs(_sort_gens([])), "[]")

  let wrt_blank = _sort_gens_wrt(["x", "y"], "   ")
  assert_eq(pu_wb_repr_strs(wrt_blank), "[\"x\",\"y\"]")

  assert_eq(gens_rank("y10").0, 1)
  assert_eq(gens_rank("z3").0, 2)

  assert_true(compare_gens("x1", "x10") < 0)
  assert_true(compare_gens("x1", "x01") != 0)

  let sorted_unknown = _sort_gens(["y10", "y2", "z11", "z3"], sort="x > p")
  assert_eq(pu_wb_repr_strs(sorted_unknown), "[\"y2\",\"y10\",\"z3\",\"z11\"]")

  assert_eq(pu_wb_repr_strs(_unify_gens([], ["u", "v"])), "[\"u\",\"v\"]")
  assert_eq(pu_wb_repr_strs(_unify_gens(["u", "v"], [])), "[\"u\",\"v\"]")

  let cycle = _unify_gens(["x", "y"], ["y", "x"])
  assert_eq(pu_wb_repr_strs(cycle), "[\"x\",\"y\"]")
}

///|
test "polyutils wb: nested gens and factor tie ordering" {
  let nested = _analyze_gens_nested([["x", "y"], ["z"]])
  assert_eq(pu_wb_repr_strs(nested), "[\"x\",\"y\",\"z\"]")

  let sorted = _sort_factors_multiple([([2, 1], 1), ([1, 2], 1), ([9], 3)])
  assert_true(
    sorted[0].0.length() == 1 && sorted[1].0[0] == 1 && sorted[2].0[0] == 2,
  )
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
  assert_eq(pu_wb_repr_strs(inferred), "[\"x1\",\"y2\"]")

  let auto_dict = dict_from_expr(x + y * @symcore.int(2))
  assert_true(auto_dict.contains("\"x1\"") && auto_dict.contains("\"y2\""))
}
