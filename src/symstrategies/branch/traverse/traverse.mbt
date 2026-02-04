///|\
/// Branching strategies to traverse a tree.

///|
/// Apply a rule down a tree running it on the top nodes first.
pub fn top_down(
  brule : @branch_core.BRule[@symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> @branch_core.BRule[@symcore.Expr] {
  @branch_core.chain([
    @branch_core.do_one([brule, @branch_core.identity]),
    (expr : @symcore.Expr) => sall(top_down(brule, fns~), fns~)(expr),
  ])
}

///|
/// Strategic all - apply rule to args.
pub fn sall(
  brule : @branch_core.BRule[@symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> @branch_core.BRule[@symcore.Expr] {
  let op = fns.op
  let new = fns.new
  let children = fns.children
  let leaf = fns.leaf
  (expr : @symcore.Expr) => {
    if leaf(expr) {
      return [expr]
    }
    let child_results : Array[Array[@symcore.Expr]] = Array::new()
    for child in children(expr) {
      child_results.push(brule(child))
    }
    let combos = product(child_results)
    let out : Array[@symcore.Expr] = Array::new()
    for args in combos {
      out.push(new(op(expr), args))
    }
    out
  }
}

///|
/// Cartesian product of arrays.
fn[T] product(lists : Array[Array[T]]) -> Array[Array[T]] {
  if lists.is_empty() {
    return [[]]
  }
  let mut res : Array[Array[T]] = [[]]
  for items in lists {
    let next : Array[Array[T]] = Array::new()
    for prefix in res {
      for item in items {
        let merged : Array[T] = Array::new()
        for v in prefix {
          merged.push(v)
        }
        merged.push(item)
        next.push(merged)
      }
    }
    res = next
  }
  res
}
