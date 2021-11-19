# execute this script from the folder: /src/_build/default/
# bash ../../exp_data/scripts/run_master.sh <port> <nrounds> <nbranches> <machName> <expName> 
port=$1
nRounds=$2
nBranches=$3
machName=$4
expName=$5
numNodes=3
iters=$(( nBranches/numNodes ))


# execute slaves
for i in `seq 1 $iters`
do
	branchName=$machName$i
	echo "executing slave process"
	echo $branchName
    #nohup sh ../../exp_data/scripts/exec_slave.sh $1 $2 $3 $branchName &
    sudo ../../_build/default/analyze.exe --port $1 --nbranches $3 --branch $branchName 
done

