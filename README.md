This is an OCaml implementation of the SC Merge rules, using Cassandra/Scylla as a backend database.

# Dependencies

This implementation uses OCaml, and the `ocaml-scylla` library as an interface to scylla/cassandra.

[ocaml-scylla](https://github.com/anmolsahoo25/ocaml-scylla)

This has been packaged here as a Nix package (`./ocaml-scylla.nix`) for use in `nix-shell` (Nick's dev environment).
Without `nix-shell`, the library should be installable with the following command (Nick has not tested it), according to the README for `ocaml-mrdt-v2` which also uses it.

```
$ opam pin add scylla git@github.com:anmolsahoo25/ocaml-scylla
```

[ocaml-mrdt-v2](https://github.com/anmolsahoo25/ocaml-mrdt-v2)

# Demo

First, get a scylla node running as a docker container.

```
$ docker run -p 9042:9042 --name some-scylla -d scylladb/scylla --smp 1
```

The --smp argument restricts it to using one CPU core, which prevented it from crashing in my case.
You can check if the node started up successfully by running:

```
$ docker logs some-scylla | tail
```

[Official guide to running Scylla in Docker](https://docs.scylladb.com/operating-scylla/procedures/tips/best_practices_scylla_on_docker/)

Next, run the demo program.

First, the `demo` program creates a content-addressed store and branch-tracking store, assigns several value versions to the branches, and merges the changes between them using fast-forward and 3-way merge.

Second, it recreates the blocked merge from the SC Merge notes using 6 branches.

Third, it prints out information from the database tables.

```
$ nix-shell
(nix-shell) $ cd src
(nix-shell) $ dune build
(nix-shell) $ _build/default/demo.exe
...
```

(If not using nix-shell, skip the `nix-shell` call and make sure you have installed dune, ocaml, and ocaml-scylla.)

At the end of the demo, the final pull from branch `cc2` into branch `cc1` fails because the two branches have concurrent LCAs with the third branch `cc3`.
The branches `ca1`, `ca2`, `cc1`, `cc2`, and `cc3` represent the five branches in the blocked merge diagram from the SC Merge notes (with branch `c` being their common root branch).

The bottom of the `demo.ml` file is the script of forks, updates, and pulls that produces the above behavior.

[dbtest.ml](./dbtest/dbtest.ml)

# Code

The `demo.ml` file defines a CLI-friendly wrapper around the MergeDB module.
MergeDB is the main entrypoint for development, providing implementations of the `commit`, `fork`, and `pull` (covering `fastforward` and `merge`) rules.

[MergeDB interface](./src/mergeDB.mli)

[MergeDB implementation](./src/mergeDB.ml)

The MergeDB module in turn uses four database tables, through their associated modules.

## `ContentStore`

`ContentStore` is a content-addressed store for committed values.
Values must implement the `Content.STORABLE` interface by providing hash and serialization functions to be stored in the `ContentStore`.
The module `StringData` provides an implemenation for strings.

```
[Row schema] (key: blob, value blob)
```

## `VersionGraph`

`VersionGraph` is an edgelist table storing parent-child relationships between versions.

```
[Row schema] (
  child_branch blob,
  child_version_num int,
  child_content_id blob,
  parent_branch blob,
  parent_version_num int,
  parent_content_id blob,
)
```

Branch names could probably be Ascii strings, but I defined them as Blobs following the example from `ocaml-mrdt-v2` and have not changed it.
This makes debugging the database using `cqlsh`, for example, inconvenient.
However, `VersionGraph` and a few other modules have `debug_dump` functions that print the contents of the table to the console.

## `HeadMap`

`HeadMap` maintains the current head version of each branch.

```
[Row schema] (
  branch blob,
  version_num int,
  content_id blob,
)
```

The `branch` value is the primary key, and the three elements of the row make up the complete "version" value it points to.

## `LcaMap`

`LcaMap` maintains the LCAs of each pair of branches.

```
[Row schema] (
  branch1 blob,
  branch2 blob,
  lca_branch blob,
  lca_version_num int,
  lca_content_id blob,
)
```

The pair of branches is the primary key, and the other 3 elements make up the LCA version value.
When inserting or selecting, the requested branch pair is always sorted so that only one ordering appears in the table.
