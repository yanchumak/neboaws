```shell
docker build -t my-image .
```

```shell
docker run -d -p 8090:80 my-image
```

```shell
docker tag my-image:latest <dockerhub-username>/my-image:latest
```

```shell
docker push <dockerhub-username>/my-image:latest
```