///|
/// Index analysis for tensor expressions.

///|
pub struct TensorIndexInfo {
  free : Array[TensorIndex]
  dummy : Array[(TensorIndex, TensorIndex)]
}

///|
fn index_key(index : TensorIndex) -> String {
  index.index_type.name + ":" + index.name
}

///|
fn collect_indices(expr : TensorExpr) -> Array[TensorIndex] {
  let out : Array[TensorIndex] = Array::new()
  match expr {
    TensorExpr::Tensor(_, indices) =>
      for idx in indices {
        out.push(idx)
      }
    TensorExpr::Mul(items) =>
      for item in items {
        match item {
          TensorExpr::Tensor(_, indices) =>
            for idx in indices {
              out.push(idx)
            }
          _ => ()
        }
      }
    TensorExpr::Add(items) =>
      for item in items {
        let indices = collect_indices(item)
        for idx in indices {
          out.push(idx)
        }
      }
    _ => ()
  }
  out
}

///|
pub fn get_indices(expr : TensorExpr) -> TensorIndexInfo {
  let indices = collect_indices(expr)
  let up_map : Map[String, Array[TensorIndex]] = {}
  let down_map : Map[String, Array[TensorIndex]] = {}
  for idx in indices {
    let key = index_key(idx)
    if idx.is_up {
      let list = up_map.get_or_default(key, [])
      list.push(idx)
      up_map[key] = list
    } else {
      let list = down_map.get_or_default(key, [])
      list.push(idx)
      down_map[key] = list
    }
  }
  let free : Array[TensorIndex] = Array::new()
  let dummy : Array[(TensorIndex, TensorIndex)] = Array::new()
  let keys = up_map.keys().to_array()
  for key in keys {
    let ups = up_map.get_or_default(key, [])
    let downs = down_map.get_or_default(key, [])
    let pair_count = if ups.length() < downs.length() {
      ups.length()
    } else {
      downs.length()
    }
    let mut i = 0
    while i < pair_count {
      dummy.push((ups[i], downs[i]))
      i = i + 1
    }
    for j in i..<ups.length() {
      free.push(ups[j])
    }
    for j in i..<downs.length() {
      free.push(downs[j])
    }
  }
  // include down-only keys
  let down_keys = down_map.keys().to_array()
  for key in down_keys {
    if !up_map.contains(key) {
      let downs = down_map.get_or_default(key, [])
      for idx in downs {
        free.push(idx)
      }
    }
  }
  TensorIndexInfo::{ free, dummy }
}

///|
pub fn get_free_indices(expr : TensorExpr) -> Array[TensorIndex] {
  get_indices(expr).free
}
