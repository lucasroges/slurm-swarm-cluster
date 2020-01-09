# Slurm Swarm Cluster - Base

Imagem contendo as dependências e configurações para possibilitar a execução do SLURM em um ambiente de *containers*.

## Obtenção

Para construir essa imagem, que é a base para nó controlador e nó de processamento, utilizar o comando abaixo.

```
docker build -t slurm-swarm-base:19.05.4 .
```