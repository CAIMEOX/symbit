///|
/// - Does: Stores the replacements and reduced expressions produced by common-subexpression elimination.
/// - Input: Constructed internally from `Array[(String, Expr)]` and `Array[Expr]`.
/// - Returns: One `CseResult` value.
/// - Limits: Replacement names are generated placeholders and are not stable across algorithm changes.
pub(all) struct CseResult {
  replacements : Array[(String, Expr)]
  reduced_exprs : Array[Expr]
}

///|
/// - Does: Reports how many substitutions were extracted by CSE.
/// - Input: One `CseResult`.
/// - Returns: `Int`.
/// - Limits: Counts only stored replacements and does not inspect reduced expressions again.
pub fn CseResult::replacement_count(self : CseResult) -> Int {
  self.replacements.length()
}

///|
/// - Does: Returns a defensive copy of the extracted substitution list.
/// - Input: One `CseResult`.
/// - Returns: `Array[(String, Expr)]`.
/// - Limits: Names stay in generated placeholder form and are not re-simplified.
pub fn CseResult::replacements_copy(self : CseResult) -> Array[(String, Expr)] {
  self.replacements.map(item => item)
}

///|
/// - Does: Returns a defensive copy of the reduced expressions after extraction.
/// - Input: One `CseResult`.
/// - Returns: `Array[Expr]`.
/// - Limits: Returned expressions still reference the generated replacement names.
pub fn CseResult::reduced_exprs_copy(self : CseResult) -> Array[Expr] {
  self.reduced_exprs.map(item => item)
}

///|
/// - Does: Performs common-subexpression elimination on one list of expressions.
/// - Input: `Array[Expr]` plus optional `min_nodes`.
/// - Returns: One `CseResult`.
/// - Limits: Uses exact-structure matching and generated placeholder names, so algebraically equivalent but structurally different subtrees are not merged.
pub fn cse(exprs : Array[Expr], min_nodes? : Int = 2) -> CseResult {
  let counts : Map[String, Int] = Map([])
  let key_expr : Map[String, Expr] = Map([])
  for expr in exprs {
    collect_counts(expr, counts, key_expr)
  }
  let candidates : Array[CseCandidate] = Array::new()
  for key, count in counts {
    if count <= 1 {
      continue
    }
    match key_expr.get(key) {
      Some(expr) => {
        let sz = node_count(expr)
        if sz >= min_nodes {
          candidates.push({ key, expr, size: sz })
        }
      }
      None => ()
    }
  }
  sort_candidates(candidates)

  let mut reduced = exprs.map(e => e)
  let replacements : Array[(String, Expr)] = Array::new()
  let mut idx = 0
  for candidate in candidates {
    let occ = total_occurrences(reduced, candidate.key)
    if occ <= 1 {
      continue
    }
    let sym_name = "x\{idx}"
    let sym_expr = Expr::Symbol(sym_name)
    let rhs = candidate.expr
    let next_reduced : Array[Expr] = Array::new()
    for expr in reduced {
      next_reduced.push(replace_exact(expr, candidate.key, sym_expr))
    }
    reduced = next_reduced
    replacements.push((sym_name, rhs))
    idx = idx + 1
  }
  { replacements, reduced_exprs: reduced }
}

///|
/// - Does: Reconstructs full expressions by substituting CSE replacements back into the reduced outputs.
/// - Input: One `CseResult`.
/// - Returns: `Array[Expr]`.
/// - Limits: Assumes the replacement list came from `cse`; malformed external data can reconstruct to nonsensical expressions.
pub fn cse_reconstruct(result : CseResult) -> Array[Expr] {
  let mut out = result.reduced_exprs.map(e => e)
  for i in 0..<result.replacements.length() {
    let idx = result.replacements.length() - 1 - i
    let (name, rhs) = result.replacements[idx]
    let env : Map[String, Expr] = Map([])
    env[name] = rhs
    out = out.map(expr => @symcore.subst(expr, env))
  }
  out
}

///|
priv struct CseCandidate {
  key : String
  expr : Expr
  size : Int
}

///|
fn sort_candidates(items : Array[CseCandidate]) -> Unit {
  for i in 0..<items.length() {
    let mut best = i
    for j in (i + 1)..<items.length() {
      let lhs = items[j]
      let rhs = items[best]
      let better = if lhs.size != rhs.size {
        lhs.size > rhs.size
      } else {
        lhs.key.compare(rhs.key) < 0
      }
      if better {
        best = j
      }
    }
    if best != i {
      items.swap(i, best)
    }
  }
}

///|
fn collect_counts(
  expr : Expr,
  counts : Map[String, Int],
  key_expr : Map[String, Expr],
) -> Unit {
  if is_atom(expr) {
    return
  }
  let key = Repr(expr).to_string()
  match counts.get(key) {
    Some(c) => counts[key] = c + 1
    None => {
      counts[key] = 1
      key_expr[key] = expr
    }
  }
  for child in @symcore.children(expr) {
    collect_counts(child, counts, key_expr)
  }
}

///|
fn is_atom(expr : Expr) -> Bool {
  match expr {
    Number(_) | Symbol(_) => true
    _ => false
  }
}

///|
fn node_count(expr : Expr) -> Int {
  let mut total = 1
  for child in @symcore.children(expr) {
    total = total + node_count(child)
  }
  total
}

///|
fn total_occurrences(exprs : Array[Expr], key : String) -> Int {
  let mut total = 0
  for expr in exprs {
    total = total + count_occurrences(expr, key)
  }
  total
}

///|
fn count_occurrences(expr : Expr, key : String) -> Int {
  let mut total = if Repr(expr).to_string() == key { 1 } else { 0 }
  for child in @symcore.children(expr) {
    total = total + count_occurrences(child, key)
  }
  total
}

///|
fn replace_exact(expr : Expr, key : String, replacement : Expr) -> Expr {
  if Repr(expr).to_string() == key {
    return replacement
  }
  @symcore.map_children(expr, child => replace_exact(child, key, replacement))
}
