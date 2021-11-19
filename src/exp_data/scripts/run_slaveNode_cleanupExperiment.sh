# execute this script from the folder: /src/_build/default/
# bash ../../exp_data/scripts/run_masterNode_cleanupExperiment.sh <port> <nrounds> <nbranches> <machName> <expName> 
port=$1
nRounds=$2
nBranches=$3
machName=$4
expName=$5
numNodes=3
iters=$(( nBranches/numNodes ))


res_path='../../exp_data/'$expName_$machName


echo "moving .csv files into "$res_path
sudo mv ./*.csv $res_path/ 
sudo mv ./*.log $res_path/

