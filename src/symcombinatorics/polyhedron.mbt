///|
/// Polyhedron symmetry groups (SymPy-style).

///|
fn clone_expr_array(items : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for v in items {
    out.push(v)
  }
  out
}

///|
fn clone_int_array(items : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for v in items {
    out.push(v)
  }
  out
}

///|
fn clone_int_arrays(items : Array[Array[Int]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for v in items {
    out.push(clone_int_array(v))
  }
  out
}

///|
fn clone_perm_array(items : Array[Permutation]) -> Array[Permutation] {
  let out : Array[Permutation] = Array::new()
  for v in items {
    out.push(v)
  }
  out
}

///|
fn ints_to_exprs(items : Array[Int]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for v in items {
    out.push(@symcore.int(v))
  }
  out
}

///|
fn compare_int_arrays(a : Array[Int], b : Array[Int]) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  if a.length() < b.length() { -1 } else if a.length() > b.length() { 1 } else { 0 }
}

///|
fn sort_int_arrays(values : Array[Array[Int]]) -> Array[Array[Int]] {
  let out = clone_int_arrays(values)
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if compare_int_arrays(out[j], out[i]) < 0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn min_rotation(seq : Array[Int]) -> Array[Int] {
  if seq.is_empty() {
    return []
  }
  let n = seq.length()
  let mut best = clone_int_array(seq)
  for start in 1..<n {
    let rotated : Array[Int] = Array::new()
    for k in 0..<n {
      let idx = (start + k) % n
      rotated.push(seq[idx])
    }
    if compare_int_arrays(rotated, best) < 0 {
      best = rotated
    }
  }
  best
}

///|
fn minlex_face(face : Array[Int]) -> Array[Int] {
  if face.length() <= 1 {
    return clone_int_array(face)
  }
  let direct = min_rotation(face)
  let reversed : Array[Int] = Array::new()
  let mut i = face.length() - 1
  while i >= 0 {
    reversed.push(face[i])
    i = i - 1
  }
  let rev_min = min_rotation(reversed)
  if compare_int_arrays(rev_min, direct) < 0 { rev_min } else { direct }
}

///|
fn face_key(face : Array[Int]) -> String {
  face.map((v) => "\{v}").join(",")
}

///|
fn canonical_faces(faces : Array[Array[Int]]) -> Array[Array[Int]] {
  let seen : Map[String, Array[Int]] = {}
  for f in faces {
    let canon = minlex_face(f)
    let key = face_key(canon)
    if !seen.contains(key) {
      seen[key] = canon
    }
  }
  let out : Array[Array[Int]] = Array::new()
  for _, v in seen {
    out.push(v)
  }
  sort_int_arrays(out)
}

///|
pub(all) enum PolyRotate {
  Index(Int)
  Perm(Permutation)
}

///|
pub struct Polyhedron {
  original_corners : Array[@symcore.Expr]
  mut corners : Array[@symcore.Expr]
  faces : Array[Array[Int]]
  pgroup_generators : Array[Permutation]
  pgroup : PermutationGroup
  mut edges_cache : Array[(Int, Int)]?
}

///|
pub fn Polyhedron::new(
  corners : Array[@symcore.Expr],
  faces? : Array[Array[Int]] = [],
  pgroup? : Array[Permutation] = [],
) -> Polyhedron raise CombinatoricsError {
  let corners_copy = clone_expr_array(corners)
  let face_list = canonical_faces(faces)
  let gens : Array[Permutation] = Array::new()
  for g in pgroup {
    gens.push(g)
  }
  if gens.is_empty() {
    gens.push(Permutation::identity(corners.length()))
  }
  if !gens.is_empty() && gens[0].size() != corners.length() {
    raise CombinatoricsError::ValueError("Permutation size unequal to number of corners")
  }
  let group = PermutationGroup::new(gens)
  {
    original_corners: corners_copy,
    corners: clone_expr_array(corners),
    faces: face_list,
    pgroup_generators: gens,
    pgroup: group,
    edges_cache: None,
  }
}

///|
pub fn Polyhedron::copy(self : Polyhedron) -> Polyhedron {
  {
    original_corners: clone_expr_array(self.original_corners),
    corners: clone_expr_array(self.corners),
    faces: clone_int_arrays(self.faces),
    pgroup_generators: clone_perm_array(self.pgroup_generators),
    pgroup: self.pgroup,
    edges_cache: None,
  }
}

///|
pub fn Polyhedron::corners(self : Polyhedron) -> Array[@symcore.Expr] {
  clone_expr_array(self.corners)
}

///|
pub fn Polyhedron::vertices(self : Polyhedron) -> Array[@symcore.Expr] {
  self.corners()
}

///|
pub fn Polyhedron::array_form(self : Polyhedron) -> Array[Int] raise CombinatoricsError {
  let out : Array[Int] = Array::new()
  for c in self.corners {
    let mut found = false
    let mut idx = 0
    for i in 0..<self.original_corners.length() {
      if self.original_corners[i] == c {
        idx = i
        found = true
        break
      }
    }
    if !found {
      raise CombinatoricsError::ValueError("corner not found in original list")
    }
    out.push(idx)
  }
  out
}

///|
pub fn Polyhedron::cyclic_form(self : Polyhedron) -> Array[Array[Int]] raise CombinatoricsError {
  let perm = Permutation::from_array(self.array_form())
  perm.cyclic_form()
}

///|
pub fn Polyhedron::size(self : Polyhedron) -> Int {
  self.corners.length()
}

///|
pub fn Polyhedron::faces(self : Polyhedron) -> Array[Array[Int]] {
  clone_int_arrays(self.faces)
}

///|
pub fn Polyhedron::pgroup(self : Polyhedron) -> PermutationGroup {
  self.pgroup
}

///|
pub fn Polyhedron::edges(self : Polyhedron) -> Array[(Int, Int)] {
  match self.edges_cache {
    Some(edges) => edges
    None => {
      let seen : Map[String, (Int, Int)] = {}
      for face in self.faces {
        if face.is_empty() {
          continue
        }
        let n = face.length()
        for i in 0..<n {
          let a = face[i]
          let b = if i == 0 { face[n - 1] } else { face[i - 1] }
          let p = if a < b { (a, b) } else { (b, a) }
          let key = "\{p.0},\{p.1}"
          if !seen.contains(key) {
            seen[key] = p
          }
        }
      }
      let out : Array[(Int, Int)] = Array::new()
      for _, v in seen {
        out.push(v)
      }
      let n = out.length()
      for i in 0..<n {
        for j in (i + 1)..<n {
          if out[j].0 < out[i].0 || (out[j].0 == out[i].0 && out[j].1 < out[i].1) {
            let tmp = out[i]
            out[i] = out[j]
            out[j] = tmp
          }
        }
      }
      self.edges_cache = Some(out)
      self.edges_cache.unwrap()
    }
  }
}

///|
pub fn Polyhedron::rotate(self : Polyhedron, arg : PolyRotate) -> Unit raise CombinatoricsError {
  let perm = match arg {
    PolyRotate::Index(i) => {
      if i < 0 || i >= self.pgroup_generators.length() {
        raise CombinatoricsError::ValueError("pgroup index out of range")
      }
      self.pgroup_generators[i]
    }
    PolyRotate::Perm(p) => {
      if p.size() != self.size() {
        raise CombinatoricsError::ValueError("Polyhedron and Permutation sizes differ")
      }
      p
    }
  }
  let rotated = perm.apply_array(self.corners)
  self.corners = rotated
}

///|
pub fn Polyhedron::reset(self : Polyhedron) -> Unit {
  self.corners = clone_expr_array(self.original_corners)
}

///|
fn polyhedron_from_ints(
  corners : Array[Int],
  faces : Array[Array[Int]],
  pgroup_arrays : Array[Array[Int]],
) -> Polyhedron raise CombinatoricsError {
  let corner_exprs = ints_to_exprs(corners)
  let gens : Array[Permutation] = Array::new()
  for arr in pgroup_arrays {
    gens.push(Permutation::from_array(arr))
  }
  Polyhedron::new(corner_exprs, faces=faces, pgroup=gens)
}

///|
// tetrahedron
let tetrahedron_corners = [0, 1, 2, 3]
let tetrahedron_faces = [[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]]
let tetrahedron_pgroup = [[0, 2, 3, 1], [1, 2, 0, 3], [3, 1, 0, 2], [3, 0, 2, 1], [1, 0, 3, 2], [2, 3, 0, 1], [3, 2, 1, 0]]

///|
// cube
let cube_corners = [0, 1, 2, 3, 4, 5, 6, 7]
let cube_faces = [[0, 1, 2, 3], [0, 1, 5, 4], [0, 3, 7, 4], [1, 2, 6, 5], [2, 3, 7, 6], [4, 5, 6, 7]]
let cube_pgroup = [[1, 2, 3, 0, 5, 6, 7, 4], [4, 0, 3, 7, 5, 1, 2, 6], [4, 5, 1, 0, 7, 6, 2, 3], [1, 0, 4, 5, 2, 3, 7, 6], [6, 2, 1, 5, 7, 3, 0, 4], [6, 7, 3, 2, 5, 4, 0, 1], [3, 7, 4, 0, 2, 6, 5, 1], [4, 7, 6, 5, 0, 3, 2, 1], [6, 5, 4, 7, 2, 1, 0, 3], [0, 3, 7, 4, 1, 2, 6, 5], [5, 1, 0, 4, 6, 2, 3, 7], [5, 6, 2, 1, 4, 7, 3, 0], [7, 4, 0, 3, 6, 5, 1, 2]]

///|
// octahedron
let octahedron_corners = [0, 1, 2, 3, 4, 5]
let octahedron_faces = [[0, 1, 2], [0, 1, 4], [0, 2, 3], [0, 3, 4], [1, 2, 5], [1, 4, 5], [2, 3, 5], [3, 4, 5]]
let octahedron_pgroup = [[0, 2, 3, 4, 1, 5], [4, 1, 0, 3, 5, 2], [1, 5, 2, 0, 4, 3], [1, 0, 4, 5, 2, 3], [2, 3, 0, 1, 5, 4], [3, 5, 4, 0, 2, 1], [4, 3, 5, 1, 0, 2], [5, 4, 3, 2, 1, 0], [5, 2, 1, 4, 3, 0], [4, 0, 3, 5, 1, 2], [1, 2, 0, 4, 5, 3], [2, 5, 3, 0, 1, 4], [4, 5, 1, 0, 3, 2]]

///|
// dodecahedron
let dodecahedron_corners = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
let dodecahedron_faces = [[0, 1, 2, 3, 4], [0, 1, 6, 10, 5], [0, 4, 9, 14, 5], [1, 2, 7, 11, 6], [2, 3, 8, 12, 7], [3, 4, 9, 13, 8], [5, 10, 16, 15, 14], [6, 10, 16, 17, 11], [7, 11, 17, 18, 12], [8, 12, 18, 19, 13], [9, 13, 19, 15, 14], [15, 16, 17, 18, 19]]
let dodecahedron_pgroup = [[1, 2, 3, 4, 0, 6, 7, 8, 9, 5, 11, 12, 13, 14, 10, 16, 17, 18, 19, 15], [5, 0, 4, 9, 14, 10, 1, 3, 13, 15, 6, 2, 8, 19, 16, 17, 11, 7, 12, 18], [10, 6, 1, 0, 5, 16, 11, 2, 4, 14, 17, 7, 3, 9, 15, 19, 18, 12, 8, 13], [6, 11, 7, 2, 1, 10, 17, 12, 3, 0, 16, 18, 8, 4, 5, 14, 15, 19, 13, 9], [2, 7, 12, 8, 3, 1, 11, 18, 13, 4, 6, 17, 19, 9, 0, 5, 10, 16, 15, 14], [4, 3, 8, 13, 9, 0, 2, 12, 19, 14, 1, 7, 18, 15, 5, 10, 6, 11, 17, 16], [1, 0, 5, 10, 6, 2, 4, 14, 16, 11, 3, 9, 15, 17, 7, 12, 8, 13, 19, 18], [7, 2, 1, 6, 11, 12, 3, 0, 10, 17, 8, 4, 5, 16, 18, 19, 13, 9, 14, 15], [12, 8, 3, 2, 7, 18, 13, 4, 1, 11, 19, 9, 0, 6, 17, 16, 15, 14, 5, 10], [8, 13, 9, 4, 3, 12, 19, 14, 0, 2, 18, 15, 5, 1, 7, 11, 17, 16, 10, 6], [4, 9, 14, 5, 0, 3, 13, 15, 10, 1, 8, 19, 16, 6, 2, 7, 12, 18, 17, 11], [5, 14, 15, 16, 10, 0, 9, 19, 17, 6, 4, 13, 18, 11, 1, 2, 3, 8, 12, 7], [11, 6, 10, 16, 17, 7, 1, 5, 15, 18, 2, 0, 14, 19, 12, 8, 3, 4, 9, 13], [18, 12, 7, 11, 17, 19, 8, 2, 6, 16, 13, 3, 1, 10, 15, 14, 9, 4, 0, 5], [18, 19, 13, 8, 12, 17, 15, 9, 3, 7, 16, 14, 4, 2, 11, 6, 10, 5, 0, 1], [13, 19, 15, 14, 9, 8, 18, 16, 5, 4, 12, 17, 10, 0, 3, 2, 7, 11, 6, 1], [16, 15, 19, 18, 17, 10, 14, 13, 12, 11, 5, 9, 8, 7, 6, 1, 0, 4, 3, 2], [18, 17, 16, 15, 19, 12, 11, 10, 14, 13, 7, 6, 5, 9, 8, 3, 2, 1, 0, 4], [15, 19, 18, 17, 16, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 0, 4, 3, 2, 1], [17, 16, 15, 19, 18, 11, 10, 14, 13, 12, 6, 5, 9, 8, 7, 2, 1, 0, 4, 3], [19, 18, 17, 16, 15, 13, 12, 11, 10, 14, 8, 7, 6, 5, 9, 4, 3, 2, 1, 0], [0, 4, 9, 14, 5, 1, 3, 13, 15, 10, 2, 8, 19, 16, 6, 11, 7, 12, 18, 17], [6, 1, 0, 5, 10, 11, 2, 4, 14, 16, 7, 3, 9, 15, 17, 18, 12, 8, 13, 19], [11, 7, 2, 1, 6, 17, 12, 3, 0, 10, 18, 8, 4, 5, 16, 15, 19, 13, 9, 14], [7, 12, 8, 3, 2, 11, 18, 13, 4, 1, 17, 19, 9, 0, 6, 10, 16, 15, 14, 5], [3, 8, 13, 9, 4, 2, 12, 19, 14, 0, 7, 18, 15, 5, 1, 6, 11, 17, 16, 10], [14, 9, 13, 19, 15, 5, 4, 8, 18, 16, 0, 3, 12, 17, 10, 6, 1, 2, 7, 11], [16, 10, 5, 14, 15, 17, 6, 0, 9, 19, 11, 1, 4, 13, 18, 12, 7, 2, 3, 8], [16, 17, 11, 6, 10, 15, 18, 7, 1, 5, 19, 12, 2, 0, 14, 9, 13, 8, 3, 4], [11, 17, 18, 12, 7, 6, 16, 19, 8, 2, 10, 15, 13, 3, 1, 0, 5, 14, 9, 4], [8, 12, 18, 19, 13, 3, 7, 17, 15, 9, 2, 11, 16, 14, 4, 0, 1, 6, 10, 5]]

///|
// icosahedron
let icosahedron_corners = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
let icosahedron_faces = [[0, 1, 2], [0, 1, 5], [0, 2, 3], [0, 3, 4], [0, 4, 5], [1, 2, 7], [1, 5, 6], [1, 6, 7], [2, 3, 8], [2, 7, 8], [3, 4, 9], [3, 8, 9], [4, 5, 10], [4, 9, 10], [5, 6, 10], [6, 7, 11], [6, 10, 11], [7, 8, 11], [8, 9, 11], [9, 10, 11]]
let icosahedron_pgroup = [[0, 2, 3, 4, 5, 1, 7, 8, 9, 10, 6, 11], [5, 1, 0, 4, 10, 6, 7, 2, 3, 9, 11, 8], [1, 7, 2, 0, 5, 6, 11, 8, 3, 4, 10, 9], [2, 7, 8, 3, 0, 1, 6, 11, 9, 4, 5, 10], [3, 2, 8, 9, 4, 0, 1, 7, 11, 10, 5, 6], [4, 0, 3, 9, 10, 5, 1, 2, 8, 11, 6, 7], [1, 0, 5, 6, 7, 2, 3, 4, 10, 11, 8, 9], [2, 3, 0, 1, 7, 8, 9, 4, 5, 6, 11, 10], [3, 9, 4, 0, 2, 8, 11, 10, 5, 1, 7, 6], [4, 9, 10, 5, 0, 3, 8, 11, 6, 1, 2, 7], [5, 4, 10, 6, 1, 0, 3, 9, 11, 7, 2, 8], [6, 5, 10, 11, 7, 1, 0, 4, 9, 8, 2, 3], [7, 2, 1, 6, 11, 8, 3, 0, 5, 10, 9, 4], [8, 9, 3, 2, 7, 11, 10, 4, 0, 1, 6, 5], [9, 11, 10, 4, 3, 8, 7, 6, 5, 0, 2, 1], [10, 9, 11, 6, 5, 4, 3, 8, 7, 1, 0, 2], [11, 6, 10, 9, 8, 7, 1, 5, 4, 3, 2, 0], [11, 8, 7, 6, 10, 9, 3, 2, 1, 5, 4, 0], [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0], [11, 7, 6, 10, 9, 8, 2, 1, 5, 4, 3, 0], [11, 9, 8, 7, 6, 10, 4, 3, 2, 1, 5, 0], [5, 0, 4, 10, 6, 1, 2, 3, 9, 11, 7, 8], [1, 2, 0, 5, 6, 7, 8, 3, 4, 10, 11, 9], [2, 8, 3, 0, 1, 7, 11, 9, 4, 5, 6, 10], [3, 8, 9, 4, 0, 2, 7, 11, 10, 5, 1, 6], [4, 3, 9, 10, 5, 0, 2, 8, 11, 6, 1, 7], [10, 5, 4, 9, 11, 6, 1, 0, 3, 8, 7, 2], [6, 7, 1, 5, 10, 11, 8, 2, 0, 4, 9, 3], [7, 11, 8, 2, 1, 6, 10, 9, 3, 0, 5, 4], [8, 7, 11, 9, 3, 2, 1, 6, 10, 4, 0, 5], [9, 3, 8, 11, 10, 4, 0, 2, 7, 6, 5, 1]]

///|
pub let tetrahedron : Polyhedron = try! polyhedron_from_ints(tetrahedron_corners, tetrahedron_faces, tetrahedron_pgroup)

///|
pub let cube : Polyhedron = try! polyhedron_from_ints(cube_corners, cube_faces, cube_pgroup)

///|
pub let octahedron : Polyhedron = try! polyhedron_from_ints(octahedron_corners, octahedron_faces, octahedron_pgroup)

///|
pub let dodecahedron : Polyhedron = try! polyhedron_from_ints(dodecahedron_corners, dodecahedron_faces, dodecahedron_pgroup)

///|
pub let icosahedron : Polyhedron = try! polyhedron_from_ints(icosahedron_corners, icosahedron_faces, icosahedron_pgroup)
