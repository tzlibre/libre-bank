#!/bin/bash

CONTRACT_ALIAS="tzlibre-bond-bank"
OWNER_ALIAS="owner"
USER1_ALIAS="user1"
USER2_ALIAS="user2"
ONEP6=1000000
ONEP3=1000

##################################################
# deploy contract
##################################################
OWNER="<owner-address>"
MIN_FUNDING=$[100*$ONEP6] # 100 XTZ
WITHDRAW_FEE=$ONEP3       # 0.1% 
COLL_COEFF=$[750*$ONEP3]  # 75%
tezos-client originate contract $CONTRACT_ALIAS for $OWNER_ALIAS \
transferring 0 from $OWNER_ALIAS running bond-bank.liq.tz \
--init "Pair \"$OWNER\" (Pair $MIN_FUNDING (Pair $WITHDRAW_FEE (Pair $COLL_COEFF (Pair 0 (Pair 0 {})))))" \
--delegate $OWNER --delegatable
##################################################


##################################################
# use cases
##################################################

# User deposit (USER1)
tezos-client transfer 100 from $USER1_ALIAS to $CONTRACT_ALIAS

# User deposit (USER2)
tezos-client transfer 200 from $USER2_ALIAS to $CONTRACT_ALIAS

# Owner borrow
tezos-client transfer 0 from $OWNER_ALIAS to $CONTRACT_ALIAS

# User withdraw (USER1)
tezos-client transfer 0 from $USER1_ALIAS to $CONTRACT_ALIAS

# User withdraw (USER2) -> fail
# tezos-client transfer 0 from $USER2_ALIAS to $CONTRACT_ALIAS

# Owner payback
tezos-client transfer 75 from $OWNER_ALIAS to $CONTRACT_ALIAS

# User withdraw (USER2)
tezos-client transfer 0 from $USER2_ALIAS to $CONTRACT_ALIAS
