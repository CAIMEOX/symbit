///|
fn expect_factor_list_same(poly : Poly, modulus : Int?) -> Unit raise {
  let (content, factors) = try poly.factor_list() catch { e => fail(e.to_string()) } noraise { v => v }
  let ours_raw = try factor_list_to_string(content.to_string(), factors) catch {
    err => fail(err.to_string())
  } noraise { v => v }
  let ours = normalize_spaces(sympy_oracle_call("sort_factor_repr", [OracleArg::Str(ours_raw)]))
  let args : Array[OracleArg] = match modulus {
    Some(p) => [OracleArg::Str(poly.to_string()), OracleArg::Int(p)]
    None => [OracleArg::Str(poly.to_string())]
  }
  let oracle = normalize_spaces(
    sympy_oracle_call("sort_factor_repr", [
      OracleArg::Str(sympy_oracle_call("factor_list_str", args)),
    ]),
  )
  guard ours == oracle else {
    fail("factor_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factortools: x^5 - x over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    @symcore.mul([
      @symcore.symbol("x"),
      @symcore.add([
        @symcore.pow(@symcore.symbol("x"), @symcore.int(4)),
        @symcore.int(-1),
      ]),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_factor_list_same(poly, None) catch { e => fail(e.to_string()) }
}

///|
test "factortools: x^6 + x^3 + 1 over GF(2)" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let poly = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(6)),
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.int(1),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_factor_list_same(poly, Some(2)) catch { e => fail(e.to_string()) }
}

///|
test "factortools: sqf_list compares with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    @symcore.mul([
      @symcore.pow(@symcore.add([@symcore.symbol("x"), @symcore.int(-2)]), @symcore.int(2)),
      @symcore.pow(@symcore.add([@symcore.symbol("x"), @symcore.int(3)]), @symcore.int(3)),
    ]),
  ) catch { e => fail(e.to_string()) }
  let (content, parts) = try poly.sqf_list() catch { e => fail(e.to_string()) } noraise { v => v }
  let ours_raw = try factor_list_to_string(content.to_string(), parts) catch { e => fail(e.to_string()) } noraise { v => v }
  let ours = normalize_spaces(sympy_oracle_call("sort_factor_repr", [OracleArg::Str(ours_raw)]))
  let oracle = normalize_spaces(
    sympy_oracle_call("sort_factor_repr", [
      OracleArg::Str(sympy_oracle_call("sqf_list_str", [OracleArg::Str(poly.to_string())])),
    ]),
  )
  guard ours == oracle else {
    fail("sqf_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}
