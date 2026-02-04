///|
fn terms_from_ints(values : Array[Int]) -> Array[TermInput] {
  let out : Array[TermInput] = Array::new()
  for v in values {
    out.push(TermInput::IntTerm(v))
  }
  out
}

///|
fn map_repr(mapping : Map[String, BoolExpr]) -> String {
  let keys : Array[String] = Array::new()
  for k, _ in mapping {
    keys.push(k)
  }
  keys.sort()
  let parts : Array[String] = Array::new()
  for k in keys {
    let v = mapping[k]
    parts.push("\{k}: \{to_string(v)}")
  }
  let joined = parts.join(", ")
  "{\{joined}}"
}

///|
fn bool_map_repr(res : BoolMapResult?) -> String {
  match res {
    None => "False"
    Some(r) => "(\{to_string(r.simplified)}, \{map_repr(r.mapping)})"
  }
}

///|
test "boolalg sop/pos/anf forms parity" {
  let w = bool_symbol("w")
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")
  let vars = [w, x, y, z]
  let minterms = terms_from_ints([1, 3, 7, 11, 15])
  let dontcares = terms_from_ints([0, 2, 5])
  let ours_sop = sop_form(vars, minterms, dontcares~)
  let oracle_sop = try! @sympy_logic.boolalg_sop_form_ints(
    ["w", "x", "y", "z"],
    [1, 3, 7, 11, 15],
    dontcares=[0, 2, 5],
  )
  assert_eq(to_string(ours_sop), oracle_sop)
  let ours_pos = pos_form(vars, minterms, dontcares~)
  let oracle_pos = try! @sympy_logic.boolalg_pos_form_ints(
    ["w", "x", "y", "z"],
    [1, 3, 7, 11, 15],
    dontcares=[0, 2, 5],
  )
  assert_eq(to_string(ours_pos), oracle_pos)
  let anf_vars = [bool_symbol("x"), bool_symbol("y")]
  let ours_anf = anf_form(anf_vars, [0, 1, 1, 1])
  let oracle_anf = try! @sympy_logic.boolalg_anf_form(["x", "y"], [0, 1, 1, 1])
  assert_eq(to_string(ours_anf), oracle_anf)
}

///|
test "boolalg simplify_logic parity" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")
  let expr = bool_or([
    bool_and([bool_not(x), bool_not(y), bool_not(z)]),
    bool_and([bool_not(x), bool_not(y), z]),
  ])
  let ours = simplify_logic(expr)
  let oracle = try! @sympy_logic.boolalg_simplify_logic(
    "~x & ~y & ~z | ~x & ~y & z",
  )
  assert_eq(to_string(ours), oracle)
  let dc_expr = bool_or([x, y])
  let ours_dc = simplify_logic(dc_expr, dontcare=y)
  let oracle_dc = try! @sympy_logic.boolalg_simplify_logic(
    "x | y",
    dontcare="y",
  )
  assert_eq(to_string(ours_dc), oracle_dc)
}

///|
test "boolalg bool_map and gateinputcount parity" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let a = bool_symbol("a")
  let b = bool_symbol("b")
  let ours_map = bool_map(bool_and([x, y]), bool_and([a, b]))
  let oracle_map = try! @sympy_logic.boolalg_bool_map("x & y", "a & b")
  assert_eq(bool_map_repr(ours_map), oracle_map)
  let gate_expr = bool_or([bool_and([x, y]), bool_symbol("z")])
  let ours_gate = gateinputcount(gate_expr)
  let oracle_gate = try! @sympy_logic.boolalg_gateinputcount("x & y | z")
  assert_eq(ours_gate.to_string(), oracle_gate)
}
