///|
/// Group generators and combinatorial generators.

///|
fn rotate_left_ints(values : Array[Int], k : Int) -> Array[Int] {
  if values.is_empty() {
    return values
  }
  let n = values.length()
  let shift = ((k % n) + n) % n
  let out : Array[Int] = Array::new()
  for i in 0..<n {
    out.push(values[(i + shift) % n])
  }
  out
}

///|
fn reverse_ints(values : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new()
  if values.is_empty() {
    return out
  }
  let mut i = values.length() - 1
  while i >= 0 {
    out.push(values[i])
    if i == 0 {
      break
    }
    i = i - 1
  }
  out
}

///|
fn insert_at(values : Array[Int], idx : Int, value : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for i in 0..<values.length() {
    if i == idx {
      out.push(value)
    }
    out.push(values[i])
  }
  if idx >= values.length() {
    out.push(value)
  }
  out
}

///|
fn permutations_of_range(n : Int) -> Array[Array[Int]] {
  if n <= 0 {
    return [ [] ]
  }
  let prev = permutations_of_range(n - 1)
  let out : Array[Array[Int]] = Array::new()
  for perm in prev {
    for pos in 0..=perm.length() {
      out.push(insert_at(perm, pos, n - 1))
    }
  }
  out
}

///|
pub fn symmetric(n : Int) -> Array[Permutation] raise CombinatoricsError {
  let perms = permutations_of_range(n)
  let out : Array[Permutation] = Array::new()
  for p in perms {
    out.push(Permutation::from_array(p))
  }
  out
}

///|
pub fn alternating(n : Int) -> Array[Permutation] raise CombinatoricsError {
  let perms = permutations_of_range(n)
  let out : Array[Permutation] = Array::new()
  for p in perms {
    let perm = Permutation::from_array(p)
    if perm.is_even() {
      out.push(perm)
    }
  }
  out
}

///|
pub fn cyclic(n : Int) -> Array[Permutation] raise CombinatoricsError {
  let gen : Array[Int] = Array::new()
  for i in 0..<n {
    gen.push(i)
  }
  let out : Array[Permutation] = Array::new()
  let mut curr = gen
  for _ in 0..<n {
    out.push(Permutation::from_array(curr))
    curr = rotate_left_ints(curr, 1)
  }
  out
}

///|
pub fn dihedral(n : Int) -> Array[Permutation] raise CombinatoricsError {
  let out : Array[Permutation] = Array::new()
  if n == 1 {
    out.push(Permutation::from_array([0, 1]))
    out.push(Permutation::from_array([1, 0]))
    return out
  }
  if n == 2 {
    out.push(Permutation::from_array([0, 1, 2, 3]))
    out.push(Permutation::from_array([1, 0, 3, 2]))
    out.push(Permutation::from_array([2, 3, 0, 1]))
    out.push(Permutation::from_array([3, 2, 1, 0]))
    return out
  }
  let gen : Array[Int] = Array::new()
  for i in 0..<n {
    gen.push(i)
  }
  let mut curr = gen
  for _ in 0..<n {
    out.push(Permutation::from_array(curr))
    out.push(Permutation::from_array(reverse_ints(curr)))
    curr = rotate_left_ints(curr, 1)
  }
  out
}

///|
pub fn rubik_cube_generators() -> Array[Permutation] raise CombinatoricsError {
  let raw : Array[Array[Array[Int]]] = [
    [
      [1, 3, 8, 6], [2, 5, 7, 4], [9, 33, 25, 17], [10, 34, 26, 18],
      [11, 35, 27, 19],
    ],
    [
      [9, 11, 16, 14], [10, 13, 15, 12], [1, 17, 41, 40], [4, 20, 44, 37],
      [6, 22, 46, 35],
    ],
    [
      [17, 19, 24, 22], [18, 21, 23, 20], [6, 25, 43, 16], [7, 28, 42, 13],
      [8, 30, 41, 11],
    ],
    [
      [25, 27, 32, 30], [26, 29, 31, 28], [3, 38, 43, 19], [5, 36, 45, 21],
      [8, 33, 48, 24],
    ],
    [
      [33, 35, 40, 38], [34, 37, 39, 36], [3, 9, 46, 32], [2, 12, 47, 29],
      [1, 14, 48, 27],
    ],
    [
      [41, 43, 48, 46], [42, 45, 47, 44], [14, 22, 30, 38],
      [15, 23, 31, 39], [16, 24, 32, 40],
    ],
  ]
  let out : Array[Permutation] = Array::new()
  for face in raw {
    let cycles : Array[Array[Int]] = Array::new()
    for cycle in face {
      let adjusted : Array[Int] = Array::new()
      for v in cycle {
        adjusted.push(v - 1)
      }
      cycles.push(adjusted)
    }
    out.push(Permutation::from_cycles(cycles, size=48))
  }
  out
}

///|
pub fn rubik(n : Int) -> Array[Permutation] raise CombinatoricsError {
  if n < 2 {
    raise CombinatoricsError::ValueError("dimension of cube must be > 1")
  }
  let total = 6 * n * n
  let faces : Array[Array[Int]] = Array::new()
  let mut count = 0
  for _ in 0..<6 {
    let face : Array[Int] = Array::new()
    for _ in 0..<(n * n) {
      face.push(count)
      count = count + 1
    }
    faces.push(face)
  }
  let u = 0
  let f = 1
  let r = 2
  let b = 3
  let l = 4
  let d = 5

  fn idx(n0 : Int, r : Int, c : Int) -> Int {
    r * n0 + c
  }

  fn get_row(face : Array[Int], n0 : Int, r : Int) -> Array[Int] {
    let out : Array[Int] = Array::new()
    for c in 0..<n0 {
      out.push(face[idx(n0, r, c)])
    }
    out
  }

  fn get_col(face : Array[Int], n0 : Int, c : Int) -> Array[Int] {
    let out : Array[Int] = Array::new()
    for r in 0..<n0 {
      out.push(face[idx(n0, r, c)])
    }
    out
  }

  fn set_row(face : Array[Int], n0 : Int, r : Int, values : Array[Int]) -> Unit {
    for c in 0..<n0 {
      face[idx(n0, r, c)] = values[c]
    }
  }

  fn set_col(face : Array[Int], n0 : Int, c : Int, values : Array[Int]) -> Unit {
    for r in 0..<n0 {
      face[idx(n0, r, c)] = values[r]
    }
  }

  fn reverse_vals(values : Array[Int]) -> Array[Int] {
    reverse_ints(values)
  }

  fn cw(face : Array[Int], n0 : Int, r : Int) -> Array[Int] {
    let mut f = face
    for _ in 0..<r {
      let out : Array[Int] = Array::new()
      for c in 0..<n0 {
        let mut r0 = n0 - 1
        while r0 >= 0 {
          out.push(f[idx(n0, r0, c)])
          if r0 == 0 {
            break
          }
          r0 = r0 - 1
        }
      }
      f = out
    }
    f
  }

  fn ccw(face : Array[Int], n0 : Int) -> Array[Int] {
    cw(face, n0, 3)
  }

  // plane rotations
  fn fcw(
    faces0 : Array[Array[Int]],
    n0 : Int,
    i0 : Int,
    r : Int,
  ) -> Unit {
    for _ in 0..<r {
      if i0 == 0 {
        faces0[f] = cw(faces0[f], n0, 1)
      }
      let i1 = i0 + 1
      let temp = get_col(faces0[l], n0, n0 - i1)
      set_col(faces0[l], n0, n0 - i1, get_row(faces0[d], n0, i1 - 1))
      set_row(
        faces0[d],
        n0,
        i1 - 1,
        reverse_vals(get_col(faces0[r], n0, i1 - 1)),
      )
      set_col(faces0[r], n0, i1 - 1, get_row(faces0[u], n0, n0 - i1))
      set_row(faces0[u], n0, n0 - i1, reverse_vals(temp))
    }
  }

  fn fccw(faces0 : Array[Array[Int]], n0 : Int, i0 : Int) -> Unit {
    fcw(faces0, n0, i0, 3)
  }

  fn cube_f_cw(faces0 : Array[Array[Int]], n0 : Int, r : Int) -> Unit {
    for _ in 0..<r {
      faces0[f] = cw(faces0[f], n0, 1)
      faces0[b] = ccw(faces0[b], n0)
      faces0[u] = cw(faces0[u], n0, 1)
      let t = faces0[u]
      faces0[u] = faces0[l]
      faces0[l] = faces0[d]
      faces0[d] = faces0[r]
      faces0[r] = t
    }
  }

  fn cube_f_ccw(faces0 : Array[Array[Int]], n0 : Int) -> Unit {
    cube_f_cw(faces0, n0, 3)
  }

  fn cube_u_cw(faces0 : Array[Array[Int]], n0 : Int, r : Int) -> Unit {
    for _ in 0..<r {
      faces0[u] = cw(faces0[u], n0, 1)
      faces0[d] = ccw(faces0[d], n0)
      let t = faces0[f]
      faces0[f] = faces0[r]
      faces0[r] = faces0[b]
      faces0[b] = faces0[l]
      faces0[l] = t
    }
  }

  fn cube_u_ccw(faces0 : Array[Array[Int]], n0 : Int) -> Unit {
    cube_u_cw(faces0, n0, 3)
  }

  let g : Array[Permutation] = Array::new()
  let identity : Array[Int] = Array::new()
  for i in 0..<total {
    identity.push(i)
  }

  fn perm(faces0 : Array[Array[Int]], show : Bool) -> Array[Int]? raise CombinatoricsError {
    let p : Array[Int] = Array::new()
    for face in [u, f, r, b, l, d] {
      for v in faces0[face] {
        p.push(v)
      }
    }
    if show {
      return Some(p)
    }
    g.push(Permutation::from_array(p))
    None
  }

  // F slices
  for i in 0..<(n - 1) {
    fcw(faces, n, i, 1)
    let _ = perm(faces, false)
    fccw(faces, n, i)
  }
  let check = perm(faces, true)
  if check is Some(p) && p != identity {
    raise CombinatoricsError::ValueError("rubik identity check failed")
  }

  // R slices
  cube_u_cw(faces, n, 1)
  for i in 0..<(n - 1) {
    fcw(faces, n, i, 1)
    cube_u_ccw(faces, n)
    let _ = perm(faces, false)
    cube_u_cw(faces, n, 1)
    fccw(faces, n, i)
  }
  cube_u_ccw(faces, n)
  let check2 = perm(faces, true)
  if check2 is Some(p2) && p2 != identity {
    raise CombinatoricsError::ValueError("rubik identity check failed")
  }

  // D slices
  cube_f_cw(faces, n, 1)
  cube_u_ccw(faces, n)
  cube_f_ccw(faces, n)
  for i in 0..<(n - 1) {
    fcw(faces, n, i, 1)
    cube_f_cw(faces, n, 1)
    cube_u_cw(faces, n, 1)
    cube_f_ccw(faces, n)
    let _ = perm(faces, false)
    cube_f_cw(faces, n, 1)
    cube_u_ccw(faces, n)
    cube_f_ccw(faces, n)
    fccw(faces, n, i)
  }
  cube_f_cw(faces, n, 1)
  cube_u_cw(faces, n, 1)
  cube_f_ccw(faces, n)
  let check3 = perm(faces, true)
  if check3 is Some(p3) && p3 != identity {
    raise CombinatoricsError::ValueError("rubik identity check failed")
  }

  g
}
