///|
/// Oracle helpers for SymPy combinatorics.

///|
pub type OracleArg = @sympy.OracleArg

///|
fn sympy_call(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum? raise {
  @sympy.sympy_call(path, args, kwargs~)
}

///|
fn sympy_call_must(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum raise {
  match sympy_call(path, args, kwargs~) {
    Some(obj) => obj
    None => fail("sympy-call-none:\{path}")
  }
}

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn py_callable_from_enum(obj : @py.PyObjectEnum) -> @py.PyCallable raise {
  match obj {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-callable")
      }
    _ =>
      @py.PyCallable::create(objenum_to_obj(obj)) catch {
        _ => fail("py-callable")
      }
  }
}

///|
fn py_call_with_args(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  match @sympy.py_call_object(callable, tup, print_err=true) {
    Some(obj) => obj
    None => fail("py-call-none")
  }
}

///|
fn py_call_with_args_allow_none(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> Unit raise {
  let tup = @sympy.py_pack_args(args)
  let _ = @sympy.py_call_object(callable, tup, print_err=true)
}

///|
fn py_call_with_args_kwargs(
  callable : @py.PyCallable,
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  let dict = @sympy.py_pack_kwargs(kwargs)
  match
    @sympy.py_call_object_kwargs(callable, tup, kwargs=dict, print_err=true) {
    Some(obj) => obj
    None => fail("py-call-none")
  }
}

///|
fn py_builtin_callable(name : String) -> @py.PyCallable raise {
  let state = py_gil_ensure()
  let callable = try {
    match @py.pyimport("builtins") {
      Some(mod) =>
        match mod.get_attr(name, print_err=true) {
          Some(PyCallable(callable)) => callable
          Some(PyClass(obj0)) =>
            @py.PyCallable::create(obj0) catch {
              _ => fail("py-callable")
            }
          Some(other) =>
            @py.PyCallable::create(objenum_to_obj(other)) catch {
              _ => fail("py-callable")
            }
          None => fail("py-callable-missing:\{name}")
        }
      None => fail("py-builtin-missing")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  callable
}

///|
fn py_builtin_call(
  name : String,
  args : Array[OracleArg],
) -> @py.PyObjectEnum raise {
  py_call_with_args(py_builtin_callable(name), args)
}

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
}

///|
fn py_str_enum(obj : @py.PyObjectEnum) -> String {
  py_str_obj(objenum_to_obj(obj))
}

///|
fn py_int_enum(obj : @py.PyObjectEnum) -> Int? {
  match obj {
    PyInteger(v) => Some(v.to_int64().to_int())
    _ => None
  }
}

///|
fn py_list_to_pyobjects(value : @py.PyObjectEnum) -> Array[@py.PyObject] raise {
  let state = py_gil_ensure()
  let res = try {
    let out : Array[@py.PyObject] = Array::new()
    match value {
      PyList(list) => {
        let len = list.len()
        for i in 0..<len {
          match list.get(i) {
            Some(obj) => out.push(objenum_to_obj(obj))
            None => ()
          }
        }
        out
      }
      PyTuple(tup) => {
        let len = tup.len().to_int()
        for i in 0..<len {
          match tup.get(i) {
            Some(obj) => out.push(objenum_to_obj(obj))
            None => ()
          }
        }
        out
      }
      _ => fail("expected list/tuple")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  res
}

///|
fn list_str_equiv(ours : Array[String], items : Array[@py.PyObject]) -> Bool {
  if ours.length() != items.length() {
    return false
  }
  for i in 0..<ours.length() {
    if py_str_obj(items[i]) != ours[i] {
      return false
    }
  }
  true
}

///|
fn sort_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = Array::new()
  for v in values {
    out.push(v)
  }
  let n = out.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if out[j] < out[i] {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
    }
  }
  out
}

///|
fn list_int_equiv(ours : Array[Int], items : Array[@py.PyObject]) -> Bool raise {
  if ours.length() != items.length() {
    return false
  }
  for i in 0..<ours.length() {
    let s = py_str_obj(items[i])
    if @strconv.parse_int(s) != ours[i] {
      return false
    }
  }
  true
}

///|
fn list_list_int_equiv(
  ours : Array[Array[Int]],
  items : Array[@py.PyObject],
) -> Bool raise {
  if ours.length() != items.length() {
    return false
  }
  for i in 0..<ours.length() {
    let lst = py_builtin_call("list", [OracleArg::PyObj(items[i])])
    let sub = py_list_to_pyobjects(lst)
    if !list_int_equiv(ours[i], sub) {
      return false
    }
  }
  true
}

///|
fn list_list_int_equiv_unordered(
  ours : Array[Array[Int]],
  items : Array[@py.PyObject],
) -> Bool raise {
  if ours.length() != items.length() {
    return false
  }
  let ours_keys : Array[String] = Array::new()
  for arr in ours {
    ours_keys.push(arr.map(x => "\{x}").join(","))
  }
  let items_keys : Array[String] = Array::new()
  for i in 0..<items.length() {
    let lst = py_builtin_call("list", [OracleArg::PyObj(items[i])])
    let sub = py_list_to_pyobjects(lst)
    let key = sub.map(o => py_str_obj(o)).join(",")
    items_keys.push(key)
  }
  let ours_sorted = sort_strings(ours_keys)
  let items_sorted = sort_strings(items_keys)
  for i in 0..<ours_sorted.length() {
    if ours_sorted[i] != items_sorted[i] {
      return false
    }
  }
  true
}

///|
fn array_eq_ints_local(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn array_list_eq(ours : Array[Array[Int]], other : Array[Array[Int]]) -> Bool {
  if ours.length() != other.length() {
    return false
  }
  for i in 0..<ours.length() {
    if !array_eq_ints_local(ours[i], other[i]) {
      return false
    }
  }
  true
}

///|
pub fn graycode_generate_equiv(
  n : Int,
  ours : Array[String],
  start? : String,
  rank? : Int,
) -> Bool raise {
  let gray = sympy_call_must("sympy.combinatorics.graycode.GrayCode", [
    OracleArg::Int(n),
  ])
  let kwargs : Map[String, OracleArg] = Map::new()
  match start {
    Some(s) => kwargs["start"] = OracleArg::Str(s)
    None => ()
  }
  match rank {
    Some(r) => kwargs["rank"] = OracleArg::Int(r)
    None => ()
  }
  let gen_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(gray)),
    OracleArg::Str("generate_gray"),
  ])
  let gen = py_call_with_args_kwargs(
    py_callable_from_enum(gen_call),
    [],
    kwargs,
  )
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(gen))])
  let items = py_list_to_pyobjects(lst)
  list_str_equiv(ours, items)
}

///|
pub fn graycode_rank_equiv(n : Int, start : String, ours : Int) -> Bool raise {
  let kwargs : Map[String, OracleArg] = { "start": OracleArg::Str(start) }
  let gray = sympy_call_must(
    "sympy.combinatorics.graycode.GrayCode",
    [OracleArg::Int(n)],
    kwargs~,
  )
  let rank = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(gray)),
    OracleArg::Str("rank"),
  ])
  py_str_enum(rank) == ours.to_string()
}

///|
pub fn gray_to_bin_equiv(bits : String, ours : String) -> Bool raise {
  let res = sympy_call_must("sympy.combinatorics.graycode.gray_to_bin", [
    OracleArg::Str(bits),
  ])
  py_str_enum(res) == ours
}

///|
pub fn bin_to_gray_equiv(bits : String, ours : String) -> Bool raise {
  let res = sympy_call_must("sympy.combinatorics.graycode.bin_to_gray", [
    OracleArg::Str(bits),
  ])
  py_str_enum(res) == ours
}

///|
pub fn graycode_subsets_equiv(
  items : Array[Int],
  ours : Array[Array[Int]],
) -> Bool raise {
  let res = sympy_call_must("sympy.combinatorics.graycode.graycode_subsets", [
    OracleArg::IntList(items),
  ])
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(res))])
  let items_py = py_list_to_pyobjects(lst)
  list_list_int_equiv(ours, items_py)
}

///|
pub fn ksubsets_equiv(
  superset : Array[Int],
  k : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  let args : Array[OracleArg] = [
    OracleArg::IntList(superset),
    OracleArg::Int(k),
  ]
  let res = sympy_call_must("sympy.combinatorics.subsets.ksubsets", args)
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(res))])
  let items = py_list_to_pyobjects(lst)
  list_list_int_equiv(ours, items)
}

///|
pub fn subset_rank_equiv(
  subset : Array[Int],
  superset : Array[Int],
  ours_bin : Int,
  ours_lex : Int,
  ours_gray : Int,
) -> Bool raise {
  let args : Array[OracleArg] = [
    OracleArg::IntList(subset),
    OracleArg::IntList(superset),
  ]
  let obj = sympy_call_must("sympy.combinatorics.subsets.Subset", args)
  let rank_bin = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rank_binary"),
  ])
  let rank_lex = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rank_lexicographic"),
  ])
  let rank_gray = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rank_gray"),
  ])
  let ok_bin = py_str_enum(rank_bin) == ours_bin.to_string()
  let ok_lex = py_str_enum(rank_lex) == ours_lex.to_string()
  let ok_gray = py_str_enum(rank_gray) == ours_gray.to_string()
  ok_bin && ok_lex && ok_gray
}

///|
pub fn subset_next_prev_equiv(
  subset : Array[Int],
  superset : Array[Int],
  ours_next : Array[Int],
  ours_prev : Array[Int],
) -> Bool raise {
  let args : Array[OracleArg] = [
    OracleArg::IntList(subset),
    OracleArg::IntList(superset),
  ]
  let obj = sympy_call_must("sympy.combinatorics.subsets.Subset", args)
  let nxt_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("next_binary"),
  ])
  let prv_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("prev_binary"),
  ])
  let nxt = py_call_with_args(py_callable_from_enum(nxt_call), [])
  let prv = py_call_with_args(py_callable_from_enum(prv_call), [])
  let nxt_subset = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(nxt)),
    OracleArg::Str("subset"),
  ])
  let prv_subset = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(prv)),
    OracleArg::Str("subset"),
  ])
  let nxt_items = py_list_to_pyobjects(nxt_subset)
  let prv_items = py_list_to_pyobjects(prv_subset)
  list_int_equiv(ours_next, nxt_items) && list_int_equiv(ours_prev, prv_items)
}

///|
pub fn prufer_equiv_tree(
  seq : Array[Int],
  ours : Array[Array[Int]],
) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.prufer.Prufer", [
    OracleArg::IntList(seq),
  ])
  let tree = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("tree_repr"),
  ])
  let items = py_list_to_pyobjects(tree)
  list_list_int_equiv(ours, items)
}

///|
pub fn prufer_equiv_sequence(
  edges : Array[Array[Int]],
  ours : Array[Int],
) -> Bool raise {
  let py_edges : Array[OracleArg] = Array::new()
  for edge in edges {
    py_edges.push(OracleArg::IntList(edge))
  }
  let obj = sympy_call_must("sympy.combinatorics.prufer.Prufer", [
    OracleArg::List(py_edges),
  ])
  let seq = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("prufer_repr"),
  ])
  let items = py_list_to_pyobjects(seq)
  list_int_equiv(ours, items)
}

///|
pub fn prufer_rank_equiv(seq : Array[Int], ours : Int) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.prufer.Prufer", [
    OracleArg::IntList(seq),
  ])
  let rank = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rank"),
  ])
  py_str_enum(rank) == ours.to_string()
}

///|
pub fn integer_partition_conjugate_equiv(
  part : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.partitions.IntegerPartition", [
    OracleArg::IntList(part),
  ])
  let conj = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("conjugate"),
  ])
  let items = py_list_to_pyobjects(conj)
  list_int_equiv(ours, items)
}

///|
pub fn integer_partition_next_prev_equiv(
  part : Array[Int],
  ours_next : Array[Int],
  ours_prev : Array[Int],
) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.partitions.IntegerPartition", [
    OracleArg::IntList(part),
  ])
  let nxt_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("next_lex"),
  ])
  let prv_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("prev_lex"),
  ])
  let nxt = py_call_with_args(py_callable_from_enum(nxt_call), [])
  let prv = py_call_with_args(py_callable_from_enum(prv_call), [])
  let nxt_part = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(nxt)),
    OracleArg::Str("partition"),
  ])
  let prv_part = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(prv)),
    OracleArg::Str("partition"),
  ])
  let nxt_list = py_list_to_pyobjects(nxt_part)
  let prv_list = py_list_to_pyobjects(prv_part)
  list_int_equiv(ours_next, nxt_list) && list_int_equiv(ours_prev, prv_list)
}

///|
pub fn rgs_rank_equiv(rgs : Array[Int], ours : Int) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.partitions.RGS_rank", [
    OracleArg::IntList(rgs),
  ])
  py_str_enum(obj) == ours.to_string()
}

///|
pub fn rgs_unrank_equiv(rank : Int, m : Int, ours : Array[Int]) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.partitions.RGS_unrank", [
    OracleArg::Int(rank),
    OracleArg::Int(m),
  ])
  let items = py_list_to_pyobjects(obj)
  list_int_equiv(ours, items)
}

///|
pub fn partition_rgs_equiv(
  blocks : Array[Array[Int]],
  ours_rgs : Array[Int],
  ours_rank : Int,
) -> Bool raise {
  let args : Array[OracleArg] = Array::new()
  for block in blocks {
    args.push(OracleArg::IntList(block))
  }
  let obj = sympy_call_must("sympy.combinatorics.partitions.Partition", args)
  let rgs = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("RGS"),
  ])
  let rank = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rank"),
  ])
  let items = py_list_to_pyobjects(rgs)
  list_int_equiv(ours_rgs, items) && py_str_enum(rank) == ours_rank.to_string()
}

///|
fn perm_obj_from_array(
  array : Array[Int],
  size : Int?,
) -> @py.PyObjectEnum raise {
  let kwargs : Map[String, OracleArg] = {}
  match size {
    Some(s) => kwargs["size"] = OracleArg::Int(s)
    None => ()
  }
  sympy_call_must(
    "sympy.combinatorics.permutations.Permutation",
    [OracleArg::IntList(array)],
    kwargs~,
  )
}

///|
fn perm_obj_from_cycles(
  cycles : Array[Array[Int]],
  size : Int?,
) -> @py.PyObjectEnum raise {
  let kwargs : Map[String, OracleArg] = {}
  match size {
    Some(s) => kwargs["size"] = OracleArg::Int(s)
    None => ()
  }
  let args_list : Array[OracleArg] = Array::new()
  for cycle in cycles {
    args_list.push(OracleArg::IntList(cycle))
  }
  sympy_call_must(
    "sympy.combinatorics.permutations.Permutation",
    [OracleArg::List(args_list)],
    kwargs~,
  )
}

///|
fn perm_class_obj() -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let obj = try {
    match @py.pyimport("sympy.combinatorics.permutations") {
      Some(mod) =>
        match mod.get_attr("Permutation", print_err=true) {
          Some(attr) => attr
          None =>
            fail("sympy-missing:sympy.combinatorics.permutations.Permutation")
        }
      None => fail("sympy-missing:sympy.combinatorics.permutations")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  obj
}

///|
fn list_pair_int_equiv(
  ours : Array[(Int, Int)],
  items : Array[@py.PyObject],
) -> Bool raise {
  if ours.length() != items.length() {
    return false
  }
  for i in 0..<ours.length() {
    let lst = py_builtin_call("list", [OracleArg::PyObj(items[i])])
    let parts = py_list_to_pyobjects(lst)
    if parts.length() != 2 {
      return false
    }
    let a = @strconv.parse_int(py_str_obj(parts[0]))
    let b = @strconv.parse_int(py_str_obj(parts[1]))
    if ours[i].0 != a || ours[i].1 != b {
      return false
    }
  }
  true
}

///|
fn py_dict_pairs_sorted(obj : @py.PyObjectEnum) -> Array[(Int, Int)] raise {
  let items_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("items"),
  ])
  let items = py_call_with_args(py_callable_from_enum(items_call), [])
  let items_list = py_builtin_call("list", [
    OracleArg::PyObj(objenum_to_obj(items)),
  ])
  let items_objs = py_list_to_pyobjects(items_list)
  let pairs : Array[(Int, Int)] = Array::new()
  for item in items_objs {
    let lst = py_builtin_call("list", [OracleArg::PyObj(item)])
    let parts = py_list_to_pyobjects(lst)
    if parts.length() == 2 {
      let a = @strconv.parse_int(py_str_obj(parts[0]))
      let b = @strconv.parse_int(py_str_obj(parts[1]))
      pairs.push((a, b))
    }
  }
  let n = pairs.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if pairs[j].0 < pairs[i].0 {
        let tmp = pairs[i]
        pairs[i] = pairs[j]
        pairs[j] = tmp
      }
    }
  }
  pairs
}

///|
fn perm_array_form_from_obj(obj : @py.PyObject) -> Array[Int] raise {
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(obj),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  let out : Array[Int] = Array::new()
  for item in items {
    out.push(@strconv.parse_int(py_str_obj(item)))
  }
  out
}

///|
fn perm_list_to_arrays(obj : @py.PyObjectEnum) -> Array[Array[Int]] raise {
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(obj))])
  let items = py_list_to_pyobjects(lst)
  let out : Array[Array[Int]] = Array::new()
  for item in items {
    out.push(perm_array_form_from_obj(item))
  }
  out
}

///|
fn perm_list_list_to_arrays(
  obj : @py.PyObjectEnum,
) -> Array[Array[Array[Int]]] raise {
  let outer = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(obj))])
  let items = py_list_to_pyobjects(outer)
  let out : Array[Array[Array[Int]]] = Array::new()
  for item in items {
    let lst = py_builtin_call("list", [OracleArg::PyObj(item)])
    out.push(perm_list_to_arrays(lst))
  }
  out
}

///|
fn list_list_list_int_equiv(
  ours : Array[Array[Array[Int]]],
  other : Array[Array[Array[Int]]],
) -> Bool {
  if ours.length() != other.length() {
    return false
  }
  for i in 0..<ours.length() {
    if ours[i].length() != other[i].length() {
      return false
    }
    for j in 0..<ours[i].length() {
      if ours[i][j].length() != other[i][j].length() {
        return false
      }
      for k in 0..<ours[i][j].length() {
        if ours[i][j][k] != other[i][j][k] {
          return false
        }
      }
    }
  }
  true
}

///|
fn list_pair_int_equiv_unordered(
  ours : Array[(Int, Int)],
  items : Array[@py.PyObject],
) -> Bool raise {
  let mut ours_keys : Array[String] = Array::new()
  for p in ours {
    ours_keys.push("\{p.0},\{p.1}")
  }
  ours_keys = sort_strings(ours_keys)
  let mut other_keys : Array[String] = Array::new()
  for item in items {
    let lst = py_builtin_call("list", [OracleArg::PyObj(item)])
    let parts = py_list_to_pyobjects(lst)
    if parts.length() == 2 {
      let a = @strconv.parse_int(py_str_obj(parts[0]))
      let b = @strconv.parse_int(py_str_obj(parts[1]))
      let x = if a < b { a } else { b }
      let y = if a < b { b } else { a }
      other_keys.push("\{x},\{y}")
    }
  }
  other_keys = sort_strings(other_keys)
  if ours_keys.length() != other_keys.length() {
    return false
  }
  for i in 0..<ours_keys.length() {
    if ours_keys[i] != other_keys[i] {
      return false
    }
  }
  true
}

///|
fn perm_group_obj_from_gens(gens : Array[Array[Int]]) -> @py.PyObjectEnum raise {
  let perm_args : Array[OracleArg] = Array::new()
  for g in gens {
    let p = sympy_call_must("sympy.combinatorics.permutations.Permutation", [
      OracleArg::IntList(g),
    ])
    perm_args.push(OracleArg::PyObj(objenum_to_obj(p)))
  }
  sympy_call_must("sympy.combinatorics.perm_groups.PermutationGroup", [
    OracleArg::List(perm_args),
  ])
}

///|
fn py_import_module(path : String) -> @py.PyModule raise {
  match @py.pyimport(path) {
    Some(mod) => mod
    None => fail("py-import-missing:\{path}")
  }
}

///|
fn perm_group_elements(obj : @py.PyObjectEnum) -> Array[@py.PyObject] raise {
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("generate_dimino"),
  ])
  let kwargs : Map[String, OracleArg] = { "af": OracleArg::Bool(true) }
  let res = py_call_with_args_kwargs(py_callable_from_enum(call), [], kwargs)
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(res))])
  py_list_to_pyobjects(lst)
}

///|
pub fn perm_array_form_equiv_from_array(
  array : Array[Int],
  ours : Array[Int],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  list_int_equiv(ours, items)
}

///|
pub fn perm_array_form_equiv_from_cycles(
  cycles : Array[Array[Int]],
  ours : Array[Int],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_cycles(cycles, size)
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  list_int_equiv(ours, items)
}

///|
pub fn perm_cyclic_form_equiv_from_array(
  array : Array[Int],
  ours : Array[Array[Int]],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let cyc = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("cyclic_form"),
  ])
  let items = py_list_to_pyobjects(cyc)
  list_list_int_equiv(ours, items)
}

///|
pub fn perm_full_cyclic_form_equiv_from_array(
  array : Array[Int],
  ours : Array[Array[Int]],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let cyc = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("full_cyclic_form"),
  ])
  let items = py_list_to_pyobjects(cyc)
  list_list_int_equiv(ours, items)
}

///|
pub fn perm_cycle_structure_equiv_from_array(
  array : Array[Int],
  ours : Array[(Int, Int)],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let cs = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("cycle_structure"),
  ])
  let pairs = py_dict_pairs_sorted(cs)
  if ours.length() != pairs.length() {
    return false
  }
  for i in 0..<ours.length() {
    if ours[i].0 != pairs[i].0 || ours[i].1 != pairs[i].1 {
      return false
    }
  }
  true
}

///|
pub fn perm_parity_equiv_from_array(
  array : Array[Int],
  ours : Int,
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("parity"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  py_str_enum(res) == ours.to_string()
}

///|
pub fn perm_order_equiv_from_array(
  array : Array[Int],
  ours : Int,
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("order"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  py_str_enum(res) == ours.to_string()
}

///|
pub fn perm_rank_equiv_from_array(
  array : Array[Int],
  ours : Int,
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rank"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  py_str_enum(res) == ours.to_string()
}

///|
pub fn perm_inversion_vector_equiv_from_array(
  array : Array[Int],
  ours : Array[Int],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("inversion_vector"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  let items = py_list_to_pyobjects(res)
  list_int_equiv(ours, items)
}

///|
pub fn perm_transpositions_equiv_from_array(
  array : Array[Int],
  ours : Array[(Int, Int)],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("transpositions"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  let items = py_list_to_pyobjects(res)
  list_pair_int_equiv(ours, items)
}

///|
pub fn perm_unrank_lex_equiv(
  size : Int,
  rank : Int,
  ours : Array[Int],
) -> Bool raise {
  let cls = perm_class_obj()
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(cls)),
    OracleArg::Str("unrank_lex"),
  ])
  let obj = py_call_with_args(py_callable_from_enum(call), [
    OracleArg::Int(size),
    OracleArg::Int(rank),
  ])
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  list_int_equiv(ours, items)
}

///|
pub fn perm_next_lex_equiv(
  array : Array[Int],
  has_value : Bool,
  ours : Array[Int],
) -> Bool raise {
  let obj = perm_obj_from_array(array, None)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("next_lex"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  let is_none = py_str_enum(res) == "None"
  if !has_value {
    return is_none
  }
  if is_none {
    return false
  }
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(res)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  list_int_equiv(ours, items)
}

///|
pub fn perm_apply_array_equiv(
  array : Array[Int],
  values : Array[String],
  ours : Array[String],
  size? : Int,
) -> Bool raise {
  let obj = perm_obj_from_array(array, size)
  let args : Array[OracleArg] = Array::new()
  for v in values {
    args.push(OracleArg::Str(v))
  }
  let call = py_call_with_args(py_callable_from_enum(obj), [
    OracleArg::List(args),
  ])
  let items = py_list_to_pyobjects(call)
  list_str_equiv(ours, items)
}

///|
pub fn perm_from_sequence_string_equiv(
  seq : String,
  ours : Array[Int],
) -> Bool raise {
  let cls = perm_class_obj()
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(cls)),
    OracleArg::Str("from_sequence"),
  ])
  let obj = py_call_with_args(py_callable_from_enum(call), [OracleArg::Str(seq)])
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  list_int_equiv(ours, items)
}

///|
pub fn generators_symmetric_equiv(
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  let gen = sympy_call_must("sympy.combinatorics.generators.symmetric", [
    OracleArg::Int(n),
  ])
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(gen))])
  let items = py_list_to_pyobjects(lst)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn generators_cyclic_equiv(n : Int, ours : Array[Array[Int]]) -> Bool raise {
  let gen = sympy_call_must("sympy.combinatorics.generators.cyclic", [
    OracleArg::Int(n),
  ])
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(gen))])
  let items = py_list_to_pyobjects(lst)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn generators_alternating_equiv(
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  let gen = sympy_call_must("sympy.combinatorics.generators.alternating", [
    OracleArg::Int(n),
  ])
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(gen))])
  let items = py_list_to_pyobjects(lst)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn generators_dihedral_equiv(
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  let gen = sympy_call_must("sympy.combinatorics.generators.dihedral", [
    OracleArg::Int(n),
  ])
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(gen))])
  let items = py_list_to_pyobjects(lst)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn perm_group_elements_equiv_from_gens(
  gens : Array[Array[Int]],
  ours : Array[Array[Int]],
) -> Bool raise {
  let obj = perm_group_obj_from_gens(gens)
  let items = perm_group_elements(obj)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn perm_group_order_equiv_from_gens(
  gens : Array[Array[Int]],
  ours : Int,
) -> Bool raise {
  let obj = perm_group_obj_from_gens(gens)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("order"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  py_str_enum(res) == ours.to_string()
}

///|
pub fn named_group_elements_equiv(
  kind : String,
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  let mod = py_import_module("sympy.combinatorics.named_groups")
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(mod.obj()),
    OracleArg::Str(kind),
  ])
  let obj = py_call_with_args(py_callable_from_enum(call), [OracleArg::Int(n)])
  let items = perm_group_elements(obj)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn named_group_order_equiv(
  kind : String,
  n : Int,
  ours : Int,
) -> Bool raise {
  let mod = py_import_module("sympy.combinatorics.named_groups")
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(mod.obj()),
    OracleArg::Str(kind),
  ])
  let obj = py_call_with_args(py_callable_from_enum(call), [OracleArg::Int(n)])
  let order_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("order"),
  ])
  let res = py_call_with_args(py_callable_from_enum(order_call), [])
  py_str_enum(res) == ours.to_string()
}

///|
pub fn abelian_group_elements_equiv(
  orders : Array[Int],
  ours : Array[Array[Int]],
) -> Bool raise {
  let mod = py_import_module("sympy.combinatorics.named_groups")
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(mod.obj()),
    OracleArg::Str("AbelianGroup"),
  ])
  let args : Array[OracleArg] = Array::new()
  for n in orders {
    args.push(OracleArg::Int(n))
  }
  let obj = py_call_with_args(py_callable_from_enum(call), args)
  let items = perm_group_elements(obj)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn group_numbers_is_nilpotent_equiv(n : Int, ours : Bool) -> Bool raise {
  let res = sympy_call(
    "sympy.combinatorics.group_numbers.is_nilpotent_number",
    [OracleArg::Int(n)],
  )
  match res {
    Some(obj) => py_str_enum(obj) == (if ours { "True" } else { "False" })
    None => false
  }
}

///|
pub fn group_numbers_is_abelian_equiv(n : Int, ours : Bool) -> Bool raise {
  let res = sympy_call("sympy.combinatorics.group_numbers.is_abelian_number", [
    OracleArg::Int(n),
  ])
  match res {
    Some(obj) => py_str_enum(obj) == (if ours { "True" } else { "False" })
    None => false
  }
}

///|
pub fn group_numbers_is_cyclic_equiv(n : Int, ours : Bool) -> Bool raise {
  let res = sympy_call("sympy.combinatorics.group_numbers.is_cyclic_number", [
    OracleArg::Int(n),
  ])
  match res {
    Some(obj) => py_str_enum(obj) == (if ours { "True" } else { "False" })
    None => false
  }
}

///|
pub fn group_numbers_groups_count_equiv(
  n : Int,
  ours_ok : Bool,
  ours_value : String,
) -> Bool raise {
  let res : Result[@py.PyObjectEnum?, Error] = try? sympy_call(
    "sympy.combinatorics.group_numbers.groups_count",
    [OracleArg::Int(n)],
  )
  match res {
    Ok(opt) =>
      match opt {
        Some(obj) => ours_ok && py_str_enum(obj) == ours_value
        None => !ours_ok
      }
    Err(_) => !ours_ok
  }
}

///|
pub fn schur_number_equiv(k : Int, has_value : Bool, value : Int) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.schur_number.SchurNumber", [
    OracleArg::Int(k),
  ])
  let expected = if has_value { value.to_string() } else { "SchurNumber(\{k})" }
  py_str_enum(obj) == expected
}

///|
pub fn schur_number_lower_bound_equiv(k : Int, value : Int) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.schur_number.SchurNumber", [
    OracleArg::Int(k),
  ])
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("lower_bound"),
  ])
  let res = py_call_with_args(py_callable_from_enum(call), [])
  py_str_enum(res) == value.to_string()
}

///|
pub fn schur_partition_equiv(n : Int, ours : Array[Array[Int]]) -> Bool raise {
  let obj = sympy_call_must(
    "sympy.combinatorics.schur_number.schur_partition",
    [OracleArg::Int(n)],
  )
  let items = py_list_to_pyobjects(obj)
  list_list_int_equiv(ours, items)
}

///|
pub fn galois_group_elements_equiv(
  name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  let mod = py_import_module("sympy.combinatorics.galois")
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(mod.obj()),
    OracleArg::Str(name),
  ])
  let obj = py_call_with_args(py_callable_from_enum(call), [])
  let items = perm_group_elements(obj)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn galois_enum_group_elements_equiv(
  enum_name : String,
  member_name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  let mod = py_import_module("sympy.combinatorics.galois")
  let enum_obj = py_builtin_call("getattr", [
    OracleArg::PyObj(mod.obj()),
    OracleArg::Str(enum_name),
  ])
  let member_obj = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(enum_obj)),
    OracleArg::Str(member_name),
  ])
  let get_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(member_obj)),
    OracleArg::Str("get_perm_group"),
  ])
  let group = py_call_with_args(py_callable_from_enum(get_call), [])
  let items = perm_group_elements(group)
  list_list_int_equiv_unordered(ours, items)
}

///|
fn polyhedron_obj(name : String) -> @py.PyObjectEnum raise {
  let mod = py_import_module("sympy.combinatorics.polyhedron")
  py_builtin_call("getattr", [OracleArg::PyObj(mod.obj()), OracleArg::Str(name)])
}

///|
fn polyhedron_copy_obj(name : String) -> @py.PyObjectEnum raise {
  let obj = polyhedron_obj(name)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("copy"),
  ])
  py_call_with_args(py_callable_from_enum(call), [])
}

///|
pub fn polyhedron_corners_equiv(
  name : String,
  ours : Array[String],
) -> Bool raise {
  let obj = polyhedron_obj(name)
  let corners = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("corners"),
  ])
  let items = py_list_to_pyobjects(corners)
  list_str_equiv(ours, items)
}

///|
pub fn polyhedron_faces_equiv(
  name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  let obj = polyhedron_obj(name)
  let faces = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("faces"),
  ])
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(faces))])
  let items = py_list_to_pyobjects(lst)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn polyhedron_edges_equiv(
  name : String,
  ours : Array[(Int, Int)],
) -> Bool raise {
  let obj = polyhedron_obj(name)
  let edges = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("edges"),
  ])
  let lst = py_builtin_call("list", [OracleArg::PyObj(objenum_to_obj(edges))])
  let items = py_list_to_pyobjects(lst)
  list_pair_int_equiv_unordered(ours, items)
}

///|
pub fn polyhedron_pgroup_elements_equiv(
  name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  let obj = polyhedron_obj(name)
  let pgroup = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("pgroup"),
  ])
  let items = perm_group_elements(pgroup)
  list_list_int_equiv_unordered(ours, items)
}

///|
pub fn polyhedron_array_form_equiv_index(
  name : String,
  idx : Int,
  ours : Array[Int],
) -> Bool raise {
  let obj = polyhedron_copy_obj(name)
  let rotate_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rotate"),
  ])
  py_call_with_args_allow_none(py_callable_from_enum(rotate_call), [
    OracleArg::Int(idx),
  ])
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  list_int_equiv(ours, items)
}

///|
pub fn polyhedron_array_form_equiv_perm(
  name : String,
  perm_array : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  let obj = polyhedron_copy_obj(name)
  let rotate_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rotate"),
  ])
  let perm = perm_obj_from_array(perm_array, None)
  py_call_with_args_allow_none(py_callable_from_enum(rotate_call), [
    OracleArg::PyObj(objenum_to_obj(perm)),
  ])
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  list_int_equiv(ours, items)
}

///|
pub fn polyhedron_cyclic_form_equiv_index(
  name : String,
  idx : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  let obj = polyhedron_copy_obj(name)
  let rotate_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("rotate"),
  ])
  py_call_with_args_allow_none(py_callable_from_enum(rotate_call), [
    OracleArg::Int(idx),
  ])
  let cyc = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("cyclic_form"),
  ])
  let items = py_list_to_pyobjects(cyc)
  list_list_int_equiv(ours, items)
}

///|
pub fn util_base_ordering_equiv(
  base : Array[Int],
  degree : Int,
  ours : Array[Int],
) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.util._base_ordering", [
    OracleArg::IntList(base),
    OracleArg::Int(degree),
  ])
  let items = py_list_to_pyobjects(obj)
  list_int_equiv(ours, items)
}

///|
fn free_group_tuple(symbols : Array[String]) -> Array[@py.PyObject] raise {
  let sym_str = symbols.join(", ")
  let obj = sympy_call_must("sympy.combinatorics.free_groups.free_group", [
    OracleArg::Str(sym_str),
  ])
  py_list_to_pyobjects(obj)
}

///|
fn free_group_word_from_form(
  symbols : Array[String],
  form : Array[(Int, Int)],
) -> @py.PyObjectEnum raise {
  let items = free_group_tuple(symbols)
  let group_obj = items[0]
  let sym_list_obj = py_builtin_call("getattr", [
    OracleArg::PyObj(group_obj),
    OracleArg::Str("symbols"),
  ])
  let sym_items = py_list_to_pyobjects(sym_list_obj)
  let dtype = py_builtin_call("getattr", [
    OracleArg::PyObj(group_obj),
    OracleArg::Str("dtype"),
  ])
  let callable = py_callable_from_enum(dtype)
  if form.is_empty() {
    return py_call_with_args(callable, [])
  }
  let pair_args : Array[OracleArg] = Array::new()
  for pair in form {
    let idx = pair.0
    let exp = pair.1
    let sym = sym_items[idx]
    let tup = py_builtin_call("tuple", [
      OracleArg::List([OracleArg::PyObj(sym), OracleArg::Int(exp)]),
    ])
    pair_args.push(OracleArg::PyObj(objenum_to_obj(tup)))
  }
  py_call_with_args(callable, [OracleArg::List(pair_args)])
}

///|
fn free_group_array_form_named(
  symbols : Array[String],
  obj : @py.PyObjectEnum,
) -> Array[(String, Int)] raise {
  let arr = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(obj)),
    OracleArg::Str("array_form"),
  ])
  let items = py_list_to_pyobjects(arr)
  let out : Array[(String, Int)] = Array::new()
  for item in items {
    // fallback for tuple unpacking
    let list_pair = py_builtin_call("list", [OracleArg::PyObj(item)])
    let values = py_list_to_pyobjects(list_pair)
    if values.length() == 2 {
      let name_str = py_str_obj(values[0])
      let name = match (try? @strconv.parse_int(name_str)) {
        Ok(idx) =>
          if idx >= 0 && idx < symbols.length() {
            symbols[idx]
          } else {
            name_str
          }
        Err(_) => name_str
      }
      let exp = @strconv.parse_int(py_str_obj(values[1]))
      out.push((name, exp))
    }
  }
  out
}

///|
fn free_group_form_to_named(
  symbols : Array[String],
  form : Array[(Int, Int)],
) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = Array::new()
  for pair in form {
    let idx = pair.0
    let exp = pair.1
    if idx >= 0 && idx < symbols.length() {
      out.push((symbols[idx], exp))
    }
  }
  out
}

///|
fn named_pairs_equiv(
  a : Array[(String, Int)],
  b : Array[(String, Int)],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i].0 != b[i].0 || a[i].1 != b[i].1 {
      return false
    }
  }
  true
}

///|
pub fn free_group_mul_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  form_b : Array[(Int, Int)],
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  let a = free_group_word_from_form(symbols, form_a)
  let b = free_group_word_from_form(symbols, form_b)
  let mul_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(a)),
    OracleArg::Str("__mul__"),
  ])
  let prod = py_call_with_args(py_callable_from_enum(mul_call), [
    OracleArg::PyObj(objenum_to_obj(b)),
  ])
  let sympy_named = free_group_array_form_named(symbols, prod)
  let ours_named = free_group_form_to_named(symbols, ours_form)
  named_pairs_equiv(ours_named, sympy_named)
}

///|
pub fn free_group_pow_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  n : Int,
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  let a = free_group_word_from_form(symbols, form_a)
  let powed = py_builtin_call("pow", [
    OracleArg::PyObj(objenum_to_obj(a)),
    OracleArg::Int(n),
  ])
  let sympy_named = free_group_array_form_named(symbols, powed)
  let ours_named = free_group_form_to_named(symbols, ours_form)
  named_pairs_equiv(ours_named, sympy_named)
}

///|
pub fn free_group_inverse_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  let a = free_group_word_from_form(symbols, form_a)
  let inv_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(a)),
    OracleArg::Str("inverse"),
  ])
  let inv = py_call_with_args(py_callable_from_enum(inv_call), [])
  let sympy_named = free_group_array_form_named(symbols, inv)
  let ours_named = free_group_form_to_named(symbols, ours_form)
  named_pairs_equiv(ours_named, sympy_named)
}

///|
pub fn free_group_subword_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  from_i : Int,
  to_j : Int,
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  let a = free_group_word_from_form(symbols, form_a)
  let call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(a)),
    OracleArg::Str("subword"),
  ])
  let sub = py_call_with_args(py_callable_from_enum(call), [
    OracleArg::Int(from_i),
    OracleArg::Int(to_j),
  ])
  let sympy_named = free_group_array_form_named(symbols, sub)
  let ours_named = free_group_form_to_named(symbols, ours_form)
  named_pairs_equiv(ours_named, sympy_named)
}

///|
pub fn fp_group_reduce_equiv(
  symbols : Array[String],
  relator_forms : Array[Array[(Int, Int)]],
  word_form : Array[(Int, Int)],
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  let items = free_group_tuple(symbols)
  let group_obj = items[0]
  let rel_args : Array[OracleArg] = Array::new()
  for rel in relator_forms {
    let w = free_group_word_from_form(symbols, rel)
    rel_args.push(OracleArg::PyObj(objenum_to_obj(w)))
  }
  let fp = sympy_call_must("sympy.combinatorics.fp_groups.FpGroup", [
    OracleArg::PyObj(group_obj),
    OracleArg::List(rel_args),
  ])
  let word = free_group_word_from_form(symbols, word_form)
  let reduce_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(fp)),
    OracleArg::Str("reduce"),
  ])
  let reduced = py_call_with_args(py_callable_from_enum(reduce_call), [
    OracleArg::PyObj(objenum_to_obj(word)),
  ])
  let sympy_named = free_group_array_form_named(symbols, reduced)
  let ours_named = free_group_form_to_named(symbols, ours_form)
  named_pairs_equiv(ours_named, sympy_named)
}

///|
pub fn fp_group_coset_table_equiv(
  symbols : Array[String],
  relator_forms : Array[Array[(Int, Int)]],
  subgroup_forms : Array[Array[(Int, Int)]],
  strategy : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  let items = free_group_tuple(symbols)
  let group_obj = items[0]
  let rel_args : Array[OracleArg] = Array::new()
  for rel in relator_forms {
    let w = free_group_word_from_form(symbols, rel)
    rel_args.push(OracleArg::PyObj(objenum_to_obj(w)))
  }
  let fp = sympy_call_must("sympy.combinatorics.fp_groups.FpGroup", [
    OracleArg::PyObj(group_obj),
    OracleArg::List(rel_args),
  ])
  let sub_args : Array[OracleArg] = Array::new()
  for rel in subgroup_forms {
    let w = free_group_word_from_form(symbols, rel)
    sub_args.push(OracleArg::PyObj(objenum_to_obj(w)))
  }
  let call = if strategy == "coset_table_based" {
    "sympy.combinatorics.fp_groups.coset_enumeration_c"
  } else {
    "sympy.combinatorics.fp_groups.coset_enumeration_r"
  }
  let coset_table = sympy_call_must(call, [
    OracleArg::PyObj(objenum_to_obj(fp)),
    OracleArg::List(sub_args),
  ])
  let compress_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(coset_table)),
    OracleArg::Str("compress"),
  ])
  py_call_with_args_allow_none(py_callable_from_enum(compress_call), [])
  let std_call = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(coset_table)),
    OracleArg::Str("standardize"),
  ])
  py_call_with_args_allow_none(py_callable_from_enum(std_call), [])
  let table = py_builtin_call("getattr", [
    OracleArg::PyObj(objenum_to_obj(coset_table)),
    OracleArg::Str("table"),
  ])
  let rows = py_list_to_pyobjects(table)
  if rows.length() != ours.length() {
    return false
  }
  for i in 0..<rows.length() {
    let row_list = py_builtin_call("list", [OracleArg::PyObj(rows[i])])
    let row_objs = py_list_to_pyobjects(row_list)
    if row_objs.length() != ours[i].length() {
      return false
    }
    for j in 0..<row_objs.length() {
      let val = @strconv.parse_int(py_str_obj(row_objs[j]))
      if val != ours[i][j] {
        return false
      }
    }
  }
  true
}

///|
pub fn util_check_cycles_alt_sym_equiv(
  perm_array : Array[Int],
  ours : Bool,
) -> Bool raise {
  let perm = perm_obj_from_array(perm_array, None)
  let res = sympy_call_must("sympy.combinatorics.util._check_cycles_alt_sym", [
    OracleArg::PyObj(objenum_to_obj(perm)),
  ])
  py_str_enum(res) == (if ours { "True" } else { "False" })
}

///|
pub fn util_distribute_gens_by_base_equiv(
  base : Array[Int],
  gens : Array[Array[Int]],
  ours : Array[Array[Array[Int]]],
) -> Bool raise {
  let perm_args : Array[OracleArg] = Array::new()
  for g in gens {
    let p = perm_obj_from_array(g, None)
    perm_args.push(OracleArg::PyObj(objenum_to_obj(p)))
  }
  let obj = sympy_call_must(
    "sympy.combinatorics.util._distribute_gens_by_base",
    [OracleArg::IntList(base), OracleArg::List(perm_args)],
  )
  let nested = perm_list_list_to_arrays(obj)
  list_list_list_int_equiv(ours, nested)
}

///|
pub fn util_strong_gens_from_distr_equiv(
  strong_gens_distr : Array[Array[Array[Int]]],
  ours : Array[Array[Int]],
) -> Bool raise {
  let outer : Array[OracleArg] = Array::new()
  for part in strong_gens_distr {
    let inner : Array[OracleArg] = Array::new()
    for g in part {
      let p = perm_obj_from_array(g, None)
      inner.push(OracleArg::PyObj(objenum_to_obj(p)))
    }
    outer.push(OracleArg::List(inner))
  }
  let obj = sympy_call_must(
    "sympy.combinatorics.util._strong_gens_from_distr",
    [OracleArg::List(outer)],
  )
  let res = perm_list_to_arrays(obj)
  if res.length() != ours.length() {
    return false
  }
  for i in 0..<ours.length() {
    if ours[i].length() != res[i].length() {
      return false
    }
    for j in 0..<ours[i].length() {
      if ours[i][j] != res[i][j] {
        return false
      }
    }
  }
  true
}

///|
fn int_list_list_arg(values : Array[Array[Int]]) -> OracleArg {
  let args : Array[OracleArg] = Array::new()
  for v in values {
    args.push(OracleArg::IntList(v))
  }
  OracleArg::List(args)
}

///|
fn sym_list_arg(values : Array[Int?]) -> OracleArg {
  let args : Array[OracleArg] = Array::new()
  for v in values {
    match v {
      Some(n) => args.push(OracleArg::Int(n))
      None => args.push(OracleArg::Null)
    }
  }
  OracleArg::List(args)
}

///|
fn perm_list_arg(values : Array[Array[Int]]) -> OracleArg raise {
  let args : Array[OracleArg] = Array::new()
  for g in values {
    let p = perm_obj_from_array(g, None)
    args.push(OracleArg::PyObj(objenum_to_obj(p)))
  }
  OracleArg::List(args)
}

///|
fn tensor_component_tuple(
  base : Array[Int],
  gens : Array[Array[Int]],
  count : Int,
  sym : Int?,
) -> @py.PyObjectEnum raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::IntList(base))
  args.push(perm_list_arg(gens))
  args.push(OracleArg::Int(count))
  match sym {
    Some(v) => args.push(OracleArg::Int(v))
    None => args.push(OracleArg::Null)
  }
  py_builtin_call("tuple", [OracleArg::List(args)])
}

///|
pub fn tensor_can_dummy_sgs_equiv(
  dummies : Array[Int],
  sym : Int?,
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  let sym_arg = match sym {
    Some(v) => OracleArg::Int(v)
    None => OracleArg::Null
  }
  let obj = sympy_call_must("sympy.combinatorics.tensor_can.dummy_sgs", [
    OracleArg::IntList(dummies),
    sym_arg,
    OracleArg::Int(n),
  ])
  let items = py_list_to_pyobjects(obj)
  list_list_int_equiv(ours, items)
}

///|
pub fn tensor_can_min_dummies_equiv(
  dummies : Array[Array[Int]],
  sym : Array[Int?],
  indices : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  let obj = sympy_call_must("sympy.combinatorics.tensor_can._min_dummies", [
    int_list_list_arg(dummies),
    sym_list_arg(sym),
    OracleArg::IntList(indices),
  ])
  let items = py_list_to_pyobjects(obj)
  list_int_equiv(ours, items)
}

///|
pub fn tensor_can_symmetric_group_equiv(
  n : Int,
  antisym : Bool,
  base : Array[Int],
  gens : Array[Array[Int]],
) -> Bool raise {
  let obj = sympy_call_must(
    "sympy.combinatorics.tensor_can.get_symmetric_group_sgs",
    [OracleArg::Int(n), OracleArg::Bool(antisym)],
  )
  let parts = py_list_to_pyobjects(obj)
  if parts.length() != 2 {
    return false
  }
  let base_items = py_list_to_pyobjects(@py.PyObjectEnum::create(parts[0]))
  if !list_int_equiv(base, base_items) {
    return false
  }
  let gens_arrays = perm_list_to_arrays(@py.PyObjectEnum::create(parts[1]))
  array_list_eq(gens, gens_arrays)
}

///|
pub fn tensor_can_perm_af_direct_product_equiv(
  gens1 : Array[Array[Int]],
  gens2 : Array[Array[Int]],
  signed : Bool,
  ours : Array[Array[Int]],
) -> Bool raise {
  let obj = sympy_call_must(
    "sympy.combinatorics.tensor_can.perm_af_direct_product",
    [
      int_list_list_arg(gens1),
      int_list_list_arg(gens2),
      OracleArg::Bool(signed),
    ],
  )
  let items = py_list_to_pyobjects(obj)
  list_list_int_equiv(ours, items)
}

///|
pub fn tensor_can_bsgs_direct_product_equiv(
  base1 : Array[Int],
  gens1 : Array[Array[Int]],
  base2 : Array[Int],
  gens2 : Array[Array[Int]],
  signed : Bool,
  ours_base : Array[Int],
  ours_gens : Array[Array[Int]],
) -> Bool raise {
  let obj = sympy_call_must(
    "sympy.combinatorics.tensor_can.bsgs_direct_product",
    [
      OracleArg::IntList(base1),
      perm_list_arg(gens1),
      OracleArg::IntList(base2),
      perm_list_arg(gens2),
      OracleArg::Bool(signed),
    ],
  )
  let parts = py_list_to_pyobjects(obj)
  if parts.length() != 2 {
    return false
  }
  let base_items = py_list_to_pyobjects(@py.PyObjectEnum::create(parts[0]))
  if !list_int_equiv(ours_base, base_items) {
    return false
  }
  let gens_arrays = perm_list_to_arrays(@py.PyObjectEnum::create(parts[1]))
  array_list_eq(ours_gens, gens_arrays)
}

///|
pub fn tensor_can_tensor_gens_equiv(
  base : Array[Int],
  gens : Array[Array[Int]],
  list_free : Array[Array[Int]],
  sym : Int?,
  ours_size : Int,
  ours_base : Array[Int],
  ours_gens : Array[Array[Int]],
) -> Bool raise {
  let sym_arg = match sym {
    Some(v) => OracleArg::Int(v)
    None => OracleArg::Null
  }
  let obj = sympy_call_must("sympy.combinatorics.tensor_can.tensor_gens", [
    OracleArg::IntList(base),
    perm_list_arg(gens),
    int_list_list_arg(list_free),
    sym_arg,
  ])
  let parts = py_list_to_pyobjects(obj)
  if parts.length() != 3 {
    return false
  }
  let size_val = match py_int_enum(@py.PyObjectEnum::create(parts[0])) {
    Some(v) => v
    None => return false
  }
  if size_val != ours_size {
    return false
  }
  let base_items = py_list_to_pyobjects(@py.PyObjectEnum::create(parts[1]))
  if !list_int_equiv(ours_base, base_items) {
    return false
  }
  let gens_arrays = perm_list_to_arrays(@py.PyObjectEnum::create(parts[2]))
  array_list_eq(ours_gens, gens_arrays)
}

///|
pub fn tensor_can_canonical_free_equiv(
  base : Array[Int],
  gens : Array[Array[Int]],
  g : Array[Int],
  num_free : Int,
  ours : Array[Int],
) -> Bool raise {
  let g_obj = perm_obj_from_array(g, None)
  let obj = sympy_call_must("sympy.combinatorics.tensor_can.canonical_free", [
    OracleArg::IntList(base),
    perm_list_arg(gens),
    OracleArg::PyObj(objenum_to_obj(g_obj)),
    OracleArg::Int(num_free),
  ])
  let items = py_list_to_pyobjects(obj)
  list_int_equiv(ours, items)
}

///|
pub fn tensor_can_double_coset_can_rep_equiv(
  dummies : Array[Array[Int]],
  sym : Array[Int?],
  base : Array[Int],
  sgens : Array[Array[Int]],
  g : Array[Int],
  ours : Array[Int]?,
) -> Bool raise {
  let transv = sympy_call_must(
    "sympy.combinatorics.tensor_can.get_transversals",
    [OracleArg::IntList(base), perm_list_arg(sgens)],
  )
  let g_obj = perm_obj_from_array(g, None)
  let obj = sympy_call_must(
    "sympy.combinatorics.tensor_can.double_coset_can_rep",
    [
      int_list_list_arg(dummies),
      sym_list_arg(sym),
      OracleArg::IntList(base),
      perm_list_arg(sgens),
      OracleArg::PyObj(objenum_to_obj(transv)),
      OracleArg::PyObj(objenum_to_obj(g_obj)),
    ],
  )
  match py_int_enum(obj) {
    Some(v) => {
      if v != 0 {
        return false
      }
      ours is None
    }
    None =>
      match ours {
        Some(arr) => {
          let items = py_list_to_pyobjects(obj)
          list_int_equiv(arr, items)
        }
        None => false
      }
  }
}

///|
pub fn tensor_can_canonicalize_equiv(
  dummies : Array[Array[Int]],
  msym : Array[Int?],
  g : Array[Int],
  bases : Array[Array[Int]],
  gens_list : Array[Array[Array[Int]]],
  counts : Array[Int],
  syms : Array[Int?],
  ours : Array[Int]?,
) -> Bool raise {
  let g_obj = perm_obj_from_array(g, None)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(objenum_to_obj(g_obj)))
  args.push(int_list_list_arg(dummies))
  args.push(sym_list_arg(msym))
  for i in 0..<counts.length() {
    let tup = tensor_component_tuple(bases[i], gens_list[i], counts[i], syms[i])
    args.push(OracleArg::PyObj(objenum_to_obj(tup)))
  }
  let obj = sympy_call_must("sympy.combinatorics.tensor_can.canonicalize", args)
  match py_int_enum(obj) {
    Some(v) => {
      if v != 0 {
        return false
      }
      ours is None
    }
    None =>
      match ours {
        Some(arr) => {
          let items = py_list_to_pyobjects(obj)
          list_int_equiv(arr, items)
        }
        None => false
      }
  }
}
