///|
pub(all) enum CombineMode {
  Associative
  Commutative
} derive(Eq)

///|
/// Pick elements from `values` by index.
pub fn[T] index(values : Array[T], indices : Array[Int]) -> Array[T] {
  let out : Array[T] = []
  for idx in indices {
    out.push(values[idx])
  }
  out
}

///|
/// Partition `values` according to groups of indices.
///
/// Each inner array in `parts` describes one output group.
pub fn[T] partition(
  values : Array[T],
  parts : Array[Array[Int]],
) -> Array[Array[T]] {
  let out : Array[Array[T]] = []
  for part in parts {
    out.push(index(values, part))
  }
  out
}

///|
fn contiguous_index_partitions(
  start : Int,
  total : Int,
  bins : Int,
) -> Array[Array[Array[Int]]] {
  if bins <= 0 || total < bins {
    return []
  }
  if bins == 1 {
    let part : Array[Int] = []
    for i in start..<(start + total) {
      part.push(i)
    }
    return [[part]]
  }
  let out : Array[Array[Array[Int]]] = []
  let max_first = total - bins + 1
  for first_len in 1..<=max_first {
    let first : Array[Int] = []
    for i in start..<(start + first_len) {
      first.push(i)
    }
    let rest = contiguous_index_partitions(
      start + first_len,
      total - first_len,
      bins - 1,
    )
    for tail in rest {
      let piece : Array[Array[Int]] = [first]
      for item in tail {
        piece.push(item)
      }
      out.push(piece)
    }
  }
  out
}

///|
fn[T] permutations(values : Array[T]) -> Array[Array[T]] {
  let out : Array[Array[T]] = []
  let used : Array[Bool] = Array::make(values.length(), false)
  let current : Array[T] = []
  letrec dfs = () => {
    if current.length() == values.length() {
      out.push(current.copy())
      return
    }
    for i in 0..<values.length() {
      if used[i] {
        continue
      }
      used[i] = true
      current.push(values[i])
      dfs()
      ignore(current.pop())
      used[i] = false
    }
  }
  dfs()
  out
}

///|
/// Enumerate all grouped pairings used by associative or commutative matching.
///
/// The result pairs a grouped view of `lhs` with a grouped view of `rhs`. In
/// commutative mode, permutations of the larger side are considered as well.
pub fn[T] allcombinations(
  lhs : Array[T],
  rhs : Array[T],
  mode : CombineMode,
) -> Array[(Array[Array[T]], Array[Array[T]])] {
  let out : Array[(Array[Array[T]], Array[Array[T]])] = []
  let lhs_is_small = lhs.length() <= rhs.length()
  let sm = if lhs_is_small { lhs } else { rhs }
  let bg = if lhs_is_small { rhs } else { lhs }
  let base_partitions = contiguous_index_partitions(0, bg.length(), sm.length())
  let candidates = match mode {
    CombineMode::Associative => [bg.copy()]
    CombineMode::Commutative => permutations(bg)
  }
  for candidate in candidates {
    for part in base_partitions {
      let grouped_big = partition(candidate, part)
      let grouped_small : Array[Array[T]] = []
      for item in sm {
        grouped_small.push([item])
      }
      if lhs_is_small {
        out.push((grouped_small, grouped_big))
      } else {
        out.push((grouped_big, grouped_small))
      }
    }
  }
  out
}

///|
fn[T, Op] unpack_compound(
  op : Op,
  args : Array[UnifyTerm[T, Op]],
) -> UnifyTerm[T, Op] {
  if args.length() == 1 {
    args[0]
  } else {
    compound(op, args)
  }
}

///|
/// Test whether binding `key` to `term` would create a recursive substitution.
pub fn[T : Eq, Op] occur_check(
  key : MatchVar[T],
  term : UnifyTerm[T, Op],
) -> Bool {
  match term_match_var(term) {
    Some(other) => other == key
    None =>
      match compound_parts(term) {
        Some((_, args)) => args.any(arg => occur_check(key, arg))
        None =>
          match sequence_items(term) {
            Some(items) => items.any(item => occur_check(key, item))
            None => false
          }
      }
  }
}

///|
fn[T : Eq + Hash, Op : Eq] unify_many_into(
  out : Array[Substitution[T, Op]],
  lhs : Array[UnifyTerm[T, Op]],
  rhs : Array[UnifyTerm[T, Op]],
  subst : Substitution[T, Op],
  is_associative : (UnifyTerm[T, Op]) -> Bool,
  is_commutative : (UnifyTerm[T, Op]) -> Bool,
) -> Unit {
  if lhs.length() != rhs.length() {
    return
  }
  if lhs.is_empty() {
    out.push(subst)
    return
  }
  let head_matches = core_unify(
    lhs[0],
    rhs[0],
    s=subst,
    is_associative~,
    is_commutative~,
  )
  let lhs_tail : Array[UnifyTerm[T, Op]] = []
  let rhs_tail : Array[UnifyTerm[T, Op]] = []
  for i in 1..<lhs.length() {
    lhs_tail.push(lhs[i])
    rhs_tail.push(rhs[i])
  }
  for head_subst in head_matches {
    unify_many_into(
      out, lhs_tail, rhs_tail, head_subst, is_associative, is_commutative,
    )
  }
}

///|
fn[T : Eq + Hash, Op : Eq] unify_variable_into(
  out : Array[Substitution[T, Op]],
  var_term : UnifyTerm[T, Op],
  expr : UnifyTerm[T, Op],
  subst : Substitution[T, Op],
  is_associative : (UnifyTerm[T, Op]) -> Bool,
  is_commutative : (UnifyTerm[T, Op]) -> Bool,
) -> Unit {
  let key = match term_match_var(var_term) {
    Some(found) => found
    None => return
  }
  match subst.get(key) {
    Some(bound) =>
      for
        next_subst in core_unify(
          bound,
          expr,
          s=subst,
          is_associative~,
          is_commutative~,
        ) {
        out.push(next_subst)
      }
    None =>
      if occur_check(key, expr) {
        ()
      } else {
        match term_cond_validator(var_term) {
          Some(valid) =>
            if valid(expr) {
              out.push(substitution_assoc(subst, key, expr))
            }
          None => out.push(substitution_assoc(subst, key, expr))
        }
      }
  }
}

///|
/// Unify two generic terms and return every consistent substitution.
///
/// The optional callbacks describe which compound terms should be treated as
/// associative or commutative during matching. The result array is empty when no
/// unifier exists.
pub fn[T : Eq + Hash, Op : Eq] core_unify(
  lhs : UnifyTerm[T, Op],
  rhs : UnifyTerm[T, Op],
  s? : Substitution[T, Op] = {},
  is_associative? : (UnifyTerm[T, Op]) -> Bool = _ => false,
  is_commutative? : (UnifyTerm[T, Op]) -> Bool = _ => false,
) -> Array[Substitution[T, Op]] {
  let out : Array[Substitution[T, Op]] = []
  if term_equal(lhs, rhs) {
    out.push(s)
    return out
  }
  if term_match_var(lhs) is Some(_) {
    unify_variable_into(out, lhs, rhs, s, is_associative, is_commutative)
    return out
  }
  if term_match_var(rhs) is Some(_) {
    unify_variable_into(out, rhs, lhs, s, is_associative, is_commutative)
    return out
  }
  match (compound_parts(lhs), compound_parts(rhs)) {
    (Some((op_lhs, args_lhs)), Some((op_rhs, args_rhs))) => {
      if op_lhs != op_rhs {
        return out
      }
      let lhs_assoc = is_associative(lhs)
      let rhs_assoc = is_associative(rhs)
      if lhs_assoc && rhs_assoc {
        let small = if args_lhs.length() <= args_rhs.length() {
          lhs
        } else {
          rhs
        }
        let big = if args_lhs.length() <= args_rhs.length() { rhs } else { lhs }
        let (small_op, small_args) = compound_parts(small).unwrap_or(
          (op_lhs, []),
        )
        let (_, big_args) = compound_parts(big).unwrap_or((op_rhs, []))
        let mode = if is_commutative(lhs) && is_commutative(rhs) {
          CombineMode::Commutative
        } else {
          CombineMode::Associative
        }
        for combo in allcombinations(small_args, big_args, mode) {
          let (lhs_groups, rhs_groups) = combo
          let lhs_terms : Array[UnifyTerm[T, Op]] = []
          let rhs_terms : Array[UnifyTerm[T, Op]] = []
          for group in lhs_groups {
            lhs_terms.push(unpack_compound(small_op, group))
          }
          for group in rhs_groups {
            rhs_terms.push(unpack_compound(small_op, group))
          }
          unify_many_into(
            out, lhs_terms, rhs_terms, s, is_associative, is_commutative,
          )
        }
        return out
      }
      unify_many_into(
        out, args_lhs, args_rhs, s, is_associative, is_commutative,
      )
      return out
    }
    _ => ()
  }
  match (sequence_items(lhs), sequence_items(rhs)) {
    (Some(lhs_items), Some(rhs_items)) =>
      unify_many_into(
        out, lhs_items, rhs_items, s, is_associative, is_commutative,
      )
    _ => ()
  }
  out
}
