Building Quark
==================

You need OCaml 4.12+ and Opam 2.1.0+. The preferred way is install
opam first and then use it to install OCaml.

* Installing opam:

```
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"
```

* Installing OCaml with opam:

```
# environment setup
opam init
eval $(opam env)
# install given version of the compiler
opam switch create 4.12.0
eval $(opam env)
# check you got what you want
which ocaml
ocaml -version
```

The Quark project uses the [dune](https://dune.build/) build system.
Install dune:

```
opam install dune
```

There is a `dune` file included under `src` that tells dune how to
build the project. The dune file lists several library dependencies
none which are installed yet. Running `dune build` (under `src`) first
time tells you the packages that are missing and also generates an
opam command you can run to install them. One caveat: the `scylla`
package is not available in any of the opam repositories, so remove it
from the list and install everything else. Once all other packages are
installed, run the following to install `scylla` package.

```
opam pin add scylla git@github.com:gowthamk/ocaml-scylla
```

This would install OCaml bindings for Scylla database (but not the
database itself.) Once all package dependencies are installed, `dune
build` should succeed. Note that sometimes there may be system
packages that are missing, in which they must be installed using the
system's package manager, .e.g, `apt-get` or `brew`. If `dune build`
succeeds it creates two new executables -- `monkey.exe` and
`analyze.exe`, under `_build/default`.

Installing Scylla
=================

[Scylla](https://www.scylladb.com/) is a distributed database that is
a C++ clone of [Cassandra](https://cassandra.apache.org/_/index.html).
You can run Scylla inside a docker (see top-level README for
instructions), but for the experiments it is preferable to run it
directly on the machine. See Scylla's [getting
started](https://docs.scylladb.com/getting-started/) page for
instructions. For distributed experiments you need to configure a
3-node cluster of Scylla. Instructions
[here](https://docs.scylladb.com/operating-scylla/procedures/cluster-management/create-cluster/).

Once Scylla is installed and running, run `monkey.exe` to see if
everything is working:

```
_build/default/monkey.exe -master --port 9042 --nrounds 10 --nbranches 1
```

Running experiments
===================

Each monkey.exe process works on a single branch. There must always be
a monkey associated with a master branch. Multiple monkeys can run on
a single machine and connect to the local Scylla instance. Each monkey
would however only publish changes to its own branch. Here is how you
run three monkeys on the localhost:

```
_build/default/monkey.exe -master --port 9042 --nrounds 50 --nbranches 3

# Wait until you see "master branch created" message, which should
take no more than 3s. Then run:

_build/default/monkey.exe --port 9042 --nrounds 50 --nbranches 3 --name monkey2


_build/default/monkey.exe --port 9042 --nrounds 50 --nbranches 3 --name monkey3
```

Monkeys wait for all monkeys to setup their branches before proceeding
with the experiment. Each monkey measures latency for each round and
logs them onto "<monkey-name>\_latency\_<timestamp>.csv". Staleness
measurement is a post-processing analysis done by `analyze.exe`.

```
# Following generates `master_staleness_<timestamp>.csv`
_build/default/monkey.exe --port 9042 --nbranches 3 --name master

# Following generates `monkey2_staleness_<timestamp>.csv`
_build/default/monkey.exe --port 9042 --nbranches 3 --name monkey2

# Following generates `monkey3_staleness_<timestamp>.csv`
_build/default/monkey.exe --port 9042 --nbranches 3 --name monkey3
```

Since we are interested in overall latency and staleness values, you
may combine the latency numbers from all three
experiments (likewise with staleness).

