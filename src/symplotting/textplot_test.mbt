///|
fn joined_lines(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
test "symplotting textplot matches SymPy axis alignment defaults" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                                                     ..", "        |                                                  ...  ",
    "        |                                                ..     ", "        |                                             ...       ",
    "        |                                          ...          ", "        |                                        ..             ",
    "        |                                     ...               ", "        |                                  ...                  ",
    "        |                                ..                     ", "        |                             ...                       ",
    "      0 |--------------------------...--------------------------", "        |                       ...                             ",
    "        |                     ..                                ", "        |                  ...                                  ",
    "        |               ...                                     ", "        |             ..                                        ",
    "        |          ...                                          ", "        |       ...                                             ",
    "        |     ..                                                ", "        |  ...                                                  ",
    "     -1 |_______________________________________________________", "         -1                         0                          1",
  ]
  assert_true(
    joined_lines(textplot_str(x, @symcore.int(-1), @symcore.int(1))) ==
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy custom height axis alignment" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                                                     ..", "        |                                                 ....  ",
    "        |                                              ...      ", "        |                                           ...         ",
    "        |                                       ....            ", "        |                                    ...                ",
    "        |                                 ...                   ", "        |                             ....                      ",
    "      0 |--------------------------...--------------------------", "        |                      ....                             ",
    "        |                   ...                                 ", "        |                ...                                    ",
    "        |            ....                                       ", "        |         ...                                           ",
    "        |      ...                                              ", "        |  ....                                                 ",
    "     -1 |_______________________________________________________", "         -1                         0                          1",
  ]
  assert_true(
    joined_lines(textplot_str(x, @symcore.int(-1), @symcore.int(1), height=17)) ==
    joined_lines(expected),
  )
}

///|
test "symplotting textplot handles purely imaginary constants like SymPy" {
  let imag = @symcore.Expr::NumberSymbol(ImaginaryUnit)
  let expected = [
    "      1 |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "      0 |-------------------------------------------------------", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "     -1 |_______________________________________________________", "         -1                         0                          1",
  ]
  assert_true(
    joined_lines(textplot_str(imag, @symcore.int(-1), @symcore.int(1))) ==
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for 1/x singularity" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "     54 | .                                                     ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "   27.5 |--.----------------------------------------------------", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "        |   .                                                   ", "        |    \\                                                  ",
    "        |     \\                                                 ", "        |      ..                                               ",
    "        |        ...                                            ", "        |           .............                               ",
    "      1 |_______________________________________________________", "         0                          0.5                        1",
  ]
  let expr = @symcore.mul([@symcore.int(1), @symcore.pow(x, @symcore.int(-1))])
  assert_true(
    joined_lines(textplot_str(expr, @symcore.int(0), @symcore.int(1))) ==
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for log singularity" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      0 |                                                 ......", "        |                                         ........      ",
    "        |                                 ........              ", "        |                           ......                      ",
    "        |                      .....                            ", "        |                  ....                                 ",
    "        |               ...                                     ", "        |             ..                                        ",
    "        |          ...                                          ", "        |         /                                             ",
    "     -2 |-------..----------------------------------------------", "        |      /                                                ",
    "        |     /                                                 ", "        |    /                                                  ",
    "        |   .                                                   ", "        |                                                       ",
    "        |  .                                                    ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "     -4 |_______________________________________________________", "         0                          0.5                        1",
  ]
  let expr = @symcore.function("log", [x])
  assert_true(
    joined_lines(textplot_str(expr, @symcore.int(0), @symcore.int(1))) ==
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for sinc shape" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                          . .                          ", "        |                         .   .                         ",
    "        |                                                       ", "        |                        .     .                        ",
    "        |                                                       ", "        |                       .       .                       ",
    "        |                                                       ", "        |                                                       ",
    "        |                      .         .                      ", "        |                                                       ",
    "    0.4 |-------------------------------------------------------", "        |                     .           .                     ",
    "        |                                                       ", "        |                    .             .                    ",
    "        |                                                       ", "        |    .....                                     .....    ",
    "        |  ..     \\         .               .         /     ..  ", "        | /        \\                                 /        \\ ",
    "        |/          \\      .                 .      /          \\", "        |            \\    /                   \\    /            ",
    "   -0.2 |_______________________________________________________", "         -10                        0                          10",
  ]
  let expr = @symcore.mul([
    @symcore.function("sin", [x]),
    @symcore.pow(x, @symcore.int(-1)),
  ])
  assert_true(
    joined_lines(textplot_str(expr, @symcore.int(-10), @symcore.int(10))) ==
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for sqrt branch over reals" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                                                     ..", "        |                                                   ..  ",
    "        |                                                ...    ", "        |                                              ..       ",
    "        |                                            ..         ", "        |                                          ..           ",
    "        |                                        ..             ", "        |                                      ..               ",
    "        |                                    ..                 ", "        |                                   /                   ",
    "    0.5 |----------------------------------/--------------------", "        |                                ..                     ",
    "        |                               /                       ", "        |                              .                        ",
    "        |                                                       ", "        |                             .                         ",
    "        |                            .                          ", "        |                                                       ",
    "        |                                                       ", "        |                                                       ",
    "      0 |_______________________________________________________", "         -1                         0                          1",
  ]
  let expr = @symcore.function("sqrt", [x])
  assert_true(
    joined_lines(textplot_str(expr, @symcore.int(-1), @symcore.int(1))) ==
    joined_lines(expected),
  )
}

///|
test "symplotting textplot rejects expressions with more than one free symbol" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  ignore(
    try {
      ignore(
        textplot_str(@symcore.add([x, y]), @symcore.int(-1), @symcore.int(1)),
      )
      fail("expected multi-variable error")
    } catch {
      PlottingError::ValueError(message) =>
        assert_true(
          message.contains("The expression must have a single variable."),
        )
      _ => fail("unexpected error")
    },
  )
}

///|
test "symplotting textplot rejects non-real numeric bounds" {
  let x = @symcore.Expr::Symbol("x")
  let imag = @symcore.Expr::NumberSymbol(ImaginaryUnit)
  ignore(
    try {
      ignore(textplot_str(x, imag, @symcore.int(1)))
      fail("expected bounds error")
    } catch {
      PlottingError::ValueError(message) =>
        inspect(
          message,
          content="textplot bounds must be real numeric expressions",
        )
      _ => fail("unexpected error")
    },
  )
}
