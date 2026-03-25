///|
test "symcore parity number symbols render as SymPy core singletons" {
  inspect(core_expr_sstr(@symcore.pi()), content="pi")
  inspect(core_expr_sstr(@symcore.imag_unit()), content="I")
  inspect(core_expr_sstr(@symcore.oo()), content="oo")
  inspect(core_expr_sstr(@symcore.zoo()), content="zoo")
  inspect(core_expr_sstr(@symcore.nan_expr()), content="nan")
}

///|
test "symcore parity dummy wild and undefined-function heads" {
  inspect(core_expr_sstr(@symcore.dummy(name="x")), content="_x")
  inspect(core_expr_sstr(@symcore.wild("x")), content="x_")
  inspect(core_expr_sstr(@symcore.undefined_function("f")), content="f")
  inspect(
    core_expr_sstr(@symcore.function("f", [@symcore.symbol("x")])),
    content="f(x)",
  )
}

///|
test "symcore parity dict and tuple containers" {
  inspect(
    core_expr_sstr(@symcore.tuple_expr([@symcore.symbol("x"), @symcore.int(2)])),
    content="(x, 2)",
  )
  inspect(
    core_expr_sstr(
      @symcore.dict_expr([
        (@symcore.symbol("x"), @symcore.symbol("y")),
        (@symcore.int(1), @symcore.symbol("z")),
      ]),
    ),
    content="{1: z, x: y}",
  )
}

///|
test "symcore parity sympify typed inputs" {
  inspect(
    core_expr_sstr(
      @symcore.sympify_tuple([
        @symcore.sympify_int_input(1),
        @symcore.sympify_symbol_input("x"),
      ]),
    ),
    content="(1, x)",
  )
  inspect(
    core_expr_sstr(
      @symcore.sympify_dict([
        (@symcore.sympify_symbol_input("x"), @symcore.sympify_int_input(2)),
      ]),
    ),
    content="{x: 2}",
  )
}
