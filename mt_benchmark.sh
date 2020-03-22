#!/bin/bash -x

#
# Compare the performance of Redis and ScyllaDB using memtier as
# a client load generator. The comparisons are made using Redis
# protocol (i.e., using ScyllaDB's redis port)
#

# Platform specific changes. User to change these
server=172.31.5.186
outdir=/tmp/memtier_logs
num_ops=1000000
mt=./memtier_benchmark

threads=20
clients=50
val_sz=1000

# Do not change these

# Workload write:read ratios
run1_100p='1:0'
run2_100g='0:1'
run3_20p='2:8'

common_args="--key-prefix=key_ --key-maximum=2000000000 --key-pattern=P:P --distinct-client-seed"

usage() {
cat << EOF
	./mt_benchmark [redis|scylla]
		redis   : Use redis as server
		scylla  : Use scylladb as server
EOF
	exit -1
}

mt_run() {
	workload=$1
	ratio=$2
	port=$3
	$mt $common_args --threads=$threads --clients=$clients \
		--server=$server --port=$port --ratio=$ratio \
		--requests=$num_ops --data-size=$val_sz \
		--out-file=${outdir}/${protocol}/${workload}.txt
}

mt_run_mix() {
	workload=$1
	ratio=$2
	port=$3
	$mt $common_args --threads=$threads --clients=$clients \
		--server=$server --port=$port --ratio=$ratio \
		--test-time=900 --data-size=$val_sz \
		--out-file=${outdir}/${protocol}/${workload}.txt
}

main()
{
	mkdir -p ${outdir}/${protocol}
	log=${outdir}/${protocol}/run.out

	echo "" > ${log}

	echo "[`date`] Running 100% put ... " >> $log
	mt_run "load" $run1_100p $port
	echo "[`date`] Running 100% get ... " >> $log
	mt_run "get" $run2_100g $port
	echo "[`date`] Running 70:30 get:set ... " >> $log
	mt_run_mix "mixed" $run3_20p $port
}

if [ $# -ne 1 ]; then
	usage
fi

if [ "$1" = "redis" ]; then
	protocol="redis"
	port=6379
else
	protocol="scylladb"
	port=7001
fi

main
