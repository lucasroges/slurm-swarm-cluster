# Slurm Swarm Cluster - Controller

Imagem contendo um *script* de execução que configura arquivos e dirétórios do Munge e do SLURM, no nó controlador e nos nós de processamento, para possibilitar o funcionamento do SLURM em todos esses nós.

## Obtenção

Para construir essa imagem, utilizar o comando abaixo.

```
docker build -t slurm-swarm-controller:19.05.4 .
```