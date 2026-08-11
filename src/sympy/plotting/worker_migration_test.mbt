///|
test "plotting oracle transports quoted expression text without source interpolation" {
  let lines = oracle_textplot_lines(
    "x + Symbol(\"q'quoted\") * 0", "-1", "1", 15, 5,
  )
  assert_true(lines.length() > 0)
}

///|
test "plotting oracle worker recovers after a rejected expression" {
  let rejected = try {
    oracle_textplot_lines("(", "-1", "1", 15, 5) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(oracle_textplot_lines("x", "-1", "1", 15, 5).length() > 0)
}

///|
test "plot backend transports quoted data and recovers after rejection" {
  assert_true(
    oracle_plot_text_lines("x + Symbol(\"q'quoted\") * 0", "x", "-1", "1").length() >
    0,
  )
  let rejected = try {
    oracle_plot_text_lines("(", "x", "-1", "1") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(oracle_plot_text_lines("x", "x", "-1", "1").length() > 0)
}
