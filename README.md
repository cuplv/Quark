First, get a scylla node running as a docker container.

```
$ docker run -p 9042:9042 --name some-scylla -d scylladb/scylla --smp 1
```

The --smp argument restricts it to using one CPU core, which prevented it from crashing in my case.

[Official guide to running Scylla in Docker](https://docs.scylladb.com/operating-scylla/procedures/tips/best_practices_scylla_on_docker/)

Next, create the "mrdt" keyspace, so that tables can be added for new mrdt stores.
This can be accomplished using `csqlsh`, which can be found in the `cassandra` package on NixOS.

```
$ nix run nixpkgs.cassandra -c cqlsh
Connected to  at 127.0.0.1:9042
...
...
cqlsh> CREATE KEYSPACE mrdt
   ... WITH replication = {'class':'SimpleStrategy', 'replication_factor' : 1 };
```

Finally, run the `dbtest` program.
This uses an experimental ocaml + scylla + irmin interface which is packaged by `ocaml-scylla.nix` and `ocaml-mrdt.nix`.

```
$ nix-shell
(nix-shell) $ cd dbtest
(nix-shell) $ dune build
(nix-shell) $ _build/default/dbtest.exe
```

This creates a store in the database.
More demonstrations coming soon.
