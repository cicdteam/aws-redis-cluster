#!/bin/bash

BHOST=${BASTION_HOST}
BKEY=${BASTION_KEY}
SHOST=${REDISNODE}

die () {
    echo; echo "ERROR: $1"; echo; exit 1
}

[ -z "$BHOST" ] && die "No bastion host specified"
[ -z "$BKEY" ]  && die "No no private ssh key specified"
[ -z "$SHOST" ] && die "No Main Redis cluster node specified"

bssh () {
ssh -i $BKEY -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $BKEY  -o StrictHostKeyChecking=no ubuntu@$BHOST -W %h:%p" ubuntu@$SHOST $1
}

echo

echo -e "\033[1;37mCheck connection to Redis node\033[0m"
bssh "echo Checking" || die "Sorry, no connection to Redis node"
echo

echo -e "\033[1;37mCheck Redis cluster\033[0m"
bssh "redis-trib.rb check $SHOST:6379"
echo

echo -e "\033[1;37mGet Redis cluster Info\033[0m"
bssh "redis-trib.rb info $SHOST:6379"
echo

echo -e "\033[1;37mMemory usage by Redis nodes\033[0m"
bssh '/bin/redis-mem.sh'

echo -e "\033[1;37mDone\033[0m"
