///|
/// Shared test helpers for `symutilities`.

///|
using @symutilities {
  type AssocRecurrenceMemo,
  type GroupResult,
  type MultisetPartitionState,
  type MultisetPartitionTraverser,
  type Nested,
  type PartitionResult,
  type TimethisReport,
  as_int,
  assoc_recurrence_memo,
  autowrap,
  binary_function,
  binary_partitions,
  bracelets,
  capture,
  cartes,
  codegen,
  common_prefix,
  common_suffix,
  connected_components,
  deprecated,
  factoring_visitor,
  filldedent,
  flatten,
  generate_derangements,
  get_class,
  get_mod_func,
  get_resource,
  get_srepr,
  group,
  has_dups,
  has_variety,
  ibin,
  ibin_all,
  ibin_all_str,
  ibin_str,
  implemented_function,
  int_like_bool,
  int_like_double,
  int_like_expr,
  int_like_int,
  lambdastr,
  lambdify,
  least_rotation,
  list_visitor,
  make_routine,
  memoize,
  minlex,
  multiset,
  multiset_combinations,
  multiset_partitions_taocp,
  multiset_permutations,
  necklaces,
  nested_atom,
  nested_items,
  numbered_symbols,
  ordered_partitions,
  ordinal,
  partitions,
  permutations,
  permute_signs,
  pkgdata_deprecation_warning,
  pollute,
  postfixes,
  prefixes,
  public,
  pytest_deprecation_warning,
  randtest_deprecation_warning,
  rawlines,
  recurrence_memo,
  replace,
  replacement_info,
  replacer,
  reshape,
  rotate_left,
  rotate_right,
  rotations,
  routine_result,
  runs,
  runtests_deprecation_warning,
  sequence_partitions,
  sequence_partitions_empty,
  shape_group,
  shape_take,
  sift,
  sift_binary,
  signed_permutations,
  strlines,
  strongly_connected_components,
  subsets,
  sympy_deprecation_warning,
  take,
  threadable_scalar,
  threaded,
  timed,
  timethis,
  tmpfiles_deprecation_warning,
  topological_sort,
  translate,
  ufuncify,
  unflatten,
  uniq,
  variations,
  wild_dot,
  wild_plus,
  wild_star,
  xthreaded,
}

///|
fn int_array_json(values : Array[Int]) -> String {
  "[" + values.map(v => v.to_string()).join(", ") + "]"
}

///|
fn int_matrix_json(values : Array[Array[Int]]) -> String {
  "[" + values.map(int_array_json).join(", ") + "]"
}

///|
fn string_json(value : String) -> String {
  "\"" + value + "\""
}

///|
fn string_array_json(values : Array[String]) -> String {
  "[" + values.map(string_json).join(", ") + "]"
}

///|
fn string_matrix_json(values : Array[Array[String]]) -> String {
  "[" + values.map(string_array_json).join(", ") + "]"
}

///|
fn string_tensor3_json(values : Array[Array[Array[String]]]) -> String {
  "[" + values.map(string_matrix_json).join(", ") + "]"
}

///|
fn int_count_map_json(values : Map[Int, Int]) -> String {
  let items : Array[(Int, Int)] = []
  for key, value in values {
    items.push((key, value))
  }
  items.sort_by((a, b) => a.0 - b.0)
  "[" +
  items
  .map(item => "[" + item.0.to_string() + ", " + item.1.to_string() + "]")
  .join(", ") +
  "]"
}

///|
fn partition_result_json(value : PartitionResult) -> String {
  match value {
    Parts(counts) => int_count_map_json(counts)
    Sized(size, counts) =>
      "[" + size.to_string() + ", " + int_count_map_json(counts) + "]"
  }
}

///|
fn partition_result_array_json(values : Array[PartitionResult]) -> String {
  "[" + values.map(partition_result_json).join(", ") + "]"
}

///|
fn nested_int_json(value : Nested[Int]) -> String {
  match value {
    Atom(v) => v.to_string()
    Items(items) => "[" + items.map(nested_int_json).join(", ") + "]"
  }
}

///|
fn nested_int_array_json(values : Array[Nested[Int]]) -> String {
  "[" + values.map(nested_int_json).join(", ") + "]"
}

///|
fn group_result_int_json(value : GroupResult[Int]) -> String {
  match value {
    Multiple(items) => int_matrix_json(items)
    Counts(items) =>
      "[" +
      items
      .map(item => "[" + item.0.to_string() + ", " + item.1.to_string() + "]")
      .join(", ") +
      "]"
  }
}
