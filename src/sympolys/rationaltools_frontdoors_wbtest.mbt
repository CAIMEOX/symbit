///|
test "rationaltools frontdoors: together combines rational additions" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  inspect(
    @symprint.pretty_string(together((x ^ int(-1)) + (y ^ int(-1)))),
    content=(
      #|(x + y)/(x*y)
    ),
  )
  inspect(
    @symprint.pretty_string(together(((x * y) ^ int(-1)) + (y ^ int(-2)))),
    content=(
      #|(x + y)/(x*y**2)
    ),
  )
  inspect(
    @symprint.pretty_string(
      together((x ^ int(-1)) + (y ^ int(-1)) + (z ^ int(-1))),
    ),
    content=(
      #|(x*y + x*z + y*z)/(x*y*z)
    ),
  )
}

///|
test "rationaltools frontdoors: together deep controls function arguments" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let shallow = together(
    @symcore.function("exp", [(x ^ int(-1)) + (y ^ int(-1))]),
  )
  let deep = together(
    @symcore.function("exp", [(x ^ int(-1)) + (y ^ int(-1))]),
    deep=true,
  )
  inspect(
    @symprint.pretty_string(shallow),
    content=(
      #|exp(x**-1 + y**-1)
    ),
  )
  inspect(
    @symprint.pretty_string(deep),
    content=(
      #|exp((x + y)/(x*y))
    ),
  )
}

///|
test "rationaltools frontdoors: apart decomposes distinct linear factors" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(
    @symprint.pretty_string(
      apart(y * ((x + int(2)) ^ int(-1)) * ((x + int(1)) ^ int(-1)), gen="x"),
    ),
    content=(
      #|y/((x + 1)) - y/((x + 2))
    ),
  )
  inspect(
    @symprint.pretty_string(
      apart(y * (((x ^ int(2)) + x + int(1)) ^ int(-1)), gen="x"),
    ),
    content=(
      #|y/((x**2 + x + 1))
    ),
  )
}

///|
test "rationaltools frontdoors: apart_list assembles back" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let expr = y * ((x + int(2)) ^ int(-1)) * ((x + int(1)) ^ int(-1))
  let listed = apart_list(expr, gen="x")
  inspect(listed.terms.length(), content="2")
  inspect(@symprint.pretty_string(listed.polynomial), content="0")
  inspect(
    @symprint.pretty_string(assemble_partfrac_list(listed)),
    content=(
      #|y/((x + 1)) - y/((x + 2))
    ),
  )
}

///|
test "rationaltools frontdoors: partfrac helper frontdoors" {
  let x = Expr::Symbol("x")
  let builder = PolyBuilder::new(["x"], QQ)
  let p = builder.from_expr(int(1))
  let q = builder.from_expr((x ^ int(2)) - int(1))
  let undetermined = apart_undetermined_coeffs(p, q)
  inspect(
    @symprint.pretty_string(undetermined),
    content=(
      #|1/(2*(x - 1)) - 1/(2*(x + 1))
    ),
  )
  inspect(
    @symprint.pretty_string(apart_full_decomposition(p, q)),
    content=(
      #|1/(2*(x - 1)) - 1/(2*(x + 1))
    ),
  )
  let terms = apart_list_full_decomposition(p, q)
  inspect(terms.length(), content="2")
  let assembled = assemble_partfrac_list({
    common: int(1),
    polynomial: int(0),
    terms,
  })
  inspect(
    @symprint.pretty_string(assembled),
    content=(
      #|(2*x - 2)**-1 - (2*x + 2)**-1
    ),
  )
}
