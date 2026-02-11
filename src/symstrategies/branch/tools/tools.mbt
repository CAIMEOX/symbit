///|\
/// Branching tools.

///|
/// Strategy for canonicalization with branching rules.
pub fn canon(
  rules : Array[@branch_core.BRule[@symcore.Expr]],
) -> @branch_core.BRule[@symcore.Expr] {
  let tops : Array[@branch_core.BRule[@symcore.Expr]] = rules.map(rl => {
    @branch_traverse.top_down(rl)
  })
  @branch_core.exhaust(@branch_core.multiplex(tops))
}
