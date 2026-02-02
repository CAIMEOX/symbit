///|
/// Parse a comma-separated wrt spec into list of names.
fn parse_wrt_string(spec : String) -> Array[String] {
  let trimmed = spec.trim().to_string()
  if trimmed == "" {
    return Array::new()
  }
  let parts = trimmed.split(",")
  let out : Array[String] = Array::new()
  for part in parts {
    let name = part.trim().to_string()
    if name != "" {
      out.push(name)
    }
  }
  out
}

///|
/// Parse a sort string like "x > p > q" into list of names.
fn parse_sort_string(spec : String) -> Array[String] {
  let trimmed = spec.trim().to_string()
  if trimmed == "" {
    return Array::new()
  }
  let parts = trimmed.split(">")
  let out : Array[String] = Array::new()
  for part in parts {
    let name = part.trim().to_string()
    if name != "" {
      out.push(name)
    }
  }
  out
}

///|
fn split_name(name : String) -> (String, Int?) {
  let mut i = name.length()
  while i > 0 {
    let ch = name[i - 1]
    if ch >= '0' && ch <= '9' {
      i = i - 1
    } else {
      break
    }
  }
  if i == name.length() {
    (name, None)
  } else {
    let prefix_view = try! name[0:i]
    let prefix = prefix_view.to_string()
    let mut num = 0
    for j in i..<name.length() {
      let digit = name[j].to_int() - 48
      if digit >= 0 && digit <= 9 {
        num = num * 10 + digit
      }
    }
    (prefix, Some(num))
  }
}

///|
fn gens_rank(name : String) -> (Int, String, Int?, String) {
  let (prefix, num) = split_name(name)
  let head = if prefix.has_prefix("x") {
    0
  } else if prefix.has_prefix("y") {
    1
  } else if prefix.has_prefix("z") {
    2
  } else {
    3
  }
  (head, prefix, num, name)
}

///|
fn compare_gens(a : String, b : String) -> Int {
  let (ra, pa, na, na_raw) = gens_rank(a)
  let (rb, pb, nb, nb_raw) = gens_rank(b)
  if ra != rb {
    return ra - rb
  }
  if pa != pb {
    return pa.compare(pb)
  }
  match (na, nb) {
    (Some(x), Some(y)) => if x != y { x - y } else { na_raw.compare(nb_raw) }
    (None, Some(_)) => -1
    (Some(_), None) => 1
    (None, None) => na_raw.compare(nb_raw)
  }
}

///|
fn unique_preserve(xs : Array[String]) -> Array[String] {
  let seen : Map[String, Bool] = Map::new()
  let out : Array[String] = Array::new()
  for x in xs {
    if seen.get(x) is None {
      seen.set(x, true)
      out.push(x)
    }
  }
  out
}

///|
fn sort_by_default(xs : Array[String]) -> Array[String] {
  let out = xs.copy()
  out.sort_by((a, b) => compare_gens(a, b))
  out
}

///|
/// SymPy-style generator sorting (simplified).
pub fn _sort_gens(
  gens : Array[String],
  wrt? : Array[String] = [],
  sort? : String = "",
) -> Array[String] {
  if gens.is_empty() {
    return Array::new()
  }
  let gens_u = unique_preserve(gens)
  let wrt_u = unique_preserve(wrt)
  let sort_list = parse_sort_string(sort)
  let mut remaining : Array[String] = Array::new()
  for g in gens_u {
    if wrt_u.contains(g) {
      continue
    }
    remaining.push(g)
  }
  let ordered : Array[String] = Array::new()
  for w in wrt_u {
    if gens_u.contains(w) {
      ordered.push(w)
    }
  }
  if !sort_list.is_empty() {
    let sort_rank : Map[String, Int] = Map::new()
    let mut idx = 0
    for name in sort_list {
      sort_rank.set(name, idx)
      idx = idx + 1
    }
    remaining.sort_by((a, b) => {
      let ra = match sort_rank.get(a) { Some(v) => v; None => 1_000_000 }
      let rb = match sort_rank.get(b) { Some(v) => v; None => 1_000_000 }
      if ra != rb {
        ra - rb
      } else {
        compare_gens(a, b)
      }
    })
  } else {
    remaining = sort_by_default(remaining)
  }
  for g in remaining {
    ordered.push(g)
  }
  ordered
}

///|
/// Convenience wrapper that accepts wrt as a string (comma-separated).
pub fn _sort_gens_wrt(
  gens : Array[String],
  wrt : String,
  sort? : String = "",
) -> Array[String] {
  let wrt_list = parse_wrt_string(wrt)
  _sort_gens(gens, wrt=wrt_list, sort=sort)
}

///|
fn index_of(name : String, arr : Array[String]) -> Int {
  for i in 0..<arr.length() {
    if arr[i] == name {
      return i
    }
  }
  1_000_000
}

///|
/// Unify gens by merging order constraints; falls back to first list on cycles.
pub fn _unify_gens(a : Array[String], b : Array[String]) -> Array[String] {
  if a.is_empty() {
    return b
  }
  if b.is_empty() {
    return a
  }
  let merged : Array[String] = Array::new()
  for name in a {
    merged.push(name)
  }
  for name in b {
    merged.push(name)
  }
  let nodes = unique_preserve(merged)
  let adj : Map[String, Array[String]] = Map::new()
  let indeg : Map[String, Int] = Map::new()
  for n in nodes {
    indeg.set(n, 0)
  }
  let lists : Array[Array[String]] = [a, b]
  for lst in lists {
    for i in 0..<(lst.length() - 1) {
      let u = lst[i]
      let v = lst[i + 1]
      let neighbors = match adj.get(u) { Some(xs) => xs; None => Array::new() }
      if !neighbors.contains(v) {
        neighbors.push(v)
        adj.set(u, neighbors)
        let cur = match indeg.get(v) { Some(x) => x; None => 0 }
        indeg.set(v, cur + 1)
      }
    }
  }
  let result : Array[String] = Array::new()
  let mut processed = 0
  while processed < nodes.length() {
    let available : Array[String] = Array::new()
    for n in nodes {
      if indeg.get(n) == Some(0) && !result.contains(n) {
        available.push(n)
      }
    }
    if available.is_empty() {
      return a
    }
    available.sort_by((x, y) => {
      let ix = index_of(x, a)
      let iy = index_of(y, a)
      if ix != iy {
        ix - iy
      } else {
        let jx = index_of(x, b)
        let jy = index_of(y, b)
        if jx != jy {
          jx - jy
        } else {
          compare_gens(x, y)
        }
      }
    })
    let pick = available[0]
    result.push(pick)
    processed = processed + 1
    match adj.get(pick) {
      Some(neighbors) =>
        for v in neighbors {
          let cur = match indeg.get(v) { Some(x) => x; None => 0 }
          indeg.set(v, cur - 1)
        }
      None => ()
    }
  }
  result
}

///|
pub fn _analyze_gens(gens : Array[String]) -> Array[String] {
  gens
}

///|
pub fn _analyze_gens_nested(gens : Array[Array[String]]) -> Array[String] {
  if gens.length() == 1 {
    return gens[0]
  }
  let out : Array[String] = Array::new()
  for g in gens {
    for name in g {
      out.push(name)
    }
  }
  out
}

///|
fn compare_int_lists(a : Array[Int], b : Array[Int]) -> Int {
  if a.length() != b.length() {
    return a.length() - b.length()
  }
  for i in 0..<a.length() {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  0
}

///|
pub fn _sort_factors(factors : Array[Array[Int]]) -> Array[Array[Int]] {
  let out = factors.copy()
  out.sort_by((a, b) => compare_int_lists(a, b))
  out
}

///|
pub fn _sort_factors_multiple(
  factors : Array[(Array[Int], Int)],
) -> Array[(Array[Int], Int)] {
  let out = factors.copy()
  out.sort_by((a, b) => {
    let len_diff = a.0.length() - b.0.length()
    if len_diff != 0 {
      len_diff
    } else if a.1 != b.1 {
      a.1 - b.1
    } else {
      compare_int_lists(a.0, b.0)
    }
  })
  out
}

///|
fn infer_gens_expr_local(expr : @symcore.Expr) -> Array[String] {
  let seen : Map[String, Bool] = Map::new()
  collect_symbols_local(expr, seen)
  let names : Array[String] = Array::new()
  for name, _ in seen {
    names.push(name)
  }
  names.sort_by((a, b) => compare_gens(a, b))
  names
}

///|
fn collect_symbols_local(expr : @symcore.Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => seen.set(name, true)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for child in args {
        collect_symbols_local(child, seen)
      }
    @symcore.Expr::Pow(base, exp) => {
      collect_symbols_local(base, seen)
      collect_symbols_local(exp, seen)
    }
    @symcore.Expr::Function(_, args) =>
      for child in args {
        collect_symbols_local(child, seen)
      }
    _ => ()
  }
}

///|
fn tuple_repr(exps : Array[Int]) -> String {
  if exps.length() == 1 {
    return "(\{exps[0]},)"
  }
  let parts = exps.map(x => x.to_string()).join(",")
  "(\{parts})"
}

///|
fn dict_repr(entries : Array[(Array[Int], String)]) -> String {
  let parts : Array[String] = Array::new()
  for entry in entries {
    let (exps, coeff) = entry
    parts.push("\{tuple_repr(exps)}:\{coeff}")
  }
  let joined = parts.join(",")
  "{\{joined}}"
}

///|
pub fn dict_from_expr(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise PolyError {
  let gens_list = if gens.is_empty() { infer_gens_expr_local(expr) } else { gens }
  let poly = Poly::from_expr_defaults(expr, gens=gens_list)
  let entries : Array[(Array[Int], String)] = Array::new()
  for m, c in poly.coeffs {
    entries.push((m.exps.copy(), c.to_string()))
  }
  entries.sort_by((a, b) => compare_int_lists(a.0, b.0))
  let dict_str = dict_repr(entries)
  let gens_str = gens_list.map(n => "\"\{n}\"").join(",")
  "\{dict_str}||[\{gens_str}]"
}
