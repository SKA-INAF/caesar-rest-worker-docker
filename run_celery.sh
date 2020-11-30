#!/bin/bash

##########################
##    PARSE ARGS
##########################
RUNUSER="caesar"
NPROC=2
APP_NAME="caesar_rest"
BROKER_URL="amqp://guest:guest@127.0.0.1:5672/"
RESULT_BACKEND_URL="mongodb://127.0.0.1:27017/caesardb"
LOG_FILE="/opt/caesar-rest/logs/%n%I.log"
PID_FILE="/opt/caesar-rest/run/%n.pid"

echo "ARGS: $@"

for item in "$@"
do
	case $item in
		--runuser=*)
    	RUNUSER=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--nproc=*)
    	NPROC=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--app=*)
    	APP_NAME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--broker=*)
    	BROKER_URL=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--result-backend=*)
    	RESULT_BACKEND_URL=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		

	*)
    # Unknown option
    echo "ERROR: Unknown option ($item)...exit!"
    exit 1
    ;;
	esac
done


###############################
##    RUN CELERY
###############################
#CMD="/usr/local/bin/celery --broker=$BROKER_URL --result-backend=$RESULT_BACKEND_URL --app=$APP_NAME worker --loglevel=INFO --concurrency=$NPROC"
#CMD="/usr/local/bin/celery multi start caesar_worker --uid=$RUNUSER --gid=$RUNUSER --app=$APP_NAME --broker=$BROKER_URL --result-backend=$RESULT_BACKEND_URL --loglevel=INFO --concurrency=$NPROC --logfile=$LOG_FILE --pidfile=$PID_FILE"
CMD="runuser -l $RUNUSER -g $RUNUSER -c'""/usr/local/bin/celery --broker=$BROKER_URL --result-backend=$RESULT_BACKEND_URL --app=$APP_NAME worker --loglevel=INFO --concurrency=$NPROC""'"


echo "INFO: Running celery (cmd=$CMD) ..."


eval "$CMD"


