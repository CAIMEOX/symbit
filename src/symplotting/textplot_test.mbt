///|
fn joined_lines(lines : Array[String]) -> String {
  lines.join("\n")
}

///|
test "symplotting textplot matches SymPy axis alignment defaults" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                                                     ..",
    "        |                                                  ...  ",
    "        |                                                ..     ",
    "        |                                             ...       ",
    "        |                                          ...          ",
    "        |                                        ..             ",
    "        |                                     ...               ",
    "        |                                  ...                  ",
    "        |                                ..                     ",
    "        |                             ...                       ",
    "      0 |--------------------------...--------------------------",
    "        |                       ...                             ",
    "        |                     ..                                ",
    "        |                  ...                                  ",
    "        |               ...                                     ",
    "        |             ..                                        ",
    "        |          ...                                          ",
    "        |       ...                                             ",
    "        |     ..                                                ",
    "        |  ...                                                  ",
    "     -1 |_______________________________________________________",
    "         -1                         0                          1",
  ]
  assert_eq(joined_lines(textplot_str(x, @symcore.int(-1), @symcore.int(1))), joined_lines(expected))
}

///|
test "symplotting textplot matches SymPy custom height axis alignment" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                                                     ..",
    "        |                                                 ....  ",
    "        |                                              ...      ",
    "        |                                           ...         ",
    "        |                                       ....            ",
    "        |                                    ...                ",
    "        |                                 ...                   ",
    "        |                             ....                      ",
    "      0 |--------------------------...--------------------------",
    "        |                      ....                             ",
    "        |                   ...                                 ",
    "        |                ...                                    ",
    "        |            ....                                       ",
    "        |         ...                                           ",
    "        |      ...                                              ",
    "        |  ....                                                 ",
    "     -1 |_______________________________________________________",
    "         -1                         0                          1",
  ]
  assert_eq(
    joined_lines(textplot_str(x, @symcore.int(-1), @symcore.int(1), height=17)),
    joined_lines(expected),
  )
}

///|
test "symplotting textplot handles purely imaginary constants like SymPy" {
  let imag = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let expected = [
    "      1 |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "      0 |-------------------------------------------------------",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "     -1 |_______________________________________________________",
    "         -1                         0                          1",
  ]
  assert_eq(
    joined_lines(textplot_str(imag, @symcore.int(-1), @symcore.int(1))),
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for 1/x singularity" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "     54 | .                                                     ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "   27.5 |--.----------------------------------------------------",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |   .                                                   ",
    "        |    \\                                                  ",
    "        |     \\                                                 ",
    "        |      ..                                               ",
    "        |        ...                                            ",
    "        |           .............                               ",
    "      1 |_______________________________________________________",
    "         0                          0.5                        1",
  ]
  let expr = @symcore.mul([@symcore.int(1), @symcore.pow(x, @symcore.int(-1))])
  assert_eq(
    joined_lines(textplot_str(expr, @symcore.int(0), @symcore.int(1))),
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for log singularity" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      0 |                                                 ......",
    "        |                                         ........      ",
    "        |                                 ........              ",
    "        |                           ......                      ",
    "        |                      .....                            ",
    "        |                  ....                                 ",
    "        |               ...                                     ",
    "        |             ..                                        ",
    "        |          ...                                          ",
    "        |         /                                             ",
    "     -2 |-------..----------------------------------------------",
    "        |      /                                                ",
    "        |     /                                                 ",
    "        |    /                                                  ",
    "        |   .                                                   ",
    "        |                                                       ",
    "        |  .                                                    ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "     -4 |_______________________________________________________",
    "         0                          0.5                        1",
  ]
  let expr = @symcore.function("log", [x])
  assert_eq(
    joined_lines(textplot_str(expr, @symcore.int(0), @symcore.int(1))),
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for sinc shape" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                          . .                          ",
    "        |                         .   .                         ",
    "        |                                                       ",
    "        |                        .     .                        ",
    "        |                                                       ",
    "        |                       .       .                       ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                      .         .                      ",
    "        |                                                       ",
    "    0.4 |-------------------------------------------------------",
    "        |                     .           .                     ",
    "        |                                                       ",
    "        |                    .             .                    ",
    "        |                                                       ",
    "        |    .....                                     .....    ",
    "        |  ..     \\         .               .         /     ..  ",
    "        | /        \\                                 /        \\ ",
    "        |/          \\      .                 .      /          \\",
    "        |            \\    /                   \\    /            ",
    "   -0.2 |_______________________________________________________",
    "         -10                        0                          10",
  ]
  let expr = @symcore.mul([@symcore.function("sin", [x]), @symcore.pow(x, @symcore.int(-1))])
  assert_eq(
    joined_lines(textplot_str(expr, @symcore.int(-10), @symcore.int(10))),
    joined_lines(expected),
  )
}

///|
test "symplotting textplot matches SymPy for sqrt branch over reals" {
  let x = @symcore.Expr::Symbol("x")
  let expected = [
    "      1 |                                                     ..",
    "        |                                                   ..  ",
    "        |                                                ...    ",
    "        |                                              ..       ",
    "        |                                            ..         ",
    "        |                                          ..           ",
    "        |                                        ..             ",
    "        |                                      ..               ",
    "        |                                    ..                 ",
    "        |                                   /                   ",
    "    0.5 |----------------------------------/--------------------",
    "        |                                ..                     ",
    "        |                               /                       ",
    "        |                              .                        ",
    "        |                                                       ",
    "        |                             .                         ",
    "        |                            .                          ",
    "        |                                                       ",
    "        |                                                       ",
    "        |                                                       ",
    "      0 |_______________________________________________________",
    "         -1                         0                          1",
  ]
  let expr = @symcore.function("sqrt", [x])
  assert_eq(
    joined_lines(textplot_str(expr, @symcore.int(-1), @symcore.int(1))),
    joined_lines(expected),
  )
}
