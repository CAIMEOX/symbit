///|\
/// Integer partition helpers aligned with the high-value subset of
/// `sympy.utilities.iterables`.

///|
pub enum PartitionResult {
  Parts(Map[Int, Int])
  Sized(Int, Map[Int, Int])
} derive(Eq)

///|
fn partition_counts(parts : Array[Int]) -> Map[Int, Int] {
  let out : Map[Int, Int] = Map([])
  for part in parts {
    out[part] = match out.get(part) {
      Some(count) => count + 1
      None => 1
    }
  }
  out
}

///|
fn generate_partitions(
  remaining : Int,
  max_part : Int,
  parts_left : Int?,
  acc : Array[Int],
  out : Array[Array[Int]],
  max_keys : Int,
) -> Unit {
  if remaining == 0 {
    match parts_left {
      Some(rest) if rest != 0 => ()
      _ => out.push(acc.map(x => x))
    }
    return
  }
  let max_now = if max_part < remaining { max_part } else { remaining }
  for part in 1..<=max_now {
    let candidate = max_now - (part - 1)
    if candidate > max_keys {
      continue
    }
    match parts_left {
      Some(rest) if rest <= 0 => continue
      Some(rest) => {
        acc.push(candidate)
        generate_partitions(
          remaining - candidate,
          candidate,
          Some(rest - 1),
          acc,
          out,
          max_keys,
        )
        ignore(acc.pop())
      }
      None => {
        acc.push(candidate)
        generate_partitions(
          remaining - candidate,
          candidate,
          None,
          acc,
          out,
          max_keys,
        )
        ignore(acc.pop())
      }
    }
  }
}

///|
pub fn partitions(
  n : Int,
  m? : Int? = None,
  k? : Int? = None,
  size? : Bool = false,
) -> Array[PartitionResult] {
  if n <= 0 ||
    (m is Some(limit) && limit < 1) ||
    (k is Some(limit) && limit < 1) {
    return [if size { Sized(0, {}) } else { Parts({}) }]
  }
  let max_parts = match m {
    Some(limit) => if limit < n { limit } else { n }
    None => n
  }
  let max_keys = match k {
    Some(limit) => if limit < n { limit } else { n }
    None => n
  }
  if max_parts * max_keys < n {
    return [if size { Sized(0, {}) } else { Parts({}) }]
  }
  let raw : Array[Array[Int]] = []
  generate_partitions(n, n, None, [], raw, max_keys)
  let out : Array[PartitionResult] = []
  for parts in raw {
    if parts.length() > max_parts {
      continue
    }
    let counts = partition_counts(parts)
    if size {
      out.push(Sized(parts.length(), counts))
    } else {
      out.push(Parts(counts))
    }
  }
  out
}

///|
fn ordered_partitions_exact(
  remaining : Int,
  parts_left : Int,
  min_part : Int,
  acc : Array[Int],
  out : Array[Array[Int]],
) -> Unit {
  if parts_left == 0 {
    if remaining == 0 {
      out.push(acc.map(x => x))
    }
    return
  }
  if remaining < parts_left * min_part {
    return
  }
  let max_part = remaining - (parts_left - 1) * min_part
  for part in min_part..<=max_part {
    acc.push(part)
    ordered_partitions_exact(remaining - part, parts_left - 1, part, acc, out)
    ignore(acc.pop())
  }
}

///|
pub fn ordered_partitions(n : Int, m? : Int? = None) -> Array[Array[Int]] {
  if n < 1 || (m is Some(parts) && parts < 1) {
    return [[]]
  }
  let out : Array[Array[Int]] = []
  match m {
    Some(parts) => ordered_partitions_exact(n, parts, 1, [], out)
    None =>
      for parts in 1..<=n {
        ordered_partitions_exact(n, parts, 1, [], out)
      }
  }
  out
}
