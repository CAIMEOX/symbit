///|
fn nf_wb_iv_text(iv : (@symnum.BigRational, @symnum.BigRational)) -> String {
  "(\{iv.0}, \{iv.1})"
}

///|
fn nf_wb_factor_text(items : Array[(Int, Int)]) -> String {
  let parts : Array[String] = []
  for item in items {
    parts.push("(\{item.0},\{item.1})")
  }
  let body = parts.join(",")
  "[\{body}]"
}

///|
fn nf_wb_factor_pair_text(
  item : (Array[(Int, Int)], Array[(Int, Int)]),
) -> String {
  "\{nf_wb_factor_text(item.0)}||\{nf_wb_factor_text(item.1)}"
}

///|
fn nf_wb_coeff_search_text(values : Array[Array[Int]]) -> String {
  let rows : Array[String] = []
  for row in values {
    let body = row.map(v => v.to_string()).join(",")
    rows.push("[\{body}]")
  }
  let body = rows.join(",")
  "[\{body}]"
}

///|
test "numberfields utilities: rational predicates and numerator denominator" {
  let half = @symnum.BigRational::from_ints(1, 2) catch { _ => fail("half") }
  let neg_int = @symnum.BigRational::from_ints(-6, 3) catch {
    _ => fail("neg-int")
  }

  inspect(is_rat(half), content="true")
  inspect(is_int(half), content="false")
  inspect(is_int(neg_int), content="true")

  let reduced = @symnum.BigRational::from_ints(-6, 8) catch {
    _ => fail("reduced")
  }
  let (num, den) = get_num_denom(reduced)
  inspect("(\{num}, \{den})", content="(-3, 4)")
}

///|
test "numberfields utilities: fundamental discriminant extraction" {
  inspect(
    nf_wb_factor_pair_text(extract_fundamental_discriminant(-432)),
    content="[(-1,1),(3,1)]||[(2,2),(3,1)]",
  )
  inspect(
    nf_wb_factor_pair_text(extract_fundamental_discriminant(12)),
    content="[(2,2),(3,1)]||[]",
  )
  inspect(
    nf_wb_factor_pair_text(extract_fundamental_discriminant(5)),
    content="[(5,1)]||[]",
  )
  let invalid : Result[(Array[(Int, Int)], Array[(Int, Int)]), PolyError] = try? extract_fundamental_discriminant(
    2,
  )
  match invalid {
    Ok(value) => fail("expected invalid discriminant error, got \{value}")
    Err(_) => ()
  }
}

///|
test "numberfields utilities: coefficient search prefix" {
  inspect(
    nf_wb_coeff_search_text(coeff_search(2, 1, count=13)),
    content="[[1,1],[1,0],[1,-1],[0,1],[2,2],[2,1],[2,0],[2,-1],[2,-2],[1,2],[1,-2],[0,2],[3,3]]",
  )
  inspect(nf_wb_coeff_search_text(coeff_search(0, 1, count=5)), content="[]")
  inspect(nf_wb_coeff_search_text(coeff_search(3, 0, count=5)), content="[]")
}

///|
test "numberfields frontdoors: isolate rational and real radicals" {
  let half = @symcore.rational_from_ints(1, 2)
  inspect(nf_wb_iv_text(isolate(half)), content="(1/2, 1/2)")

  let sqrt2 = int(2) ^ @symcore.rational_from_ints(1, 2)
  inspect(nf_wb_iv_text(isolate(sqrt2)), content="(1, 2)")
  inspect(nf_wb_iv_text(isolate(int(0) - sqrt2)), content="(-2, -1)")
  inspect(nf_wb_iv_text(isolate(int(2) * sqrt2)), content="(2, 3)")
}

///|
test "numberfields frontdoors: round_two and prime decomposition" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  inspect(
    round_two(b.from_expr((x ^ int(2)) - int(2))),
    content="(Submodule[[1, 0], [0, 1]], 8)",
  )
  inspect(
    round_two(b.from_expr((x ^ int(2)) - int(5))),
    content="(Submodule[[2, 0], [1, 1]]/2, 5)",
  )
  let inert = prime_decomp(3, b.from_expr((x ^ int(2)) - int(2)))
  inspect(inert.map(item => item.to_string()).join(" | "), content="(3)")
  let ramified = prime_decomp(2, b.from_expr((x ^ int(2)) - int(2)))
  inspect(ramified.map(item => item.to_string()).join(" | "), content="(2, x)")
  inspect(prime_valuation(8, ramified[0]), content="6")
}
