///|
fn sq_adv_assert_expr_oracle(
  expr : @symcore.Expr,
  oracle_expr : String,
  _context : String,
) -> Unit raise {
  let ours = try! @sympy_physics.secondquant_eval_str(@symprint.to_string(expr))
  let expected = try! @sympy_physics.secondquant_exec_str(oracle_expr)
  assert_eq(ours, expected)
}

///|
test "physics.secondquant: fermion constructors and operator application" {
  let p = @symcore.symbol("p")
  let q = @symcore.symbol("q")
  let a = @symcore.symbol("a")
  let i = @symcore.symbol("i")

  inspect(fermion_annihilator(p).to_string(), content="f(p)")
  inspect(fermion_creator(q).to_string(), content="f+(q)")
  inspect(
    @symprint.to_string(secondquant_dagger(f(p))),
    content="CreateFermion(p)",
  )
  inspect(
    @symprint.to_string(
      secondquant_dagger(fket([@symcore.int(1), @symcore.int(2)])),
    ),
    content="FockStateFermionBra(Tuple(1, 2))",
  )

  sq_adv_assert_expr_oracle(
    secondquant_apply_operators(
      @symcore.raw_mul([
        f(@symcore.int(1)),
        fket([@symcore.int(1), @symcore.int(2)]),
      ]),
    ),
    "apply_operators(F(1)*FKet([1, 2]))",
    "fermion annihilate occupied state",
  )
  sq_adv_assert_expr_oracle(
    secondquant_apply_operators(
      @symcore.raw_mul([
        f(@symcore.int(2)),
        fket([@symcore.int(1), @symcore.int(2)]),
      ]),
    ),
    "apply_operators(F(2)*FKet([1, 2]))",
    "fermion annihilate second occupied state",
  )
  sq_adv_assert_expr_oracle(
    secondquant_apply_operators(
      @symcore.raw_mul([
        fd(@symcore.int(3)),
        fket([@symcore.int(1), @symcore.int(2)]),
      ]),
    ),
    "apply_operators(Fd(3)*FKet([1, 2]))",
    "fermion create new occupied state",
  )
  sq_adv_assert_expr_oracle(
    secondquant_apply_operators(@symcore.raw_mul([fd(p), fket([q])])),
    "apply_operators(Fd(p)*FKet([q]))",
    "fermion create symbolic state",
  )
  sq_adv_assert_expr_oracle(
    secondquant_apply_operators(@symcore.raw_mul([fd(a), fket([])])),
    "apply_operators(Fd(a)*FKet([]))",
    "fermion create restricted symbolic state stays conservative",
  )
  sq_adv_assert_expr_oracle(
    secondquant_apply_operators(@symcore.raw_mul([f(i), fket([])])),
    "apply_operators(F(i)*FKet([]))",
    "fermion annihilate restricted symbolic state stays conservative",
  )
  sq_adv_assert_expr_oracle(
    secondquant_inner_product(fbra([p, q]), fket([p, q])),
    "InnerProduct(FBra([p, q]), FKet([p, q]))",
    "fermion tuple inner product",
  )
}

///|
test "physics.secondquant: tensors and antisymmetry" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let i = @symcore.symbol("i")
  let j = @symcore.symbol("j")
  inspect(
    @symprint.to_string(tensor_symbol(@symcore.symbol("T"))),
    content="TensorSymbol(T)",
  )
  sq_adv_assert_expr_oracle(
    anti_symmetric_tensor(@symcore.symbol("v"), [b, a], [j, i]),
    "AntiSymmetricTensor(v, (b, a), (j, i))",
    "antisymmetric tensor canonicalization",
  )
}

///|
test "physics.secondquant: normal ordering, contraction, deltas, and permutations" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let i = @symcore.symbol("i")
  let j = @symcore.symbol("j")
  let p = @symcore.symbol("p")
  let q = @symcore.symbol("q")

  sq_adv_assert_expr_oracle(
    no(@symcore.raw_mul([f(q), fd(p)])),
    "NO(F(q)*Fd(p))",
    "NO fermion reorder",
  )
  sq_adv_assert_expr_oracle(
    contraction(f(a), fd(b)),
    "contraction(F(a), Fd(b))",
    "particle contraction",
  )
  sq_adv_assert_expr_oracle(
    contraction(fd(i), f(j)),
    "contraction(Fd(i), F(j))",
    "hole contraction",
  )
  sq_adv_assert_expr_oracle(
    contraction(f(p), fd(q)),
    "contraction(F(p), Fd(q))",
    "general contraction",
  )
  sq_adv_assert_expr_oracle(
    secondquant_evaluate_deltas(
      @symcore.raw_mul([
        @symcore.raw_function("KroneckerDelta", [i, p]),
        @symcore.raw_function("T", [p, q]),
      ]),
    ),
    "evaluate_deltas(KroneckerDelta(i, p)*T(p, q))",
    "delta evaluation",
  )
  sq_adv_assert_expr_oracle(
    secondquant_wicks(
      @symcore.raw_mul([
        fd(p),
        @symcore.raw_add([f(q), f(@symcore.symbol("r"))]),
      ]),
    ),
    "wicks(Fd(p)*(F(q) + F(r)))",
    "wicks additive expansion",
  )
  sq_adv_assert_expr_oracle(
    secondquant_simplify_index_permutations(
      @symcore.raw_add([
        @symcore.raw_mul([
          @symcore.raw_function("f", [p]),
          @symcore.raw_function("g", [q]),
        ]),
        @symcore.int(-1) *
        @symcore.raw_mul([
          @symcore.raw_function("f", [q]),
          @symcore.raw_function("g", [p]),
        ]),
      ]),
      [secondquant_permutation_operator(p, q)],
    ),
    "simplify_index_permutations(f(p)*g(q) - f(q)*g(p), [PermutationOperator(p, q)])",
    "permutation simplification",
  )
}
