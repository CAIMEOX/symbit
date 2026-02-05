///|
/// Prufer sequence utilities.

///|
pub struct Prufer {
  mut prufer_repr : Array[Int]?
  mut tree_repr : Array[Array[Int]]?
  nodes : Int
  mut rank_cache : Int?
}

///|
pub fn Prufer::from_edges(
  edges : Array[Array[Int]],
  nodes? : Int,
) -> Prufer raise CombinatoricsError {
  if edges.is_empty() {
    raise CombinatoricsError::ValueError("Prufer expects at least one edge")
  }
  let mut nnodes = 0
  if nodes is Some(v) {
    nnodes = v
  } else {
    let mut max_node = 0
    let seen : Array[Int] = Array::new()
    for edge in edges {
      if edge.length() != 2 {
        raise CombinatoricsError::ValueError("Edge must have length 2")
      }
      for v in edge {
        if !seen.any(x => x == v) {
          seen.push(v)
        }
        if v > max_node {
          max_node = v
        }
      }
    }
    nnodes = max_node + 1
    if seen.length() != nnodes {
      raise CombinatoricsError::ValueError("Missing node in edge list")
    }
  }
  {
    prufer_repr: None,
    tree_repr: Some(edges),
    nodes: nnodes,
    rank_cache: None,
  }
}

///|
pub fn Prufer::from_sequence(seq : Array[Int]) -> Prufer {
  let nnodes = seq.length() + 2
  {
    prufer_repr: Some(seq),
    tree_repr: None,
    nodes: nnodes,
    rank_cache: None,
  }
}

///|
pub fn Prufer::prufer_repr(self : Prufer) -> Array[Int] {
  match self.prufer_repr {
    Some(seq) => seq
    None => {
      let tree = self.tree_repr.unwrap()
      let seq = to_prufer(tree, self.nodes)
      self.prufer_repr = Some(seq)
      self.prufer_repr.unwrap()
    }
  }
}

///|
pub fn Prufer::tree_repr(self : Prufer) -> Array[Array[Int]] {
  match self.tree_repr {
    Some(tree) => tree
    None => {
      let seq = self.prufer_repr.unwrap()
      let tree = to_tree(seq)
      self.tree_repr = Some(tree)
      self.tree_repr.unwrap()
    }
  }
}

///|
pub fn Prufer::rank(self : Prufer) -> Int {
  match self.rank_cache {
    Some(r) => r
    None => {
      let r = self.prufer_rank()
      self.rank_cache = Some(r)
      r
    }
  }
}

///|
pub fn Prufer::size(self : Prufer) -> Int {
  pow_int(self.nodes, self.nodes - 2)
}

///|
pub fn to_prufer(tree : Array[Array[Int]], n : Int) -> Array[Int] {
  let degrees : Array[Int] = Array::make(n, 0)
  let edges : Array[Array[Int]] = Array::new()
  for edge in tree {
    if edge.length() != 2 {
      continue
    }
    let a = edge[0]
    let b = edge[1]
    degrees[a] = degrees[a] + 1
    degrees[b] = degrees[b] + 1
    edges.push([a, b])
  }
  let out : Array[Int] = Array::new()
  for _ in 0..<(n - 2) {
    let mut x = 0
    while x < n && degrees[x] != 1 {
      x = x + 1
    }
    let mut y = 0
    let mut idx = 0
    while idx < edges.length() {
      let edge = edges[idx]
      if edge[0] == x {
        y = edge[1]
        let _ = edges.remove(idx)
        break
      } else if edge[1] == x {
        y = edge[0]
        let _ = edges.remove(idx)
        break
      }
      idx = idx + 1
    }
    out.push(y)
    degrees[x] = degrees[x] - 1
    degrees[y] = degrees[y] - 1
  }
  out
}

///|
pub fn to_tree(prufer : Array[Int]) -> Array[Array[Int]] {
  let n = prufer.length() + 2
  let degrees : Array[Int] = Array::make(n, 1)
  for p in prufer {
    degrees[p] = degrees[p] + 1
  }
  let tree : Array[Array[Int]] = Array::new()
  for p in prufer {
    let mut j = 0
    while j < n && degrees[j] != 1 {
      j = j + 1
    }
    degrees[p] = degrees[p] - 1
    degrees[j] = degrees[j] - 1
    let a = if p < j { p } else { j }
    let b = if p < j { j } else { p }
    tree.push([a, b])
  }
  let last : Array[Int] = Array::new()
  for i in 0..<n {
    if degrees[i] == 1 {
      last.push(i)
    }
  }
  if last.length() == 2 {
    tree.push([last[0], last[1]])
  }
  tree
}

///|
pub fn prufer_edges(runs : Array[Array[Int]]) -> (Array[Array[Int]], Int) raise CombinatoricsError {
  fn parse_key(view : StringView) -> Int raise CombinatoricsError {
    try @strconv.parse_int(view) catch {
      _ => raise CombinatoricsError::ValueError("Invalid edge label")
    }
  }
  let edge_map : Map[String, Bool] = Map::new()
  let mut nmin : Int? = None
  let mut nmax : Int? = None
  for run in runs {
    if run.length() < 2 {
      continue
    }
    for i in 0..<(run.length() - 1) {
      let mut a = run[i]
      let mut b = run[i + 1]
      if b < a {
        let tmp = a
        a = b
        b = tmp
      }
      let key = "\{a},\{b}"
      edge_map[key] = true
      nmin = match nmin {
        Some(v) => Some(if a < v { a } else { v })
        None => Some(a)
      }
      nmax = match nmax {
        Some(v) => Some(if b > v { b } else { v })
        None => Some(b)
      }
    }
  }
  if nmin is None || nmax is None {
    raise CombinatoricsError::ValueError("No edges provided")
  }
  let minv = nmin.unwrap()
  let maxv = nmax.unwrap()
  let present : Array[Bool] = Array::make(maxv - minv + 1, false)
  for key, _ in edge_map {
    let parts = key.split(",").to_array()
    if parts.length() == 2 {
      let a = parse_key(parts[0])
      let b = parse_key(parts[1])
      present[a - minv] = true
      present[b - minv] = true
    }
  }
  for i in 0..<present.length() {
    if !present[i] {
      raise CombinatoricsError::ValueError("Node missing in edge list")
    }
  }
  let edges : Array[Array[Int]] = Array::new()
  let keys : Array[String] = Array::new()
  for key, _ in edge_map {
    keys.push(key)
  }
  keys.sort()
  for key in keys {
    let parts = key.split(",").to_array()
    if parts.length() == 2 {
      let mut a = parse_key(parts[0])
      let mut b = parse_key(parts[1])
      if minv != 0 {
        a = a - minv
        b = b - minv
      }
      edges.push([a, b])
    }
  }
  let nnodes = maxv - minv + 1
  (edges, nnodes)
}

///|
pub fn Prufer::prufer_rank(self : Prufer) -> Int {
  let seq = self.prufer_repr()
  let mut r = 0
  let mut p = 1
  let mut i = self.nodes - 3
  while i >= 0 {
    r = r + p * seq[i]
    p = p * self.nodes
    i = i - 1
  }
  r
}

///|
pub fn Prufer::unrank(rank : Int, n : Int) -> Prufer {
  let mut r = rank
  let values : Array[Int] = Array::new()
  let mut i = n - 3
  while i >= 0 {
    let v = r % n
    values.push(v)
    r = (r - v) / n
    i = i - 1
  }
  let values = array_reverse(values)
  Prufer::from_sequence(values)
}

///|
pub fn Prufer::next(self : Prufer, delta? : Int = 1) -> Prufer {
  Prufer::unrank(self.rank() + delta, self.nodes)
}

///|
pub fn Prufer::prev(self : Prufer, delta? : Int = 1) -> Prufer {
  Prufer::unrank(self.rank() - delta, self.nodes)
}
