#!/bin/bash

BHOST=${BASTION_HOST:-bastion.snaprapid.com}
BKEY=${BASTION_KEY:-~/.ssh/snaprapid_infra.pem}
MNODE=${MAINNODE}
DNODE=${REDISNODE}

die () {
    echo; echo "ERROR: $1"; echo; exit 1
}

[ -z "$BHOST" ] && die "No bastion host specified"
[ -z "$BKEY" ]  && die "No no private ssh key specified"
[ -z "$MNODE" ] && die "No Main Redis cluster node specified"
[ -z "$DNODE" ] && die "No Redis node specified"

bssh () {
ssh -i $BKEY -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $BKEY  -o StrictHostKeyChecking=no ubuntu@$BHOST -W %h:%p" ubuntu@$MNODE $1
}

echo

echo -e "\033[1;37mCheck connection to Main Redis node\033[0m"
bssh "echo Checking" || die "Sorry, no connection to Main Redis node"
echo

nodeid=`bssh "redis-cli -h $DNODE cluster nodes | grep myself | grep -o '^[^ ]\+'"`
mainid=`bssh "redis-cli cluster nodes | grep myself | grep -o '^[^ ]\+'"`
slots=`bssh "redis-trib.rb info $MNODE:6379" | grep $DNODE | sed 's/.*\( [0-9]* slots\).*/\1/' | sed 's/.*\( [0-9]* \).*/\1/' | sed 's/ //'`

#echo -e "\033[1;37mFlush all keys on deleting node\033[0m"
#bssh "redis-cli -h $DNODE flushall"
#echo
#sleep 5

echo -e "\033[1;37mReshard slots from node\033[0m"
bssh "redis-trib.rb reshard --from $nodeid --to $mainid --slots $slots --pipeline 100 --yes $MNODE:6379 >/dev/null"
echo
sleep 5

echo -e "\033[1;37mRemove node from cluster\033[0m"
bssh "redis-trib.rb del-node $MNODE:6379 $nodeid"
echo
sleep 5

echo -e "\033[1;37mRebalance cluster\033[0m"
bssh "redis-trib.rb rebalance --use-empty-masters --pipeline 100 $MNODE:6379 >/dev/null"
echo
sleep 5

echo -e "\033[1;37mCheck cluster\033[0m"
bssh "redis-trib.rb check $MNODE:6379"
echo
