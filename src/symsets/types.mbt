///|
/// Core symbolic set types and constructors.
///
/// Current Limits:
/// - This package exposes symbolic set objects and canonical constructors.
/// - More advanced reasoning lives in `ops.mbt`; the constructors here mostly preserve symbolic structure.

///|
/// Store one symbolic set expression.
///
/// - Does: Represents exact sets such as intervals, finite sets, products, symbolic predicates, and set operations.
/// - Input: Variant-specific fields such as explicit elements, interval endpoints, or child sets.
/// - Returns: A `Set` value.
/// - Limits: This type stores symbolic structure; deeper reasoning is handled by the set operations package.
pub(all) enum Set {
  EmptySet
  UniversalSet
  FiniteSet(Array[Expr])
  Interval(left~ : Expr, right~ : Expr, left_open~ : Bool, right_open~ : Bool)
  ConditionSet(symbol~ : Expr, condition~ : @symlogic.BoolExpr, base~ : Set)
  ImageSet(symbol~ : Expr, expr~ : Expr, base~ : Set)
  ProductSet(Array[Set])
  Union(Array[Set])
  Intersection(Array[Set])
  Complement(Set, Set)
  Naturals
  Naturals0
  Integers
  Rationals
  Reals
  Complexes
}

///|
/// Store a three-valued decision result for set queries.
///
/// - Does: Represents successful truth, successful falsity, or an undecided result.
/// - Input: One of the variants `True`, `False`, or `Unknown`.
/// - Returns: A `SetBool` value.
/// - Limits: `Unknown` means the current implementation cannot decide the query from the available structure.
pub enum SetBool {
  True
  False
  Unknown
} derive(Eq)

///|
/// Return the empty set.
///
/// - Does: Builds the canonical empty set value.
/// - Input: No arguments.
/// - Returns: `Set::EmptySet`.
/// - Limits: None.
pub fn empty_set() -> Set {
  Set::EmptySet
}

///|
/// Return the universal set.
///
/// - Does: Builds the top element of the symbolic set lattice.
/// - Input: No arguments.
/// - Returns: `Set::UniversalSet`.
/// - Limits: None.
pub fn universal_set() -> Set {
  Set::UniversalSet
}

///|
/// Return the set of positive integers.
///
/// - Does: Builds the canonical set `{1, 2, 3, ...}`.
/// - Input: No arguments.
/// - Returns: `Set::Naturals`.
/// - Limits: None.
pub fn naturals() -> Set {
  Set::Naturals
}

///|
/// Return the set of non-negative integers.
///
/// - Does: Builds the canonical set `{0, 1, 2, ...}`.
/// - Input: No arguments.
/// - Returns: `Set::Naturals0`.
/// - Limits: None.
pub fn naturals0() -> Set {
  Set::Naturals0
}

///|
/// Return the set of integers.
///
/// - Does: Builds the canonical set of all integers.
/// - Input: No arguments.
/// - Returns: `Set::Integers`.
/// - Limits: None.
pub fn integers() -> Set {
  Set::Integers
}

///|
/// Return the set of rational numbers.
///
/// - Does: Builds the canonical rational-number set.
/// - Input: No arguments.
/// - Returns: `Set::Rationals`.
/// - Limits: None.
pub fn rationals() -> Set {
  Set::Rationals
}

///|
/// Return the set of real numbers.
///
/// - Does: Builds the canonical real-number set.
/// - Input: No arguments.
/// - Returns: `Set::Reals`.
/// - Limits: None.
pub fn reals() -> Set {
  Set::Reals
}

///|
/// Return the set of complex numbers.
///
/// - Does: Builds the canonical complex-number set.
/// - Input: No arguments.
/// - Returns: `Set::Complexes`.
/// - Limits: None.
pub fn complexes() -> Set {
  Set::Complexes
}

///|
fn dedup_exprs(items : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = Array::new()
  if items.is_empty() {
    return out
  }
  let tmp : Array[Expr] = Array::new()
  for item in items {
    tmp.push(item)
  }
  @symcore.sort_exprs_in_place(tmp)
  for item in tmp {
    if out.is_empty() {
      out.push(item)
    } else {
      let last = out[out.length() - 1]
      if @symcore.compare_expr(item, last) != 0 {
        out.push(item)
      }
    }
  }
  out
}

///|
/// Build a finite set from explicit elements.
///
/// - Does: Canonicalizes the input expressions, removes duplicates, and wraps them as a finite set.
/// - Input: An `Array[Expr]` of explicit set elements.
/// - Returns: A canonical `FiniteSet` or `EmptySet`.
/// - Limits: Equality is structural, not semantic.
pub fn finite_set(items : Array[Expr]) -> Set {
  let uniq = dedup_exprs(items)
  if uniq.is_empty() {
    Set::EmptySet
  } else {
    Set::FiniteSet(uniq)
  }
}

///|
/// Build a set defined by a boolean predicate over one symbol.
///
/// - Does: Stores the values in `base` that satisfy `condition` for the bound `symbol`.
/// - Input: One bound `Expr`, one `BoolExpr` predicate, and an optional base set.
/// - Returns: A simplified `Set`, often `ConditionSet`, `base`, or `EmptySet`.
/// - Limits: Only obvious `True` and `False` simplifications are applied here.
pub fn condition_set(
  symbol : Expr,
  condition : @symlogic.BoolExpr,
  base? : Set = Set::UniversalSet,
) -> Set {
  match base {
    Set::EmptySet => Set::EmptySet
    _ =>
      match condition {
        @symlogic.BoolExpr::True => base
        @symlogic.BoolExpr::False => Set::EmptySet
        _ => Set::ConditionSet(symbol~, condition~, base~)
      }
  }
}

///|
/// Build the image of a set under a symbolic mapping.
///
/// - Does: Represents all values obtained by substituting members of `base` into `expr` through the bound `symbol`.
/// - Input: One bound `Expr`, one target expression, and an optional base set.
/// - Returns: A simplified `Set`, often `base`, `EmptySet`, a singleton `FiniteSet`, or `ImageSet`.
/// - Limits: Constant-map simplification is eager; general image reasoning is deferred.
pub fn image_set(
  symbol : Expr,
  expr : Expr,
  base? : Set = Set::UniversalSet,
) -> Set {
  let var_name = match symbol {
    Expr::Symbol(name) => name
    _ => ""
  }
  if expr_equal(expr, symbol) {
    return base
  }
  if var_name != "" && !expr_depends_on(expr, var_name) {
    match set_is_empty(base) {
      SetBool::True => return Set::EmptySet
      SetBool::False => return finite_set([expr])
      SetBool::Unknown => ()
    }
  }
  match base {
    Set::EmptySet => Set::EmptySet
    _ => Set::ImageSet(symbol~, expr~, base~)
  }
}

///|
/// Build a Cartesian product of sets.
///
/// - Does: Flattens nested products and constructs one symbolic Cartesian product.
/// - Input: An `Array[Set]` of factors.
/// - Returns: A simplified `Set`, often `EmptySet`, a tuple singleton, or `ProductSet`.
/// - Limits: If any factor is empty the result is empty; an empty input becomes the singleton empty tuple.
pub fn product_set(sets : Array[Set]) -> Set {
  if sets.is_empty() {
    return finite_set([@symcore.function("Tuple", [])])
  }
  let flat : Array[Set] = Array::new()
  for set in sets {
    match set {
      Set::ProductSet(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(set)
    }
  }
  for item in flat {
    match set_is_empty(item) {
      SetBool::True => return Set::EmptySet
      _ => ()
    }
  }
  Set::ProductSet(flat)
}

///|
fn expr_number_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_equal(a : Expr, b : Expr) -> Bool {
  @symcore.compare_expr(a, b) == 0
}

///|
/// Build a symbolic interval.
///
/// - Does: Constructs a closed, open, or half-open interval and simplifies obvious numeric degeneracies.
/// - Input: Two endpoint expressions plus optional openness flags.
/// - Returns: A simplified `Set`, often `Interval`, `FiniteSet`, or `EmptySet`.
/// - Limits: Endpoint normalization is strongest when both bounds are numeric.
pub fn interval(
  left : Expr,
  right : Expr,
  left_open? : Bool = false,
  right_open? : Bool = false,
) -> Set {
  if expr_equal(left, right) {
    if left_open || right_open {
      return Set::EmptySet
    }
    return finite_set([left])
  }
  match (expr_number_value(left), expr_number_value(right)) {
    (Some(lv), Some(rv)) => {
      let cmp = lv.compare(rv)
      if cmp > 0 {
        Set::EmptySet
      } else if cmp == 0 {
        if left_open || right_open {
          Set::EmptySet
        } else {
          finite_set([left])
        }
      } else {
        Set::Interval(left~, right~, left_open~, right_open~)
      }
    }
    _ => Set::Interval(left~, right~, left_open~, right_open~)
  }
}

///|
fn variant_rank(set : Set) -> Int {
  match set {
    Set::EmptySet => 0
    Set::UniversalSet => 1
    Set::Interval(..) => 2
    Set::FiniteSet(_) => 3
    Set::ConditionSet(..) => 4
    Set::ImageSet(..) => 5
    Set::ProductSet(_) => 6
    Set::Naturals => 7
    Set::Naturals0 => 8
    Set::Integers => 9
    Set::Rationals => 10
    Set::Reals => 11
    Set::Complexes => 12
    Set::Union(_) => 13
    Set::Intersection(_) => 14
    Set::Complement(_, _) => 15
  }
}

///|
fn compare_exprs(a : Expr, b : Expr) -> Int {
  @symcore.compare_expr(a, b)
}

///|
fn compare_expr_arrays(xs : Array[Expr], ys : Array[Expr]) -> Int {
  let len_x = xs.length()
  let len_y = ys.length()
  let min_len = if len_x < len_y { len_x } else { len_y }
  for i in 0..<min_len {
    let cmp = compare_exprs(xs[i], ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  if len_x < len_y {
    -1
  } else if len_x > len_y {
    1
  } else {
    0
  }
}

///|
fn compare_set_arrays(xs : Array[Set], ys : Array[Set]) -> Int {
  let len_x = xs.length()
  let len_y = ys.length()
  let min_len = if len_x < len_y { len_x } else { len_y }
  for i in 0..<min_len {
    let cmp = compare_set(xs[i], ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  if len_x < len_y {
    -1
  } else if len_x > len_y {
    1
  } else {
    0
  }
}

///|
/// Compare two sets with the package's canonical structural order.
///
/// - Does: Produces a stable ordering for sorting, deduplication, and hashing support.
/// - Input: Two `Set` values.
/// - Returns: A negative, zero, or positive `Int`.
/// - Limits: This is a structural order, not a mathematical order such as subset inclusion.
pub fn compare_set(a : Set, b : Set) -> Int {
  let ra = variant_rank(a)
  let rb = variant_rank(b)
  if ra != rb {
    return if ra < rb { -1 } else { 1 }
  }
  match (a, b) {
    (
      Set::Interval(left=al, right=ar, left_open=alo, right_open=aro),
      Set::Interval(left=bl, right=br, left_open=blo, right_open=bro),
    ) => {
      let cmp_l = compare_exprs(al, bl)
      if cmp_l != 0 {
        return cmp_l
      }
      let cmp_r = compare_exprs(ar, br)
      if cmp_r != 0 {
        return cmp_r
      }
      if alo != blo {
        return if alo { 1 } else { -1 }
      }
      if aro != bro {
        return if aro { 1 } else { -1 }
      }
      0
    }
    (Set::FiniteSet(xs), Set::FiniteSet(ys)) => compare_expr_arrays(xs, ys)
    (
      Set::ConditionSet(symbol=sym_a, condition=cond_a, base=base_a),
      Set::ConditionSet(symbol=sym_b, condition=cond_b, base=base_b),
    ) => {
      let c0 = compare_exprs(sym_a, sym_b)
      if c0 != 0 {
        c0
      } else {
        let s0 = @symlogic.to_string(cond_a)
        let s1 = @symlogic.to_string(cond_b)
        let c1 = s0.compare(s1)
        if c1 != 0 {
          c1
        } else {
          compare_set(base_a, base_b)
        }
      }
    }
    (
      Set::ImageSet(symbol=sym_a, expr=expr_a, base=base_a),
      Set::ImageSet(symbol=sym_b, expr=expr_b, base=base_b),
    ) => {
      let c0 = compare_exprs(sym_a, sym_b)
      if c0 != 0 {
        c0
      } else {
        let c1 = compare_exprs(expr_a, expr_b)
        if c1 != 0 {
          c1
        } else {
          compare_set(base_a, base_b)
        }
      }
    }
    (Set::ProductSet(xs), Set::ProductSet(ys)) => compare_set_arrays(xs, ys)
    (Set::Union(xs), Set::Union(ys)) => compare_set_arrays(xs, ys)
    (Set::Intersection(xs), Set::Intersection(ys)) => compare_set_arrays(xs, ys)
    (Set::Complement(a0, a1), Set::Complement(b0, b1)) => {
      let c0 = compare_set(a0, b0)
      if c0 != 0 {
        c0
      } else {
        compare_set(a1, b1)
      }
    }
    _ => 0
  }
}

///|
/// Sort a mutable array of sets in canonical structural order.
///
/// - Does: Reorders the array in place using `compare_set`.
/// - Input: A mutable `Array[Set]`.
/// - Returns: `Unit`.
/// - Limits: The ordering is structural and only intended for canonicalization tasks.
pub fn sort_sets_in_place(args : Array[Set]) -> Unit {
  args.sort_by(compare_set)
}

///|
/// Compare two sets through the standard `Compare` interface.
///
/// - Does: Delegates to `compare_set`.
/// - Input: Two `Set` values.
/// - Returns: A negative, zero, or positive `Int`.
/// - Limits: Has the same structural semantics as `compare_set`.
pub impl Compare for Set with compare(self, other : Set) -> Int {
  compare_set(self, other)
}

///|
/// Test structural equality between two sets.
///
/// - Does: Compares two sets with the canonical structural order and reports equality.
/// - Input: Two `Set` values.
/// - Returns: `true` when the sets are structurally equal.
/// - Limits: Equality is structural and does not perform deep semantic reasoning.
pub impl Eq for Set with equal(self, other : Set) -> Bool {
  compare_set(self, other) == 0
}

///|
/// Test structural inequality between two sets.
///
/// - Does: Negates the result of the structural equality check.
/// - Input: Two `Set` values.
/// - Returns: `true` when the sets are not structurally equal.
/// - Limits: Has the same structural semantics as `equal`.
pub impl Eq for Set with not_equal(self, other : Set) -> Bool {
  !self.equal(other)
}

///|
/// Hash one set value.
///
/// - Does: Builds a fresh hasher, combines the set into it, and returns the final hash code.
/// - Input: One `Set` value.
/// - Returns: One `Int` hash value.
/// - Limits: Hash stability follows the package's structural canonicalization rules.
pub impl Hash for Set with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
/// Combine one set value into an existing hasher.
///
/// - Does: Mixes the set structure and payload into the provided hasher.
/// - Input: One `Set` value and one mutable `Hasher`.
/// - Returns: `Unit`.
/// - Limits: Hashing is structural and follows the same semantics as `compare_set`.
pub impl Hash for Set with hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_int(variant_rank(self))
  match self {
    Set::FiniteSet(items) =>
      for item in items {
        item.hash_combine(hasher)
      }
    Set::Interval(left~, right~, left_open~, right_open~) => {
      left.hash_combine(hasher)
      right.hash_combine(hasher)
      hasher.combine_int(if left_open { 1 } else { 0 })
      hasher.combine_int(if right_open { 1 } else { 0 })
    }
    Set::ConditionSet(symbol~, condition~, base~) => {
      symbol.hash_combine(hasher)
      condition.hash_combine(hasher)
      base.hash_combine(hasher)
    }
    Set::ImageSet(symbol~, expr~, base~) => {
      symbol.hash_combine(hasher)
      expr.hash_combine(hasher)
      base.hash_combine(hasher)
    }
    Set::ProductSet(items) =>
      for item in items {
        item.hash_combine(hasher)
      }
    Set::Union(items) | Set::Intersection(items) =>
      for item in items {
        item.hash_combine(hasher)
      }
    Set::Complement(a, b) => {
      a.hash_combine(hasher)
      b.hash_combine(hasher)
    }
    _ => ()
  }
}
