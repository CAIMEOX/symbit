///|
pub(all) struct CseResult {
  replacements : Array[(String, Expr)]
  reduced_exprs : Array[Expr]
}

///|
/// Return the number of extracted substitutions.
pub fn CseResult::replacement_count(self : CseResult) -> Int {
  self.replacements.length()
}

///|
/// Return a copy of the extracted substitution list.
pub fn CseResult::replacements_copy(self : CseResult) -> Array[(String, Expr)] {
  self.replacements.map(item => item)
}

///|
/// Return a copy of reduced expressions after extraction.
pub fn CseResult::reduced_exprs_copy(self : CseResult) -> Array[Expr] {
  self.reduced_exprs.map(item => item)
}

///|
/// Perform common subexpression elimination on a list of expressions.
pub fn cse(exprs : Array[Expr], min_nodes? : Int = 2) -> CseResult {
  let counts : Map[String, Int] = {}
  let key_expr : Map[String, Expr] = {}
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
          candidates.push(CseCandidate::{ key, expr, size: sz })
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
    let sym_expr = symbol(sym_name)
    let rhs = candidate.expr
    let next_reduced : Array[Expr] = Array::new()
    for expr in reduced {
      next_reduced.push(replace_exact(expr, candidate.key, sym_expr))
    }
    reduced = next_reduced
    replacements.push((sym_name, rhs))
    idx = idx + 1
  }
  CseResult::{ replacements, reduced_exprs: reduced }
}

///|
/// Reconstruct original expressions by substituting CSE replacements back.
pub fn cse_reconstruct(result : CseResult) -> Array[Expr] {
  let mut out = result.reduced_exprs.map(e => e)
  for i in 0..<result.replacements.length() {
    let idx = result.replacements.length() - 1 - i
    let (name, rhs) = result.replacements[idx]
    let env : Map[String, Expr] = {}
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
  let key = @symprint.debug_repr(expr)
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
    Expr::Number(_) | Expr::Symbol(_) => true
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
  let mut total = if @symprint.debug_repr(expr) == key { 1 } else { 0 }
  for child in @symcore.children(expr) {
    total = total + count_occurrences(child, key)
  }
  total
}

///|
fn replace_exact(expr : Expr, key : String, replacement : Expr) -> Expr {
  if @symprint.debug_repr(expr) == key {
    return replacement
  }
  @symcore.map_children(expr, child => replace_exact(child, key, replacement))
}
