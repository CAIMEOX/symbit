///|
/// Quine–McCluskey helpers and SOP/POS/ANF forms.

///|
pub(all) enum TermInput {
  IntTerm(Int)
  BitsTerm(Array[Int])
  MapTerm(Map[String, Int])
}

///|
fn _check_pair(minterm1 : Array[Int], minterm2 : Array[Int]) -> Int {
  let mut index = -1
  for i in 0..<minterm1.length() {
    if minterm1[i] != minterm2[i] {
      if index == -1 {
        index = i
      } else {
        return -1
      }
    }
  }
  index
}

///|
fn _simplified_pairs(terms : Array[Array[Int]]) -> Array[Array[Int]] {
  if terms.is_empty() {
    return []
  }
  let simplified_terms : Array[Array[Int]] = Array::new()
  let todo : Array[Bool] = Array::make(terms.length(), true)
  let termdict : Map[Int, Array[Int]] = Map::new()
  for i in 0..<terms.length() {
    let term = terms[i]
    let mut ones = 0
    for t in term {
      if t == 1 {
        ones += 1
      }
    }
    let entry = termdict.get(ones)
    match entry {
      Some(list) => list.push(i)
      None => termdict[ones] = [i]
    }
  }
  let variables = terms[0].length()
  for k in 0..<variables {
    match termdict.get(k) {
      Some(list1) =>
        match termdict.get(k + 1) {
          Some(list2) =>
            for i in list1 {
              for j in list2 {
                let index = _check_pair(terms[i], terms[j])
                if index != -1 {
                  todo[i] = false
                  todo[j] = false
                  let newterm = terms[i].copy()
                  newterm[index] = 3
                  if !simplified_terms.contains(newterm) {
                    simplified_terms.push(newterm)
                  }
                }
              }
            }
          None => ()
        }
      None => ()
    }
  }
  let mut next = simplified_terms
  if !next.is_empty() {
    next = _simplified_pairs(next)
  }
  for i in 0..<terms.length() {
    if todo[i] {
      next.push(terms[i])
    }
  }
  next
}

///|
fn _rem_redundancy(
  l1 : Array[Array[Int]],
  terms : Array[Array[Int]],
) -> Array[Array[Int]] {
  if terms.is_empty() {
    return []
  }
  let nterms = terms.length()
  let nl1 = l1.length()
  let dommatrix : Array[Array[Int]] = Array::new()
  for _ in 0..<nterms {
    dommatrix.push(Array::make(nl1, 0))
  }
  let colcount : Array[Int] = Array::make(nl1, 0)
  let rowcount : Array[Int] = Array::make(nterms, 0)
  fn covers(prime : Array[Int], term : Array[Int]) -> Bool {
    for i in 0..<prime.length() {
      let p = prime[i]
      if !(p == 3 || p == term[i]) {
        return false
      }
    }
    true
  }

  for primei in 0..<nl1 {
    let prime = l1[primei]
    for termi in 0..<nterms {
      if covers(prime, terms[termi]) {
        dommatrix[termi][primei] = 1
        colcount[primei] += 1
        rowcount[termi] += 1
      }
    }
  }
  let mut anythingchanged = true
  while anythingchanged {
    anythingchanged = false
    for rowi in 0..<nterms {
      if rowcount[rowi] == 0 {
        continue
      }
      let row = dommatrix[rowi]
      for row2i in 0..<nterms {
        if rowi == row2i || rowcount[row2i] == 0 {
          continue
        }
        if rowcount[rowi] <= rowcount[row2i] {
          let row2 = dommatrix[row2i]
          let mut dominates = true
          for n in 0..<nl1 {
            if row2[n] < row[n] {
              dominates = false
              break
            }
          }
          if dominates {
            rowcount[row2i] = 0
            anythingchanged = true
            for primei in 0..<nl1 {
              if row2[primei] == 1 {
                dommatrix[row2i][primei] = 0
                colcount[primei] -= 1
              }
            }
          }
        }
      }
    }
    let colcache : Map[Int, Array[Int]] = Map::new()
    for coli in 0..<nl1 {
      if colcount[coli] == 0 {
        continue
      }
      let col = match colcache.get(coli) {
        Some(cached) => cached
        None => {
          let c : Array[Int] = Array::new()
          for i in 0..<nterms {
            c.push(dommatrix[i][coli])
          }
          colcache[coli] = c
          c
        }
      }
      for col2i in 0..<nl1 {
        if coli == col2i || colcount[col2i] == 0 {
          continue
        }
        if colcount[coli] >= colcount[col2i] {
          let col2 = match colcache.get(col2i) {
            Some(cached) => cached
            None => {
              let c : Array[Int] = Array::new()
              for i in 0..<nterms {
                c.push(dommatrix[i][col2i])
              }
              colcache[col2i] = c
              c
            }
          }
          let mut dominates = true
          for n in 0..<nterms {
            if col[n] < col2[n] {
              dominates = false
              break
            }
          }
          if dominates {
            colcount[col2i] = 0
            anythingchanged = true
            for termi in 0..<nterms {
              if col2[termi] == 1 && dommatrix[termi][col2i] == 1 {
                dommatrix[termi][col2i] = 0
                rowcount[termi] -= 1
              }
            }
          }
        }
      }
    }
    if !anythingchanged {
      let mut maxterms = 0
      let mut bestcolidx = -1
      for coli in 0..<nl1 {
        let s = colcount[coli]
        if s > maxterms {
          maxterms = s
          bestcolidx = coli
        }
      }
      if bestcolidx != -1 && maxterms > 1 {
        for primei in 0..<nl1 {
          if primei == bestcolidx {
            continue
          }
          let col = match colcache.get(bestcolidx) {
            Some(cached) => cached
            None => {
              let c : Array[Int] = Array::new()
              for i in 0..<nterms {
                c.push(dommatrix[i][bestcolidx])
              }
              c
            }
          }
          for termi in 0..<nterms {
            if col[termi] == 1 && dommatrix[termi][primei] == 1 {
              dommatrix[termi][primei] = 0
              anythingchanged = true
              rowcount[termi] -= 1
              colcount[primei] -= 1
            }
          }
        }
      }
    }
  }
  let out : Array[Array[Int]] = Array::new()
  for i in 0..<nl1 {
    if colcount[i] != 0 {
      out.push(l1[i])
    }
  }
  out
}

///|
fn _convert_to_varsSOP(
  term : Array[Int],
  variables : Array[BoolExpr],
) -> BoolExpr {
  let args : Array[BoolExpr] = Array::new()
  for i in 0..<term.length() {
    match term[i] {
      1 => args.push(variables[i])
      0 => args.push(bool_not(variables[i]))
      _ => ()
    }
  }
  bool_and(args)
}

///|
fn _convert_to_varsPOS(
  term : Array[Int],
  variables : Array[BoolExpr],
) -> BoolExpr {
  let args : Array[BoolExpr] = Array::new()
  for i in 0..<term.length() {
    match term[i] {
      0 => args.push(variables[i])
      1 => args.push(bool_not(variables[i]))
      _ => ()
    }
  }
  bool_or(args)
}

///|
fn _convert_to_varsANF(
  term : Array[Int],
  variables : Array[BoolExpr],
) -> BoolExpr {
  let args : Array[BoolExpr] = Array::new()
  for i in 0..<term.length() {
    if term[i] == 1 {
      args.push(variables[i])
    }
  }
  if args.is_empty() {
    return BoolExpr::True
  }
  bool_and(args)
}

///|
fn _input_to_binlist(
  inputlist : Array[TermInput],
  variables : Array[BoolExpr],
) -> Array[Array[Int]] {
  let binlist : Array[Array[Int]] = Array::new()
  let bits = variables.length()
  let names = symbol_names_from_exprs(variables)
  for val in inputlist {
    match val {
      TermInput::IntTerm(n) => binlist.push(ibin(n, bits))
      TermInput::BitsTerm(term) => {
        if term.length() != bits {
          return []
        }
        binlist.push(term.copy())
      }
      TermInput::MapTerm(map) => {
        let nonspec : Array[String] = Array::new()
        for name in names {
          match map.get(name) {
            Some(_) => ()
            None => nonspec.push(name)
          }
        }
        let combos = all_bit_vectors(nonspec.length())
        for combo in combos {
          let filled : Map[String, Int] = Map::new()
          for k, v in map {
            filled[k] = v
          }
          for i in 0..<nonspec.length() {
            filled[nonspec[i]] = combo[i]
          }
          let term_bits : Array[Int] = Array::new()
          for name in names {
            match filled.get(name) {
              Some(v) => term_bits.push(v)
              None => return []
            }
          }
          binlist.push(term_bits)
        }
      }
    }
  }
  binlist
}

///|
pub fn sop_form(
  variables : Array[BoolExpr],
  minterms : Array[TermInput],
  dontcares? : Array[TermInput],
) -> BoolExpr {
  if minterms.is_empty() {
    return BoolExpr::False
  }
  let mins = _input_to_binlist(minterms, variables)
  let dcs = _input_to_binlist(
    match dontcares {
      Some(v) => v
      None => []
    },
    variables,
  )
  for d in dcs {
    if mins.contains(d) {
      return BoolExpr::False
    }
  }
  _sop_form(variables, mins, dcs)
}

///|
fn _sop_form(
  variables : Array[BoolExpr],
  minterms : Array[Array[Int]],
  dontcares : Array[Array[Int]],
) -> BoolExpr {
  let new = _simplified_pairs(minterms + dontcares)
  let essential = _rem_redundancy(new, minterms)
  let args : Array[BoolExpr] = Array::new()
  for term in essential {
    args.push(_convert_to_varsSOP(term, variables))
  }
  bool_or(args)
}

///|
pub fn pos_form(
  variables : Array[BoolExpr],
  minterms : Array[TermInput],
  dontcares? : Array[TermInput],
) -> BoolExpr {
  if minterms.is_empty() {
    return BoolExpr::False
  }
  let mins = _input_to_binlist(minterms, variables)
  let dcs = _input_to_binlist(
    match dontcares {
      Some(v) => v
      None => []
    },
    variables,
  )
  for d in dcs {
    if mins.contains(d) {
      return BoolExpr::False
    }
  }
  let maxterms : Array[Array[Int]] = Array::new()
  let all = all_bit_vectors(variables.length())
  for t in all {
    if !mins.contains(t) && !dcs.contains(t) {
      maxterms.push(t)
    }
  }
  if maxterms.is_empty() {
    return BoolExpr::True
  }
  let new = _simplified_pairs(maxterms + dcs)
  let essential = _rem_redundancy(new, maxterms)
  let args : Array[BoolExpr] = Array::new()
  for term in essential {
    args.push(_convert_to_varsPOS(term, variables))
  }
  bool_and(args)
}

///|
pub fn anf_form(
  variables : Array[BoolExpr],
  truthvalues : Array[Int],
) -> BoolExpr {
  let n_vars = variables.length()
  let n_values = truthvalues.length()
  if n_values != 1 << n_vars {
    return BoolExpr::False
  }
  let coeffs = anf_coeffs(truthvalues)
  let terms : Array[BoolExpr] = Array::new()
  for i in 0..<coeffs.length() {
    if coeffs[i] == 1 {
      let bits = ibin(i, n_vars)
      terms.push(_convert_to_varsANF(bits, variables))
    }
  }
  if terms.is_empty() {
    return BoolExpr::False
  }
  xor_keep_true(terms)
}

///|
pub fn anf_coeffs(truthvalues : Array[Int]) -> Array[Int] {
  let mut n = 0
  let mut len = truthvalues.length()
  while len > 1 {
    if len % 2 != 0 {
      return []
    }
    len = len >> 1
    n += 1
  }
  let mut coeffs : Array[Array[Int]] = Array::new()
  for v in truthvalues {
    coeffs.push([v])
  }
  for i in 0..<n {
    let tmp : Array[Array[Int]] = Array::new()
    let pairs = 1 << (n - i - 1)
    for j in 0..<pairs {
      let left = coeffs[2 * j]
      let right = coeffs[2 * j + 1]
      let combined : Array[Int] = Array::new()
      for k in 0..<left.length() {
        combined.push(left[k])
      }
      for k in 0..<left.length() {
        combined.push(left[k] ^ right[k])
      }
      tmp.push(combined)
    }
    coeffs = tmp
  }
  coeffs[0]
}
