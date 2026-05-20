///|
test "sympolys monomial frontdoors enumerate total and bounded degrees" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let total = itermonomials([x, y], 2).map(item => @symprint.pretty_string(item))
  total.sort()
  inspect(
    total.join(" | "),
    content=(
      #|1 | x | y | x*y | x**2 | y**2
    ),
  )
  let bounded = itermonomials_bounded([x, y], [2, 3], min_degrees=[1, 2]).map(item => {
    @symprint.pretty_string(item)
  })
  bounded.sort()
  inspect(
    bounded.join(" | "),
    content=(
      #|x*y**2 | x*y**3 | x**2*y**2 | x**2*y**3
    ),
  )
  let a = monomial_from_array([3, 4, 1])
  let b = monomial_from_array([1, 2, 2])
  inspect(monomial_ldiv(a, b).to_array(), content="[2, 2, -1]")
  inspect(monomial_deg(a), content="8")
  match
    term_div(
      (monomial_from_array([3, 2]), fe_from_int(6, Domain::ZZ)),
      (monomial_from_array([1, 1]), fe_from_int(3, Domain::ZZ)),
      Domain::ZZ,
    ) {
    Some((m, c)) => {
      inspect(m.to_array(), content="[2, 1]")
      inspect(c, content="2")
    }
    None => fail("expected exact term division")
  }
}

///|
test "sympolys special polynomial frontdoors build exact expressions" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  inspect(
    @symprint.pretty_string(cyclotomic_poly(5)),
    content=(
      #|x**2 + x**3 + x**4 + x + 1
    ),
  )
  inspect(
    @symprint.pretty_string(swinnerton_dyer_poly(2)),
    content=(
      #|x**4 - 10*x**2 + 1
    ),
  )
  inspect(
    @symprint.pretty_string(symmetric_poly(2, [x, y, z])),
    content=(
      #|x*y + x*z + y*z
    ),
  )
  inspect(
    @symprint.pretty_string(
      interpolating_poly(2, x, xs=[int(0), int(1)], ys=[int(1), int(3)]),
    ),
    content=(
      #|(x - 1)/-1 + 3*x
    ),
  )
  inspect(
    @symprint.pretty_string(random_poly("x", 3, -2, 2, seed=7)),
    content=(
      #|x**2 - x**3 - x - 2
    ),
  )
}

///|
test "sympolys special polynomial Fateman benchmark frontdoors" {
  let (_, _, h1) = fateman_poly_F_1(1)
  inspect(@symprint.pretty_string(h1.to_expr()), content="1")
  let (_, _, h2) = fateman_poly_F_2(2)
  inspect(
    @symprint.pretty_string(h2.to_expr()).contains("y_0**2"),
    content="true",
  )
  let (f3, g3, h3) = fateman_poly_F_3(2)
  inspect(f3.gens.length(), content="3")
  inspect(g3.gens.length(), content="3")
  inspect(h3.gens.length(), content="3")
}
