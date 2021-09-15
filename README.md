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

Currently, the `dbtest` program creates a content-addressed store, stores two items (string values) in it, and retrieves them.

```
$ nix-shell
(nix-shell) $ cd dbtest
(nix-shell) $ dune build
(nix-shell) $ _build/default/dbtest.exe
Opened connection.
Created store.
Stored items.
Found "Earth".
Found "Moon".
```
