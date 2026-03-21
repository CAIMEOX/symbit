///|
fn cmp_to_ord(c : Int) -> Int {
  if c < 0 {
    -1
  } else if c > 0 {
    1
  } else {
    0
  }
}

///|
test "orderings: lex/grlex/grevlex keys and comparisons" {
  let a = [1, 2, 3]
  let b = [2, 2, 3]
  let c = [1, 3, 3]
  let d = [1, 2, 4]
  let e = [0, 2, 3]
  let f = [1, 1, 3]
  let g = [1, 2, 2]

  // lex
  inspect(
    cmp_to_ord(@sympolys.compare_exps_lex(a, b)).to_string(),
    content="-1",
  )
  inspect(cmp_to_ord(@sympolys.compare_exps_lex(b, a)), content="1")
  inspect(cmp_to_ord(@sympolys.compare_exps_lex(a, a)), content="0")

  // grlex compares total degree then lex
  inspect(@sympolys.compare_exps_grlex(b, a), content="1")
  inspect(@sympolys.compare_exps_grlex(c, a), content="1")
  inspect(@sympolys.compare_exps_grlex(d, a), content="1")
  inspect(@sympolys.compare_exps_grlex(e, a), content="-1")
  inspect(@sympolys.compare_exps_grlex(f, a), content="-1")
  inspect(@sympolys.compare_exps_grlex(g, a), content="-1")

  // grevlex reverses tie-breaker
  inspect(@sympolys.compare_exps_grevlex(b, d), content="1")
  inspect(@sympolys.compare_exps_grevlex(c, d), content="1")
  inspect(@sympolys.compare_exps_grevlex(e, g), content="-1")
  inspect(@sympolys.compare_exps_grevlex(f, g), content="-1")
}

///|
test "orderings: inverse lex and grlex flip comparisons" {
  let p = [1, 2, 3]
  let q = [2, 0, 3]
  let r = [0, 2, 3]
  inspect(@sympolys.compare_exps_ilex(p, q), content="1")
  inspect(@sympolys.compare_exps_igrlex(p, r), content="-1")
}
