///|
test "misc filldedent and string layout behavior" {
  let text = "\n    alpha beta gamma delta\n    epsilon\n"
  inspect(filldedent(text, w=16), content="\nalpha beta gamma\ndelta epsilon")
  inspect(strlines("abc", c=2), content="(\n'a'\n'b'\n'c'\n)")
  inspect(rawlines("a a\na"), content="dedent('''\\\n    a a\n    a''')")
}

///|
test "misc translate replace ordinal behavior" {
  assert_eq(replace("abc", [("a", "b"), ("c", "C")]), "bbC")
  assert_eq(try! translate("abc", deletechars=Some("a")), "bc")
  assert_eq(
    try! translate("abc", oldchars=Some("a"), newchars=Some("x")),
    "xbc",
  )
  assert_eq(try! translate("abc", multimap=[("ab", "x")]), "xc")
  assert_eq(ordinal(101), "101st")
}

///|
test "misc as_int behavior" {
  assert_eq(try! as_int(int_like_int(3)), 3)
  assert_eq(try! as_int(int_like_bool(true), strict=false), 1)
  assert_eq(try! as_int(int_like_expr(@symcore.int(5))), 5)
  guard (try? as_int(int_like_double(1.1), strict=false)) is Err(_) else {
    fail("expected as_int to reject non-integral double")
  }
}
