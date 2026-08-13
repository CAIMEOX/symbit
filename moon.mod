name = "CAIMEOX/symbit"

version = "0.5.10"

import {
  "moonbitlang/quickcheck@0.9.10",
  "CAIMEOX/moon_floating@0.3.0",
}

readme = "README.mbt.md"

repository = "https://github.com/CAIMEOX/symbit.git"

license = "Apache-2.0"

keywords = [ "symbolic", "math", "algebra", "polynomials", "physics" ]

description = "A symbolic mathematics library for Moonbit."

options(
  source: "src",
  exclude: [ "src/sympy" ],
)
