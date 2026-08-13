# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, this is a `moon.mod` file listing about the
  module and some meta information.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

- Do not rely on MoonBit's transitional implicit promotion from
  `impl Trait for Type` to dot methods. Call trait methods explicitly as
  `Trait::method(value, ...)`. A package's `trait_optouts.mbt` uses
  `#deprecated pub extend Type with Trait::{method}` as the compiler's E0079
  opt-out marker and as a deprecated public migration shim; production and
  test call sites in this module must not use that extension.

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

- Python oracle/parity packages under `src/sympy/*` use a persistent subprocess
  worker. Select the interpreter explicitly when the default `python3` is not
  the sibling SymPy-compatible environment:

  ```bash
  SYMBIT_PYTHON=$HOME/miniconda3/bin/python \
  moon test --target native <pkg-path>
  ```

  Use the same environment with
  `moon check --target native --deny-warn <pkg-path>` for the oracle warning
  gate.

  The MoonBit test process does not embed or link CPython. Each executable
  lazily starts one worker and exchanges framed JSON over pipes; Python objects
  must remain request-scoped. Do not add `Python.h`, libpython, GIL wrappers, or
  remote-object handles back to oracle packages. A broken `PYTHONHOME` must not
  affect the MoonBit process when `SYMBIT_PYTHON` names a valid interpreter.

- You can run `moon check` to check the code is linted correctly.

- This module may be checked from a parent `moon.work`. A bare `moon check` can
  therefore include sibling modules, while `moon check src` only checks the
  dependency closure rooted at `src`. To check every non-oracle package and
  reject default warnings plus E0073/E0079, use:

  ```bash
  find src -type f -name moon.pkg ! -path 'src/sympy/*' -print \
    | sed 's#/moon.pkg$##' \
    | xargs moon check --frozen --deny-warn --warn-list +73+79
  ```

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

- agent-todo.md has some small tasks that are easy for AI to pick up, agent is
  welcome to finish the tasks and check the box when you are done
