# Slurm Swarm Cluster - Worker

Imagem apenas executa `sshd` para aguardar a conexão do controlador, que realiza a configuração necessária (Munge e SLURM).

## Obtenção

Para construir essa imagem, utilizar o comando abaixo.

```
docker build -t slurm-swarm-worker:19.05.4 .
```