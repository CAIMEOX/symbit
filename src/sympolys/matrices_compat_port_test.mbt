///|
fn mx_trim(s : String) -> String {
  s
  .replace_all(old=" ", new="")
  .replace_all(old="\n", new="")
  .replace_all(old=".0", new="")
}

///|
fn mx_expr_norm(e : @symcore.Expr) -> String {
  (try! @sympy_polys.sympy_normalize(@symprint.to_string(e)).trim().to_string())
    .replace_all(old=" ", new="")
}

///|
fn basis_to_sympy_text(basis : Array[Array[FieldElem]]) -> String {
  let cols : Array[String] = Array::new()
  for vec in basis {
    let rows : Array[String] = Array::new()
    for v in vec {
      rows.push("[\{fe_to_string(v)}]")
    }
    let rows_joined = rows.join(",")
    cols.push("Matrix([\{rows_joined}])")
  }
  let cols_joined = cols.join(",")
  "[\{cols_joined}]"
}

///|
fn ddm_to_int_rows(ddm : DDM) -> Array[Array[Int]] raise PolyError {
  let rows = ddm.to_list()
  let out : Array[Array[Int]] = Array::new()
  for row in rows {
    let out_row : Array[Int] = Array::new()
    for v in row {
      let q = fe_expect_rational(v)
      if !q.denominator().equal_int(1) {
        raise PolyError::DomainMismatch
      }
      out_row.push(q.numerator().to_int())
    }
    out.push(out_row)
  }
  out
}

///|
test "matrices: DDM add/mul/det/rref parity" {
  let a = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = ddm_from_ints([[5, 6], [7, 8]], Domain::QQ)

  let ours_add = a.add(b).to_string()
  let ours_mul = a.mul(b).to_string()
  let ours_det = fe_to_string(a.det())
  let (r, pivots) = a.rref()
  let pivot_text = pivots.map(i => i.to_string()).join(",")
  let ours_rref = "\{r.to_string()}||[\{pivot_text}]"

  let oracle_add = @sympy_polys.ddm_add([[1, 2], [3, 4]], [[5, 6], [7, 8]], "QQ")
  let oracle_mul = @sympy_polys.ddm_mul([[1, 2], [3, 4]], [[5, 6], [7, 8]], "QQ")
  let oracle_det = @sympy_polys.ddm_det([[1, 2], [3, 4]], "QQ")
  let oracle_rref = @sympy_polys.ddm_rref([[1, 2], [3, 4]], "QQ")

  guard mx_trim(ours_add) == mx_trim(oracle_add) else {
    fail("ddm add mismatch: ours=\{ours_add}, oracle=\{oracle_add}")
  }
  guard mx_trim(ours_mul) == mx_trim(oracle_mul) else {
    fail("ddm mul mismatch: ours=\{ours_mul}, oracle=\{oracle_mul}")
  }
  guard mx_trim(ours_det) == mx_trim(oracle_det) else {
    fail("ddm det mismatch: ours=\{ours_det}, oracle=\{oracle_det}")
  }
  guard mx_trim(ours_rref) == mx_trim(oracle_rref) else {
    fail("ddm rref mismatch: ours=\{ours_rref}, oracle=\{oracle_rref}")
  }
}

///|
test "matrices: DDM rank/inv/nullspace parity" {
  let rank_case = ddm_from_ints([[1, 2], [2, 4]], Domain::QQ)
  guard rank_case.rank() == @sympy_polys.ddm_rank([[1, 2], [2, 4]], "QQ") else {
    fail("ddm rank mismatch")
  }

  let inv_case = ddm_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let ours_inv = "Matrix(\{inv_case.inv().to_string()})"
  let oracle_inv = @sympy_polys.ddm_inv([[1, 2], [3, 5]], "QQ")
  guard mx_trim(ours_inv) == mx_trim(oracle_inv) else {
    fail("ddm inv mismatch: ours=\{ours_inv}, oracle=\{oracle_inv}")
  }

  let ns_case = ddm_from_ints([[1, 2, 3], [2, 4, 6]], Domain::QQ)
  let ours_ns = basis_to_sympy_text(ns_case.nullspace())
  let oracle_ns = @sympy_polys.ddm_nullspace([[1, 2, 3], [2, 4, 6]], "QQ")
  guard mx_trim(ours_ns) == mx_trim(oracle_ns) else {
    fail("ddm nullspace mismatch: ours=\{ours_ns}, oracle=\{oracle_ns}")
  }
}

///|
test "matrices: DomainMatrix LLL and transform parity" {
  let rows = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
  let a = ddm_from_ints(rows, Domain::ZZ)

  let reduced = a.lll()
  let hnf_orig = @sympy_polys.matrix_hnf_code(rows)
  let hnf_reduced = @sympy_polys.matrix_hnf_code(try! ddm_to_int_rows(reduced))
  guard hnf_orig == hnf_reduced else {
    fail("lll lattice mismatch: hnf(orig)=\{hnf_orig}, hnf(reduced)=\{hnf_reduced}")
  }

  let (reduced2, transform) = a.lll_transform()
  let recomposed = transform.mul(a).to_string()
  guard mx_trim(recomposed) == mx_trim(reduced2.to_string()) else {
    fail("lll transform reconstruction mismatch")
  }
  let hnf_reduced2 = @sympy_polys.matrix_hnf_code(try! ddm_to_int_rows(reduced2))
  guard hnf_orig == hnf_reduced2 else {
    fail("lll transform lattice mismatch")
  }
}

///|
test "matrices: HNF parity on integer cases" {
  let cases = [
    [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
  ]
  for rows in cases {
    let a = ddm_from_ints(rows, Domain::ZZ)
    let ours_rows = try! ddm_to_int_rows(a.hermite_normal_form())
    let oracle_code = @sympy_polys.matrix_hnf_code(rows)
    let ours_code = @sympy_polys.matrix_hnf_code(ours_rows)
    guard ours_code == oracle_code else {
      fail("hnf lattice mismatch: ours=\{ours_code}, oracle=\{oracle_code}")
    }
  }
}

///|
test "matrices: SDM add/mul and dense conversion" {
  let two = try! fe_from_int(2, Domain::ZZ)
  let one = try! fe_from_int(1, Domain::ZZ)
  let three = try! fe_from_int(3, Domain::ZZ)
  let four = try! fe_from_int(4, Domain::ZZ)

  let s = sdm_from_entries(2, 2, [(0, 1, two), (1, 0, one)], Domain::ZZ)
  let t = sdm_from_entries(2, 2, [(0, 0, three), (1, 1, four)], Domain::ZZ)

  let add = s.add(t)
  let mul = s.mul(t)
  let add_dense = add.to_dense().to_string()
  let mul_dense = mul.to_dense().to_string()

  guard mx_trim(add_dense) == "[[3,2],[1,4]]" else {
    fail("sdm add mismatch: \{add_dense}")
  }
  guard mx_trim(mul_dense) == "[[0,8],[3,0]]" else {
    fail("sdm mul mismatch: \{mul_dense}")
  }
}

///|
test "matrices: DomainScalar coercion and arithmetic" {
  let a = domain_scalar_from_int(2, Domain::ZZ)
  let b = domain_scalar_from_int(1, Domain::QQ)
  let c = a.add(b)
  guard c.domain is Domain::QQ else {
    fail("domain scalar unify should promote to QQ")
  }
  guard c.to_string() == "3" else {
    fail("domain scalar add mismatch")
  }

  let d = c.mul(domain_scalar_from_int(2, Domain::QQ))
  guard d.to_string() == "6" else {
    fail("domain scalar mul mismatch")
  }
}

///|
test "matrices: linsolve unique/no-solution/parametric" {
  let a = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = [fe_from_int(5, Domain::QQ), fe_from_int(11, Domain::QQ)]
  match linear_solve(a, b) {
    LinearSolveResult::Unique(sol) => {
      guard sol.length() == 2 else { fail("unique solution length") }
      guard fe_to_string(sol[0]) == "1" && fe_to_string(sol[1]) == "2" else {
        fail("unique solution mismatch")
      }
    }
    _ => fail("expected unique solution")
  }

  let a2 = ddm_from_ints([[1, 1], [1, 1]], Domain::QQ)
  let b2 = [fe_from_int(1, Domain::QQ), fe_from_int(2, Domain::QQ)]
  guard linear_solve(a2, b2) is LinearSolveResult::NoSolution else {
    fail("expected inconsistent system")
  }

  let a3 = ddm_from_ints([[1, 1]], Domain::QQ)
  let b3 = [fe_from_int(0, Domain::QQ)]
  match linear_solve(a3, b3) {
    LinearSolveResult::Parametric(exprs, params) => {
      guard params.length() == 1 else { fail("param count mismatch") }
      guard params[0] == "t1" else { fail("param naming mismatch") }
      guard exprs.length() == 2 else { fail("solution arity mismatch") }
      guard mx_expr_norm(exprs[0]) == "-t1" && mx_expr_norm(exprs[1]) == "t1" else {
        fail("parametric solution mismatch")
      }
    }
    _ => fail("expected parametric solution")
  }
}
