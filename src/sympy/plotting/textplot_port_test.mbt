///|
fn textplot_join(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
fn assert_textplot_oracle(
  label : String,
  expr : @symcore.Expr,
  a0 : @symcore.Expr,
  b0 : @symcore.Expr,
  width? : Int = 55,
  height? : Int = 21,
) -> Unit raise {
  let ours = @symplotting.textplot_str(expr, a0, b0, width~, height~)
  let oracle = oracle_textplot_lines(
    @symprint.to_string(expr),
    @symprint.to_string(a0),
    @symprint.to_string(b0),
    width,
    height,
  )
  if textplot_join(ours) != textplot_join(oracle) {
    println("textplot mismatch [\{label}]")
    println("ours:")
    println(textplot_join(ours))
    println("oracle:")
    println(textplot_join(oracle))
  }
  assert_eq(textplot_join(ours), textplot_join(oracle))
}

///|
test "plotting parity textplot matches additional SymPy public cases" {
  let x = @symcore.Expr::Symbol("x")
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let inv_x = @symcore.mul([@symcore.int(1), @symcore.pow(x, @symcore.int(-1))])
  let log_x = @symcore.function("log", [x])
  let sinc = @symcore.mul([
    @symcore.function("sin", [x]),
    @symcore.pow(x, @symcore.int(-1)),
  ])
  let sqrt_x = @symcore.function("sqrt", [x])

  assert_textplot_oracle("identity", x, @symcore.int(-1), @symcore.int(1))
  assert_textplot_oracle(
    "identity_height17",
    x,
    @symcore.int(-1),
    @symcore.int(1),
    height=17,
  )
  assert_textplot_oracle(
    "inv_x_singularity",
    inv_x,
    @symcore.int(0),
    @symcore.int(1),
  )
  assert_textplot_oracle(
    "log_singularity",
    log_x,
    @symcore.int(0),
    @symcore.int(1),
  )
  assert_textplot_oracle("sinc", sinc, @symcore.int(-10), @symcore.int(10))
  assert_textplot_oracle(
    "sqrt_branch",
    sqrt_x,
    @symcore.int(-1),
    @symcore.int(1),
  )
  assert_textplot_oracle(
    "imag_constant",
    imag,
    @symcore.int(-1),
    @symcore.int(1),
  )
}
