# SENEC collector

Collect SENEC battery data and push it to Influxdata


# Build image

```bash
docker buildx build --platform linux/arm/v7 -t senec-collector .
```

# Run container

Prepare an `.env` file. Then:

```bash
docker run --env-file .env senec-collector ruby collect.rb
```
