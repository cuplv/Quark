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
This uses an experimental ocaml + scylla + irmin interface, found in these two repos:

[ocaml-scylla](https://github.com/anmolsahoo25/ocaml-scylla)

[ocaml-mrdt](https://github.com/cuplv/ocaml-mrdt-v2)

These are packaged for use in `nix-shell` by the `ocaml-scylla.nix` and `ocaml-mrdt.nix` files.

```
$ nix-shell
(nix-shell) $ cd dbtest
(nix-shell) $ dune build
(nix-shell) $ _build/default/dbtest.exe
R0 added element 5.
R0 says min element is 5.
R1 added element 7.
R1 says min element is 7.
After merge, R1 says min element is 5.
```

This creates two database replicas, and merges their values.
