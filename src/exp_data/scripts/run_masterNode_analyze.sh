# execute this script from the folder: /src/_build/default/
# bash ../../exp_data/scripts/run_masterNode_analyze.sh <port> <nrounds> <nbranches> <machName> <expName> 
port=$1
nRounds=$2
nBranches=$3
machName=$4
expName=$5
numNodes=3
iters=$(( nBranches/numNodes ))


res_path='../../exp_data/'$expName'_'$machName 


# execute the master-process
echo "master: executing analyze"
sudo ./analyze.exe --port $1 --nbranches $3 --branch master

# execute slaves
for i in `seq 2 $iters`
do
	branchName=$machName$i
	echo "executing slave process"
	echo $branchName
    #nohup sh ../../exp_data/scripts/exec_slave.sh $1 $2 $3 $branchName &
    sudo ./analyze.exe --port $1 --nbranches $3 --branch $branchName 
done

mv ./*.csv $res_path/ 
mv ./*.log $res_path/

