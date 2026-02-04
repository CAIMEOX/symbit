///|
/// Weyl group data and operations.

///|
pub struct WeylGroup {
  cartan_type : CartanType
}

///|
pub fn weyl_group_from_string(ct : String) -> WeylGroup raise {
  let cartan = cartan_type_from_string(ct)
  WeylGroup::{ cartan_type: cartan }
}

///|
pub fn WeylGroup::cartan_type(self : WeylGroup) -> CartanType {
  self.cartan_type
}

///|
fn parse_reflections(weylelt : String) -> Array[Int] {
  let out : Array[Int] = Array::new()
  if weylelt.is_empty() {
    return out
  }
  for part in weylelt.split("*") {
    let token = part.to_string()
    if token.length() < 2 {
      continue
    }
    let num_str = (try! token[1:token.length()]).to_string()
    out.push(try! @strconv.parse_int(num_str, base=10))
  }
  out
}

///|
pub fn WeylGroup::generators(self : WeylGroup) -> Array[String] {
  let n = self.cartan_type.rank()
  let gens : Array[String] = Array::new()
  for i in 1..<=n {
    gens.push("r\{i.to_string()}")
  }
  gens
}

///|
fn factorial(n : Int) -> @symnum.BigRational {
  if n <= 1 {
    return br_int(1)
  }
  let mut acc = br_int(1)
  for i in 2..<=n {
    acc = acc * br_int(i)
  }
  acc
}

///|
fn pow2(n : Int) -> @symnum.BigRational {
  let mut acc = br_int(1)
  for _ in 0..<n {
    acc = acc * br_int(2)
  }
  acc
}

///|
pub fn WeylGroup::group_order(self : WeylGroup) -> @symnum.BigRational {
  let n = self.cartan_type.rank()
  match self.cartan_type.series() {
    "A" => factorial(n + 1)
    "B" => factorial(n) * pow2(n)
    "C" => factorial(n) * pow2(n)
    "D" => factorial(n) * pow2(n - 1)
    "E" =>
      if n == 6 {
        br_int(51840)
      } else if n == 7 {
        br_int(2903040)
      } else {
        br_int(696729600)
      }
    "F" => br_int(1152)
    "G" => br_int(12)
    _ => panic()
  }
}

///|
pub fn WeylGroup::group_name(self : WeylGroup) -> String {
  let n = self.cartan_type.rank()
  match self.cartan_type.series() {
    "A" => {
      let dim = n + 1
      let dim_str = dim.to_string()
      "S\{dim_str}: the symmetric group acting on \{dim_str} elements."
    }
    "B" => {
      let dim = 2 * n
      let dim_str = dim.to_string()
      "The hyperoctahedral group acting on \{dim_str} elements."
    }
    "C" => {
      let dim = 2 * n
      let dim_str = dim.to_string()
      "The hyperoctahedral group acting on \{dim_str} elements."
    }
    "D" =>
      "The symmetry group of the \{n.to_string()}-dimensional demihypercube."
    "E" =>
      if n == 6 {
        "The symmetry group of the 6-polytope."
      } else if n == 7 {
        "The symmetry group of the 7-polytope."
      } else {
        "The symmetry group of the 8-polytope."
      }
    "F" => "The symmetry group of the 24-cell, or icositetrachoron."
    "G" =>
      "D6, the dihedral group of order 12, and symmetry group of the hexagon."
    _ => panic()
  }
}

///|
fn matrix_order(group : WeylGroup, weylelt : String, size : Int) -> Int {
  let id = matrix_eye(size)
  let mut a = group.matrix_form(weylelt)
  let mut order = 1
  while a != id {
    a = a.mul(group.matrix_form(weylelt))
    order += 1
  }
  order
}

///|
fn delete_doubles(reflections : Array[Int]) -> Array[Int] {
  let copy = reflections.copy()
  let mut idx = 0
  while idx < copy.length() {
    if idx < copy.length() - 1 && copy[idx] == copy[idx + 1] {
      ignore(copy.remove(idx))
      ignore(copy.remove(idx))
    }
    idx += 1
  }
  copy
}

///|
pub fn WeylGroup::element_order(self : WeylGroup, weylelt : String) -> Int {
  let n = self.cartan_type.rank()
  match self.cartan_type.series() {
    "A" => matrix_order(self, weylelt, n + 1)
    "D" => matrix_order(self, weylelt, n)
    "E" => matrix_order(self, weylelt, 8)
    "F" => matrix_order(self, weylelt, 4)
    "B" => matrix_order(self, weylelt, n)
    "C" => matrix_order(self, weylelt, n)
    "G" => {
      let reflections = parse_reflections(weylelt)
      let mut m = delete_doubles(reflections)
      while vec_equal_int_list(delete_doubles(m), m) == false {
        m = delete_doubles(m)
      }
      if m.length() % 2 == 1 {
        2
      } else if m.length() == 0 {
        1
      } else if m.length() == 1 {
        2
      } else {
        let half_len = m.length() / 2
        let lcm = 6 * half_len / igcd(half_len, 6)
        lcm / half_len
      }
    }
    _ => panic()
  }
}

///|
fn vec_equal_int_list(lhs : Array[Int], rhs : Array[Int]) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if lhs[i] != rhs[i] {
      return false
    }
  }
  true
}

///|
fn igcd(a : Int, b : Int) -> Int {
  let mut x = if a < 0 { -a } else { a }
  let mut y = if b < 0 { -b } else { b }
  while y != 0 {
    let temp = x % y
    x = y
    y = temp
  }
  x
}

///|
pub fn WeylGroup::matrix_form(self : WeylGroup, weylelt : String) -> Matrix {
  let reflections = parse_reflections(weylelt)
  let n = self.cartan_type.rank()
  match self.cartan_type.series() {
    "A" => {
      let mut matrixform = matrix_eye(n + 1)
      for a in reflections {
        let mat = matrix_eye(n + 1)
        mat.set(a - 1, a - 1, br_int(0))
        mat.set(a - 1, a, br_int(1))
        mat.set(a, a - 1, br_int(1))
        mat.set(a, a, br_int(0))
        matrixform = matrixform.mul(mat)
      }
      matrixform
    }
    "D" => {
      let mut matrixform = matrix_eye(n)
      for a in reflections {
        let mat = matrix_eye(n)
        if a < n {
          mat.set(a - 1, a - 1, br_int(0))
          mat.set(a - 1, a, br_int(1))
          mat.set(a, a - 1, br_int(1))
          mat.set(a, a, br_int(0))
        } else {
          mat.set(n - 2, n - 1, br_int(-1))
          mat.set(n - 2, n - 2, br_int(0))
          mat.set(n - 1, n - 2, br_int(-1))
          mat.set(n - 1, n - 1, br_int(0))
        }
        matrixform = matrixform.mul(mat)
      }
      matrixform
    }
    "G" => {
      let mut matrixform = matrix_eye(3)
      let two_thirds = br_rat(2, 3)
      let neg_third = br_rat(-1, 3)
      for a in reflections {
        if a == 1 {
          let mat = matrix_from_rows([
            [br_int(1), br_int(0), br_int(0)],
            [br_int(0), br_int(0), br_int(1)],
            [br_int(0), br_int(1), br_int(0)],
          ])
          matrixform = matrixform.mul(mat)
        } else {
          let mat = matrix_from_rows([
            [two_thirds, two_thirds, neg_third],
            [two_thirds, neg_third, two_thirds],
            [neg_third, two_thirds, two_thirds],
          ])
          matrixform = matrixform.mul(mat)
        }
      }
      matrixform
    }
    "F" => {
      let mut matrixform = matrix_eye(4)
      let half = br_rat(1, 2)
      let neg_half = br_rat(-1, 2)
      for a in reflections {
        let mat = if a == 1 {
          matrix_from_rows([
            [br_int(1), br_int(0), br_int(0), br_int(0)],
            [br_int(0), br_int(0), br_int(1), br_int(0)],
            [br_int(0), br_int(1), br_int(0), br_int(0)],
            [br_int(0), br_int(0), br_int(0), br_int(1)],
          ])
        } else if a == 2 {
          matrix_from_rows([
            [br_int(1), br_int(0), br_int(0), br_int(0)],
            [br_int(0), br_int(1), br_int(0), br_int(0)],
            [br_int(0), br_int(0), br_int(0), br_int(1)],
            [br_int(0), br_int(0), br_int(1), br_int(0)],
          ])
        } else if a == 3 {
          matrix_from_rows([
            [br_int(1), br_int(0), br_int(0), br_int(0)],
            [br_int(0), br_int(1), br_int(0), br_int(0)],
            [br_int(0), br_int(0), br_int(1), br_int(0)],
            [br_int(0), br_int(0), br_int(0), br_int(-1)],
          ])
        } else {
          matrix_from_rows([
            [half, half, half, half],
            [half, half, neg_half, neg_half],
            [half, neg_half, half, neg_half],
            [half, neg_half, neg_half, half],
          ])
        }
        matrixform = matrixform.mul(mat)
      }
      matrixform
    }
    "E" => {
      let mut matrixform = matrix_eye(8)
      let q1 = br_rat(1, 4)
      let q3 = br_rat(3, 4)
      let qn1 = br_rat(-1, 4)
      let qn3 = br_rat(-3, 4)
      for a in reflections {
        let mat = if a == 1 {
          matrix_from_rows([
            [q3, q1, q1, q1, q1, q1, q1, qn1],
            [q1, q3, qn1, qn1, qn1, qn1, q1, qn1],
            [q1, qn1, q3, qn1, qn1, qn1, qn1, q1],
            [q1, qn1, qn1, q3, qn1, qn1, qn1, q1],
            [q1, qn1, qn1, qn1, q3, qn1, qn1, q1],
            [q1, qn1, qn1, qn1, qn1, q3, qn1, q1],
            [q1, q1, qn1, qn1, qn1, qn1, qn3, q1],
            [q1, qn1, qn1, qn1, qn1, qn1, qn1, q3],
          ])
        } else if a == 2 {
          let temp = matrix_eye(8)
          temp.set(0, 0, br_int(0))
          temp.set(0, 1, br_int(-1))
          temp.set(1, 0, br_int(-1))
          temp.set(1, 1, br_int(0))
          temp
        } else {
          let temp = matrix_eye(8)
          temp.set(a - 3, a - 3, br_int(0))
          temp.set(a - 3, a - 2, br_int(1))
          temp.set(a - 2, a - 3, br_int(1))
          temp.set(a - 2, a - 2, br_int(0))
          temp
        }
        matrixform = matrixform.mul(mat)
      }
      matrixform
    }
    "B" => {
      let mut matrixform = matrix_eye(n)
      for a in reflections {
        let mat = matrix_eye(n)
        if a == 1 {
          mat.set(0, 0, br_int(-1))
        } else {
          mat.set(a - 2, a - 2, br_int(0))
          mat.set(a - 2, a - 1, br_int(1))
          mat.set(a - 1, a - 2, br_int(1))
          mat.set(a - 1, a - 1, br_int(0))
        }
        matrixform = matrixform.mul(mat)
      }
      matrixform
    }
    "C" => {
      let mut matrixform = matrix_eye(n)
      for a in reflections {
        let mat = matrix_eye(n)
        if a == 1 {
          mat.set(0, 0, br_int(-1))
        } else {
          mat.set(a - 2, a - 2, br_int(0))
          mat.set(a - 2, a - 1, br_int(1))
          mat.set(a - 1, a - 2, br_int(1))
          mat.set(a - 1, a - 1, br_int(0))
        }
        matrixform = matrixform.mul(mat)
      }
      matrixform
    }
    _ => panic()
  }
}

///|
pub fn WeylGroup::coxeter_diagram(self : WeylGroup) -> String raise {
  let n = self.cartan_type.rank()
  match self.cartan_type.series() {
    "A" => self.cartan_type.dynkin_diagram()
    "D" => self.cartan_type.dynkin_diagram()
    "E" => self.cartan_type.dynkin_diagram()
    "B" => {
      let zeros : Array[String] = Array::new()
      for _ in 1..<n {
        zeros.push("0")
      }
      let chain = zeros.join("---")
      let top = "\{chain}===0"
      let nums : Array[String] = Array::new()
      for i in 1..<=n {
        nums.push(i.to_string())
      }
      let bottom = nums.join("   ")
      "\{top}\n\{bottom}"
    }
    "C" => {
      let zeros : Array[String] = Array::new()
      for _ in 1..<n {
        zeros.push("0")
      }
      let chain = zeros.join("---")
      let top = "\{chain}===0"
      let nums : Array[String] = Array::new()
      for i in 1..<=n {
        nums.push(i.to_string())
      }
      let bottom = nums.join("   ")
      "\{top}\n\{bottom}"
    }
    "F" => {
      let mut diag = "0---0===0---0\n"
      let nums : Array[String] = Array::new()
      for i in 1..<=4 {
        nums.push(i.to_string())
      }
      diag = diag + nums.join("   ")
      diag
    }
    "G" => "0≡≡≡0\n1   2"
    _ => panic()
  }
}
