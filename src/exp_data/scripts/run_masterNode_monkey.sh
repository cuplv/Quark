# execute this script from the folder: /src/_build/default/
# run_master.sh <port> <nrounds> <nbranches> <machName> <expName> 
# bash ../../exp_data/scripts/run_masterNode_monkey.sh 9042 1000 6 machA test01_6br_1000r
port=$1
nRounds=$2
nBranches=$3
machName=$4
expName=$5
numNodes=3
iters=$(( nBranches/numNodes ))
res_path='../../exp_data/'$expName_$machName

echo "$res_path"
mkdir $res_path

# clear previous experiment results
rm ./*.csv
rm ./*.log

# execute the master-process
echo "master: executing monkey"
sudo sh -c "nohup ./monkey.exe -master --port $1 --nrounds $2 --nbranches $3  > master.log 2>&1 &"

sleep 10

# execute slaves
echo "total slaves on node: "$iters
for i in `seq 2 $iters`
do
	branchName=$machName$i
	echo "executing slave process"
	echo $branchName
    #nohup sh ../../exp_data/scripts/exec_slave.sh $1 $2 $3 $branchName &
    sudo sh -c "nohup ./monkey.exe --port $1 --nrounds $2 --nbranches $3 --branch $branchName > monkey_$branchName.log  2>&1 &"
    sleep 1
done

