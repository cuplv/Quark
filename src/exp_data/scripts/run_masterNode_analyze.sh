# execute this script from the folder: /src/_build/default/
# run_master.sh <port> <nrounds> <nbranches> <machName> <expName> 
port=$1
nRounds=$2
nBranches=$3
machName=$4
expName=$5

res_path='../../exp_data/'$expName'_'$machName 



# execute the master-process
echo "master: executing analyze"
./analyze.exe --port $1 --nbranches $3 --branch master

# execute slaves
for i in `seq 2 $nBranches`
do
	branchName=$machName$i
	echo "executing slave process"
	echo $branchName
    #nohup sh ../../exp_data/scripts/exec_slave.sh $1 $2 $3 $branchName &
    ./analyze.exe --port $1 --nbranches $3 --branch $branchName 
done

mv ./*.csv $res_path/ 
mv ./*.log $res_path/

