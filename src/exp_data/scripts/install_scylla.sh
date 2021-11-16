sudo apt-get update
sudo apt-get install build-essential git bubblewrap unzip curl

bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"

opam init
eval $(opam env)
opam switch create 4.12.0
eval $(opam env --switch=4.12.0)
which ocaml

opam install dune irmin lwt lwt_ppx ppx_irmin
opam pin add scylla git+https://git@github.com/gowthamk/ocaml-scylla


# Install Scylla

sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 5e08fbd8b5d6ec9c

sudo curl -L --output /etc/apt/sources.list.d/scylla.list http://downloads.scylladb.com/deb/ubuntu/scylla-4.5-$(lsb_release -s -c).list

sudo apt-get update
sudo apt-get install -y scylla openjdk-8-jre-headless

sudo update-java-alternatives --jre-headless -s java-1.8.0-openjdk-amd64


# sudo /opt/scylladb/scripts/scylla_dev_mode_setup --developer-mode 1

# It should be manual from here onwards
#sudo scylla_setup
#sudo systemctl start scylla-server
#nodetool status


# download git repository
#mkdir Work
#cd Work
#git clone https://github.com/cuplv/merge-experiments
#dune build

