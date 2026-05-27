# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg.json` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, this is a `moon.mod.json` file listing about the
  module and some meta information.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check the test is passed. MoonBit supports snapshot
  testing, so when your changes indeed change the behavior of the code, you
  should run `moon test --update` to update the snapshot.

- For native Python oracle/parity packages under `src/sympy/*`, use miniconda
  Python and force Moon away from `tcc -run`:

  ```bash
  env -u CC \
  MallocNanoZone=0 \
  MOON_CC=/usr/bin/gcc \
  PATH=$HOME/miniconda3/bin:$PATH \
  LIBRARY_PATH=$HOME/miniconda3/lib \
  DYLD_LIBRARY_PATH=$HOME/miniconda3/lib \
  moon test --target native <pkg-path>
  ```

  `PATH` must put miniconda first so `python3-config` exposes the matching
  `Python.h` and libpython flags. `MOON_CC=/usr/bin/gcc` is the switch that
  disables Moon's default `tcc -run`; setting only `CC=gcc` is not enough. On
  macOS, `/usr/bin/gcc` is usually Apple clang and is fine for this purpose.
  Keep `MallocNanoZone=0` for native oracle tests; it avoids allocator-level
  nondeterminism when embedded Python and Moon native code share a process.

- You can run `moon check` to check the code is linted correctly.

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

- agent-todo.md has some small tasks that are easy for AI to pick up, agent is
  welcome to finish the tasks and check the box when you are done
