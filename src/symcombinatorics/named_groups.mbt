///|
/// Named permutation groups.

///|
pub fn abelian_group(
  cyclic_orders : Array[Int],
) -> PermutationGroup raise CombinatoricsError {
  let groups : Array[PermutationGroup] = Array::new()
  let mut order = 1
  for size in cyclic_orders {
    order = order * size
    groups.push(cyclic_group(size))
  }
  let g = direct_product(groups)
  g.is_abelian_cache = Some(true)
  g.is_solvable_cache = Some(true)
  g.is_nilpotent_cache = Some(true)
  g.order_cache = Some(order)
  g
}

///|
pub fn alternating_group(n : Int) -> PermutationGroup raise CombinatoricsError {
  if n == 1 || n == 2 {
    return PermutationGroup::new([Permutation::from_array([0])])
  }
  let a : Array[Int] = Array::new()
  for i in 0..<n {
    a.push(i)
  }
  let tmp = a[0]
  a[0] = a[1]
  a[1] = a[2]
  a[2] = tmp
  let gen1 = Permutation::from_array(a)
  let gen2 = if n % 2 == 1 {
    let b : Array[Int] = Array::new()
    for i in 1..<n {
      b.push(i)
    }
    b.push(0)
    Permutation::from_array(b)
  } else {
    let b : Array[Int] = Array::new()
    b.push(0)
    for i in 2..<n {
      b.push(i)
    }
    b.push(1)
    Permutation::from_array(b)
  }
  let mut gens : Array[Permutation] = [gen1, gen2]
  let g1 = gen1.array_form()
  let g2 = gen2.array_form()
  if g1.length() == g2.length() {
    let mut same = true
    for i in 0..<g1.length() {
      if g1[i] != g2[i] {
        same = false
        break
      }
    }
    if same {
      gens = [gen1]
    }
  }
  let g = PermutationGroup::new(gens, dups=false)
  if n < 4 {
    g.is_abelian_cache = Some(true)
    g.is_nilpotent_cache = Some(true)
  } else {
    g.is_abelian_cache = Some(false)
    g.is_nilpotent_cache = Some(false)
  }
  if n < 5 {
    g.is_solvable_cache = Some(true)
  } else {
    g.is_solvable_cache = Some(false)
  }
  g.is_transitive_cache = Some(true)
  g.is_dihedral_cache = Some(false)
  g.is_alternating_cache = Some(true)
  g
}

///|
pub fn cyclic_group(n : Int) -> PermutationGroup raise CombinatoricsError {
  let a : Array[Int] = Array::new()
  for i in 1..<n {
    a.push(i)
  }
  a.push(0)
  let gen = Permutation::from_array(a)
  let g = PermutationGroup::new([gen])
  g.is_abelian_cache = Some(true)
  g.is_nilpotent_cache = Some(true)
  g.is_solvable_cache = Some(true)
  g.is_transitive_cache = Some(true)
  g.order_cache = Some(n)
  g.is_dihedral_cache = Some(n == 2)
  g.is_cyclic_cache = Some(true)
  g
}

///|
pub fn dihedral_group(n : Int) -> PermutationGroup raise CombinatoricsError {
  if n == 1 {
    return PermutationGroup::new([Permutation::from_array([1, 0])])
  }
  if n == 2 {
    return PermutationGroup::new([
      Permutation::from_array([1, 0, 3, 2]),
      Permutation::from_array([2, 3, 0, 1]),
      Permutation::from_array([3, 2, 1, 0]),
    ])
  }
  let a : Array[Int] = Array::new()
  for i in 1..<n {
    a.push(i)
  }
  a.push(0)
  let gen1 = Permutation::from_array(a)
  let b : Array[Int] = Array::new()
  for i in 0..<n {
    b.push(n - 1 - i)
  }
  let gen2 = Permutation::from_array(b)
  let g = PermutationGroup::new([gen1, gen2])
  if (n & (n - 1)) == 0 {
    g.is_nilpotent_cache = Some(true)
  } else {
    g.is_nilpotent_cache = Some(false)
  }
  g.is_dihedral_cache = Some(true)
  g.is_abelian_cache = Some(false)
  g.is_solvable_cache = Some(true)
  g.is_transitive_cache = Some(true)
  g.order_cache = Some(2 * n)
  g
}

///|
pub fn symmetric_group(n : Int) -> PermutationGroup raise CombinatoricsError {
  let g = if n == 1 {
    PermutationGroup::new([Permutation::from_array([0])])
  } else if n == 2 {
    PermutationGroup::new([Permutation::from_array([1, 0])])
  } else {
    let a : Array[Int] = Array::new()
    for i in 1..<n {
      a.push(i)
    }
    a.push(0)
    let gen1 = Permutation::from_array(a)
    let b : Array[Int] = Array::new()
    for i in 0..<n {
      b.push(i)
    }
    let tmp = b[0]
    b[0] = b[1]
    b[1] = tmp
    let gen2 = Permutation::from_array(b)
    PermutationGroup::new([gen1, gen2])
  }
  if n < 3 {
    g.is_abelian_cache = Some(true)
    g.is_nilpotent_cache = Some(true)
  } else {
    g.is_abelian_cache = Some(false)
    g.is_nilpotent_cache = Some(false)
  }
  if n < 5 {
    g.is_solvable_cache = Some(true)
  } else {
    g.is_solvable_cache = Some(false)
  }
  g.is_transitive_cache = Some(true)
  g.is_dihedral_cache = Some(n == 2 || n == 3)
  g.is_symmetric_cache = Some(true)
  g
}

///|
pub fn rubik_group(n : Int) -> PermutationGroup raise CombinatoricsError {
  if n <= 1 {
    raise CombinatoricsError::ValueError(
      "Invalid cube. n has to be greater than 1",
    )
  }
  PermutationGroup::new(rubik(n))
}
