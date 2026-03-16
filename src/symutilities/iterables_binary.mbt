///|\
/// Binary and sign/permutation helpers aligned with the utility iterables
/// helpers from SymPy.

///|
fn ibin_bits(n : Int, bits : Int) -> Array[Int] {
  if bits <= 0 {
    return []
  }
  let out : Array[Int] = []
  for i in 0..<bits {
    let shift = bits - 1 - i
    out.push((n >> shift) & 1)
  }
  out
}

///|
pub fn ibin(n : Int, bits? : Int = -1) -> Array[Int] {
  let width = if bits < 0 {
    let mut w = 1
    let mut value = if n < 0 { -n } else { n }
    while value >= 2 {
      value /= 2
      w += 1
    }
    w
  } else {
    bits
  }
  ibin_bits(n, width)
}

///|
pub fn ibin_str(n : Int, bits? : Int = -1) -> String {
  let values = ibin(n, bits~)
  values.map(x => x.to_string()).join("")
}

///|
pub fn ibin_all(bits : Int) -> Array[Array[Int]] {
  if bits < 0 {
    return []
  }
  let out : Array[Array[Int]] = []
  let stop = 1 << bits
  for i in 0..<stop {
    out.push(ibin(i, bits~))
  }
  out
}

///|
pub fn ibin_all_str(bits : Int) -> Array[String] {
  ibin_all(bits).map(bits0 => bits0.map(bit => bit.to_string()).join(""))
}

///|
fn permute_signs_one(
  values : Array[Int],
  positions : Array[Int],
  index : Int,
  out : Array[Array[Int]],
) -> Unit {
  if index >= positions.length() {
    out.push(values.map(x => x))
    return
  }
  let pos = positions[index]
  permute_signs_one(values, positions, index + 1, out)
  values[pos] = -values[pos]
  permute_signs_one(values, positions, index + 1, out)
  values[pos] = -values[pos]
}

///|
pub fn permute_signs(values : Array[Int]) -> Array[Array[Int]] {
  let nonzero : Array[Int] = []
  for i in 0..<values.length() {
    if values[i] != 0 {
      nonzero.push(i)
    }
  }
  nonzero.rev_in_place()
  let out : Array[Array[Int]] = []
  let seed = values.map(x => x)
  permute_signs_one(seed, nonzero, 0, out)
  out
}

///|
pub fn signed_permutations(values : Array[Int]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  for perm in multiset_permutations(values) {
    for signed in permute_signs(perm) {
      out.push(signed)
    }
  }
  out
}

///|
pub fn binary_partitions(n : Int) -> Array[Array[Int]] {
  if n <= 0 {
    return [[]]
  }
  let highest = 1 << @math.ceil(@math.log2(n.to_double())).to_int()
  let mut power = highest
  let mut acc = 0
  let partition : Array[Int] = []
  while power > 0 {
    if acc + power <= n {
      partition.push(power)
      acc += power
    }
    power /= 2
  }
  let out : Array[Array[Int]] = []
  letrec step = (current : Array[Int]) => {
    out.push(current.map(x => x))
    let mut split_at = -1
    for i in 0..<current.length() {
      if current[i] > 1 {
        split_at = i
      }
    }
    if split_at < 0 {
      return
    }
    let next = current.map(x => x)
    let value = next[split_at] / 2
    next[split_at] = value
    next.insert(split_at + 1, value)
    next.sort_by((a, b) => b - a)
    step(next)
  }
  step(partition)
  out
}

///|
pub fn[T : Compare] minlex(seq : Array[T], directed? : Bool = true) -> Array[T] {
  if seq.is_empty() {
    return []
  }
  let best = rotate_left(seq, least_rotation(seq))
  if directed {
    return best
  }
  let reversed = seq.rev()
  let alt = rotate_left(reversed, least_rotation(reversed))
  if alt.compare(best) < 0 {
    alt
  } else {
    best
  }
}

///|
fn necklaces_rec(
  length : Int,
  colors : Int,
  current : Array[Int],
  out : Array[Array[Int]],
  free : Bool,
) -> Unit {
  if current.length() == length {
    let canonical = minlex(current, directed=!free)
    if current == canonical {
      out.push(current.map(x => x))
    }
    return
  }
  for color in 0..<colors {
    current.push(color)
    necklaces_rec(length, colors, current, out, free)
    ignore(current.pop())
  }
}

///|
pub fn necklaces(
  length : Int,
  colors : Int,
  free? : Bool = false,
) -> Array[Array[Int]] {
  if length < 0 || colors < 0 {
    return []
  }
  if length == 0 {
    return [[]]
  }
  let out : Array[Array[Int]] = []
  necklaces_rec(length, colors, [], out, free)
  out
}

///|
pub fn bracelets(length : Int, colors : Int) -> Array[Array[Int]] {
  necklaces(length, colors, free=true)
}
