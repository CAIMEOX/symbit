///|
test "polys DDM worker preserves domain-backed operations and formatting" {
  assert_eq(
    ddm_add([[1, 2], [3, 4]], [[5, 6], [7, 8]], "QQ"),
    "[[6, 8], [10, 12]]",
  )
  assert_eq(ddm_mul([[1, 2], [3, 4]], 2, "QQ"), "[[2, 4], [6, 8]]")
  assert_eq(
    ddm_matmul([[1, 2], [3, 4]], [[5, 6], [7, 8]], "QQ"),
    "[[19, 22], [43, 50]]",
  )
  assert_eq(ddm_det([[1, 2], [3, 4]], "QQ"), "-2")
  assert_eq(ddm_det([], "QQ"), "1")
  assert_eq(ddm_add([[4]], [[4]], "GF(5)"), "[[3 mod 5]]")
  assert_eq(ddm_det([[4]], "GF(5)"), "4 mod 5")
  assert_eq(ddm_rref([[1, 2], [3, 4]], "QQ"), "[[1, 0], [0, 1]]||[0,1]")
  assert_eq(ddm_rref([], "QQ"), "[]||[]")
}

///|
test "polys DDM Matrix-backed operations ignore domain and preserve text" {
  let ignored_domain = "DefinitelyMissingDomain"
  assert_eq(ddm_rank([[1, 2], [2, 4]], ignored_domain), 1)
  assert_eq(
    ddm_inv([[1, 2], [3, 5]], ignored_domain),
    "Matrix([[-5, 2], [3, -1]])",
  )
  assert_eq(
    ddm_nullspace([[1, 2, 3], [2, 4, 6]], ignored_domain),
    "[Matrix([\n[-2],\n[ 1],\n[ 0]]), Matrix([\n[-3],\n[ 0],\n[ 1]])]",
  )
}

///|
test "polys DDM worker reports strict errors then recovers" {
  let bad_domain = try {
    ddm_det([[1]], "DefinitelyMissingDomain") |> ignore
    false
  } catch {
    _ => true
  }
  let ragged_ddm = try {
    ddm_add([[1], [2, 3]], [[1], [2]], "QQ") |> ignore
    false
  } catch {
    _ => true
  }
  let ragged_matrix = try {
    ddm_rank([[1], [2, 3]], "ignored") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(bad_domain)
  assert_true(ragged_ddm)
  assert_true(ragged_matrix)
  assert_eq(ddm_det([[7]], "QQ"), "7")
}
