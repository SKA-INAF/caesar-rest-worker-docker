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
QUEUE="celery"
MOUNT_RCLONE_VOLUME=0
MOUNT_VOLUME_PATH="/mnt/storage"
RCLONE_REMOTE_STORAGE="neanias-nextcloud"
RCLONE_REMOTE_STORAGE_PATH="."
RCLONE_MOUNT_WAIT_TIME=10

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
		--queue=*)
    	QUEUE=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--mount-rclone-volume=*)
    	MOUNT_RCLONE_VOLUME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--mount-volume-path=*)
    	MOUNT_VOLUME_PATH=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-remote-storage=*)
    	RCLONE_REMOTE_STORAGE=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-remote-storage-path=*)
    	RCLONE_REMOTE_STORAGE_PATH=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-mount-wait=*)
    	RCLONE_MOUNT_WAIT_TIME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;

	*)
    # Unknown option
    echo "ERROR: Unknown option ($item)...exit!"
    exit 1
    ;;
	esac
done

###############################
##    SOURCE ENVIRONMENT VARS
###############################
echo "Sourcing env vars ..."
source /etc/profile.d/setupSoft.sh
echo "PATH=$PATH"
echo "PYTHONPATH=$PYTHONPATH"


###############################
##    MOUNT VOLUMES
###############################
if [ "$MOUNT_RCLONE_VOLUME" = "1" ] ; then

	# - Create mount directory if not existing
	echo "INFO: Creating mount directory $MOUNT_VOLUME_PATH ..."
	mkdir -p $MOUNT_VOLUME_PATH	

	# - Get device ID of standard dir, for example $HOME
	#   To be compared with mount point to check if mount is ready
	DEVICE_ID=`stat "$HOME" -c %d`
	echo "INFO: Standard device id @ $HOME: $DEVICE_ID"

	# - Mount rclone volume in background
	uid=`id -u $RUNUSER`

	echo "INFO: Mounting rclone volume at path $MOUNT_VOLUME_PATH for uid/gid=$uid ..."
	MOUNT_CMD="/usr/bin/rclone mount --daemon --uid=$uid --gid=$uid --umask 000 --allow-other --file-perms 0777 --dir-cache-time 0m5s --vfs-cache-mode full $RCLONE_REMOTE_STORAGE:$RCLONE_REMOTE_STORAGE_PATH $MOUNT_VOLUME_PATH -vvv"
	#MOUNT_CMD="/usr/bin/rclone mount --daemon --umask 000 --dir-cache-time 0m5s --vfs-cache-mode full $RCLONE_REMOTE_STORAGE:$RCLONE_REMOTE_STORAGE_PATH $MOUNT_VOLUME_PATH -vvv"
	#MOUNT_CMD="/usr/bin/rclone mount --daemon --uid=$uid --gid=$uid --umask 000 --allow-other --dir-cache-time 0m5s --vfs-cache-mode full $RCLONE_REMOTE_STORAGE:$RCLONE_REMOTE_STORAGE_PATH $MOUNT_VOLUME_PATH -vvv"
	eval $MOUNT_CMD

	# - Wait until filesystem is ready
	echo "INFO: Sleeping $RCLONE_MOUNT_WAIT_TIME seconds and then check if mount is ready..."
	sleep $RCLONE_MOUNT_WAIT_TIME
	#until findmnt --mountpoint "$MOUNT_VOLUME_PATH" --mtab >/dev/null; do :; done
	#findmnt --poll --timeout 2000

	# - Get device ID of mount point
	MOUNT_DEVICE_ID=`stat "$MOUNT_VOLUME_PATH" -c %d`
	echo "INFO: MOUNT_DEVICE_ID=$MOUNT_DEVICE_ID"
	if [ "$MOUNT_DEVICE_ID" = "$DEVICE_ID" ] ; then
 		echo "ERROR: Failed to mount rclone storage at $MOUNT_VOLUME_PATH within $RCLONE_MOUNT_WAIT_TIME seconds, exit!"
		exit 1
	fi

	# - Print mount dir content
	echo "INFO: Mounted rclone storage at $MOUNT_VOLUME_PATH with success (MOUNT_DEVICE_ID: $MOUNT_DEVICE_ID)..."
	ls -ltr $MOUNT_VOLUME_PATH

	# - Create job & data directories
	echo "INFO: Creating job & data directories ..."
	mkdir -p 	$MOUNT_VOLUME_PATH/jobs
	mkdir -p 	$MOUNT_VOLUME_PATH/data

fi

###############################
##    RUN CELERY
###############################
#CMD="/usr/local/bin/celery --broker=$BROKER_URL --result-backend=$RESULT_BACKEND_URL --app=$APP_NAME worker --loglevel=INFO --concurrency=$NPROC"
#CMD="/usr/local/bin/celery multi start caesar_worker --uid=$RUNUSER --gid=$RUNUSER --app=$APP_NAME --broker=$BROKER_URL --result-backend=$RESULT_BACKEND_URL --loglevel=INFO --concurrency=$NPROC --logfile=$LOG_FILE --pidfile=$PID_FILE"

###CMD="runuser -l $RUNUSER -g $RUNUSER -c'""/usr/local/bin/celery --broker=$BROKER_URL --result-backend=$RESULT_BACKEND_URL --app=$APP_NAME worker --loglevel=INFO --concurrency=$NPROC -Q $QUEUE""'"

CMD="runuser -l $RUNUSER -g $RUNUSER -c'""source /etc/profile.d/setupSoft.sh && echo $PYTHONPATH && /usr/local/bin/celery --broker=$BROKER_URL --result-backend=$RESULT_BACKEND_URL --app=$APP_NAME worker --loglevel=INFO --concurrency=$NPROC -Q $QUEUE""'"


echo "INFO: Running celery (cmd=$CMD) ..."


eval "$CMD"


