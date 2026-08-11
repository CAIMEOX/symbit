///|
test "printing worker keeps one Symbol atom for punctuation-rich names" {
  assert_eq(printing_call("srepr", Symbol("x y,z")), "Symbol('x y,z')")
  assert_eq(printing_call("printing.latex", Symbol("x")), "x")
}

///|
test "printing worker rejects a missing printer and recovers" {
  let rejected = try {
    printing_call("__symbit_missing_printer__", Symbol("x")) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let none_rejected = try {
    printing_call("pprint", Symbol("x")) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(none_rejected)
  assert_eq(printing_call("sstr", Symbol("x")), "x")
}
