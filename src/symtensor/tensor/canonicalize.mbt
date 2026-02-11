///|
/// Canonicalization for tensor expressions using tensor_can where possible.

///|

///|
fn index_eq(a : TensorIndex, b : TensorIndex) -> Bool {
  a.name == b.name &&
  a.is_up == b.is_up &&
  a.index_type.name == b.index_type.name
}

///|
fn sort_indices(indices : Array[TensorIndex]) -> Array[TensorIndex] {
  let out : Array[TensorIndex] = Array::new()
  for idx in indices {
    out.push(idx)
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if index_key(out[j]) < index_key(out[i]) {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn permutation_from_order(
  sorted : Array[TensorIndex],
  current : Array[TensorIndex],
) -> Array[Int] {
  let used : Array[Bool] = Array::make(current.length(), false)
  let perm : Array[Int] = Array::new()
  for item in sorted {
    let mut found = false
    for i in 0..<current.length() {
      if !used[i] && index_eq(item, current[i]) {
        perm.push(i)
        used[i] = true
        found = true
        break
      }
    }
    if !found {
      perm.push(0)
    }
  }
  perm
}

///|
fn extend_perm(
  perm : @symcombinatorics.Permutation,
  rank : Int,
) -> @symcombinatorics.Permutation raise {
  let arr = perm.array_form()
  if arr.length() == rank + 2 {
    return perm
  }
  if arr.length() != rank {
    fail("perm size mismatch")
  }
  let full : Array[Int] = Array::new()
  for v in arr {
    full.push(v)
  }
  full.push(rank)
  full.push(rank + 1)
  @symcombinatorics.Permutation::from_array(full)
}

///|
fn canonicalize_tensor(
  head : TensorHead,
  indices : Array[TensorIndex],
) -> TensorExpr raise {
  match head.symmetry {
    None => TensorExpr::Tensor(head, indices)
    Some(sym) => {
      if sym.generators.is_empty() {
        return TensorExpr::Tensor(head, indices)
      }
      let rank = indices.length()
      let sorted = sort_indices(indices)
      let perm0 = permutation_from_order(sorted, indices)
      let g_array : Array[Int] = Array::new()
      for v in perm0 {
        g_array.push(v)
      }
      g_array.push(rank)
      g_array.push(rank + 1)
      let g = @symcombinatorics.Permutation::from_array(g_array)
      let gens_full : Array[@symcombinatorics.Permutation] = Array::new()
      for gen in sym.generators {
        gens_full.push(extend_perm(gen, rank))
      }
      let comp = @symcombinatorics.TensorComponent::{
        base: [],
        gens: gens_full,
        count: 1,
        sym: sym.sign,
      }
      let result = @symcombinatorics.canonicalize(g, [], [], [comp])
      match result {
        Some(arr) => {
          if arr.length() < rank {
            return TensorExpr::Tensor(head, indices)
          }
          let new_indices : Array[TensorIndex] = Array::new()
          for i in 0..<rank {
            let pos = arr[i]
            if pos < sorted.length() {
              new_indices.push(sorted[pos])
            }
          }
          if new_indices.length() == rank {
            TensorExpr::Tensor(head, new_indices)
          } else {
            TensorExpr::Tensor(head, indices)
          }
        }
        None => TensorExpr::Tensor(head, indices)
      }
    }
  }
}

///|
pub fn canonicalize(expr : TensorExpr) -> TensorExpr raise {
  match expr {
    TensorExpr::Tensor(head, indices) => canonicalize_tensor(head, indices)
    TensorExpr::Mul(items) => {
      let canon_items : Array[TensorExpr] = Array::new()
      for item in items {
        canon_items.push(canonicalize(item))
      }
      // stable ordering by string repr
      let n = canon_items.length()
      for i in 0..<n {
        for j in (i + 1)..<n {
          if to_string(canon_items[j]) < to_string(canon_items[i]) {
            let tmp = canon_items[i]
            canon_items[i] = canon_items[j]
            canon_items[j] = tmp
          }
        }
      }
      mul(canon_items)
    }
    TensorExpr::Add(items) => {
      let canon_items : Array[TensorExpr] = Array::new()
      for item in items {
        canon_items.push(canonicalize(item))
      }
      add(canon_items)
    }
    _ => expr
  }
}
