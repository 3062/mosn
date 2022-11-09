#!/bin/bash

mosn=$1
nohup $mosn start -c test/mosn_performance_test.json &
nohup /root/java_server/bin/start.sh
sleep 5s
nohup sofaload -D 10 --qps=2000 -c 200 -t 16 -p sofarpc sofarpc://127.0.0.1:12200