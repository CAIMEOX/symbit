///|
pub(all) struct CseResult {
  replacements : Array[(String, @symcore.Expr)]
  reduced_exprs : Array[@symcore.Expr]
}

///|
pub fn CseResult::replacement_count(self : CseResult) -> Int {
  self.replacements.length()
}

///|
pub fn CseResult::replacements_copy(
  self : CseResult,
) -> Array[(String, @symcore.Expr)] {
  self.replacements.map(item => item)
}

///|
pub fn CseResult::reduced_exprs_copy(
  self : CseResult,
) -> Array[@symcore.Expr] {
  self.reduced_exprs.map(item => item)
}

///|
pub fn cse(
  exprs : Array[@symcore.Expr],
  min_nodes? : Int = 2,
) -> CseResult {
  let counts : Map[String, Int] = {}
  let key_expr : Map[String, @symcore.Expr] = {}
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
  let replacements : Array[(String, @symcore.Expr)] = Array::new()
  let mut idx = 0
  for candidate in candidates {
    let occ = total_occurrences(reduced, candidate.key)
    if occ <= 1 {
      continue
    }
    let sym_name = "x\{idx}"
    let sym_expr = @symcore.symbol(sym_name)
    let rhs = candidate.expr
    let next_reduced : Array[@symcore.Expr] = Array::new()
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
pub fn cse_reconstruct(result : CseResult) -> Array[@symcore.Expr] {
  let mut out = result.reduced_exprs.map(e => e)
  for i in 0..<result.replacements.length() {
    let idx = result.replacements.length() - 1 - i
    let (name, rhs) = result.replacements[idx]
    let env : Map[String, @symcore.Expr] = {}
    env[name] = rhs
    out = out.map(expr => @symcore.subst(expr, env))
  }
  out
}

///|
priv struct CseCandidate {
  key : String
  expr : @symcore.Expr
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
  expr : @symcore.Expr,
  counts : Map[String, Int],
  key_expr : Map[String, @symcore.Expr],
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
fn is_atom(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(_) | @symcore.Expr::Symbol(_) => true
    _ => false
  }
}

///|
fn node_count(expr : @symcore.Expr) -> Int {
  let mut total = 1
  for child in @symcore.children(expr) {
    total = total + node_count(child)
  }
  total
}

///|
fn total_occurrences(exprs : Array[@symcore.Expr], key : String) -> Int {
  let mut total = 0
  for expr in exprs {
    total = total + count_occurrences(expr, key)
  }
  total
}

///|
fn count_occurrences(expr : @symcore.Expr, key : String) -> Int {
  let mut total = if @symprint.debug_repr(expr) == key { 1 } else { 0 }
  for child in @symcore.children(expr) {
    total = total + count_occurrences(child, key)
  }
  total
}

///|
fn replace_exact(
  expr : @symcore.Expr,
  key : String,
  replacement : @symcore.Expr,
) -> @symcore.Expr {
  if @symprint.debug_repr(expr) == key {
    return replacement
  }
  @symcore.map_children(
    expr,
    child => replace_exact(child, key, replacement),
  )
}
