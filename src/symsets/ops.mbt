///|
/// Core set operations and membership.

///|
fn setbool_or(a : SetBool, b : SetBool) -> SetBool {
  match (a, b) {
    (SetBool::True, _) | (_, SetBool::True) => SetBool::True
    (SetBool::Unknown, _) | (_, SetBool::Unknown) => SetBool::Unknown
    _ => SetBool::False
  }
}

///|
fn setbool_and(a : SetBool, b : SetBool) -> SetBool {
  match (a, b) {
    (SetBool::False, _) | (_, SetBool::False) => SetBool::False
    (SetBool::Unknown, _) | (_, SetBool::Unknown) => SetBool::Unknown
    _ => SetBool::True
  }
}

///|
fn setbool_not(a : SetBool) -> SetBool {
  match a {
    SetBool::True => SetBool::False
    SetBool::False => SetBool::True
    SetBool::Unknown => SetBool::Unknown
  }
}

///|
fn expr_depends_on(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(s) => s == name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => expr_depends_on(child, name))
    @symcore.Expr::Pow(base, exp) =>
      expr_depends_on(base, name) || expr_depends_on(exp, name)
    @symcore.Expr::Function(_, args) =>
      args.any(child => expr_depends_on(child, name))
    _ => false
  }
}

///|
fn set_is_empty(set : Set) -> SetBool {
  match set {
    Set::EmptySet => SetBool::True
    Set::UniversalSet => SetBool::False
    Set::FiniteSet(items) =>
      if items.is_empty() {
        SetBool::True
      } else {
        SetBool::False
      }
    Set::Interval(..) => SetBool::False
    Set::Naturals
    | Set::Naturals0
    | Set::Integers
    | Set::Rationals
    | Set::Reals => SetBool::False
    Set::ProductSet(items) => {
      for item in items {
        match set_is_empty(item) {
          SetBool::True => return SetBool::True
          SetBool::Unknown => return SetBool::Unknown
          _ => ()
        }
      }
      SetBool::False
    }
    Set::ConditionSet(symbol=_, condition=_, base~) => set_is_empty(base)
    Set::ImageSet(symbol=_, expr=_, base~) => set_is_empty(base)
    _ => SetBool::Unknown
  }
}

///|

///|
fn eval_lra_constraint(
  constraint : @symlogic.LinearConstraint,
  var_name : String,
  value : @symnum.BigRational,
) -> SetBool {
  let coeffs = constraint.coeffs
  if coeffs.is_empty() {
    let cmp = @symnum.BigRational::zero().compare(constraint.rhs)
    return match constraint.op {
      @symlogic.RelOp::Le =>
        if cmp <= 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Ge =>
        if cmp >= 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Lt =>
        if cmp < 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Gt =>
        if cmp > 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Eq =>
        if cmp == 0 {
          SetBool::True
        } else {
          SetBool::False
        }
    }
  }
  if coeffs.length() != 1 {
    return SetBool::Unknown
  }
  match coeffs.get(var_name) {
    None => SetBool::Unknown
    Some(coeff) => {
      let lhs = coeff.mul_r(value)
      let cmp = lhs.compare(constraint.rhs)
      match constraint.op {
        @symlogic.RelOp::Le =>
          if cmp <= 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Ge =>
          if cmp >= 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Lt =>
          if cmp < 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Gt =>
          if cmp > 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Eq =>
          if cmp == 0 {
            SetBool::True
          } else {
            SetBool::False
          }
      }
    }
  }
}

///|
fn eval_bool_expr(
  expr : @symlogic.BoolExpr,
  var_name : String,
  value : @symnum.BigRational?,
) -> SetBool {
  match expr {
    @symlogic.BoolExpr::True => SetBool::True
    @symlogic.BoolExpr::False => SetBool::False
    @symlogic.BoolExpr::Not(inner) =>
      setbool_not(eval_bool_expr(inner, var_name, value))
    @symlogic.BoolExpr::And(args) => {
      let mut acc = SetBool::True
      for arg in args {
        acc = setbool_and(acc, eval_bool_expr(arg, var_name, value))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    @symlogic.BoolExpr::Or(args) => {
      let mut acc = SetBool::False
      for arg in args {
        acc = setbool_or(acc, eval_bool_expr(arg, var_name, value))
        if acc == SetBool::True {
          return acc
        }
      }
      acc
    }
    @symlogic.BoolExpr::Implies(a, b) => {
      let not_a = setbool_not(eval_bool_expr(a, var_name, value))
      setbool_or(not_a, eval_bool_expr(b, var_name, value))
    }
    @symlogic.BoolExpr::Equivalent(args) => {
      if args.is_empty() {
        return SetBool::True
      }
      let first = eval_bool_expr(args[0], var_name, value)
      for i in 1..<args.length() {
        let current = eval_bool_expr(args[i], var_name, value)
        if first == SetBool::Unknown || current == SetBool::Unknown {
          return SetBool::Unknown
        }
        if first != current {
          return SetBool::False
        }
      }
      first
    }
    @symlogic.BoolExpr::ITE(c, t, e) =>
      match eval_bool_expr(c, var_name, value) {
        SetBool::True => eval_bool_expr(t, var_name, value)
        SetBool::False => eval_bool_expr(e, var_name, value)
        SetBool::Unknown => SetBool::Unknown
      }
    @symlogic.BoolExpr::LRA(constraint) =>
      match value {
        Some(v) => eval_lra_constraint(constraint, var_name, v)
        None => SetBool::Unknown
      }
    _ => SetBool::Unknown
  }
}

///|
fn dedup_sets(items : Array[Set]) -> Array[Set] {
  let out : Array[Set] = Array::new()
  if items.is_empty() {
    return out
  }
  let tmp : Array[Set] = Array::new()
  for item in items {
    tmp.push(item)
  }
  sort_sets_in_place(tmp)
  for item in tmp {
    if out.is_empty() {
      out.push(item)
    } else {
      let last = out[out.length() - 1]
      if compare_set(item, last) != 0 {
        out.push(item)
      }
    }
  }
  out
}

///|
fn interval_numeric(
  set : Set,
) -> (
  @symnum.BigRational,
  @symnum.BigRational,
  Bool,
  Bool,
  @symcore.Expr,
  @symcore.Expr,
)? {
  match set {
    Set::Interval(left~, right~, left_open~, right_open~) =>
      match (expr_number_value(left), expr_number_value(right)) {
        (Some(lv), Some(rv)) =>
          Some((lv, rv, left_open, right_open, left, right))
        _ => None
      }
    _ => None
  }
}

///|
fn interval_overlap_or_touch(
  a : (@symnum.BigRational, @symnum.BigRational, Bool, Bool),
  b : (@symnum.BigRational, @symnum.BigRational, Bool, Bool),
) -> Bool {
  let (_al, ar, _alo, aro) = a
  let (bl, _br, blo, _bro) = b
  let cmp = bl.compare(ar)
  if cmp < 0 {
    true
  } else if cmp > 0 {
    false
  } else {
    !(aro && blo)
  }
}

///|
fn merge_interval_pair(
  a : (
    @symnum.BigRational,
    @symnum.BigRational,
    Bool,
    Bool,
    @symcore.Expr,
    @symcore.Expr,
  ),
  b : (
    @symnum.BigRational,
    @symnum.BigRational,
    Bool,
    Bool,
    @symcore.Expr,
    @symcore.Expr,
  ),
) -> (
  @symnum.BigRational,
  @symnum.BigRational,
  Bool,
  Bool,
  @symcore.Expr,
  @symcore.Expr,
) {
  let (al, ar, alo, aro, aleft, aright) = a
  let (bl, br, _blo, bro, _bleft, bright) = b
  let left_val = al
  let left_open = if al.compare(bl) == 0 {
    if alo {
      true
    } else {
      false
    }
  } else {
    alo
  }
  let (right_val, right_open, right_expr) = if ar.compare(br) > 0 {
    (ar, aro, aright)
  } else if ar.compare(br) < 0 {
    (br, bro, bright)
  } else {
    (ar, aro && bro, aright)
  }
  (left_val, right_val, left_open, right_open, aleft, right_expr)
}

///|
fn merge_intervals(intervals : Array[Set]) -> Array[Set] {
  let numeric : Array[
    (
      @symnum.BigRational,
      @symnum.BigRational,
      Bool,
      Bool,
      @symcore.Expr,
      @symcore.Expr,
    ),
  ] = Array::new()
  let others : Array[Set] = Array::new()
  for item in intervals {
    match interval_numeric(item) {
      Some(info) => numeric.push(info)
      None => others.push(item)
    }
  }
  if numeric.is_empty() {
    return others
  }
  numeric.sort_by((a, b) => {
    let (al, _ar, alo, _aro, _ae, _ae2) = a
    let (bl, _br, blo, _bro, _be, _be2) = b
    let cmp = al.compare(bl)
    if cmp != 0 {
      cmp
    } else if alo != blo {
      if alo {
        1
      } else {
        -1
      }
    } else {
      0
    }
  })
  let out : Array[Set] = Array::new()
  let mut current = numeric[0]
  for i in 1..<numeric.length() {
    let next = numeric[i]
    let (al, ar, alo, aro, _alexpr, _arexpr) = current
    let (bl, br, blo, bro, _blexpr, _brexpr) = next
    let overlap = interval_overlap_or_touch(
      (al, ar, alo, aro),
      (bl, br, blo, bro),
    )
    if overlap {
      current = merge_interval_pair(current, next)
    } else {
      let (_cl, _cr, clo, cro, cleft, cright) = current
      out.push(interval(cleft, cright, left_open=clo, right_open=cro))
      current = next
    }
  }
  let (_cl, _cr, clo, cro, cleft, cright) = current
  out.push(interval(cleft, cright, left_open=clo, right_open=cro))
  for item in others {
    out.push(item)
  }
  out
}

///|
fn combine_finite_sets(items : Array[@symcore.Expr]) -> Set {
  finite_set(items)
}

///|
pub fn union(args : Array[Set]) -> Set {
  if args.is_empty() {
    return Set::EmptySet
  }
  let flat : Array[Set] = Array::new()
  let mut has_universal = false
  let finite_items : Array[@symcore.Expr] = Array::new()
  let intervals : Array[Set] = Array::new()
  for set in args {
    match set {
      Set::Union(inner) =>
        for item in inner {
          flat.push(item)
        }
      Set::EmptySet => ()
      Set::UniversalSet => has_universal = true
      Set::FiniteSet(items) =>
        for item in items {
          finite_items.push(item)
        }
      Set::Interval(..) => intervals.push(set)
      _ => flat.push(set)
    }
  }
  if has_universal {
    return Set::UniversalSet
  }
  let merged_intervals = merge_intervals(intervals)
  for item in merged_intervals {
    flat.push(item)
  }
  if !finite_items.is_empty() {
    let fset = combine_finite_sets(finite_items)
    match fset {
      Set::EmptySet => ()
      _ => flat.push(fset)
    }
  }
  let uniq = dedup_sets(flat)
  if uniq.is_empty() {
    Set::EmptySet
  } else if uniq.length() == 1 {
    uniq[0]
  } else {
    Set::Union(uniq)
  }
}

///|
fn interval_intersection(a : Set, b : Set) -> Set? {
  match (interval_numeric(a), interval_numeric(b)) {
    (
      Some((al, ar, alo, aro, aleft, aright)),
      Some((bl, br, blo, bro, bleft, bright)),
    ) => {
      let (left_val, left_open, left_expr) = if al.compare(bl) > 0 {
        (al, alo, aleft)
      } else if al.compare(bl) < 0 {
        (bl, blo, bleft)
      } else {
        (al, alo || blo, aleft)
      }
      let (right_val, right_open, right_expr) = if ar.compare(br) < 0 {
        (ar, aro, aright)
      } else if ar.compare(br) > 0 {
        (br, bro, bright)
      } else {
        (ar, aro || bro, aright)
      }
      let cmp = left_val.compare(right_val)
      if cmp > 0 {
        Some(Set::EmptySet)
      } else if cmp == 0 {
        if left_open || right_open {
          Some(Set::EmptySet)
        } else {
          Some(finite_set([left_expr]))
        }
      } else {
        Some(interval(left_expr, right_expr, left_open~, right_open~))
      }
    }
    _ => None
  }
}

///|
fn intersect_finite_sets(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for item in a {
    let mut found = false
    for other in b {
      if @symcore.compare_expr(item, other) == 0 {
        found = true
        break
      }
    }
    if found {
      out.push(item)
    }
  }
  out
}

///|
fn filter_finite_by_interval(
  items : Array[@symcore.Expr],
  interval_set : Set,
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for item in items {
    let res = contains(interval_set, item)
    match res {
      SetBool::True => out.push(item)
      _ => ()
    }
  }
  out
}

///|
pub fn intersection(args : Array[Set]) -> Set {
  if args.is_empty() {
    return Set::UniversalSet
  }
  let flat : Array[Set] = Array::new()
  for set in args {
    match set {
      Set::Intersection(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(set)
    }
  }
  let trimmed : Array[Set] = Array::new()
  for set in flat {
    match set {
      Set::EmptySet => return Set::EmptySet
      Set::UniversalSet => ()
      _ => trimmed.push(set)
    }
  }
  if trimmed.is_empty() {
    return Set::UniversalSet
  }
  if trimmed.length() == 1 {
    return trimmed[0]
  }
  // Handle finite sets
  let mut finite_items : Array[@symcore.Expr]? = None
  let mut interval_acc : Set? = None
  let rest : Array[Set] = Array::new()
  for set in trimmed {
    match set {
      Set::FiniteSet(items) =>
        match finite_items {
          None => finite_items = Some(items)
          Some(prev) => finite_items = Some(intersect_finite_sets(prev, items))
        }
      Set::Interval(..) =>
        match interval_acc {
          None => interval_acc = Some(set)
          Some(prev) =>
            match interval_intersection(prev, set) {
              Some(res) => interval_acc = Some(res)
              None => rest.push(set)
            }
        }
      _ => rest.push(set)
    }
  }
  match interval_acc {
    Some(Set::EmptySet) => return Set::EmptySet
    _ => ()
  }
  if finite_items is Some(items) {
    let filtered = match interval_acc {
      Some(interval_set) =>
        match interval_set {
          Set::Interval(..) => filter_finite_by_interval(items, interval_set)
          Set::FiniteSet(other_items) =>
            intersect_finite_sets(items, other_items)
          Set::EmptySet => []
          _ => items
        }
      None => items
    }
    let fset = finite_set(filtered)
    match fset {
      Set::EmptySet => return Set::EmptySet
      _ => rest.push(fset)
    }
  } else {
    match interval_acc {
      Some(interval_set) => rest.push(interval_set)
      None => ()
    }
  }
  let uniq = dedup_sets(rest)
  if uniq.is_empty() {
    Set::UniversalSet
  } else if uniq.length() == 1 {
    uniq[0]
  } else {
    Set::Intersection(uniq)
  }
}

///|
fn interval_difference(a : Set, b : Set) -> Set? {
  match (interval_numeric(a), interval_numeric(b)) {
    (
      Some((al, ar, alo, aro, aleft, aright)),
      Some((bl, br, blo, bro, bleft, bright)),
    ) => {
      // Disjoint
      if br.compare(al) < 0 || bl.compare(ar) > 0 {
        return Some(a)
      }
      // B covers A
      if (bl.compare(al) < 0 || (bl.compare(al) == 0 && (!alo || !blo))) &&
        (br.compare(ar) > 0 || (br.compare(ar) == 0 && (!aro || !bro))) {
        return Some(Set::EmptySet)
      }
      let parts : Array[Set] = Array::new()
      let left_cmp = bl.compare(al)
      if left_cmp > 0 || (left_cmp == 0 && !alo && blo) {
        let right_open = if blo { false } else { true }
        parts.push(interval(aleft, bleft, left_open=alo, right_open~))
      }
      let right_cmp = br.compare(ar)
      if right_cmp < 0 || (right_cmp == 0 && !aro && bro) {
        let left_open = if bro { false } else { true }
        parts.push(interval(bright, aright, left_open~, right_open=aro))
      }
      if parts.is_empty() {
        Some(Set::EmptySet)
      } else if parts.length() == 1 {
        Some(parts[0])
      } else {
        Some(union(parts))
      }
    }
    _ => None
  }
}

///|
pub fn complement(a : Set, b : Set) -> Set {
  match (a, b) {
    (Set::EmptySet, _) => Set::EmptySet
    (_, Set::EmptySet) => a
    (Set::UniversalSet, Set::UniversalSet) => Set::EmptySet
    (x, y) if compare_set(x, y) == 0 => Set::EmptySet
    (Set::FiniteSet(items), Set::FiniteSet(remove)) => {
      let remaining : Array[@symcore.Expr] = Array::new()
      for item in items {
        let mut found = false
        for r in remove {
          if @symcore.compare_expr(item, r) == 0 {
            found = true
            break
          }
        }
        if !found {
          remaining.push(item)
        }
      }
      finite_set(remaining)
    }
    (Set::FiniteSet(items), interval_set) =>
      match interval_set {
        Set::Interval(..) => {
          // filter_finite_by_interval keeps contained items; we need complement
          let out : Array[@symcore.Expr] = Array::new()
          for item in items {
            let res = contains(interval_set, item)
            match res {
              SetBool::True => ()
              _ => out.push(item)
            }
          }
          finite_set(out)
        }
        _ => Set::Complement(a, interval_set)
      }
    (Set::Interval(..), Set::Interval(..)) =>
      match interval_difference(a, b) {
        Some(res) => res
        None => Set::Complement(a, b)
      }
    (Set::Union(items), other) => {
      let parts : Array[Set] = Array::new()
      for item in items {
        parts.push(complement(item, other))
      }
      union(parts)
    }
    _ => Set::Complement(a, b)
  }
}

///|
fn interval_contains(set : Set, elem : @symcore.Expr) -> SetBool {
  match (set, expr_number_value(elem)) {
    (Set::Interval(left~, right~, left_open~, right_open~), Some(value)) =>
      match (expr_number_value(left), expr_number_value(right)) {
        (Some(lv), Some(rv)) => {
          let cmp_l = value.compare(lv)
          let cmp_r = value.compare(rv)
          if cmp_l < 0 || cmp_r > 0 {
            SetBool::False
          } else if cmp_l == 0 {
            if left_open {
              SetBool::False
            } else {
              SetBool::True
            }
          } else if cmp_r == 0 {
            if right_open {
              SetBool::False
            } else {
              SetBool::True
            }
          } else {
            SetBool::True
          }
        }
        _ => SetBool::Unknown
      }
    _ => SetBool::Unknown
  }
}

///|
fn finite_contains(
  items : Array[@symcore.Expr],
  elem : @symcore.Expr,
) -> SetBool {
  for item in items {
    if @symcore.compare_expr(item, elem) == 0 {
      return SetBool::True
    }
  }
  SetBool::False
}

///|
fn contains_numerical_set(kind : Set, elem : @symcore.Expr) -> SetBool {
  match expr_number_value(elem) {
    Some(value) => {
      let is_int = value.is_integral()
      match kind {
        Set::Naturals =>
          if is_int && value.compare(@symnum.BigRational::zero()) > 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        Set::Naturals0 =>
          if is_int && value.compare(@symnum.BigRational::zero()) >= 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        Set::Integers => if is_int { SetBool::True } else { SetBool::False }
        Set::Rationals => SetBool::True
        Set::Reals => SetBool::True
        _ => SetBool::Unknown
      }
    }
    None => SetBool::Unknown
  }
}

///|
pub fn contains(set : Set, elem : @symcore.Expr) -> SetBool {
  match set {
    Set::EmptySet => SetBool::False
    Set::UniversalSet => SetBool::True
    Set::FiniteSet(items) => finite_contains(items, elem)
    Set::Interval(..) => interval_contains(set, elem)
    Set::ConditionSet(symbol~, condition~, base~) => {
      let base_res = contains(base, elem)
      match base_res {
        SetBool::False => SetBool::False
        SetBool::Unknown => SetBool::Unknown
        SetBool::True => {
          let var_name = match symbol {
            @symcore.Expr::Symbol(name) => name
            _ => ""
          }
          if var_name == "" {
            SetBool::Unknown
          } else {
            let value = expr_number_value(elem)
            eval_bool_expr(condition, var_name, value)
          }
        }
      }
    }
    Set::ImageSet(symbol~, expr~, base~) => {
      let var_name = match symbol {
        @symcore.Expr::Symbol(name) => name
        _ => ""
      }
      if var_name != "" && !expr_depends_on(expr, var_name) {
        let eq = @symcore.compare_expr(expr, elem) == 0
        match set_is_empty(base) {
          SetBool::True => return SetBool::False
          SetBool::False =>
            return if eq { SetBool::True } else { SetBool::False }
          SetBool::Unknown => return SetBool::Unknown
        }
      }
      match base {
        Set::FiniteSet(items) => {
          if var_name == "" {
            return SetBool::Unknown
          }
          let env : Map[String, @symcore.Expr] = Map::new()
          for item in items {
            env[var_name] = item
            let mapped = @symcore.subst(expr, env)
            if @symcore.compare_expr(mapped, elem) == 0 {
              return SetBool::True
            }
          }
          SetBool::False
        }
        _ => SetBool::Unknown
      }
    }
    Set::ProductSet(items) =>
      match elem {
        @symcore.Expr::Function(name, args) if name == "Tuple" => {
          if args.length() != items.length() {
            return SetBool::False
          }
          let mut acc = SetBool::True
          for i in 0..<items.length() {
            acc = setbool_and(acc, contains(items[i], args[i]))
            if acc == SetBool::False {
              return acc
            }
          }
          acc
        }
        _ => SetBool::False
      }
    Set::Naturals
    | Set::Naturals0
    | Set::Integers
    | Set::Rationals
    | Set::Reals => contains_numerical_set(set, elem)
    Set::Union(items) => {
      let mut acc = SetBool::False
      for item in items {
        acc = setbool_or(acc, contains(item, elem))
        if acc == SetBool::True {
          return acc
        }
      }
      acc
    }
    Set::Intersection(items) => {
      let mut acc = SetBool::True
      for item in items {
        acc = setbool_and(acc, contains(item, elem))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    Set::Complement(a, b) =>
      setbool_and(contains(a, elem), setbool_not(contains(b, elem)))
  }
}

///|
pub fn is_subset(a : Set, b : Set) -> SetBool {
  match (a, b) {
    (Set::EmptySet, _) => SetBool::True
    (_, Set::UniversalSet) => SetBool::True
    (x, y) if compare_set(x, y) == 0 => SetBool::True
    (Set::FiniteSet(items), other) => {
      let mut acc = SetBool::True
      for item in items {
        acc = setbool_and(acc, contains(other, item))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    (Set::Interval(..), Set::Interval(..)) =>
      match (interval_numeric(a), interval_numeric(b)) {
        (
          Some((al, ar, alo, aro, _alexpr, _arexpr)),
          Some((bl, br, blo, bro, _blexpr, _brexpr)),
        ) => {
          let left_ok = if al.compare(bl) > 0 {
            true
          } else if al.compare(bl) == 0 {
            !alo || blo
          } else {
            false
          }
          let right_ok = if ar.compare(br) < 0 {
            true
          } else if ar.compare(br) == 0 {
            !aro || bro
          } else {
            false
          }
          if left_ok && right_ok {
            SetBool::True
          } else {
            SetBool::False
          }
        }
        _ => SetBool::Unknown
      }
    (Set::ProductSet(xs), Set::ProductSet(ys)) => {
      if xs.length() != ys.length() {
        return SetBool::False
      }
      let mut acc = SetBool::True
      for i in 0..<xs.length() {
        acc = setbool_and(acc, is_subset(xs[i], ys[i]))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    _ => SetBool::Unknown
  }
}
