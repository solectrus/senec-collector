# SENEC collector

Collect data from SENEC photovoltaics and push it to InfluxDB 2

Tested with SENEC.Home V3 hybrid duo
and Raspberry Pi 4 Model B on Raspbian GNU/Linux 10 (buster)

## Build image for Raspberry Pi

```bash
docker buildx build --platform linux/arm/v7 -t senec-collector .
```

## Run container

Prepare an `.env` file (see `.env.example`). Then:

```bash
docker run --env-file .env senec-collector ruby collect.rb
```

Copyright (c) 2020-2021 Georg Ledermann, released under the MIT License
