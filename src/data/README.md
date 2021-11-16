Building Quark
==================

You need OCaml 4.12+ and Opam 2.1.0+. The preferred way is install
opam first and then use it to install OCaml.

* Installing opam:

```
sudo apt-get install bubblewrap
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
opam install irmin lwt lwt_ppx ppx_irmin



opam pin add scylla git+https://git@github.com/gowthamk/ocaml-scylla

dune build
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

Installing Scylla via Docker
=============================
Access the docker-config file in `/merge-experiments/docker/docker-compose.yml`. Use the following command to install the three docker-containers running scylla:
```
docker compose up -d
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


Installation on a VM
=======================

```
sudo apt-get install build-essential git bubblewrap unzip
opam init
```

```
eval $(opam env)
# install given version of the compiler
opam switch create 4.12.0
eval $(opam env)
# check you got what you want
which ocaml
ocaml -version
```

```
opam install dune
```

### Installation of Git CLI

Install conda from [here](https://docs.conda.io/en/latest/miniconda.html#linux-installers)
```

sudo apt install hashalot


wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.10.3-Linux-x86_64.sh

# Verify download
sha256sum Miniconda3-py39_4.10.3-Linux-x86_64.sh


bash Miniconda3-py39_4.10.3-Linux-x86_64.sh
```


[Reference link](https://github.com/cli/cli#installation):
```
conda install gh --channel conda-forge

gh auth login --with-token < mytoken.txt


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


gh config set git_protocol ssh -h github.com
```

### Installation of Git Credential Manager


[Reference link](https://github.com/microsoft/Git-Credential-Manager-Core#linux-install-instructions): 
```
wget https://github.com/microsoft/Git-Credential-Manager-Core/releases/download/v2.0.567/gcmcore-linux_amd64.2.0.567.18224.deb

sudo dpkg -i <path-to-package>
git-credential-manager-core configure

```

```
sudo apt-get install gpg pass

gpg --gen-key

pass init <gpg-id>


git config --global credential.credentialStore gpg

```

#### Uninstall GMC-CORE
```
sudo dpkg -r --force-all gcmcore
```

#### Accessing the Quark Repository
Accessing the repository via github. 
```
git clone https://github.com/cuplv/merge-experiments.git

```


## Installing fresh on Ubuntu-Desktop VM

```
sudo apt-get install build-essential git unzip bubblewrap hashalot curl
```

#### Setup SSH-keys for machines with GITHUB. 

```
ssh-keygen -t ed25519 -C "prpr2770@colorado.edu"


gh auth refresh -h github.com -s admin:public_key 

gh ssh-key add ~/.ssh/id_ed25519.pub


```

### Accessing the dockers containers

`https://www.scylladb.com/download/?platform=docker#open-source`


```
$ docker run --name scylla -d scylladb/scylla


$ docker run --name scylla-node2 -d scylladb/scylla --seeds="$(docker inspect --format='{{ .NetworkSettings.IPAddress }}' scylla)"

$ docker run --name scylla-node3 -d scylladb/scylla --seeds="$(docker inspect --format='{{ .NetworkSettings.IPAddress }}' scylla)"

docker exec -it scylla nodetool status

docker exec -it scylla cqlsh
```

#### Modifying the cluster details

check config files `/etc/scylla/scylla.yaml`

```
# SEED NODE: 

cluster_name: 'Test Cluster'
num_tokens: 256
listen_address: localhost

broadcast_address: 1.2.3.4

native_shard_aware_transport_port : 19042

workdir: /var/lib/scylla
commitlog_directory: /var/lib/scylla/commitlog

commitlog_sync: periodic
commitlog_sync_period_in_ms: 10000
commitlog_segment_size_in_mb: 32

seed_provider: 
	- class_name: org.apache.cassandra.locator.SimpleSeedProvider
	  parameters: 
	  	- seeds: "127.0.0.1"

read_request_timeout_in_ms: 5000
write_request_timeout_in_ms: 2000

endpoint_snitch: SimpleSnitch

rpc_address: localhost
rpc_port: 9160

api_port: 10000
api_address: 127.0.0.1

batch_size_fail_threshold_in_kb: 50
batch_size_warn_threshold_in_kb: 5

partitioner: org.apache.cassandra.dht.Murmur3Partitioner
commitlog_total_space_in_mb: -1

murmur3_partitioner_ignore_msb_bits: 12
api_ui_dir: /opt/scylladb/swagger-ui/dist
api_doc_dir: /opt/scylladb/api/api-doc/

``` 


```
# SLAVE NODE

seed_provider: 
	# Addresses of hosts that are deemed contact points. Scylla nodes use this list of hosts to find each other and learn topology of the ring. 

listen_addres: localhost 	# Address or interface to bind to and tell other Scylla nodes to connect to. 
broadcast_address: 1.2.3.4 	# Addres to broadcast to other Scylla nodes. 

native_transport_port: 9042 	# native transport port
native_shard_aware_transport_port: 19042

endpoint_snitch: SimpleSnitch

rpc_address: localhost

```

(Networking)[https://docs.scylladb.com/operating-scylla/admin/#networking]
Scylla uses the following ports: 

```
9042 -- for cql
9142
7000
7001
7199
10000
9180
9100
9160
19042
19142
7199  -- for nodetool
```



```
Configure run SCylla Ubuntu 20.4

cluster_name
seeds: "192.168.1.201,192.168.1.202"
listen_address
rpc_address 	(ip-address of interface for client connections - CQL)



# installed location
/etc/default/scylla-server

# startup of service
sudo systemctl start scylla-server
```

(reference)[https://github.com/scylladb/scylla/issues/3538]
```
# ensure io setup is correct. 
sudo scylla_io_setup
cat /etc/scylla.d/io.conf 
sudo systemctl restart scylla-server
nodetool status
```

```
# find the ports that are open
sudo lsof -i -P -n | grep LISTEN

sudo ufw enable
sudo ufw status verbose

sudo ufw allow https
sudo ufw allow http

sudo ufw allow 22
```


## Installing Scylla on Server

(reference)[https://www.scylladb.com/download/?platform=ubuntu-18.04&version=scylla-4.5#open-source]

```
wget https://www.scylladb.com/download/?platform=ubuntu-18.04&version=scylla-4.5


sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 5e08fbd8b5d6ec9c

sudo curl -L --output /etc/apt/sources.list.d/scylla.list http://downloads.scylladb.com/deb/ubuntu/scylla-4.5-$(lsb_release -s -c).list

sudo apt-get update
sudo apt-get install -y scylla


sudo apt-get update
sudo apt-get install -y openjdk-8-jre-headless
sudo update-java-alternatives --jre-headless -s java-1.8.0-openjdk-amd64

```

### Configure and run scylla

```
sudo scylla_setup
sudo systemctl start scylla-server


nodetool status


cqlsh

# run cassandra stress
cassandra-stress write -mode cql3 native 
```