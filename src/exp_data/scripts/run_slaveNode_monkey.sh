# execute this script from the folder: /src/_build/default/
# run_master.sh <port> <nrounds> <nbranches> <machName> <expName> 
# bash ../../exp_data/scripts/run_masterNode_monkey.sh 9042 10 3 machA test01
port=$1
nRounds=$2
nBranches=$3
machName=$4
expName=$5
numNodes=3
iters=$(( nBranches/numNodes ))
res_path='../../exp_data/'$expName'_'$machName 

echo "$res_path"
mkdir $res_path


# clear previous experiment results
rm ./*.csv
rm ./*.log

# execute slaves
echo "total slaves on node: "$iters
for i in `seq 1 $iters`
do
	branchName=$machName$i
	echo "executing slave process"
	echo $branchName
    #nohup sh ../../exp_data/scripts/exec_slave.sh $1 $2 $3 $branchName &
    nohup ./monkey.exe --port $1 --nrounds $2 --nbranches $3 --branch $branchName > monkey_$branchName.log &
    sleep 2
done
