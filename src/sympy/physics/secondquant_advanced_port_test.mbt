///|
fn sq_adv_assert_port(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = secondquant_eval_str(@symprint.pretty_string(lhs))
  let expected = secondquant_exec_str(rhs)
  assert_eq(ours, expected)
}

///|
test "physics.secondquant: advanced parity" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let i = @symcore.Expr::Symbol("i")
  let j = @symcore.Expr::Symbol("j")
  let p = @symcore.Expr::Symbol("p")
  let q = @symcore.Expr::Symbol("q")
  let r = @symcore.Expr::Symbol("r")

  sq_adv_assert_port(fket([p, q]), "FKet([p, q])", "fermion ket parity")
  sq_adv_assert_port(fbra([p, q]), "FBra([p, q])", "fermion bra parity")
  sq_adv_assert_port(
    secondquant_apply_operators(@symcore.raw_mul([fd(p), fket([q])])),
    "apply_operators(Fd(p)*FKet([q]))",
    "fermion apply parity",
  )
  sq_adv_assert_port(
    secondquant_no(@symcore.raw_mul([f(q), fd(p)])),
    "NO(F(q)*Fd(p))",
    "NO parity",
  )
  sq_adv_assert_port(
    secondquant_wicks(@symcore.raw_mul([fd(p), f(q)])),
    "wicks(Fd(p)*F(q))",
    "wicks parity",
  )
  sq_adv_assert_port(
    secondquant_wicks(
      @symcore.raw_mul([f(p), fd(q)]),
      keep_only_fully_contracted=true,
    ),
    "wicks(F(p)*Fd(q), keep_only_fully_contracted=True)",
    "wicks fully contracted parity",
  )
  sq_adv_assert_port(
    secondquant_wicks(@symcore.raw_mul([fd(p), @symcore.raw_add([f(q), f(r)])])),
    "wicks(Fd(p)*(F(q) + F(r)))",
    "wicks additive parity",
  )
  sq_adv_assert_port(
    secondquant_contraction(f(a), fd(b)),
    "contraction(F(a), Fd(b))",
    "contraction above parity",
  )
  sq_adv_assert_port(
    secondquant_contraction(fd(i), f(j)),
    "contraction(Fd(i), F(j))",
    "contraction below parity",
  )
  sq_adv_assert_port(
    anti_symmetric_tensor(Symbol("v"), [b, a], [j, i]),
    "AntiSymmetricTensor(v, (b, a), (j, i))",
    "antisymmetric tensor parity",
  )
  sq_adv_assert_port(
    secondquant_evaluate_deltas(
      @symcore.raw_mul([
        @symcore.raw_function("KroneckerDelta", [i, p]),
        @symcore.raw_function("T", [p, q]),
      ]),
    ),
    "evaluate_deltas(KroneckerDelta(i, p)*T(p, q))",
    "evaluate deltas parity",
  )
  sq_adv_assert_port(
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
    "permutation parity",
  )
}
