#
FROM centos:7

#
WORKDIR /root

#
ENV SLURM_VERSION=19.05.4 \
	MUNGE_UID=981 \
	SLURM_UID=982

#
RUN yum update -y \
	&& yum install -y openssh openssh-server openssh-clients wget sudo bind-utils

# Passwordless SSH
RUN mkdir -p /var/run/sshd \
	&& ssh-keygen -A \
	&& ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' \
	&& cp .ssh/id_rsa.pub .ssh/authorized_keys \
	&& chmod 600 .ssh/authorized_keys \
	&& sed -i '/StrictHostKeyChecking/s/ask/no/' /etc/ssh/ssh_config \
	&& sed -i '/StrictHostKeyChecking/s/#   //' /etc/ssh/ssh_config

# Criação de usuários
RUN export MUNGE_UID=991 && groupadd -g $MUNGE_UID munge \
	&& useradd -m -c "MUNGE Uid N Gid Emporium" -d /var/lib/munge -u $MUNGE_UID -g munge -s /sbin/nologin munge \
	&& export SLURM_UID=992 && groupadd -g $SLURM_UID slurm \
	&& useradd -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURM_UID -g slurm -s /bin/bash slurm

# Instalação do EPEL
RUN yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y

# Instalação do MUNGE
RUN yum install munge munge-libs munge-devel -y

# Instalação de componentes para o SLURM
RUN yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel gcc g++ readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad perl-ExtUtils-MakeMaker perl-Switch -y

# Instalação do banco de dados
RUN yum install mariadb-server mariadb-devel -y

# Instalação do SLURM
RUN wget https://download.schedmd.com/slurm/slurm-$SLURM_VERSION.tar.bz2 \
	&& yum install rpm-build -y \
	&& rpmbuild -ta slurm-$SLURM_VERSION.tar.bz2 \
	&& tar -jxvf slurm-$SLURM_VERSION.tar.bz2 \
	&& cd slurm-$SLURM_VERSION \
	&& ./configure && make && make check && make install && make installcheck

# Instalação dos RPMs
RUN cd /root/rpmbuild/RPMS/x86_64 \
	&& rpm --install slurm-*

#
EXPOSE 22 6817 6818

#
COPY slurm_test.job /root

# Remoção de arquivos
RUN rm -rf rpmbuild slurm-19.05.4 slurm-19.05.4.tar.bz2

