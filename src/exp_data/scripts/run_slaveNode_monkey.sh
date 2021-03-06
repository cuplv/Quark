# execute this script from the folder: /src/_build/default/
# bash ../../exp_data/scripts/run_slaveNode_monkey.sh <port> <nrounds> <nbranches> <machName> <expName> 
# bash ../../exp_data/scripts/run_masterNode_monkey.sh 9042 10 3 machA test01
port=$1
nRounds=$2
nBranches=$3
machName=$4
expName=$5
numNodes=3
iters=$(( nBranches/numNodes ))

res_path='../../exp_data/'$expName'-'$machName
echo "$res_path"
mkdir $res_path

# execute slaves
echo "total slaves on node: "$iters
for i in `seq 1 $iters`
do
	branchName=$machName$i
	echo "executing slave process"
	echo $branchName
    #nohup sh ../../exp_data/scripts/exec_slave.sh $1 $2 $3 $branchName &
    sudo sh -c "nohup ./monkey.exe --port $1 --nrounds $2 --nbranches $3 --branch $branchName > monkey_$branchName.log 2>&1 &"
    sleep 1
done

