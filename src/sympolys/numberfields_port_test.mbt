///|
fn nf_norm(expr : @symcore.Expr) -> String {
  (try! @sympy_polys.sympy_normalize(@symprint.to_string(expr)).trim().to_string())
    .replace_all(old=" ", new="")
}

///|
fn nf_oracle_minpoly(expr : String, gen? : String = "x") -> String {
  (try! @sympy_polys.sympy_normalize(
    @sympy_polys.numberfield_minpoly(expr, gen~),
  )
    .trim()
    .to_string())
    .replace_all(old=" ", new="")
}

///|
test "numberfields: minpoly parity for rationals and radicals" {
  let q = try! @symcore.rational_from_ints(3, 2)
  let q_mp = minpoly(q, gen="x")
  let q_ours = nf_norm(q_mp.to_expr())
  let q_oracle = nf_oracle_minpoly("3/2", gen="x")
  guard q_ours == q_oracle else {
    fail("minpoly(3/2) mismatch: ours=\{q_ours}, oracle=\{q_oracle}")
  }

  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let s_mp = minpoly(sqrt2, gen="x")
  let s_ours = nf_norm(s_mp.to_expr())
  let s_oracle = nf_oracle_minpoly("sqrt(2)", gen="x")
  guard s_ours == s_oracle else {
    fail("minpoly(sqrt(2)) mismatch: ours=\{s_ours}, oracle=\{s_oracle}")
  }
}

///|
test "numberfields: affine radical minpoly parity" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let one_third = try! @symcore.rational_from_ints(1, 3)
  let sqrt2 = @symcore.int(2) ^ half

  let shifted = @symcore.int(1) + sqrt2
  let shifted_ours = nf_norm(minpoly(shifted, gen="x").to_expr())
  let shifted_oracle = nf_oracle_minpoly("1 + sqrt(2)", gen="x")
  guard shifted_ours == shifted_oracle else {
    fail(
      "minpoly(1+sqrt(2)) mismatch: ours=\{shifted_ours}, oracle=\{shifted_oracle}",
    )
  }

  let scaled = @symcore.int(3) * sqrt2 - one_third
  let scaled_ours = nf_norm(minpoly(scaled, gen="x").to_expr())
  let scaled_oracle = nf_oracle_minpoly("3*sqrt(2) - 1/3", gen="x")
  guard scaled_ours == scaled_oracle else {
    fail(
      "minpoly(3*sqrt(2)-1/3) mismatch: ours=\{scaled_ours}, oracle=\{scaled_oracle}",
    )
  }
}

///|
test "numberfields: to_number_field and primitive_element parity" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half
  let k = to_number_field(sqrt2, gen="a")
  match k {
    Domain::AlgExt(base, gens, rels) => {
      guard base is Domain::QQ && gens.equal(["a"]) && rels.length() == 1 else {
        fail("unexpected number field descriptor")
      }
      let rel = nf_norm(rels[0])
      guard rel == "a**2-2" else {
        fail("unexpected defining relation: \{rel}")
      }
    }
    _ => fail("expected algebraic extension domain")
  }

  let (prim, coeffs) = primitive_element([sqrt2, sqrt3])
  guard coeffs == [1, 1] else {
    fail("primitive_element coefficients mismatch: \{coeffs}")
  }
  let prim_norm = nf_norm(prim)
  let oracle_coeffs = @sympy_polys.numberfield_primitive_coeffs(
    ["sqrt(2)", "sqrt(3)"],
    gen="x",
  )
  guard coeffs == oracle_coeffs else {
    fail(
      "primitive_element coeff parity mismatch: ours=\{coeffs}, oracle=\{oracle_coeffs}",
    )
  }
  guard prim_norm == nf_norm(sqrt2 + sqrt3) else {
    fail("primitive_element expression mismatch")
  }
}

///|
test "numberfields: field_isomorphic parity for simple algebraic fields" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half

  let qa = to_number_field(sqrt2, gen="a")
  let qb = to_number_field(sqrt2, gen="b")
  let qc = to_number_field(sqrt3, gen="c")

  let ours_same = field_isomorphic(qa, qb)
  let ours_diff = field_isomorphic(qa, qc)

  let oracle_same = @sympy_polys.numberfield_field_isomorphic("sqrt(2)", "sqrt(2)")
  let oracle_diff = @sympy_polys.numberfield_field_isomorphic("sqrt(2)", "sqrt(3)")

  guard ours_same == oracle_same else {
    fail("field_isomorphic(sqrt2,sqrt2) mismatch")
  }
  guard ours_diff == oracle_diff else {
    fail("field_isomorphic(sqrt2,sqrt3) mismatch")
  }
}
