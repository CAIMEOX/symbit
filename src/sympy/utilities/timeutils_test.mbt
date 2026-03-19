///|
test "timeutils timed returns sensible summary" {
  let result = timed(
    () => {
      let _ = 1 + 1
    },
    limit=Some(1000),
  )
  assert_true(result.number > 0)
  assert_true(result.seconds_per_call >= 0.0)
  assert_true(result.scaled >= 0.0)
  assert_true(["s", "ms", "us", "ns"].contains(result.unit))
}

///|
test "timeutils timethis reports elapsed time" {
  let seen : Ref[TimethisReport?] = { val: None }
  let wrapped = timethis("demo", reporter=report => seen.val = Some(report), (
    x : Int,
  ) => x + 1)
  assert_eq(wrapped(4), 5)
  match seen.val {
    Some(report) => {
      assert_eq(report.name, "demo")
      assert_true(report.elapsed_seconds >= 0.0)
    }
    None => fail("expected timethis to report")
  }
}
