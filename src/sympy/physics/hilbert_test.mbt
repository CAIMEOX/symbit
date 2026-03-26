///|
test "physics.quantum.hilbert: spaces and dimensions" {
  let hs = hilbert_space()
  inspect(hs.to_string(), content="H")
  inspect(hs.repr(), content="HilbertSpace()")

  let c2 = complex_space(@symcore.int(2))
  inspect(c2.to_string(), content="C(2)")
  inspect(c2.repr(), content="ComplexSpace(Integer(2))")
  inspect(@symprint.to_string(c2.dimension()), content="2")

  let n = @symcore.Expr::Symbol("n")
  let cn = complex_space(n)
  inspect(cn.repr(), content="ComplexSpace(Symbol('n'))")
  inspect(@symprint.to_string(cn.dimension()), content="n")

  let l2s = l2_space(interval(@symcore.int(0), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)))
  inspect(l2s.to_string(), content="L2(Interval(0, oo))")
  inspect(@symprint.to_string(l2s.dimension()), content="oo")

  let f = fock_space()
  inspect(f.to_string(), content="F")

  let prod = tensor_product_space([c2, cn])
  inspect(prod.to_string(), content="C(2)*C(n)")
  inspect(@symprint.to_string(prod.dimension()), content="2*n")

  let sum = direct_sum_space([c2, f, cn])
  inspect(sum.to_string(), content="C(2)+F+C(n)")
  inspect(@symprint.to_string(sum.dimension()), content="oo")

  let pow = tensor_power(cn, @symcore.int(2))
  inspect(pow.to_string(), content="C(n)**2")
  inspect(@symprint.to_string(pow.dimension()), content="n**2")
}
