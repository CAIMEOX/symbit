///|
/// Core set types and constructors.

///|
pub(all) enum Set {
  EmptySet
  UniversalSet
  FiniteSet(Array[@symcore.Expr])
  Interval(
    left~ : @symcore.Expr,
    right~ : @symcore.Expr,
    left_open~ : Bool,
    right_open~ : Bool
  )
  ConditionSet(
    symbol~ : @symcore.Expr,
    condition~ : @symlogic.BoolExpr,
    base~ : Set
  )
  ImageSet(symbol~ : @symcore.Expr, expr~ : @symcore.Expr, base~ : Set)
  ProductSet(Array[Set])
  Union(Array[Set])
  Intersection(Array[Set])
  Complement(Set, Set)
  Naturals
  Naturals0
  Integers
  Rationals
  Reals
}

///|
pub enum SetBool {
  True
  False
  Unknown
}

///|
pub fn empty_set() -> Set {
  Set::EmptySet
}

///|
pub fn universal_set() -> Set {
  Set::UniversalSet
}

///|
pub fn naturals() -> Set {
  Set::Naturals
}

///|
pub fn naturals0() -> Set {
  Set::Naturals0
}

///|
pub fn integers() -> Set {
  Set::Integers
}

///|
pub fn rationals() -> Set {
  Set::Rationals
}

///|
pub fn reals() -> Set {
  Set::Reals
}

///|
fn dedup_exprs(items : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  if items.is_empty() {
    return out
  }
  let tmp : Array[@symcore.Expr] = Array::new()
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
pub fn finite_set(items : Array[@symcore.Expr]) -> Set {
  let uniq = dedup_exprs(items)
  if uniq.is_empty() {
    Set::EmptySet
  } else {
    Set::FiniteSet(uniq)
  }
}

///|
pub fn condition_set(
  symbol : @symcore.Expr,
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
pub fn image_set(
  symbol : @symcore.Expr,
  expr : @symcore.Expr,
  base? : Set = Set::UniversalSet,
) -> Set {
  let var_name = match symbol {
    @symcore.Expr::Symbol(name) => name
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
fn expr_number_value(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_equal(a : @symcore.Expr, b : @symcore.Expr) -> Bool {
  @symcore.compare_expr(a, b) == 0
}

///|
pub fn interval(
  left : @symcore.Expr,
  right : @symcore.Expr,
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
    Set::Union(_) => 12
    Set::Intersection(_) => 13
    Set::Complement(_, _) => 14
  }
}

///|
fn compare_exprs(a : @symcore.Expr, b : @symcore.Expr) -> Int {
  @symcore.compare_expr(a, b)
}

///|
fn compare_expr_arrays(
  xs : Array[@symcore.Expr],
  ys : Array[@symcore.Expr],
) -> Int {
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
pub fn sort_sets_in_place(args : Array[Set]) -> Unit {
  args.sort_by(compare_set)
}

///|
pub impl Compare for Set with compare(self, other : Set) -> Int {
  compare_set(self, other)
}

///|
pub impl Eq for Set with equal(self, other : Set) -> Bool {
  compare_set(self, other) == 0
}

///|
pub impl Eq for Set with not_equal(self, other : Set) -> Bool {
  !self.equal(other)
}

///|
pub impl Hash for Set with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
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

///|
pub impl Eq for SetBool with equal(self, other : SetBool) -> Bool {
  match (self, other) {
    (SetBool::True, SetBool::True) => true
    (SetBool::False, SetBool::False) => true
    (SetBool::Unknown, SetBool::Unknown) => true
    _ => false
  }
}

///|
pub impl Eq for SetBool with not_equal(self, other : SetBool) -> Bool {
  !self.equal(other)
}
