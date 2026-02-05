///|
/// Group constructions.

///|
pub fn direct_product(groups : Array[PermutationGroup]) -> PermutationGroup raise CombinatoricsError {
  let degrees : Array[Int] = Array::new()
  let gens_count : Array[Int] = Array::new()
  let mut total_degree = 0
  let mut total_gens = 0
  for group in groups {
    let deg = group.degree()
    degrees.push(deg)
    total_degree = total_degree + deg
    let count = group.generators().length()
    gens_count.push(count)
    total_gens = total_gens + count
  }
  let array_gens : Array[Array[Int]] = Array::new()
  for _ in 0..<total_gens {
    let arr : Array[Int] = Array::new()
    for i in 0..<total_degree {
      arr.push(i)
    }
    array_gens.push(arr)
  }
  let mut current_gen = 0
  let mut current_deg = 0
  for i in 0..<groups.length() {
    let group = groups[i]
    let gens = group.generators()
    for j in current_gen..<(current_gen + gens_count[i]) {
      let gen = gens[j - current_gen].array_form()
      for k in 0..<degrees[i] {
        array_gens[j][current_deg + k] = gen[k] + current_deg
      }
    }
    current_gen = current_gen + gens_count[i]
    current_deg = current_deg + degrees[i]
  }
  let perm_gens : Array[Permutation] = Array::new()
  for a in array_gens {
    let p = Permutation::from_array(a)
    let mut seen = false
    for q in perm_gens {
      let qa = q.array_form()
      let pa = p.array_form()
      if qa.length() == pa.length() {
        let mut eq = true
        for i in 0..<qa.length() {
          if qa[i] != pa[i] {
            eq = false
            break
          }
        }
        if eq {
          seen = true
          break
        }
      }
    }
    if !seen {
      perm_gens.push(p)
    }
  }
  PermutationGroup::new(perm_gens, dups=false)
}
