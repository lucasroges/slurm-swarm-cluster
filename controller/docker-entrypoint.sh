#!/bin/sh

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

# main
/usr/sbin/sshd
_munge_config
_wait_for_workers
_create_slurmconf
_send_to_workers
_slurmctld
_configure_workers

tail -f /dev/null
