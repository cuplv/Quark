# Experiments on solo node


## INSTALL UBUNTU-DEPENDENCIES
```
sudo apt-get update
sudo apt-get install build-essential git bubblewrap unzip screen

```



## Install DOCKER

```
 $ sudo apt-get update

 $ sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

 $ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg


 $ echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


 $ sudo apt-get update

 $ sudo apt-get install docker-ce docker-ce-cli containerd.io

```


## Install Docker-Compose

(reference)[https://docs.docker.com/compose/install/]
```
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose


chmod +x /usr/local/bin/docker-compose


docker-compose --version
```

## Set PERMISSIONS for USER on DOCKER
```
sudo usermod -aG docker $USER


```


## Install OPAM/OCAML

```
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"

# environment setup
opam init
eval $(opam env)
# install given version of the compiler
opam switch create 4.12.0
eval $(opam env)
# check you got what you want
which ocaml
ocaml -version

opam install dune irmin lwt lwt_ppx ppx_irmin

```

## Install SCYLLA OCAML BINDINGS

```
opam pin add scylla git+https://git@github.com/gowthamk/ocaml-scylla

```


## Install REPOSITORY

```
git clone https://github.com/cuplv/merge-experiments.git

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

dune build

```



## Test execution

### Startup the ScyllaDB instances

#### Using Docker

```
sudo docker run --name scylla -d -p 9042:9042  scylladb/scylla

sudo docker run --name scylla2 -d -p 9043:9042 scylladb/scylla --seeds="$(docker inspect --format='{{ .NetworkSettings.IPAddress }}' scylla)"

sudo docker run --name scylla3 -d -p 9044:9042 scylladb/scylla --seeds="$(docker inspect --format='{{ .NetworkSettings.IPAddress }}' scylla)"

sudo docker exec -it scylla nodetool status

sudo docker exec -it scylla cqlsh

```

#### Using Docker-Compose
```
sudo docker-compose up -d
sudo docker container ls


sudo docker exec -it scylla nodetool status

sudo docker exec -it scylla cqlsh

```

## Conduct Single Monkey Experiment

Navigate into `src/_build/default` folder
```

#On MASTER BRANCH

sudo bash ../../exp_data/scripts/run_masterNode_monkey.sh 9042 500 3 machA [test01]

# On SLAVE BRANCH

sudo bash ../../exp_data/scripts/run_slaveNode_monkey.sh <port-number> 500 3 <mach-Name> [test01]

```

### Extract staleness values

```
#On MASTER BRANCH

sudo bash ../../exp_data/scripts/run_masterNode_analyze.sh 9042 500 3 machA [test01]

# On SLAVE BRANCH

sudo bash ../../exp_data/scripts/run_slaveNode_analyze.sh <port-number> 500 3 <mach-Name> [test01]


```

### Archive the datasets

```

sudo bash ../../exp_data/scripts/run_masterNode_cleanupExperiment.sh 9042 500 3 machA [test01]


```