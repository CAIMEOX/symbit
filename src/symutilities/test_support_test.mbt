///|\
/// Shared test helpers for `symutilities`.

///|
fn int_array_json(values : Array[Int]) -> String {
  "[" + values.map(v => v.to_string()).join(", ") + "]"
}

///|
fn int_matrix_json(values : Array[Array[Int]]) -> String {
  "[" + values.map(int_array_json).join(", ") + "]"
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
    PartitionResult::Parts(counts) => int_count_map_json(counts)
    PartitionResult::Sized(size, counts) =>
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
    Nested::Atom(v) => v.to_string()
    Nested::Items(items) => "[" + items.map(nested_int_json).join(", ") + "]"
  }
}

///|
fn nested_int_array_json(values : Array[Nested[Int]]) -> String {
  "[" + values.map(nested_int_json).join(", ") + "]"
}

///|
fn group_result_int_json(value : GroupResult[Int]) -> String {
  match value {
    GroupResult::Multiple(items) => int_matrix_json(items)
    GroupResult::Counts(items) =>
      "[" +
      items
      .map(item => "[" + item.0.to_string() + ", " + item.1.to_string() + "]")
      .join(", ") +
      "]"
  }
}
