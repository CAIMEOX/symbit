///|
/// Root system data for simple Lie algebras.

///|
pub struct RootSystem {
  cartan_type : CartanType
}

///|
/// Build a root-system object from a Cartan type string.
pub fn root_system_from_string(ct : String) -> RootSystem raise {
  let cartan = cartan_type_from_string(ct)
  RootSystem::{ cartan_type: cartan }
}

///|
/// Build a root-system object from `(series, rank)`.
pub fn root_system_from_parts(series : String, n : Int) -> RootSystem raise {
  let cartan = cartan_type_from_parts(series, n)
  RootSystem::{ cartan_type: cartan }
}

///|
/// Return the underlying Cartan type.
pub fn RootSystem::cartan_type(self : RootSystem) -> CartanType {
  self.cartan_type
}

///|
/// Return indexed simple roots.
pub fn RootSystem::simple_roots(self : RootSystem) -> Map[Int, RootVector] {
  let n = self.cartan_type.rank()
  let roots : Map[Int, RootVector] = {}
  for i in 1..<=n {
    roots[i] = try! self.cartan_type.simple_root(i)
  }
  roots
}

///|
/// Return all roots (negative then positive) in index order.
pub fn RootSystem::all_roots(self : RootSystem) -> Map[Int, RootVector] {
  let alpha = self.cartan_type.positive_roots()
  let mut k = 0
  let keys : Array[Int] = Array::new()
  for key, _ in alpha {
    keys.push(key)
    if key > k {
      k = key
    }
  }
  for key in keys {
    k += 1
    let root = vec_neg(alpha[key])
    alpha[k] = root
  }
  alpha
}

///|
/// Describe the ambient root-space dimension.
pub fn RootSystem::root_space(self : RootSystem) -> String {
  let n = self.cartan_type.rank()
  let parts : Array[String] = Array::new()
  for i in 1..<=n {
    parts.push("alpha[\{i.to_string()}]")
  }
  parts.join(" + ")
}

///|
/// Add two simple roots by index.
pub fn RootSystem::add_simple_roots(
  self : RootSystem,
  root1 : Int,
  root2 : Int,
) -> RootVector raise {
  let alpha = self.simple_roots()
  let count = alpha.length()
  if root1 > count || root2 > count {
    fail("You've used a root that doesn't exist!")
  }
  let a1 = alpha[root1]
  let a2 = alpha[root2]
  vec_add(a1, a2)
}

///|
fn roots_contains(roots : Map[Int, RootVector], target : RootVector) -> Bool {
  for _, root in roots {
    if vec_equal(root, target) {
      return true
    }
  }
  false
}

///|
/// Add two roots and validate that the sum is a root.
pub fn RootSystem::add_as_roots(
  self : RootSystem,
  root1 : RootVector,
  root2 : RootVector,
) -> Result[RootVector, String] {
  let alpha = self.all_roots()
  let newroot = vec_add(root1, root2)
  if roots_contains(alpha, newroot) {
    Ok(newroot)
  } else {
    Err("The sum of these two roots is not a root")
  }
}

///|
/// Return the Cartan matrix of this root system.
pub fn RootSystem::cartan_matrix(self : RootSystem) -> Matrix raise {
  self.cartan_type.cartan_matrix()
}

///|
/// Return the Dynkin diagram of this root system.
pub fn RootSystem::dynkin_diagram(self : RootSystem) -> String raise {
  self.cartan_type.dynkin_diagram()
}
