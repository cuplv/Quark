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

Next, run the `dbtest` program.
This uses the ocaml-scylla library to query the scylla docker container
The library is packaged for use in `nix-shell` by the `ocaml-scylla.nix` file.

[ocaml-scylla](https://github.com/anmolsahoo25/ocaml-scylla)

Currently, the `dbtest` program creates a content-addressed store and branch-tracking store, assigns several value versions to the branches, and merges the changes between them using fast-forward and 3-way merge.

```
$ nix-shell
(nix-shell) $ cd dbtest
(nix-shell) $ dune build
(nix-shell) $ _build/default/dbtest.exe
Opening connection...
Opened connection.
Created store tables.
Updated/created branch b1 with value "Hello".
Forked new branch b2 off of b1.
Updated/created branch b2 with value "Hello Earth".
Updated/created branch b1 with value "Hello Moon".
Pulled from b1 into b2 to get "Hello Moon Earth".
Updated/created branch b1 with value "Hello Moon, Mars".
Pulled from b2 into b1 to get "Hello Moon Earth, Mars".
Pulled from b1 into b2 to get "Hello Moon Earth, Mars".
Updated/created branch b1 with value "Hello Moon Earth, Mars, etc.".
Pulled from b1 into b2 to get "Hello Moon Earth, Mars, etc.".
```

The bottom of the `dbtest.ml` file is the script of forks, updates, and pulls that produces the above behavior.
This file also contains the simple string merge function used, `str_merge`.

[dbtest.ml](./dbtest/dbtest.ml)
