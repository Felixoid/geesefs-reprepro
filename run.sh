set -e
source ./env.sh
[ -f ./secrets.sh ] && source ./secrets.sh

[ -f "data/distributions" ] || bash -x ./prepare.sh

read_input() {
  read -rp "Enter value for $1: " input
  echo "export $1='$input'" >> secrets.sh
  echo "$input"
}

AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-$(read_input AWS_ACCESS_KEY_ID)}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-$(read_input AWS_SECRET_ACCESS_KEY)}
R2_ENDPOINT=${R2_ENDPOINT:-$(read_input R2_ENDPOINT)}
R2_BUCKET=${R2_BUCKET:-$(read_input R2_BUCKET)}

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY R2_ENDPOINT R2_BUCKET

mkdir -p data/r2-mount

if grep -q 'server-side' data/geesefs.log; then
  echo "Is reproduced during the last run"
  exit 0
fi

rm -f data/geesefs.log

docker run -i -e PACKAGE_VERSIONS="$PACKAGE_VERSIONS" -e GNUPGHOME=/data/gnupg \
  -e AWS_SECRET_ACCESS_KEY -e AWS_ACCESS_KEY_ID -e R2_ENDPOINT -e R2_BUCKET \
  -v ./data:/data --privileged --cap-add=SYS_ADMIN --device /dev/fuse \
  geesefs-reproduce:latest bash -x << 'EOF'
DEB_HOST_ARCH=$(dpkg-architecture -q DEB_HOST_ARCH)
apt install /data/reprepro_5.4.1-1_${DEB_HOST_ARCH}.deb
"./geesefs-linux-${DEB_HOST_ARCH}" "$R2_BUCKET" /data/r2-mount -o "rw,--cheap,--fsync-on-close,--file-mode=0666,--dir-mode=0777,--endpoint=$R2_ENDPOINT,--memory-limit=2050,--gc-interval=100,--max-flushers=5,--max-parallel-parts=3,--max-parallel-copy=2,dev,suid,--debug_s3,--log-file=/data/geesefs.log,-f" &
REPRO_DIR=/data/r2-mount/reproduce
for i in {1..20}; do
  findmnt /data/r2-mount && break || sleep 1
  [ $i -eq 20 ] && exit 1
done
rm -rf "${REPRO_DIR}"
mkdir -p "${REPRO_DIR}/configs/deb/conf"
cp /data/distributions "${REPRO_DIR}/configs/deb/conf/distributions"
reprepro=(reprepro --basedir "${REPRO_DIR}/configs/deb" --verbose --export=force --outdir "${REPRO_DIR}/deb")
for version in $PACKAGE_VERSIONS; do
  "${reprepro[@]}" includedeb stable /data/*"$version"*.deb
  "${reprepro[@]}" export
  packages=()
  for package in /data/*"$version"*.deb; do
    package=$(basename "$package")
    version=${package#*_}; version=${version%_*}
    package=${package%%_*}
    packages+=("$package=$version")
  done
  "${reprepro[@]}" copy lts stable "${packages[@]}"
  "${reprepro[@]}" export
done
umount /data/r2-mount
wait
EOF
