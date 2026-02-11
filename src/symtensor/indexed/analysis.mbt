///|
/// Analysis helpers for indexed expressions.

///|
pub struct IndexInfo {
  free : Array[String]
  dummy : Array[String]
}

///|
fn index_name(index : Index) -> String {
  match index {
    Index::Expr(expr) => @symprint.to_string(expr)
    Index::Idx(item) => item.name
  }
}

///|
fn collect_index_names(item : Indexed) -> Array[String] {
  let out : Array[String] = Array::new()
  for idx in item.indices {
    out.push(index_name(idx))
  }
  out
}

///|
fn count_indices(expr : IndexedExpr) -> Map[String, Int] {
  let counts : Map[String, Int] = {}
  fn bump(name : String) -> Unit {
    let current = counts.get_or_default(name, 0)
    counts[name] = current + 1
  }
  match expr {
    IndexedExpr::Atom(item) =>
      for name in collect_index_names(item) {
        bump(name)
      }
    IndexedExpr::Mul(items) =>
      for item in items {
        match item {
          IndexedExpr::Atom(atom) =>
            for name in collect_index_names(atom) {
              bump(name)
            }
          _ => ()
        }
      }
    _ => ()
  }
  counts
}

///|
fn merge_names(target : Map[String, Bool], names : Array[String]) -> Unit {
  for name in names {
    target[name] = true
  }
}

///|
pub fn get_indices(expr : IndexedExpr) -> IndexInfo {
  match expr {
    IndexedExpr::Add(items) => {
      let free_set : Map[String, Bool] = {}
      let dummy_set : Map[String, Bool] = {}
      for item in items {
        let info = get_indices(item)
        merge_names(free_set, info.free)
        merge_names(dummy_set, info.dummy)
      }
      IndexInfo::{
        free: free_set.keys().to_array(),
        dummy: dummy_set.keys().to_array(),
      }
    }
    IndexedExpr::Mul(_) | IndexedExpr::Atom(_) => {
      let counts = count_indices(expr)
      let free : Array[String] = Array::new()
      let dummy : Array[String] = Array::new()
      for name in counts.keys() {
        let count = counts[name]
        if count >= 2 {
          dummy.push(name)
        } else {
          free.push(name)
        }
      }
      free.sort()
      dummy.sort()
      IndexInfo::{ free, dummy }
    }
    _ => IndexInfo::{ free: [], dummy: [] }
  }
}

///|
pub fn get_contraction_structure(
  expr : IndexedExpr,
) -> Map[String, Array[Indexed]] {
  let out : Map[String, Array[Indexed]] = {}
  fn add_entry(key : String, items : Array[Indexed]) -> Unit {
    if out.contains(key) {
      let cur = out[key]
      for item in items {
        cur.push(item)
      }
      out[key] = cur
    } else {
      out[key] = items
    }
  }
  fn process_term(term : IndexedExpr) -> Unit {
    let atoms : Array[Indexed] = Array::new()
    match term {
      IndexedExpr::Atom(item) => atoms.push(item)
      IndexedExpr::Mul(items) =>
        for item in items {
          match item {
            IndexedExpr::Atom(atom) => atoms.push(atom)
            _ => ()
          }
        }
      _ => ()
    }
    if atoms.is_empty() {
      return
    }
    let info = get_indices(term)
    if info.dummy.is_empty() {
      add_entry("", atoms)
    } else {
      let key = info.dummy.join(",")
      add_entry(key, atoms)
    }
  }
  match expr {
    IndexedExpr::Add(items) =>
      for item in items {
        process_term(item)
      }
    _ => process_term(expr)
  }
  out
}
