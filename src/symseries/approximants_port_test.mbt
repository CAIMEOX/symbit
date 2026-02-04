///|
fn normalize_appr(expr : @symcore.Expr) -> String {
  let s = @symprint.to_string(expr)
  try! @sympy_series.sympy_normalize_str(s)
}

///|

///|
fn sympy_equiv_expr_str(expr : @symcore.Expr, other : String) -> Bool {
  let s = @symprint.to_string(expr)
  try! @sympy_series.sympy_equiv_str(s, other)
}

///|
fn split_list_items(list_str : String) -> Array[String] {
  let trimmed = list_str.trim()
  if trimmed.length() < 2 {
    return []
  }
  let inner_view = try trimmed[1:trimmed.length() - 1] catch {
    _ => return []
  } noraise {
    v => v
  }
  let inner = inner_view.to_string()
  if inner.trim().length() == 0 {
    return []
  }
  let parts : Array[String] = Array::new()
  for part in inner.split(", ") {
    parts.push(part.to_string())
  }
  parts
}

///|
test "symseries pade approximant parity" {
  let x = @symcore.symbol("x")
  let denom = @symcore.add([
    @symcore.int(1),
    @symcore.mul([@symcore.int(-1), x]),
  ])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let ours = try! pade_approximant(expr, x, m=1, n=1)
  let sympy_list = try! @sympy_series.approximants_str([1, 1, 1, 1, 1, 1], "x")
  let items = split_list_items(sympy_list)
  guard items.length() > 1 else { fail("sympy approximants missing entry") }
  assert_true(sympy_equiv_expr_str(ours, items[1]))
}

///|
test "symseries approximants list parity" {
  let x = @symcore.symbol("x")
  let coeffs_expr : Array[@symcore.Expr] = [
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(1),
  ]
  let ours = try! approximants(coeffs_expr, x~)
  let ours_norm : Array[String] = Array::new()
  for v in ours {
    ours_norm.push(normalize_appr(v))
  }
  let sympy_list = try! @sympy_series.approximants_str([1, 1, 1, 1, 1, 1], "x")
  let items = split_list_items(sympy_list)
  assert_eq(ours_norm.length(), items.length())
  for i in 0..<ours_norm.length() {
    assert_true(sympy_equiv_expr_str(ours[i], items[i]))
  }
}
