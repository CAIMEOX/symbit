///|
test "physics.quantum.hilbert: spaces and dimensions" {
  let hs = hilbert_space()
  inspect(Show::to_string(hs), content="H")
  inspect(hs.repr(), content="HilbertSpace()")

  let c2 = complex_space(@symcore.int(2))
  inspect(Show::to_string(c2), content="C(2)")
  inspect(c2.repr(), content="ComplexSpace(Integer(2))")
  inspect(@symprint.pretty_string(c2.dimension()), content="2")

  let n = @symcore.Expr::Symbol("n")
  let cn = complex_space(n)
  inspect(cn.repr(), content="ComplexSpace(Symbol('n'))")
  inspect(@symprint.pretty_string(cn.dimension()), content="n")

  let l2s = l2_space(interval(@symcore.int(0), NumberSymbol(Infinity)))
  inspect(Show::to_string(l2s), content="L2(Interval(0, oo))")
  inspect(@symprint.pretty_string(l2s.dimension()), content="oo")

  let f = fock_space()
  inspect(Show::to_string(f), content="F")

  let prod = tensor_product_space([c2, cn])
  inspect(Show::to_string(prod), content="C(2)*C(n)")
  inspect(@symprint.pretty_string(prod.dimension()), content="2*n")

  let sum = direct_sum_space([c2, f, cn])
  inspect(Show::to_string(sum), content="C(2)+F+C(n)")
  inspect(@symprint.pretty_string(sum.dimension()), content="oo")

  let pow = tensor_power(cn, @symcore.int(2))
  inspect(Show::to_string(pow), content="C(n)**2")
  inspect(@symprint.pretty_string(pow.dimension()), content="n**2")
}
