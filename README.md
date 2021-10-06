# SENEC collector

Collect data from SENEC photovoltaics and push it to InfluxDB 2

Tested with SENEC.Home V3 hybrid duo
and Raspberry Pi 4 Model B on Raspbian GNU/Linux 10 (buster)

## Build Docker image

```bash
docker buildx build -t senec-collector .
```

To target a specific platform, you can provide the `--platform` flag. E.g. for a Raspberry Pi with 32bit processor, use:

```bash
docker buildx build --platform linux/arm/v7 -t senec-collector .
```

## Run container

Prepare an `.env` file (see `.env.example`). Then:

```bash
docker run --env-file .env senec-collector src/main.rb
```

Copyright (c) 2020-2021 Georg Ledermann, released under the MIT License
