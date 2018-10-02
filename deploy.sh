#!/bin/bash

CONTRACT_ALIAS="libre-bank-v1.0"
OWNER_ALIAS="libre-bank-owner"
BAKER_ALIAS="baker01"
ONEP6=1000000
ONEP3=1000

##################################################
# deploy contract
##################################################
OWNER="tz1T4H8uQerqskAVxCx6CHXsADvKqr88kyh2"
MAX_DEPOSITORS=100
MIN_FUNDING=$[1000*$ONEP6] # 1000 XTZ
WITHDRAW_FEE=$ONEP3        # 0.1% 
COLL_COEFF=$[500*$ONEP3]   # 50%

tezos-client originate contract $CONTRACT_ALIAS for $OWNER_ALIAS \
transferring 0 from $OWNER_ALIAS running libre-bank.liq.tz \
--init "Pair \"$OWNER\" (Pair $MAX_DEPOSITORS (Pair $MIN_FUNDING (Pair $WITHDRAW_FEE (Pair $COLL_COEFF (Pair 0 (Pair 0 (Pair {} 0)))))))" \
--delegate $BAKER_ALIAS --delegatable 
##################################################
