# SENEC collector

Collect data from SENEC photovoltaics and push it to InfluxDB 2

Tested with SENEC.Home V3 hybrid duo
and Raspberry Pi 4 Model B on Raspbian GNU/Linux 10 (buster)

## Getting started

1. Make sure that you have a SENEC device in your house that can be reached via the LAN and an in-house Linux box

2. Make sure your InfluxDB2 database is ready (not subject of this README)

3. Prepare an `.env` file (see `.env.example`)

4. Run the Docker container on your Linux box:

   ```bash
   docker run -d \
              --env-file .env \
              --restart on-failure \
              ghcr.io/solectrus/senec-collector:latest \
              src/main.rb
   ```

The Docker image support multiple platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

## Build Docker image by yourself

Example for Raspberry Pi:

```bash
docker buildx build --platform linux/arm/v7 -t senec-collector .
```

## License

Copyright (c) 2020,2022 Georg Ledermann, released under the MIT License
