///|
/// Rewriting system for finitely presented groups.

///|
fn rules_cache_contains(
  cache : Array[(FreeGroupElement, FreeGroupElement)],
  pair : (FreeGroupElement, FreeGroupElement),
) -> Bool {
  for item in cache {
    if item == pair {
      return true
    }
  }
  false
}

///|
fn rules_cache_push(
  cache : Array[(FreeGroupElement, FreeGroupElement)],
  pair : (FreeGroupElement, FreeGroupElement),
  max_len : Int,
) -> Unit {
  cache.push(pair)
  if cache.length() > max_len {
    ignore(cache.remove(0))
  }
}

///|
fn map_keys_sorted(
  map : Map[FreeGroupElement, FreeGroupElement],
) -> Array[FreeGroupElement] {
  let out : Array[FreeGroupElement] = Array::new()
  for k, _ in map {
    out.push(k)
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
pub struct RewritingSystem {
  free_group : FreeGroup
  relators : Array[FreeGroupElement]
  generators : Array[FreeGroupElement]
  group_name : String
  alphabet : Array[FreeGroupElement]
  mut is_confluent_cache : Bool?
  mut maxeqns : Int
  tidyint : Int
  mut max_exceeded : Bool
  mut reduction_automaton : StateMachine?
  mut new_rules : Map[FreeGroupElement, FreeGroupElement]
  rules : Map[FreeGroupElement, FreeGroupElement]
  rules_cache : Array[(FreeGroupElement, FreeGroupElement)]
}

///|
pub fn RewritingSystem::new(
  free_group : FreeGroup,
  relators : Array[FreeGroupElement],
  generators : Array[FreeGroupElement],
  group_name : String,
) -> RewritingSystem {
  let alphabet : Array[FreeGroupElement] = Array::new()
  for g in generators {
    alphabet.push(g)
  }
  for g in generators {
    alphabet.push(g.inverse())
  }
  let rs : RewritingSystem = {
    free_group,
    relators,
    generators,
    group_name,
    alphabet,
    is_confluent_cache: None,
    maxeqns: 32767,
    tidyint: 100,
    max_exceeded: false,
    reduction_automaton: None,
    new_rules: {},
    rules: {},
    rules_cache: Array::new(),
  }
  try! rs._init_rules()
  // Disable automaton construction for now to avoid unstable state during porting.
  rs.reduction_automaton = None
  rs
}

///|
pub fn RewritingSystem::set_max(self : RewritingSystem, n : Int) -> Unit {
  if n > self.maxeqns {
    self.max_exceeded = false
  }
  self.maxeqns = n
}

///|
pub fn RewritingSystem::is_confluent(
  self : RewritingSystem,
) -> Bool raise CombinatoricsError {
  match self.is_confluent_cache {
    Some(v) => v
    None => {
      let v = self._check_confluence()
      self.is_confluent_cache = Some(v)
      v
    }
  }
}

///|
fn RewritingSystem::_init_rules(
  self : RewritingSystem,
) -> Unit raise CombinatoricsError {
  let identity = self.free_group.identity()
  for r in self.relators {
    ignore(self.add_rule(r, identity))
  }
  ignore(self._remove_redundancies())
}

///|
fn RewritingSystem::_add_rule(
  self : RewritingSystem,
  r1 : FreeGroupElement,
  r2 : FreeGroupElement,
) -> Unit raise CombinatoricsError {
  if self.rules.length() + 1 > self.maxeqns {
    self.is_confluent_cache = Some(self._check_confluence())
    self.max_exceeded = true
    raise CombinatoricsError::ValueError("too many rules were defined")
  }
  self.rules[r1] = r2
  match self.reduction_automaton {
    Some(_) => self.new_rules[r1] = r2
    None => ()
  }
}

///|
pub fn RewritingSystem::add_rule(
  self : RewritingSystem,
  w1 : FreeGroupElement,
  w2 : FreeGroupElement,
  check? : Bool = false,
) -> Array[FreeGroupElement] raise CombinatoricsError {
  let new_keys : Array[FreeGroupElement] = Array::new()
  if w1 == w2 {
    return new_keys
  }
  let mut s1 = w1
  let mut s2 = w2
  if s1 < s2 {
    let tmp = s1
    s1 = s2
    s2 = tmp
  }
  let pair = (s1, s2)
  if rules_cache_contains(self.rules_cache, pair) {
    return new_keys
  }
  rules_cache_push(self.rules_cache, pair, 50)
  if s1.length() - s2.length() < 3 {
    if !self.rules.contains(s1) {
      new_keys.push(s1)
      if !check {
        self._add_rule(s1, s2)
      }
    }
    let inv1 = s1.inverse()
    let inv2 = s2.inverse()
    if inv2 > inv1 && !self.rules.contains(inv2) {
      new_keys.push(inv2)
      if !check {
        self._add_rule(inv2, inv1)
      }
    }
  }

  // overlaps on the right
  let mut right_s1 = s1
  let mut right_s2 = s2
  while right_s1.length() - right_s2.length() > -1 {
    let g = right_s1.letter_at(right_s1.length() - 1)
    right_s1 = right_s1.subword(0, right_s1.length() - 1)
    right_s2 = right_s2.mul(g.pow(-1))
    if right_s1.length() - right_s2.length() < 0 {
      if !self.rules.contains(right_s2) {
        if !check {
          self._add_rule(right_s2, right_s1)
        }
        new_keys.push(right_s2)
      }
    } else if right_s1.length() - right_s2.length() < 3 {
      let more = self.add_rule(right_s1, right_s2, check~)
      for v in more {
        new_keys.push(v)
      }
    }
  }

  // overlaps on the left
  let mut left_w1 = s1
  let mut left_w2 = s2
  while left_w1.length() - left_w2.length() > -1 {
    let g = left_w1.letter_at(0)
    left_w1 = left_w1.subword(1, left_w1.length())
    left_w2 = g.pow(-1).mul(left_w2)
    if left_w1.length() - left_w2.length() < 0 {
      if !self.rules.contains(left_w2) {
        if !check {
          self._add_rule(left_w2, left_w1)
        }
        new_keys.push(left_w2)
      }
    } else if left_w1.length() - left_w2.length() < 3 {
      let more = self.add_rule(left_w1, left_w2, check~)
      for v in more {
        new_keys.push(v)
      }
    }
  }
  new_keys
}

///|
fn RewritingSystem::_remove_redundancies(
  self : RewritingSystem,
  changes? : Bool = false,
) -> (Array[FreeGroupElement], Array[FreeGroupElement])? raise CombinatoricsError {
  let removed : Array[FreeGroupElement] = Array::new()
  let added : Array[FreeGroupElement] = Array::new()
  let rules_copy : Array[(FreeGroupElement, FreeGroupElement)] = Array::new()
  for r, v in self.rules {
    rules_copy.push((r, v))
  }
  for pair in rules_copy {
    let r = pair.0
    let v = self.reduce(r, exclude=r)
    let w = self.reduce(pair.1)
    if v != r {
      self.rules.remove(r)
      removed.push(r)
      if v > w {
        added.push(v)
        self.rules[v] = w
      } else if v < w {
        added.push(w)
        self.rules[w] = v
      }
    } else {
      self.rules[v] = w
    }
  }
  if changes {
    Some((removed, added))
  } else {
    None
  }
}

///|
fn overlaps(
  r1 : FreeGroupElement,
  r2 : FreeGroupElement,
) -> Array[FreeGroupElement] raise CombinatoricsError {
  let len1 = r1.length()
  let len2 = r2.length()
  let result : Array[FreeGroupElement] = Array::new()
  for j in 1..<(len1 + len2) {
    let lhs = r1.subword(len1 - j, len1 + len2 - j, strict=false)
    let rhs = r2.subword(j - len1, j, strict=false)
    if lhs == rhs {
      let a = r1.subword(0, len1 - j, strict=false)
      let a2 = r2.subword(0, j - len1, strict=false)
      let b = r2.subword(j - len1, j, strict=false)
      let c = r2.subword(j, len2, strict=false)
      let c2 = r1.subword(len1 + len2 - j, len1, strict=false)
      result.push(a.mul(a2).mul(b).mul(c).mul(c2))
    }
  }
  result
}

///|
fn process_overlap(
  rs : RewritingSystem,
  w : FreeGroupElement,
  r1 : FreeGroupElement,
  r2 : FreeGroupElement,
  check : Bool,
) -> Array[FreeGroupElement]? raise CombinatoricsError {
  let s = rs.reduce(w.eliminate_word(r1, by=rs.rules[r1]))
  let t = rs.reduce(w.eliminate_word(r2, by=rs.rules[r2]))
  if s != t {
    if check {
      return Some([rs.free_group.identity()])
    }
    let new_keys = rs.add_rule(t, s, check~)
    return Some(new_keys)
  }
  None
}

///|
pub fn RewritingSystem::make_confluent(
  self : RewritingSystem,
  check? : Bool = false,
) -> Bool raise CombinatoricsError {
  if self.max_exceeded {
    return self.is_confluent_cache.unwrap_or(false)
  }
  let lhs = map_keys_sorted(self.rules)
  let mut added = 0
  let mut i = 0
  while i < lhs.length() {
    let r1 = lhs[i]
    i = i + 1
    let mut j = 0
    while j < lhs.length() {
      let r2 = lhs[j]
      j = j + 1
      if r1 == r2 {
        continue
      }
      let ovs = overlaps(r1, r2)
      let inv = r1.inverse()
      for w in overlaps(inv, r2) {
        ovs.push(w)
      }
      if ovs.is_empty() {
        continue
      }
      for w in ovs {
        let res = process_overlap(self, w, r1, r2, check)
        match res {
          Some(keys) => {
            if check {
              return false
            }
            if keys.is_empty() {
              continue
            }
            for v in keys {
              lhs.push(v)
            }
            added = added + keys.length()
          }
          None => ()
        }
      }
      if added > self.tidyint && !check {
        let removed_added = self._remove_redundancies(changes=true)
        added = 0
        match removed_added {
          Some((removed, added_keys)) => {
            if !removed.is_empty() {
              let mut min_idx = lhs.length()
              for r in removed {
                let mut k = 0
                while k < lhs.length() {
                  if lhs[k] == r {
                    if k < min_idx {
                      min_idx = k
                    }
                    ignore(lhs.remove(k))
                    break
                  }
                  k = k + 1
                }
              }
              if min_idx < i {
                i = min_idx
              }
            }
            for a in added_keys {
              lhs.push(a)
            }
            if removed.any(x => x == r1) {
              break
            }
          }
          None => ()
        }
      }
    }
  }
  self.is_confluent_cache = Some(true)
  if !check {
    ignore(self._remove_redundancies())
  }
  true
}

///|
fn RewritingSystem::_check_confluence(
  self : RewritingSystem,
) -> Bool raise CombinatoricsError {
  self.make_confluent(check=true)
}

///|
pub fn RewritingSystem::reduce(
  self : RewritingSystem,
  word : FreeGroupElement,
  exclude? : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  let rules_filtered : Array[(FreeGroupElement, FreeGroupElement)] = Array::new()
  for r, v in self.rules {
    match exclude {
      Some(ex) => if r != ex { rules_filtered.push((r, v)) }
      None => rules_filtered.push((r, v))
    }
  }
  let mut again = true
  let mut new_word = word
  while again {
    again = false
    for pair in rules_filtered {
      let r = pair.0
      let v = pair.1
      let prev = new_word
      if v.inverse() > r.inverse() {
        new_word = new_word.eliminate_word(r, by=v, all=true, inverse=false)
      } else {
        new_word = new_word.eliminate_word(r, by=v, all=true)
      }
      if new_word != prev {
        again = true
      }
    }
  }
  new_word
}

///|
fn RewritingSystem::_compute_inverse_rules(
  self : RewritingSystem,
  rules : Map[FreeGroupElement, FreeGroupElement],
) -> Map[FreeGroupElement, FreeGroupElement] {
  let inv_rules : Map[FreeGroupElement, FreeGroupElement] = {}
  for r, v in rules {
    let inv_key = r.inverse()
    let inv_val = v.inverse()
    if inv_val < inv_key {
      inv_rules[inv_key] = inv_val
    } else {
      inv_rules[inv_val] = inv_key
    }
  }
  inv_rules
}

///|
pub fn RewritingSystem::construct_automaton(
  self : RewritingSystem,
) -> Unit raise CombinatoricsError {
  self._add_to_automaton(self.rules)
}

///|
fn RewritingSystem::_add_to_automaton(
  self : RewritingSystem,
  rules : Map[FreeGroupElement, FreeGroupElement],
) -> Unit raise CombinatoricsError {
  let automaton_alphabet : Array[FreeGroupElement] = Array::new()
  let all_rules : Map[FreeGroupElement, FreeGroupElement] = {}
  for r, v in rules {
    all_rules[r] = v
  }
  let inv_rules = self._compute_inverse_rules(all_rules)
  for r, v in inv_rules {
    all_rules[r] = v
  }
  let mut accept_states : Array[StateName] = Array::new()
  for rule, rhs in all_rules {
    for letter in rule.letter_form_elm() {
      automaton_alphabet.push(letter)
    }
    let letter_word_array = rule.letter_form_elm()
    let len_letters = letter_word_array.length()
    for i in 1..<len_letters {
      let prev = letter_word_array[i - 1]
      let next = prev.mul(letter_word_array[i])
      letter_word_array[i] = next
      let elem = prev
      let name = StateName::Word(elem)
      match self.reduction_automaton {
        Some(machine) =>
          if !machine.has_state(name) {
            machine.add_state(name, StateType::Accept)
            accept_states.push(name)
          }
        None => ()
      }
    }
    let rule_state = StateName::Word(rule)
    match self.reduction_automaton {
      Some(machine) => {
        if accept_states.any(s => s == rule_state) {
          machine.set_dead_rule(rule_state, rhs)
          let filtered : Array[StateName] = Array::new()
          for s in accept_states {
            if s != rule_state {
              filtered.push(s)
            }
          }
          accept_states = filtered
        }
        if !machine.has_state(rule_state) {
          machine.add_state(rule_state, StateType::Dead, rh_rule=rhs)
        }
      }
      None => ()
    }
  }

  // unique alphabet
  let uniq : Array[FreeGroupElement] = Array::new()
  for letter in automaton_alphabet {
    if !uniq.any(x => x == letter) {
      uniq.push(letter)
    }
  }
  match self.reduction_automaton {
    Some(machine) => {
      let state_names = machine.state_names()
      for name in state_names {
        let state = machine.get_state(name)
        match state {
          Some(st) =>
            match st.state_type {
              StateType::Start =>
                for letter in uniq {
                  let to_state = if machine.has_state(StateName::Word(letter)) {
                    StateName::Word(letter)
                  } else {
                    name
                  }
                  machine.add_transition(name, letter, to_state)
                }
              StateType::Accept =>
                for letter in uniq {
                  let mut next = match name {
                    StateName::Word(w) => w.mul(letter)
                    StateName::Start => letter
                  }
                  while next.length() > 0 &&
                        !machine.has_state(StateName::Word(next)) {
                    next = next.subword(1, next.length())
                  }
                  let to_state = if next.length() == 0 {
                    StateName::Start
                  } else {
                    StateName::Word(next)
                  }
                  machine.add_transition(name, letter, to_state)
                }
              StateType::Dead => ()
            }
          None => ()
        }
      }
    }
    None => ()
  }
}

///|
pub fn RewritingSystem::reduce_using_automaton(
  self : RewritingSystem,
  word : FreeGroupElement,
) -> FreeGroupElement raise CombinatoricsError {
  if self.new_rules.length() > 0 {
    let rules = self.new_rules
    self._add_to_automaton(rules)
    self.new_rules = {}
  }
  match self.reduction_automaton {
    Some(machine) => {
      let mut flag = true
      let mut current_word = word
      while flag {
        flag = false
        let mut current_state = StateName::Start
        let letters = current_word.letter_form_elm()
        let mut i = 0
        while i < letters.length() {
          let s = letters[i]
          let next_state_name = machine.transition(current_state, s)
          let next_name = match next_state_name {
            Some(n) => n
            None => StateName::Start
          }
          let next_state = machine.get_state(next_name)
          match next_state {
            Some(st) =>
              if st.state_type == StateType::Dead {
                let subst = st.rh_rule.unwrap_or(self.free_group.identity())
                let offset = match next_name {
                  StateName::Word(w) => w.length() - 1
                  StateName::Start => 0
                }
                let start = i - offset
                current_word = current_word.substituted_word(
                  start,
                  i + 1,
                  subst,
                )
                flag = true
                break
              }
            None => ()
          }
          current_state = next_name
          i = i + 1
        }
      }
      current_word
    }
    None => self.reduce(word)
  }
}
