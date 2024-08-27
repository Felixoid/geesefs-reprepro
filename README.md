# A repo to reproduce https://github.com/yandex-cloud/geesefs/issues/98

## How to run

`bash -x run.sh`

It requires just gnupg, docker and curl to run.

As well, you need `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to connect to `R2_ENDPOINT` `R2_BUCKET`. Everything can be get from the Cloudflare dashboard. `run.sh` script will ask about values only once, and save them into `secrets.sh`.
