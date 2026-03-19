///|\
/// Container helpers aligned with the portable core of `sympy.utilities.iterables`.

///|
pub enum Nested[T] {
  Atom(T)
  Items(Array[Nested[T]])
} derive(Eq)

///|
pub enum ShapeSpec {
  Take(Int)
  Group(Array[ShapeSpec])
} derive(Eq)

///|
pub enum GroupResult[T] {
  Multiple(Array[Array[T]])
  Counts(Array[(T, Int)])
} derive(Eq)

///|
pub struct NumberedSymbols {
  prefix : String
  next_index : Ref[Int]
  exclude : Array[String]
}

///|
pub fn[T] nested_atom(value : T) -> Nested[T] {
  Nested::Atom(value)
}

///|
pub fn[T] nested_items(values : Array[Nested[T]]) -> Nested[T] {
  Nested::Items(values)
}

///|
pub fn shape_take(count : Int) -> ShapeSpec {
  ShapeSpec::Take(count)
}

///|
pub fn shape_group(parts : Array[ShapeSpec]) -> ShapeSpec {
  ShapeSpec::Group(parts)
}

///|
pub fn[T : Eq] is_palindromic(
  seq : Array[T],
  start? : Int = 0,
  stop? : Int = -1,
) -> Bool {
  let n = seq.length()
  let mut lo = if start < 0 { start + n } else { start }
  let mut hi = if stop < 0 { stop + n } else { stop }
  if lo < 0 {
    lo = 0
  }
  if lo > n {
    lo = n
  }
  if hi < 0 {
    hi = 0
  }
  if hi > n {
    hi = n
  }
  let mut i = lo
  let mut j = hi - 1
  while i < j {
    if seq[i] != seq[j] {
      return false
    }
    i += 1
    j -= 1
  }
  true
}

///|
pub fn[T] flatten(
  items : Array[Nested[T]],
  levels? : Int = -1,
) -> Array[T] raise UtilitiesError {
  if levels < -1 {
    raise UtilitiesError::InvalidArgument(
      "expected non-negative number of levels",
    )
  }
  let out : Array[T] = []
  letrec visit = (value : Nested[T], depth : Int) => {
    match value {
      Nested::Atom(v) => out.push(v)
      Nested::Items(xs) =>
        if depth == 0 {
          for item in xs {
            match item {
              Nested::Atom(v) => out.push(v)
              Nested::Items(_) => ()
            }
          }
        } else {
          let next_depth = if depth < 0 { -1 } else { depth - 1 }
          for item in xs {
            visit(item, next_depth)
          }
        }
    }
  }
  for item in items {
    visit(item, levels)
  }
  out
}

///|
pub fn[T] unflatten(
  seq : Array[T],
  n : Int,
) -> Array[Array[T]] raise UtilitiesError {
  if n <= 0 || seq.length() % n != 0 {
    raise UtilitiesError::InvalidArgument(
      "expected chunk size dividing the sequence length",
    )
  }
  let out : Array[Array[T]] = []
  let mut i = 0
  while i < seq.length() {
    let chunk : Array[T] = []
    for j in 0..<n {
      chunk.push(seq[i + j])
    }
    out.push(chunk)
    i += n
  }
  out
}

///|
fn nested_size(spec : ShapeSpec) -> Int {
  match spec {
    ShapeSpec::Take(n) => n
    ShapeSpec::Group(parts) =>
      parts.fold(init=0, fn(acc, item) { acc + nested_size(item) })
  }
}

///|
fn[T] reshape_one(seq : Array[T], start : Int, spec : ShapeSpec) -> Nested[T] {
  match spec {
    ShapeSpec::Take(n) => {
      let values : Array[Nested[T]] = []
      for i in 0..<n {
        values.push(Nested::Atom(seq[start + i]))
      }
      Nested::Items(values)
    }
    ShapeSpec::Group(parts) => {
      let values : Array[Nested[T]] = []
      let mut offset = start
      for part in parts {
        values.push(reshape_one(seq, offset, part))
        offset += nested_size(part)
      }
      Nested::Items(values)
    }
  }
}

///|
pub fn[T] reshape(
  seq : Array[T],
  template : Array[ShapeSpec],
) -> Array[Nested[T]] raise UtilitiesError {
  let block = template.fold(init=0, fn(acc, item) { acc + nested_size(item) })
  if block <= 0 || seq.length() % block != 0 {
    raise UtilitiesError::InvalidArgument(
      "shape template must consume the input exactly",
    )
  }
  let out : Array[Nested[T]] = []
  let mut offset = 0
  while offset < seq.length() {
    let row : Array[Nested[T]] = []
    for part in template {
      row.push(reshape_one(seq, offset, part))
      offset += nested_size(part)
    }
    out.push(Nested::Items(row))
  }
  out
}

///|
pub fn[T : Eq] group(seq : Array[T], multiple? : Bool = true) -> GroupResult[T] {
  if seq.is_empty() {
    return if multiple {
      GroupResult::Multiple([])
    } else {
      GroupResult::Counts([])
    }
  }
  let runs : Array[Array[T]] = []
  let counts : Array[(T, Int)] = []
  let mut current : Array[T] = [seq[0]]
  for i in 1..<seq.length() {
    if seq[i] == current[0] {
      current.push(seq[i])
    } else {
      counts.push((current[0], current.length()))
      runs.push(current)
      current = [seq[i]]
    }
  }
  counts.push((current[0], current.length()))
  runs.push(current)
  if multiple {
    GroupResult::Multiple(runs)
  } else {
    GroupResult::Counts(counts)
  }
}

///|
fn[T] choose_k(
  seq : Array[T],
  k : Int,
  start : Int,
  acc : Array[T],
  out : Array[Array[T]],
) -> Unit {
  if k == 0 {
    out.push(acc.map(x => x))
    return
  }
  for i in start..<(seq.length() - k + 1) {
    let next = acc.map(x => x)
    next.push(seq[i])
    choose_k(seq, k - 1, i + 1, next, out)
  }
}

///|
fn[T] choose_k_rep(
  seq : Array[T],
  k : Int,
  start : Int,
  acc : Array[T],
  out : Array[Array[T]],
) -> Unit {
  if k == 0 {
    out.push(acc.map(x => x))
    return
  }
  for i in start..<seq.length() {
    let next = acc.map(x => x)
    next.push(seq[i])
    choose_k_rep(seq, k - 1, i, next, out)
  }
}

///|
pub fn[T] subsets(
  seq : Array[T],
  k? : Int = -1,
  repetition? : Bool = false,
) -> Array[Array[T]] {
  let out : Array[Array[T]] = []
  if k < 0 {
    for size in 0..<=seq.length() {
      let part = subsets(seq, k=size, repetition~)
      for item in part {
        out.push(item)
      }
    }
    return out
  }
  if k == 0 {
    return [[]]
  }
  if repetition {
    choose_k_rep(seq, k, 0, [], out)
  } else if k <= seq.length() {
    choose_k(seq, k, 0, [], out)
  }
  out
}

///|
fn[T] permute_k(
  seq : Array[T],
  n : Int,
  used : Array[Bool],
  acc : Array[T],
  out : Array[Array[T]],
) -> Unit {
  if acc.length() == n {
    out.push(acc.map(x => x))
    return
  }
  for i in 0..<seq.length() {
    if used[i] {
      continue
    }
    used[i] = true
    acc.push(seq[i])
    permute_k(seq, n, used, acc, out)
    ignore(acc.pop())
    used[i] = false
  }
}

///|
fn[T] permute_k_rep(
  seq : Array[T],
  n : Int,
  acc : Array[T],
  out : Array[Array[T]],
) -> Unit {
  if acc.length() == n {
    out.push(acc.map(x => x))
    return
  }
  for item in seq {
    acc.push(item)
    permute_k_rep(seq, n, acc, out)
    ignore(acc.pop())
  }
}

///|
pub fn[T] variations(
  seq : Array[T],
  n? : Int = -1,
  repetition? : Bool = false,
) -> Array[Array[T]] {
  let size = if n < 0 { seq.length() } else { n }
  if size == 0 {
    return [[]]
  }
  let out : Array[Array[T]] = []
  if repetition {
    permute_k_rep(seq, size, [], out)
  } else if size <= seq.length() {
    let used = Array::make(seq.length(), false)
    permute_k(seq, size, used, [], out)
  }
  out
}

///|
pub fn[T] cartes(seqs : Array[Array[T]]) -> Array[Array[T]] {
  if seqs.is_empty() {
    return [[]]
  }
  let mut out : Array[Array[T]] = [[]]
  for seq in seqs {
    let next : Array[Array[T]] = []
    for prefix in out {
      for item in seq {
        let row = prefix.map(x => x)
        row.push(item)
        next.push(row)
      }
    }
    out = next
  }
  out
}

///|
pub fn[T : Eq] common_prefix(seqs : Array[Array[T]]) -> Array[T] {
  if seqs.is_empty() {
    return []
  }
  if seqs.length() == 1 {
    return seqs[0].map(x => x)
  }
  let mut common = seqs[0].length()
  for seq in seqs {
    if seq.length() < common {
      common = seq.length()
    }
  }
  let mut i = 0
  while i < common {
    let probe = seqs[0][i]
    let mut ok = true
    for j in 1..<seqs.length() {
      if seqs[j][i] != probe {
        ok = false
        break
      }
    }
    if !ok {
      break
    }
    i += 1
  }
  let out : Array[T] = []
  for j in 0..<i {
    out.push(seqs[0][j])
  }
  out
}

///|
pub fn[T : Eq] common_suffix(seqs : Array[Array[T]]) -> Array[T] {
  if seqs.is_empty() {
    return []
  }
  if seqs.length() == 1 {
    return seqs[0].map(x => x)
  }
  let mut common = seqs[0].length()
  for seq in seqs {
    if seq.length() < common {
      common = seq.length()
    }
  }
  let mut i = 0
  while i < common {
    let probe = seqs[0][seqs[0].length() - 1 - i]
    let mut ok = true
    for j in 1..<seqs.length() {
      if seqs[j][seqs[j].length() - 1 - i] != probe {
        ok = false
        break
      }
    }
    if !ok {
      break
    }
    i += 1
  }
  let out : Array[T] = []
  for j in (common - i)..<common {
    out.push(seqs[0][j])
  }
  out
}

///|
pub fn capture(run : ((String) -> Unit) -> Unit) -> String {
  let builder = StringBuilder::new()
  run(s => builder.write_string(s))
  builder.to_string()
}

///|
pub fn[T, K : Eq + Hash] sift(
  seq : Array[T],
  keyfunc : (T) -> K,
) -> Map[K, Array[T]] {
  let out : Map[K, Array[T]] = {}
  for item in seq {
    let key = keyfunc(item)
    match out.get(key) {
      Some(values) => values.push(item)
      None => out[key] = [item]
    }
  }
  out
}

///|
pub fn[T] sift_binary(
  seq : Array[T],
  keyfunc : (T) -> Bool,
) -> (Array[T], Array[T]) {
  let yes : Array[T] = []
  let no : Array[T] = []
  for item in seq {
    if keyfunc(item) {
      yes.push(item)
    } else {
      no.push(item)
    }
  }
  (yes, no)
}

///|
pub fn[T] take(items : Iter[T], n : Int) -> Array[T] {
  let out : Array[T] = []
  if n <= 0 {
    return out
  }
  let mut count = 0
  for item in items {
    if count >= n {
      break
    }
    out.push(item)
    count += 1
  }
  out
}

///|
pub fn[K : Eq + Hash, V] dict_merge(dicts : Array[Map[K, V]]) -> Map[K, V] {
  let out : Map[K, V] = {}
  for mapping in dicts {
    for k, v in mapping {
      out[k] = v
    }
  }
  out
}

///|
pub fn[T] prefixes(seq : Array[T]) -> Array[Array[T]] {
  let out : Array[Array[T]] = []
  for i in 1..<=seq.length() {
    let prefix : Array[T] = []
    for j in 0..<i {
      prefix.push(seq[j])
    }
    out.push(prefix)
  }
  out
}

///|
pub fn[T] postfixes(seq : Array[T]) -> Array[Array[T]] {
  let out : Array[Array[T]] = []
  let mut i = seq.length() - 1
  while i >= 0 {
    let suffix : Array[T] = []
    for j in i..<seq.length() {
      suffix.push(seq[j])
    }
    out.push(suffix)
    i -= 1
  }
  out
}

///|
pub fn[T : Compare + Eq + Hash] topological_sort(
  vertices : Array[T],
  edges : Array[(T, T)],
) -> Array[T] raise UtilitiesError {
  let indegree : Map[T, Int] = {}
  let outgoing : Map[T, Array[T]] = {}
  for v in vertices {
    indegree[v] = 0
    outgoing[v] = []
  }
  for edge in edges {
    let (src, dst) = edge
    match outgoing.get(src) {
      Some(items) => items.push(dst)
      None => outgoing[src] = [dst]
    }
    indegree[dst] = match indegree.get(dst) {
      Some(count) => count + 1
      None => 1
    }
  }
  let ready : Array[T] = []
  for v in vertices {
    let degree = match indegree.get(v) {
      Some(value) => value
      None => 0
    }
    if degree == 0 {
      ready.push(v)
    }
  }
  ready.sort()
  let out : Array[T] = []
  while !ready.is_empty() {
    let current = ready[0]
    ignore(ready.remove(0))
    out.push(current)
    match outgoing.get(current) {
      Some(targets) => {
        for dst in targets {
          let next_deg = match indegree.get(dst) {
            Some(value) => value - 1
            None => -1
          }
          indegree[dst] = next_deg
          if next_deg == 0 {
            ready.push(dst)
          }
        }
        ready.sort()
      }
      None => ()
    }
  }
  if out.length() != vertices.length() {
    raise UtilitiesError::InvalidArgument("cycle detected in topological_sort")
  }
  out
}

///|
pub fn[T : Eq + Hash] has_dups(seq : Array[T]) -> Bool {
  let seen : Map[T, Unit] = {}
  for item in seq {
    match seen.get(item) {
      Some(_) => return true
      None => seen[item] = ()
    }
  }
  false
}

///|
pub fn[T : Eq + Hash] uniq(seq : Array[T]) -> Array[T] {
  let seen : Map[T, Unit] = {}
  let out : Array[T] = []
  for item in seq {
    if !seen.contains(item) {
      seen[item] = ()
      out.push(item)
    }
  }
  out
}

///|
pub fn[T : Eq] has_variety(seq : Array[T]) -> Bool {
  if seq.length() < 2 {
    return false
  }
  let first = seq[0]
  seq.any(item => item != first)
}

///|
pub fn[T] rotate_left(seq : Array[T], steps : Int) -> Array[T] {
  if seq.is_empty() {
    return []
  }
  let n = seq.length()
  let mut shift = steps % n
  if shift < 0 {
    shift += n
  }
  let out : Array[T] = []
  for i in 0..<n {
    out.push(seq[(i + shift) % n])
  }
  out
}

///|
pub fn[T] rotate_right(seq : Array[T], steps : Int) -> Array[T] {
  if seq.is_empty() {
    return []
  }
  rotate_left(seq, seq.length() - steps % seq.length())
}

///|
pub fn[T : Compare] least_rotation(seq : Array[T]) -> Int {
  if seq.is_empty() {
    return 0
  }
  let mut best_index = 0
  let mut best = seq.map(x => x)
  for i in 1..<seq.length() {
    let candidate = rotate_left(seq, i)
    if candidate.compare(best) < 0 {
      best = candidate
      best_index = i
    }
  }
  best_index
}

///|
pub fn[T] rotations(seq : Array[T], dir? : Int = 1) -> Array[Array[T]] {
  let out : Array[Array[T]] = []
  let mut current = seq.map(x => x)
  for _ in 0..<seq.length() {
    out.push(current.map(x => x))
    current = rotate_left(current, dir)
  }
  out
}

///|
pub fn numbered_symbols(
  prefix? : String = "x",
  start? : Int = 0,
  exclude? : Array[String] = [],
) -> NumberedSymbols {
  { prefix, next_index: { val: start }, exclude: exclude.map(x => x) }
}

///|
pub fn NumberedSymbols::next(self : NumberedSymbols) -> Expr {
  let mut index = self.next_index.val
  let mut name = self.prefix + index.to_string()
  while self.exclude.contains(name) {
    index += 1
    name = self.prefix + index.to_string()
  }
  self.next_index.val = index + 1
  symbol(name)
}
