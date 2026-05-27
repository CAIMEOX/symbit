///|
test "sqf_norm frontdoor: univariate algebraic extension shift" {
  let x = Expr::Symbol("x")
  let a = Expr::Symbol("a")
  let rel = (a ^ int(2)) - int(3)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let poly = PolyBuilder::new(["x"], alg_domain).from_expr(
    (x ^ int(2)) - int(2),
  )
  let (shifts, shifted, norm) = sqf_norm(poly)
  debug_inspect(shifts, content="[1]")
  inspect(
    shifted,
    content=(
      #|x**2 - 2*a*x + 1
    ),
  )
  inspect(
    norm,
    content=(
      #|x**4 - 10*x**2 + 1
    ),
  )
}
