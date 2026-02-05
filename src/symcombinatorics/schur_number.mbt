///|
/// Schur numbers and partitions.

///|
pub fn schur_number(k : Int) -> Int? raise CombinatoricsError {
  if k < 0 {
    raise CombinatoricsError::ValueError("k should be a positive integer")
  }
  if k == 0 {
    return Some(0)
  }
  let known : Map[Int, Int] = { 1: 1, 2: 4, 3: 13, 4: 44, 5: 160 }
  match known.get(k) {
    Some(v) => Some(v)
    None => None
  }
}

///|
pub fn schur_number_lower_bound(k : Int) -> Int raise CombinatoricsError {
  if k < 0 {
    raise CombinatoricsError::ValueError("k should be a positive integer")
  }
  if k == 0 {
    return 0
  }
  match schur_number(k) {
    Some(v) => return v
    None => ()
  }
  if k == 6 {
    return 536
  }
  if k == 7 {
    return 1680
  }
  if k >= 1 {
    return 3 * schur_number_lower_bound(k - 1) - 1
  }
  0
}

///|
fn schur_subsets_number(n : Int) -> Int raise CombinatoricsError {
  if n <= 0 {
    raise CombinatoricsError::ValueError("n must be a non-zero positive integer.")
  }
  if n <= 3 {
    return 1
  }
  let mut k = 1
  let mut threshold = 3
  let target = 2 * n + 1
  while threshold < target {
    threshold = threshold * 3
    k = k + 1
  }
  k
}

///|
fn generate_next_list(current_list : Array[Array[Int]], n : Int) -> Array[Array[Int]] {
  let new_list : Array[Array[Int]] = Array::new()
  for item in current_list {
    let temp1 : Array[Int] = Array::new()
    let temp2 : Array[Int] = Array::new()
    for number in item {
      let v1 = number * 3
      if v1 <= n {
        temp1.push(v1)
      }
      let v2 = number * 3 - 1
      if v2 <= n {
        temp2.push(v2)
      }
    }
    for v in temp2 {
      temp1.push(v)
    }
    new_list.push(temp1)
  }
  let last_list : Array[Int] = Array::new()
  let mut k = 0
  while k <= current_list.length() {
    let v = 3 * k + 1
    if v <= n {
      last_list.push(v)
    }
    k = k + 1
  }
  new_list.push(last_list)
  new_list
}

///|
pub fn schur_partition(n : Int) -> Array[Array[Int]] raise CombinatoricsError {
  let number_of_subsets = schur_subsets_number(n)
  let sum_free_subsets : Array[Array[Int]] =
    if n == 1 {
      [[1]]
    } else if n == 2 {
      [[1, 2]]
    } else if n == 3 {
      [[1, 2, 3]]
    } else {
      [[1, 4], [2, 3]]
    }
  let mut subsets = sum_free_subsets
  while subsets.length() < number_of_subsets {
    subsets = generate_next_list(subsets, n)
    let missed : Array[Int] = Array::new()
    let start = subsets.length()
    let end = (n - 1) / 3
    if start <= end {
      for k in start..=end {
        missed.push(3 * k + 1)
      }
    }
    let last_idx = subsets.length() - 1
    for v in missed {
      subsets[last_idx].push(v)
    }
  }
  subsets
}
