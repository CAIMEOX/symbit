///|
/// Type E simple Lie algebra data.

///|
pub fn type_e_dimension(_n : Int) -> Int {
  8
}

///|
pub fn type_e_basic_root(i : Int, j : Int) -> RootVector {
  let root = vec_zero(8)
  root[i] = br_int(-1)
  root[j] = br_int(1)
  root
}

///|
pub fn type_e_simple_root(n : Int, i : Int) -> RootVector raise {
  if i == 1 {
    let root = Array::make(8, br_rat(-1, 2))
    root[0] = br_rat(1, 2)
    root[7] = br_rat(1, 2)
    return root
  }
  if i == 2 {
    let root = vec_zero(8)
    root[1] = br_int(1)
    root[0] = br_int(1)
    return root
  }
  if (i == 7 || i == 8) && n == 6 {
    fail("E6 only has six simple roots!")
  }
  if i == 8 && n == 7 {
    fail("E7 only has seven simple roots!")
  }
  type_e_basic_root(i - 3, i - 2)
}

///|
pub fn type_e_positive_roots(n : Int) -> Map[Int, RootVector] {
  let poshalf = br_rat(1, 2)
  let neghalf = br_rat(-1, 2)
  if n == 6 {
    let posroots : Map[Int, RootVector] = {}
    let mut k = 0
    for i in 0..<(n - 1) {
      for j in (i + 1)..<(n - 1) {
        k += 1
        let root = type_e_basic_root(i, j)
        posroots[k] = root
        k += 1
        let root2 = vec_copy(root)
        root2[i] = br_int(1)
        posroots[k] = root2
      }
    }
    let root = [
      poshalf, poshalf, poshalf, poshalf, poshalf, neghalf, neghalf, poshalf,
    ]
    for a in 0..<=1 {
      for b in 0..<=1 {
        for c in 0..<=1 {
          for d in 0..<=1 {
            for e in 0..<=1 {
              if (a + b + c + d + e) % 2 == 0 {
                k += 1
                if a == 1 {
                  root[0] = neghalf
                }
                if b == 1 {
                  root[1] = neghalf
                }
                if c == 1 {
                  root[2] = neghalf
                }
                if d == 1 {
                  root[3] = neghalf
                }
                if e == 1 {
                  root[4] = neghalf
                }
                posroots[k] = vec_copy(root)
              }
            }
          }
        }
      }
    }
    return posroots
  }
  if n == 7 {
    let posroots : Map[Int, RootVector] = {}
    let mut k = 0
    for i in 0..<(n - 1) {
      for j in (i + 1)..<(n - 1) {
        k += 1
        let root = type_e_basic_root(i, j)
        posroots[k] = root
        k += 1
        let root2 = vec_copy(root)
        root2[i] = br_int(1)
        posroots[k] = root2
      }
    }
    k += 1
    posroots[k] = vec_from_ints([0, 0, 0, 0, 0, 1, 1, 0])
    let root = [
      poshalf, poshalf, poshalf, poshalf, poshalf, neghalf, neghalf, poshalf,
    ]
    for a in 0..<=1 {
      for b in 0..<=1 {
        for c in 0..<=1 {
          for d in 0..<=1 {
            for e in 0..<=1 {
              for f in 0..<=1 {
                if (a + b + c + d + e + f) % 2 == 0 {
                  k += 1
                  if a == 1 {
                    root[0] = neghalf
                  }
                  if b == 1 {
                    root[1] = neghalf
                  }
                  if c == 1 {
                    root[2] = neghalf
                  }
                  if d == 1 {
                    root[3] = neghalf
                  }
                  if e == 1 {
                    root[4] = neghalf
                  }
                  if f == 1 {
                    root[5] = poshalf
                  }
                  posroots[k] = vec_copy(root)
                }
              }
            }
          }
        }
      }
    }
    return posroots
  }
  let posroots : Map[Int, RootVector] = {}
  let mut k = 0
  for i in 0..<n {
    for j in (i + 1)..<n {
      k += 1
      let root = type_e_basic_root(i, j)
      posroots[k] = root
      k += 1
      let root2 = vec_copy(root)
      root2[i] = br_int(1)
      posroots[k] = root2
    }
  }
  let root = [
    poshalf, poshalf, poshalf, poshalf, poshalf, neghalf, neghalf, poshalf,
  ]
  for a in 0..<=1 {
    for b in 0..<=1 {
      for c in 0..<=1 {
        for d in 0..<=1 {
          for e in 0..<=1 {
            for f in 0..<=1 {
              for g in 0..<=1 {
                if (a + b + c + d + e + f + g) % 2 == 0 {
                  k += 1
                  if a == 1 {
                    root[0] = neghalf
                  }
                  if b == 1 {
                    root[1] = neghalf
                  }
                  if c == 1 {
                    root[2] = neghalf
                  }
                  if d == 1 {
                    root[3] = neghalf
                  }
                  if e == 1 {
                    root[4] = neghalf
                  }
                  if f == 1 {
                    root[5] = poshalf
                  }
                  if g == 1 {
                    root[6] = poshalf
                  }
                  posroots[k] = vec_copy(root)
                }
              }
            }
          }
        }
      }
    }
  }
  posroots
}

///|
pub fn type_e_roots(n : Int) -> Int {
  if n == 6 {
    return 72
  }
  if n == 7 {
    return 126
  }
  240
}

///|
pub fn type_e_basis(n : Int) -> Int {
  if n == 6 {
    return 78
  }
  if n == 7 {
    return 133
  }
  248
}

///|
pub fn type_e_dynkin_diagram(n : Int) -> String {
  dynkin_type_e(n)
}
