# SENEC collector

Collect data SENEC photovoltaics and push it to InfluxDB 2

Tested with SENEC.Home V3 hybrid duo

## Build image for Raspberry Pi

```bash
docker buildx build --platform linux/arm/v7 -t senec-collector .
```

## Run container

Prepare an `.env` file. Then:

```bash
docker run --env-file .env senec-collector ruby collect.rb
```

Copyright (c) 2020-2021 Georg Ledermann, released under the MIT License
