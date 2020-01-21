#!/bin/sh

SLURM_ACCT_DB_SQL=/slurm_acct_db.sql
STORAGE_HOST=`hostname`
STORAGE_USER=slurm
STORAGE_PASS=password
STORAGE_PORT=3306
DBD_ADDR=`hostname`
DBD_HOST=`hostname`
DBD_PORT=6819

_munge_config() {
        chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
        chmod 0700 /etc/munge
        chmod 0711 /var/lib/munge
        chmod 0700 /var/log/munge
        chmod 0755 /var/run/munge
        /sbin/create-munge-key -f
        sudo -u munge /sbin/munged
        munge -n
        munge -n | unmunge
        remunge
}

_wait_for_workers() {
        iplists=`dig +short tasks.worker A`
        echo -n "waiting for workers"
        for i in $iplists; do
                while [[ $(ping -c 1 $i) -ne 0 ]]; do
                        echo -n "."
                done
        done
	sleep 5s
}

_create_slurmconf() {
        HOSTNAME=`hostname`
        IP=`hostname -i`

        cat <<EOM >/etc/slurm/slurm.conf
ControlMachine=${HOSTNAME}
ClusterName=swarm-cluster
ControlAddr=${IP}
MailProg=/bin/mail
ReturnToService=0
SlurmctldPort=6817
SlurmdPort=6818
SlurmUser=slurm
AuthType=auth/munge
StateSaveLocation=/var/spool
SwitchType=switch/none
TaskPlugin=task/none
MpiDefault=none
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
ProctrackType=proctrack/pgid
SlurmdSpoolDir=/var/spool/slurmd
SlurmctldTimeout=300
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0
SchedulerType=sched/backfill
SelectType=select/linear
FastSchedule=1
AccountingStorageType=accounting_storage/none
# JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=3
SlurmctldLogFile=/var/log/slurmctld.log
SlurmdDebug=3
SlurmdLogFile=/var/log/slurmd.log
# COMPUTE NODES
EOM

	iplists=`dig +short tasks.worker A`
	for i in $iplists; do
		ssh $i "slurmd -C | sed -e '2d'" >> /etc/slurm/slurm.conf
	done

	echo "# PARTITION" >> /etc/slurm/slurm.conf

	export PARTITION="PartitionName=swarm-partition Nodes="

	for i in $iplists; do
		export PARTITION=$PARTITION`ssh $i "hostname"`,
	done

	export PARTITION=`echo $PARTITION | sed 's/,$//g'`
	export PARTITION=$PARTITION" Default=YES MaxTime=INFINITE State=UP OverSubscribe=FORCE"

	echo $PARTITION >> /etc/slurm/slurm.conf

	cp /etc/slurm/slurm.conf /usr/local/etc/slurm.conf
}

_send_to_workers() {
	iplists=`dig +short tasks.worker A`
	for i in $iplists; do
		scp /etc/munge/munge.key root@$i:/etc/munge/munge.key
		scp /etc/slurm/slurm.conf root@$i:/etc/slurm/slurm.conf
	done
}

_slurmctld() {
	mkdir /var/spool/slurmctld
	chown slurm: /var/spool/slurmctld
	chmod 755 /var/spool/slurmctld
	touch /var/log/slurmctld.log
	chown slurm: /var/log/slurmctld.log
	touch /var/log/slurm_jobacct.log
	touch /var/log/slurm_jobcomp.log
	chown slurm: /var/log/slurm_jobacct.log
	chown slurm: /var/log/slurm_jobcomp.log
	chown -R slurm: /var/spool/
	slurmctld
}

_configure_workers() {
	iplists=`dig +short tasks.worker A`
	for i in $iplists; do
		ssh $i "chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge /etc/munge/munge.key \
			&& chmod 0700 /etc/munge \
			&& chmod 0711 /var/lib/munge \
			&& chmod 0700 /var/log/munge \
			&& chmod 0755 /var/run/munge \
			&& sudo -u munge /sbin/munged \
			&& munge -n \
			&& munge -n | unmunge \
			&& remunge \
			&& cp /etc/slurm/slurm.conf /usr/local/etc/slurm.conf \
  			&& mkdir /var/spool/slurmd \
			&& chown slurm: /var/spool/slurmd \
			&& chmod 755 /var/spool/slurmd \
			&& touch /var/log/slurmd.log \
			&& chown slurm: /var/log/slurmd.log \
			&& slurmd" 
	done
}

_slurm_acct_db() {
	{
	    echo "create database slurm_acct_db;"
	    echo "create user '${STORAGE_USER}'@'${STORAGE_HOST}';"
	    echo "set password for '${STORAGE_USER}'@'${STORAGE_HOST}' = password('${STORAGE_PASS}');"
	    echo "grant usage on *.* to '${STORAGE_USER}'@'${STORAGE_HOST}';"
	    echo "grant all privileges on slurm_acct_db.* to '${STORAGE_USER}'@'${STORAGE_HOST}';"
	    echo "flush privileges;"
	} >> $SLURM_ACCT_DB_SQL
}

_configure_db() {
	ln -s /usr/bin/resolveip /usr/libexec/resolveip
	mysql_install_db
	chown -R mysql: /var/lib/mysql/ /var/log/mariadb/ /var/run/mariadb
	cd /var/lib/mysql
	mysqld_safe --user=mysql &
	cd /
	_slurm_acct_db
	sleep 5s
	mysql -uroot < $SLURM_ACCT_DB_SQL
}

_create_slurmdbdconf() {
	HOSTNAME=`hostname`

	cat <<EOM >/etc/slurm/slurmdbd.conf
#
# Example slurmdbd.conf file.
#
# See the slurmdbd.conf man page for more information.
#
# Archive info
#ArchiveJobs=yes
#ArchiveDir="/tmp"
#ArchiveSteps=yes
#ArchiveScript=
#JobPurge=12
#StepPurge=1
#
# Authentication info
AuthType=auth/munge
#AuthInfo=/var/run/munge/munge.socket.2
#
# slurmDBD info
DbdAddr=`hostname`
DbdHost=`hostname`
DbdPort=6819
SlurmUser=slurm
#MessageTimeout=300
DebugLevel=verbose
#DefaultQOS=normal,standby
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/var/run/slurmdbd.pid
#PluginDir=/usr/lib/slurm
#PrivateData=accounts,users,usage,jobs
#TrackWCKey=yes
#
# Database info
StorageType=accounting_storage/mysql
StorageHost=`hostname`
StoragePort=3306
StoragePass=password
StorageUser=slurm
StorageLoc=slurm_acct_db
EOM

	cp /etc/slurm/slurmdbd.conf /usr/local/etc/slurmdbd.conf
}

_slurmdbd() {
	mkdir -p /var/spool/slurm/d \
    	/var/log/slurm
	chown slurm: /var/spool/slurm/d \
    	/var/log/slurm
    /usr/sbin/slurmdbd
}

# main
/usr/sbin/sshd
_munge_config
_wait_for_workers
_create_slurmconf
_send_to_workers
_slurmctld
_configure_workers

#db
_configure_db
_create_slurmdbdconf
_slurmdbd

tail -f /dev/null
