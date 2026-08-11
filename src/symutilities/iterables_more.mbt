///|\
/// Additional pure combinatorial helpers aligned with the broader
/// `sympy.utilities.iterables` surface.

///|
pub fn[T : Eq + Hash] multiset(seq : Array[T]) -> Map[T, Int] {
  let counts : Map[T, Int] = Map([])
  for item in seq {
    counts[item] = match counts.get(item) {
      Some(n) => n + 1
      None => 1
    }
  }
  counts
}

///|
fn[T : Eq + Hash + Compare] multiset_groups(seq : Array[T]) -> Array[(T, Int)] {
  let counts = multiset(seq)
  let out : Array[(T, Int)] = []
  for key, value in counts {
    out.push((key, value))
  }
  out.sort_by((a, b) => Compare::compare(a.0, b.0))
  out
}

///|
pub fn[T] permutations(seq : Array[T], size? : Int = -1) -> Array[Array[T]] {
  variations(seq, n=size, repetition=false)
}

///|
fn[T] multiset_combinations_from_groups(
  groups : Array[(T, Int)],
  index : Int,
  size : Int,
) -> Array[Array[T]] {
  if size == 0 {
    return [[]]
  }
  if index >= groups.length() {
    return []
  }
  let (item, count) = groups[index]
  let out : Array[Array[T]] = []
  let max_use = if count < size { count } else { size }
  for skipped in 0..<=max_use {
    let take_count = max_use - skipped
    let suffixes = multiset_combinations_from_groups(
      groups,
      index + 1,
      size - take_count,
    )
    for suffix in suffixes {
      let row : Array[T] = []
      for _ in 0..<take_count {
        row.push(item)
      }
      for value in suffix {
        row.push(value)
      }
      out.push(row)
    }
  }
  out
}

///|
pub fn[T : Eq + Hash + Compare] multiset_combinations(
  seq : Array[T],
  size : Int,
) -> Array[Array[T]] {
  if size < 0 {
    return []
  }
  multiset_combinations_from_groups(multiset_groups(seq), 0, size)
}

///|
fn[T] multiset_permutations_from_groups(
  groups : Array[(T, Int)],
  size : Int,
  acc : Array[T],
  out : Array[Array[T]],
) -> Unit {
  if acc.length() == size {
    out.push(acc.map(x => x))
    return
  }
  for i in 0..<groups.length() {
    let (item, count) = groups[i]
    if count == 0 {
      continue
    }
    groups[i] = (item, count - 1)
    acc.push(item)
    multiset_permutations_from_groups(groups, size, acc, out)
    ignore(acc.pop())
    groups[i] = (item, count)
  }
}

///|
pub fn[T : Eq + Hash + Compare] multiset_permutations(
  seq : Array[T],
  size? : Int = -1,
) -> Array[Array[T]] {
  let groups = multiset_groups(seq)
  let total = groups.fold(init=0, fn(acc, item) { acc + item.1 })
  let n = if size < 0 { total } else { size }
  if n < 0 || n > total {
    return []
  }
  if n == 0 {
    return [[]]
  }
  let out : Array[Array[T]] = []
  multiset_permutations_from_groups(groups, n, [], out)
  out
}

///|
pub fn[T : Compare] runs(seq : Array[T]) -> Array[Array[T]] {
  runs_by(seq, (a, b) => a.compare(b) > 0)
}

///|
pub fn[T] runs_by(seq : Array[T], op : (T, T) -> Bool) -> Array[Array[T]] {
  if seq.is_empty() {
    return []
  }
  let out : Array[Array[T]] = []
  let mut run : Array[T] = [seq[0]]
  for i in 1..<seq.length() {
    if op(seq[i], run[run.length() - 1]) {
      run.push(seq[i])
    } else {
      out.push(run)
      run = [seq[i]]
    }
  }
  out.push(run)
  out
}

///|
pub fn[T : Eq + Hash] strongly_connected_components(
  vertices : Array[T],
  edges : Array[(T, T)],
) -> Array[Array[T]] {
  let graph : Map[T, Array[T]] = Map([])
  for vertex in vertices {
    graph[vertex] = []
  }
  for edge in edges {
    let (src, dst) = edge
    match graph.get(src) {
      Some(targets) => targets.push(dst)
      None => graph[src] = [dst]
    }
    if !graph.contains(dst) {
      graph[dst] = []
    }
  }
  let index : Map[T, Int] = Map([])
  let lowlink : Map[T, Int] = Map([])
  let on_stack : Map[T, Bool] = Map([])
  let stack : Array[T] = []
  let components : Array[Array[T]] = []
  let next_index : Ref[Int] = { val: 0 }
  letrec strong_connect = (vertex : T) => {
    let current = next_index.val
    index[vertex] = current
    lowlink[vertex] = current
    next_index.val = current + 1
    stack.push(vertex)
    on_stack[vertex] = true
    let neighbors = match graph.get(vertex) {
      Some(items) => items
      None => []
    }
    for neighbor in neighbors {
      if !index.contains(neighbor) {
        strong_connect(neighbor)
        let candidate = lowlink[neighbor]
        let current_low = lowlink[vertex]
        lowlink[vertex] = if candidate < current_low {
          candidate
        } else {
          current_low
        }
      } else if on_stack.get(neighbor).unwrap_or(false) {
        let candidate = index[neighbor]
        let current_low = lowlink[vertex]
        lowlink[vertex] = if candidate < current_low {
          candidate
        } else {
          current_low
        }
      }
    }
    if lowlink[vertex] == index[vertex] {
      let component : Array[T] = []
      let mut done = false
      while !done {
        let item = stack.pop().unwrap()
        on_stack[item] = false
        component.push(item)
        if item == vertex {
          done = true
        }
      }
      components.push(component.rev())
    }
  }
  for vertex in vertices {
    if !index.contains(vertex) {
      strong_connect(vertex)
    }
  }
  components
}

///|
pub fn[T : Eq + Hash] connected_components(
  vertices : Array[T],
  edges : Array[(T, T)],
) -> Array[Array[T]] {
  let undirected : Array[(T, T)] = []
  for edge in edges {
    let (src, dst) = edge
    undirected.push((src, dst))
    undirected.push((dst, src))
  }
  strongly_connected_components(vertices, undirected)
}

///|
fn[T] sequence_partitions_rec(
  seq : Array[T],
  bins : Int,
  allow_empty : Bool,
  out : Array[Array[Array[T]]],
  acc : Array[Array[T]],
) -> Unit {
  if bins == 1 {
    let row = acc.map(part => part.map(x => x))
    row.push(seq.map(x => x))
    out.push(row)
    return
  }
  let start = if allow_empty { 0 } else { 1 }
  let stop = if allow_empty { seq.length() } else { seq.length() - 1 }
  for i in start..<=stop {
    let next = acc.map(part => part.map(x => x))
    let part : Array[T] = []
    for j in 0..<i {
      part.push(seq[j])
    }
    next.push(part)
    let tail : Array[T] = []
    for j in i..<seq.length() {
      tail.push(seq[j])
    }
    sequence_partitions_rec(tail, bins - 1, allow_empty, out, next)
  }
}

///|
pub fn[T] sequence_partitions(
  seq : Array[T],
  bins : Int,
) -> Array[Array[Array[T]]] {
  if bins <= 0 {
    return []
  }
  if bins == 1 {
    return [[seq.map(x => x)]]
  }
  if seq.is_empty() {
    return []
  }
  let out : Array[Array[Array[T]]] = []
  sequence_partitions_rec(seq, bins, false, out, [])
  out
}

///|
pub fn[T] sequence_partitions_empty(
  seq : Array[T],
  bins : Int,
) -> Array[Array[Array[T]]] {
  if bins <= 0 {
    return []
  }
  let out : Array[Array[Array[T]]] = []
  sequence_partitions_rec(seq, bins, true, out, [])
  out
}

///|
pub fn[T : Eq + Hash + Compare] multiset_derangements(
  seq : Array[T],
) -> Array[Array[T]] {
  let out : Array[Array[T]] = []
  for perm in multiset_permutations(seq) {
    let mut ok = true
    for i in 0..<seq.length() {
      if perm[i] == seq[i] {
        ok = false
        break
      }
    }
    if ok {
      out.push(perm)
    }
  }
  out
}

///|
pub fn[T : Eq + Hash + Compare] generate_derangements(
  seq : Array[T],
) -> Array[Array[T]] {
  multiset_derangements(seq)
}
