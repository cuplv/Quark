Here is the trace resulting from running the alice-bob-cheryl experiment:

## On Alice

```
$_build/default/alice.exe
Opened connection.
Created store tables.
Created root branch alice with value "[]".
1. Alice created Root. Can Alice commit?y
Updated branch alice to value "[1;2]".
4. Alice committed. Can Alice sync?y
Results of sync:
        bob : ok; cheryl : ok
7. Alice synced. Can Alice commit?y
Updated branch alice to value "[11;1;2;3;4;5;6]".
10. Alice committed. Can Alice sync?y
Results of sync:
        bob : blocked by cheryl; cheryl : blocked by bob
Latest value on alice: [11;1;2;3;4;5;6]
13. Alice done. End?y
Version graph: (child <- parent)
bob:0 <- alice:0
bob:1 <- bob:0
bob:3 <- bob:2
cheryl:0 <- alice:0
cheryl:1 <- cheryl:0
cheryl:3 <- cheryl:2
alice:1 <- alice:0
alice:4 <- alice:3

LCA Map: (b1, b2) <- lca)
(bob, alice) <- alice:4
(cheryl, alice) <- cheryl:1
(cheryl, bob) <- bob:5

Branches:
bob, cheryl, alice,
```

## On Bob

```
$_build/default/bob.exe
Opened connection.
LCAs with:
Forked new branch bob off of alice.
2. Bob forked. Can Bob commit?y
Updated branch bob to value "[3;4]".
5. Bob committed. Can Bob sync?y
Results of sync:
        cheryl : blocked by alice; alice : ok
8. Bob synced. Can Bob commit?y
Updated branch bob to value "[12;1;2;3;4;5;6]".
11. Bob committed. Can Bob sync?y
Results of sync:
        cheryl : ok; alice : ok
Latest value on bob: [11;12;13;1;2;3;4;5;6]

```

## On Cheryl

```
$_build/default/cheryl.exe
Opened connection.
LCAs with: bob,
Forked new branch cheryl off of alice.
3. Cheryl forked. Can Cheryl commit?y
Updated branch cheryl to value "[5;6]".
6. Cheryl committed. Can Cheryl sync?y
Results of sync:
        bob : ok; alice : blocked by bob
9. Cheryl synced. Can Cheryl commit?y
Updated branch cheryl to value "[13;1;2;3;4;5;6]".
12. Cheryl committed. Can Cheryl sync?y
Results of sync:
        bob : ok; alice : blocked by bob
Latest value on cheryl: [11;12;13;1;2;3;4;5;6]
```
