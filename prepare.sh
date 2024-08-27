set -e
source ./env.sh

docker image inspect geesefs-reproduce > /dev/null \
  || docker build -t geesefs-reproduce .

# Download and build software
mkdir -p "$GIT_ROOT/prepare"
cd "$GIT_ROOT/prepare"

if ! [ -x "geesefs-linux-${DEB_ARCH}" ]; then
  curl -C - -LO "https://github.com/yandex-cloud/geesefs/releases/download/v0.41.1/geesefs-linux-${DEB_ARCH}"
  chmod +x "geesefs-linux-${DEB_ARCH}"
fi

if [ ! -f "reprepro_5.4.1-1_${DEB_ARCH}.deb" ]; then
  git clone https://salsa.debian.org/debian/reprepro.git
  git -C reprepro checkout reprepro-debian-5.4.1-1

  docker run --rm -i -v "$GIT_ROOT/prepare":/prepare -w /prepare geesefs-reproduce << EOF
    cd reprepro
    dpkg-buildpackage -b --no-sign
    git config --global --add safe.directory /prepare/reprepro
    git clean -fdx
    git checkout .
EOF
fi

# Download packages
mkdir -p "$GIT_ROOT/data"
cd "$GIT_ROOT/data"

for f in geesefs-linux-${DEB_ARCH} reprepro_5.4.1-1_${DEB_ARCH}.deb; do
  [ -f "$f" ] || cp "$GIT_ROOT/prepare/$f" .
done

curl_args=()
for package in clickhouse-common-static{,-dbg} clickhouse-client clickhouse-server clickhouse-keeper{,-dbg} clickhouse-{library,odbc}-bridge; do
  for arch in amd64 arm64; do
    for version in 24.6.2.17 24.6.3.38 24.8.2.3 24.3.9.5 ; do
      package_name="${package}_${version}_${arch}.deb"
      [ -f "$package_name" ] || curl_args+=(-LO "https://packages.clickhouse.com/deb/pool/main/c/clickhouse/${package_name}")
    done
  done
done
[ ${#curl_args[@]} -eq 0 ] || curl -sC - "${curl_args[@]}"

GEN_KEY_ID=
if [ ! -d "$GIT_ROOT/data/gnupg" ]; then
  GEN_KEY_ID=1
  mkdir -p "$GIT_ROOT/data/gnupg"
  chmod 0700 "$GIT_ROOT/data/gnupg"
  (
    GNUPGHOME="$GIT_ROOT/data/gnupg" \
    gpg --quick-gen-key --batch --passphrase '' dummy@test-r2
  )
fi

if [ ! -f "$GIT_ROOT/data/key-id" ] || [ "$GEN_KEY_ID" ]; then
  (
    GNUPGHOME="$GIT_ROOT/data/gnupg" \
    gpg --with-colons --with-fingerprint --list-secret-key dummy@test-r2 \
      | awk -F: '$1 == "sec" {id=$5}; $0 ~ id && $1=="fpr" {print $10}' > "$GIT_ROOT/data/key-id"
  )
fi

cat > "$GIT_ROOT/data/distributions" << EOF
Origin: ClickHouse
Label: ClickHouse
Codename: stable
Architectures: amd64 arm64
Components: main
SignWith: $(< "$GIT_ROOT/data/key-id")
Limit: -1
EOF
