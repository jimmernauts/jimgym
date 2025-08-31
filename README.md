

## Deployment

### Local docker

to build and run the docker image locally:
```
docker build -t jimgym:latest .
docker run --rm --name jimgym -p 8000:8000 --env-file .env jimgym:latest
```
