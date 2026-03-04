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
fn nf_coeffs_norm(coeffs : Array[@symnum.BigRational]?) -> String {
  match coeffs {
    Some(items) => {
      let body = items.map(c => c.to_string()).join(",")
      "[\{body}]"
    }
    None => "None"
  }
}

///|
fn nf_reps_norm(reps : Array[Array[@symnum.BigRational]]) -> String {
  let outer = reps.map(rep => {
    let body = rep.map(c => c.to_string()).join(",")
    "[\{body}]"
  })
  let joined = outer.join(",")
  "[\{joined}]"
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
test "numberfields: perfect-power radicals reduce to true minpoly" {
  let third = try! @symcore.rational_from_ints(1, 3)
  let quarter = try! @symcore.rational_from_ints(1, 4)

  let cbrt8 = @symcore.int(8) ^ third
  let mp_cbrt8 = nf_norm(minpoly(cbrt8, gen="x").to_expr())
  let oracle_cbrt8 = nf_oracle_minpoly("8**(1/3)", gen="x")
  guard mp_cbrt8 == oracle_cbrt8 else {
    fail("minpoly(8**(1/3)) mismatch: ours=\{mp_cbrt8}, oracle=\{oracle_cbrt8}")
  }

  let fourth4 = @symcore.int(4) ^ quarter
  let mp_fourth4 = nf_norm(minpoly(fourth4, gen="x").to_expr())
  let oracle_fourth4 = nf_oracle_minpoly("4**(1/4)", gen="x")
  guard mp_fourth4 == oracle_fourth4 else {
    fail(
      "minpoly(4**(1/4)) mismatch: ours=\{mp_fourth4}, oracle=\{oracle_fourth4}",
    )
  }

  let one_sixteenth = try! @symcore.rational_from_ints(1, 16)
  let fourth_small = one_sixteenth ^ quarter
  let mp_small = nf_norm(minpoly(fourth_small, gen="x").to_expr())
  let oracle_small = nf_oracle_minpoly("(1/16)**(1/4)", gen="x")
  guard mp_small == oracle_small else {
    fail(
      "minpoly((1/16)**(1/4)) mismatch: ours=\{mp_small}, oracle=\{oracle_small}",
    )
  }
}

///|
test "numberfields: to_number_field(expr, theta) coeff parity" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half
  let sqrt5 = @symcore.int(5) ^ half
  let theta = sqrt2 + sqrt3

  let ours_s2 = nf_coeffs_norm(Some(to_number_field_coeffs(sqrt2, theta)))
  let oracle_s2 = @sympy_polys.numberfield_to_number_field_coeffs(
    "sqrt(2)",
    "sqrt(2) + sqrt(3)",
  )
    .replace_all(old=" ", new="")
  guard ours_s2 == oracle_s2 else {
    fail("to_number_field coeff mismatch sqrt2/theta: ours=\{ours_s2}, oracle=\{oracle_s2}")
  }

  let ours_s3 = nf_coeffs_norm(Some(to_number_field_coeffs(sqrt3, theta)))
  let oracle_s3 = @sympy_polys.numberfield_to_number_field_coeffs(
    "sqrt(3)",
    "sqrt(2) + sqrt(3)",
  )
    .replace_all(old=" ", new="")
  guard ours_s3 == oracle_s3 else {
    fail("to_number_field coeff mismatch sqrt3/theta: ours=\{ours_s3}, oracle=\{oracle_s3}")
  }

  let fail_case : Result[Array[@symnum.BigRational], PolyError] = try? to_number_field_coeffs(
    sqrt5,
    theta,
  )
  match fail_case {
    Ok(value) => fail("expected embedding failure for sqrt(5), got \{value}")
    Err(_) => ()
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
test "numberfields: primitive_element ex reps parity" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half

  let (prim, coeffs, reps) = primitive_element_ex([sqrt2, sqrt3])
  guard coeffs == [1, 1] else {
    fail("primitive_element_ex coefficients mismatch: \{coeffs}")
  }
  guard nf_norm(prim) == nf_norm(sqrt2 + sqrt3) else {
    fail("primitive_element_ex primitive mismatch")
  }

  let oracle_coeffs = @sympy_polys.numberfield_primitive_coeffs(
    ["sqrt(2)", "sqrt(3)"],
    gen="x",
  )
  guard coeffs == oracle_coeffs else {
    fail(
      "primitive_element_ex coeff parity mismatch: ours=\{coeffs}, oracle=\{oracle_coeffs}",
    )
  }

  let ours_reps = nf_reps_norm(reps)
  let oracle_reps = @sympy_polys.numberfield_primitive_reps(
    ["sqrt(2)", "sqrt(3)"],
    gen="x",
  )
    .replace_all(old=" ", new="")
  guard ours_reps == oracle_reps else {
    fail(
      "primitive_element_ex reps mismatch: ours=\{ours_reps}, oracle=\{oracle_reps}",
    )
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

///|
test "numberfields: subfield field_isomorphism coefficient parity" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt8 = @symcore.int(8) ^ half
  let sqrt3 = @symcore.int(3) ^ half

  let cases = [
    (sqrt2, @symcore.int(-1) * sqrt2, "sqrt(2)", "-sqrt(2)"),
    (sqrt2, sqrt8, "sqrt(2)", "sqrt(8)"),
    (@symcore.int(1) + sqrt2, sqrt2, "1 + sqrt(2)", "sqrt(2)"),
    (
      @symcore.int(1) + @symcore.int(2) * sqrt2,
      @symcore.int(-3) + @symcore.int(4) * sqrt8,
      "1 + 2*sqrt(2)",
      "-3 + 4*sqrt(8)",
    ),
    (sqrt2, sqrt2 + sqrt3, "sqrt(2)", "sqrt(2) + sqrt(3)"),
    (sqrt3, sqrt2 + sqrt3, "sqrt(3)", "sqrt(2) + sqrt(3)"),
    (sqrt2, @symcore.int(4) ^ (try! @symcore.rational_from_ints(1, 4)), "sqrt(2)", "4**(1/4)"),
    (try! @symcore.rational_from_ints(3, 2), sqrt2, "3/2", "sqrt(2)"),
    (sqrt2, try! @symcore.rational_from_ints(3, 2), "sqrt(2)", "3/2"),
    (sqrt2, sqrt3, "sqrt(2)", "sqrt(3)"),
  ]

  for item in cases {
    let lhs = item.0
    let rhs = item.1
    let lhs_str = item.2
    let rhs_str = item.3
    let ours = nf_coeffs_norm(field_isomorphism(lhs, rhs))
    let oracle = @sympy_polys.numberfield_field_isomorphism_coeffs(
      lhs_str,
      rhs_str,
    )
      .replace_all(old=" ", new="")
    guard ours == oracle else {
      fail(
        "field_isomorphism mismatch for \{lhs_str} in Q(\{rhs_str}): ours=\{ours}, oracle=\{oracle}",
      )
    }
  }
}

///|
test "numberfields: is_isomorphism_possible basic sanity" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let sqrt3 = @symcore.int(3) ^ half
  let sqrt8 = @symcore.int(8) ^ half
  let theta = sqrt2 + sqrt3

  guard is_isomorphism_possible(sqrt2, sqrt8) else {
    fail("sqrt2 -> sqrt8 should pass degree pre-check")
  }
  guard is_isomorphism_possible(sqrt2, sqrt3) else {
    fail("sqrt2 -> sqrt3 should pass degree pre-check")
  }
  guard is_isomorphism_possible(sqrt2, theta) else {
    fail("sqrt2 -> sqrt2+sqrt3 should pass multiquadratic degree pre-check")
  }
  guard is_isomorphism_possible(try! @symcore.rational_from_ints(3, 2), sqrt2) else {
    fail("rationals should pass degree pre-check")
  }
}
