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
    right_open~ : Bool,
  )
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
        Set::Interval(left=left, right=right, left_open=left_open, right_open=right_open)
      }
    }
    _ => Set::Interval(left=left, right=right, left_open=left_open, right_open=right_open)
  }
}

///|
fn variant_rank(set : Set) -> Int {
  match set {
    Set::EmptySet => 0
    Set::UniversalSet => 1
    Set::Interval(..) => 2
    Set::FiniteSet(_) => 3
    Set::Naturals => 4
    Set::Naturals0 => 5
    Set::Integers => 6
    Set::Rationals => 7
    Set::Reals => 8
    Set::Union(_) => 9
    Set::Intersection(_) => 10
    Set::Complement(_, _) => 11
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
  if len_x < len_y { -1 } else if len_x > len_y { 1 } else { 0 }
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
  if len_x < len_y { -1 } else if len_x > len_y { 1 } else { 0 }
}

///|
pub fn compare_set(a : Set, b : Set) -> Int {
  let ra = variant_rank(a)
  let rb = variant_rank(b)
  if ra != rb {
    return if ra < rb { -1 } else { 1 }
  }
  match (a, b) {
    (Set::Interval(left=al, right=ar, left_open=alo, right_open=aro),
     Set::Interval(left=bl, right=br, left_open=blo, right_open=bro)) => {
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
    (Set::Union(xs), Set::Union(ys)) => compare_set_arrays(xs, ys)
    (Set::Intersection(xs), Set::Intersection(ys)) => compare_set_arrays(xs, ys)
    (Set::Complement(a0, a1), Set::Complement(b0, b1)) => {
      let c0 = compare_set(a0, b0)
      if c0 != 0 { c0 } else { compare_set(a1, b1) }
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
    Set::Interval(left=left, right=right, left_open=left_open, right_open=right_open) => {
      left.hash_combine(hasher)
      right.hash_combine(hasher)
      hasher.combine_int(if left_open { 1 } else { 0 })
      hasher.combine_int(if right_open { 1 } else { 0 })
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
