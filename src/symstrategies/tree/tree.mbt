///|\
/// Strategy trees (SymPy strategies.tree port).

///|
pub(all) enum Tree[T] {
  Leaf(T)
  Choice(Array[Tree[T]])
  Seq(Array[Tree[T]])
}

///|
pub(all) struct TreeJoin[T] {
  choice : (Array[T]) -> T
  seq : (Array[T]) -> T
}

///|
/// Apply functions onto recursive containers (tree).
fn[A, B] treeapply_map(
  tree : Tree[A],
  join : TreeJoin[B],
  leaf : (A) -> B,
) -> B {
  match tree {
    Tree::Leaf(v) => leaf(v)
    Tree::Choice(items) => {
      let mapped : Array[B] = items.map(item => treeapply_map(item, join, leaf))
      (join.choice)(mapped)
    }
    Tree::Seq(items) => {
      let mapped : Array[B] = items.map(item => treeapply_map(item, join, leaf))
      (join.seq)(mapped)
    }
  }
}

///|
/// Apply functions onto recursive containers (tree).
pub fn[T] treeapply(
  tree : Tree[T],
  join : TreeJoin[T],
  leaf? : (T) -> T = @strategies_core.identity,
) -> T {
  treeapply_map(tree, join, leaf)
}

///|
/// Execute a strategic tree; select alternatives greedily.
pub fn[T : Compare] greedy(
  tree : Tree[(T) -> T],
  objective? : (T) -> T = @strategies_core.identity,
) -> (T) -> T {
  let join : TreeJoin[(T) -> T] = {
    choice: (rules) => @strategies_core.minimize(rules, objective~),
    seq: (rules) => @strategies_core.chain(rules),
  }
  treeapply(tree, join)
}

///|
/// Execute a strategic tree; return all possibilities.
pub fn[T : Eq + Hash] allresults(
  tree : Tree[(T) -> T],
  leaf? : ((T) -> T) -> (T) -> Array[T] = @strategies_branch.yieldify,
) -> (T) -> Array[T] {
  let join : TreeJoin[(T) -> Array[T]] = {
    choice: (rules) => @strategies_branch.multiplex(rules),
    seq: (rules) => @strategies_branch.chain(rules),
  }
  treeapply_map(tree, join, leaf)
}

///|
/// Brute-force over all results and select the minimum by objective.
pub fn[T : Compare + Eq + Hash] brute(
  tree : Tree[(T) -> T],
  objective? : (T) -> T = @strategies_core.identity,
) -> (T) -> T {
  (expr : T) => {
    let results = allresults(tree)(expr)
    if results.is_empty() {
      return expr
    }
    let mut best = results[0]
    let mut best_key = objective(best)
    for i in 1..<results.length() {
      let cand = results[i]
      let cand_key = objective(cand)
      if cand_key.compare(best_key) < 0 {
        best = cand
        best_key = cand_key
      }
    }
    best
  }
}

///|
/// Convert a rule into a branching rule (re-export).
pub fn[T] yieldify(rule : (T) -> T) -> (T) -> Array[T] {
  @strategies_branch.yieldify(rule)
}

///|
/// Partial application for 2-arg functions.
pub fn[A, B, C] partial(f : (A, B) -> C, a : A) -> (B) -> C {
  (b : B) => f(a, b)
}
