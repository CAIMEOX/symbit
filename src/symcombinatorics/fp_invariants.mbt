///|
/// Abelian invariants for finitely presented groups.

///|
fn abs_int(x : Int) -> Int {
  if x < 0 {
    -x
  } else {
    x
  }
}

///|
fn gcd_int_local_inv(a0 : Int, b0 : Int) -> Int {
  let mut a = if a0 < 0 { -a0 } else { a0 }
  let mut b = if b0 < 0 { -b0 } else { b0 }
  while b != 0 {
    let t = a % b
    a = b
    b = t
  }
  a
}

///|
fn identity_matrix(n : Int) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for i in 0..<n {
    let row : Array[Int] = Array::make(n, 0)
    row[i] = 1
    out.push(row)
  }
  out
}

///|
fn copy_matrix(mat : Array[Array[Int]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for row in mat {
    let r : Array[Int] = Array::new()
    for v in row {
      r.push(v)
    }
    out.push(r)
  }
  out
}

///|
fn swap_rows(mat : Array[Array[Int]], i : Int, k : Int) -> Unit {
  if i == k {
    return
  }
  let tmp = mat[i]
  mat[i] = mat[k]
  mat[k] = tmp
}

///|
fn swap_cols(mat : Array[Array[Int]], j : Int, k : Int) -> Unit {
  if j == k {
    return
  }
  for row in mat {
    let tmp = row[j]
    row[j] = row[k]
    row[k] = tmp
  }
}

///|
fn mul_row(mat : Array[Array[Int]], i : Int, k : Int) -> Unit {
  if k == 1 {
    return
  }
  for j in 0..<mat[i].length() {
    mat[i][j] = mat[i][j] * k
  }
}

///|
fn add_row(mat : Array[Array[Int]], src : Int, dst : Int, k : Int) -> Unit {
  if k == 0 {
    return
  }
  let row_src = mat[src]
  let row_dst = mat[dst]
  for j in 0..<row_dst.length() {
    row_dst[j] = row_dst[j] + k * row_src[j]
  }
}

///|
fn add_col(mat : Array[Array[Int]], src : Int, dst : Int, k : Int) -> Unit {
  if k == 0 {
    return
  }
  for i in 0..<mat.length() {
    mat[i][dst] = mat[i][dst] + k * mat[i][src]
  }
}

///|
fn smith_normal_form_with_transform(
  mat_in : Array[Array[Int]],
) -> (Array[Int], Array[Array[Int]]) {
  let mat = copy_matrix(mat_in)
  if mat.is_empty() {
    return ([], identity_matrix(0))
  }
  let m = mat.length()
  let n = mat[0].length()
  let v = identity_matrix(n)
  let mut i = 0
  let mut j = 0
  while i < m && j < n {
    // find nonzero pivot with minimal abs value
    let mut pivot_i = -1
    let mut pivot_j = -1
    let mut best = 0
    for r in i..<m {
      for c in j..<n {
        let v0 = mat[r][c]
        if v0 != 0 {
          let av = abs_int(v0)
          if best == 0 || av < best {
            best = av
            pivot_i = r
            pivot_j = c
          }
        }
      }
    }
    if pivot_i < 0 {
      break
    }
    swap_rows(mat, i, pivot_i)
    swap_cols(mat, j, pivot_j)
    swap_cols(v, j, pivot_j)
    if mat[i][j] < 0 {
      mul_row(mat, i, -1)
    }

    // reduce until pivot divides all entries in its row/col
    let mut changed = true
    while changed {
      changed = false
      // reduce column entries
      for r in 0..<m {
        if r == i {
          continue
        }
        if mat[r][j] != 0 {
          let a = mat[i][j]
          let b = mat[r][j]
          let q = b / a
          add_row(mat, i, r, -q)
          if abs_int(mat[r][j]) < abs_int(mat[i][j]) {
            swap_rows(mat, i, r)
            changed = true
          }
        }
      }
      // reduce row entries
      for c in 0..<n {
        if c == j {
          continue
        }
        if mat[i][c] != 0 {
          let a = mat[i][j]
          let b = mat[i][c]
          let q = b / a
          add_col(mat, j, c, -q)
          add_col(v, j, c, -q)
          if abs_int(mat[i][c]) < abs_int(mat[i][j]) {
            swap_cols(mat, j, c)
            swap_cols(v, j, c)
            changed = true
          }
        }
      }
      // ensure divisibility in submatrix
      let pivot = mat[i][j]
      if pivot != 0 {
        for r in (i + 1)..<m {
          for c in (j + 1)..<n {
            if mat[r][c] % pivot != 0 {
              add_row(mat, r, i, 1)
              changed = true
              break
            }
          }
          if changed {
            break
          }
        }
      }
    }

    // clear column and row
    for r in 0..<m {
      if r == i {
        continue
      }
      if mat[r][j] != 0 {
        let q = mat[r][j] / mat[i][j]
        add_row(mat, i, r, -q)
      }
    }
    for c in 0..<n {
      if c == j {
        continue
      }
      if mat[i][c] != 0 {
        let q = mat[i][c] / mat[i][j]
        add_col(mat, j, c, -q)
        add_col(v, j, c, -q)
      }
    }
    i = i + 1
    j = j + 1
  }
  let diag : Array[Int] = Array::new()
  let r = if m < n { m } else { n }
  for k in 0..<r {
    let val = mat[k][k]
    if val != 0 {
      diag.push(if val < 0 { -val } else { val })
    }
  }
  // ensure divisibility chain (best effort)
  let mut idx = 0
  while idx + 1 < diag.length() {
    if diag[idx + 1] % diag[idx] != 0 {
      let g = gcd_int_local_inv(diag[idx], diag[idx + 1])
      diag[idx] = g
      diag[idx + 1] = diag[idx + 1] / g * diag[idx]
    }
    idx = idx + 1
  }
  (diag, v)
}

///|
pub struct AbelianInvariants {
  rank : Int
  torsion : Array[Int]
  basis : Array[Array[Int]]
}

///|
fn relation_matrix(fp : FpGroup) -> Array[Array[Int]] {
  let n = fp.generators.length()
  let rows : Array[Array[Int]] = Array::new()
  for rel in fp.relators {
    let row : Array[Int] = Array::make(n, 0)
    for pair in rel.array_form() {
      row[pair.0] = row[pair.0] + pair.1
    }
    rows.push(row)
  }
  rows
}

///|
pub fn fp_group_abelian_invariants(fp : FpGroup) -> AbelianInvariants {
  let n = fp.generators.length()
  let mat = relation_matrix(fp)
  if mat.is_empty() {
    return { rank: n, torsion: [], basis: identity_matrix(n) }
  }
  let (diag, basis) = smith_normal_form_with_transform(mat)
  let torsion : Array[Int] = Array::new()
  for d in diag {
    if d > 1 {
      torsion.push(d)
    }
  }
  let rank = n - diag.length()
  { rank, torsion, basis }
}

///|
pub fn fp_group_abelian_quotient_moduli(
  fp : FpGroup,
  free_mod? : Int = 2,
) -> (Array[Int], Array[Array[Int]]) {
  let n = fp.generators.length()
  let inv = fp_group_abelian_invariants(fp)
  let moduli : Array[Int] = Array::make(n, 1)
  let torsion = inv.torsion
  let torsion_len = torsion.length()
  let free_rank = inv.rank
  let mut i = 0
  while i < torsion_len {
    moduli[i] = torsion[i]
    i = i + 1
  }
  let fm = if free_mod <= 0 { 2 } else { free_mod }
  let mut j = 0
  while j < free_rank {
    moduli[torsion_len + j] = fm
    j = j + 1
  }
  (moduli, inv.basis)
}
