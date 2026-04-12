///|
fn plot_port_join(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
fn assert_plot_text_oracle(
  label : String,
  expr : @symcore.Expr,
  var0 : @symcore.Expr,
  a0 : @symcore.Expr,
  b0 : @symcore.Expr,
) -> Unit raise {
  let backend = @symplotting.plot(
    [@symplotting.plot_expr(expr), @symplotting.plot_range(var0, a0, b0)],
    show=false,
    backend="text",
  )
  let ours = backend.render_lines()
  let oracle = oracle_plot_text_lines(
    @symprint.to_string(expr),
    @symprint.to_string(var0),
    @symprint.to_string(a0),
    @symprint.to_string(b0),
  )
  if plot_port_join(ours) != plot_port_join(oracle) {
    println("plot text mismatch [\{label}]")
    println("ours:")
    println(plot_port_join(ours))
    println("oracle:")
    println(plot_port_join(oracle))
  }
  assert_eq(plot_port_join(ours), plot_port_join(oracle))
}

///|
test "plotting parity text backend plot matches SymPy public cases" {
  let x = @symcore.Expr::Symbol("x")
  assert_plot_text_oracle(
    "identity_text_backend",
    x,
    x,
    @symcore.int(0),
    @symcore.int(3),
  )
  assert_plot_text_oracle(
    "quadratic_shift_text_backend",
    @symcore.add([@symcore.pow(x, @symcore.int(2)), @symcore.int(1)]),
    x,
    @symcore.int(0),
    @symcore.int(3),
  )
}
