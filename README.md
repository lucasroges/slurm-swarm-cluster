# Slurm Swarm Cluster

## Instruções para obtenção das imagens

### Local

A obtenção das imagens pode ser realizada localmente, através dos `Dockerfile` disponibilizados e do comando `docker build`.

Existem 3 imagens que devem estar disponíveis antes de executar a aplicação no Swarm: [base](base), [controller](controller) (no nó controlador), [worker](worker) (nos nós de execução de aplicações).

Em cada umas das páginas linkadas acima, encontram-se as instruções específicas para utilização do `docker build`.

### Docker Hub

As imagens estão disponíveis no Docker Hub e podem ser obtidas através dos comandos abaixo.

```
docker pull lraraujo/slurm-swarm-base:19.05.4
docker pull lraraujo/slurm-swarm-controller:19.05.4
docker pull lraraujo/slurm-swarm-worker:19.05.4
```

## Instruções para execução

Iniciar o Swarm, normalmente no nó controlador.

```
docker swarm init
```

Utilizar a saída do comando acima e executá-la nos outros nós, para que entrem no Swarm e possa ocorrer a execução de maneira distribuída.

Para verificar a situação dos nós no Swarm, pode-se executar o comando `docker node ls`. Após todos estarem ativos, podemos iniciar a pilha de serviços, utilizando o nó ... do Swarm. Para tal, utilizar o arquivo [docker-compose.yml](docker-compose.yml) (o número de replicas de *workers* deve ser editado para corresponder a quantidade de nós).

```
docker stack deploy -c docker-compose.yml slurm
```

Para verificar a condição dos serviços, utilizar `docker service ls`.

Para entrar em algum dos serviços, utilizar `docker ps` para obter o nome dos *containers* e utilizá-lo no comando abaixo.

```
docker exec -ti <nome> /bin/bash
```

## Comandos SLURM

Alguns comandos podem ser executados para verificar a estrutura do *cluster* e outros aspectos do SLURM:

* `sinfo`
* `scontrol show node <hostname>`
* `squeue`
* `sbatch` (submeter jobs)

### Exemplo

Um pequeno exemplo ([slurm_test.job](base/slurm_test.job)) foi colocado na imagem para realizar um simples teste nos nós de processamento.

Para execução do mesmo, utilizar o comando `sbatch -N <número-de-nós> slurm_test.job`.

### Exemplo MPI

Outro exemplo a ser executado, dessa vez utilizando MPI, está disponível no repositório em [mpi_hello.c](base/mpi_hello.c).

Para instalação do MPI no CentOS, executar o comando abaixo dentro dos *containers*.

```
yum install openmpi-devel
```

O compilador `mpicc` e outros estarão disponíveis em `/usr/lib64/openmpi/bin`. A aplicação é compilada executando-se `/usr/lib64/openmpi/bin/mpicc mpi_hello.c -o mpi_hello`. Sua execução se dá através de ` srun -N <número-de-nós> --mpi=openmpi mpi_hello`.

Lembrando que o MPI deve ser instalado em todos os *containers worker* (nós de processamento), assim como o arquivo executável deve estar disponível em todos esses.
