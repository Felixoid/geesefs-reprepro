# shellcheck disable=SC2034
GIT_ROOT=$(git rev-parse --show-cdup)
GIT_ROOT=$(readlink -f "${GIT_ROOT:-.}")
ARCH=$(uname -m)
PACKAGE_VERSIONS="24.6.2.17 24.6.3.38 24.8.2.3"
case "$ARCH" in
  x86_64 )
    DEB_ARCH=amd64 ;;
  aarch64 )
    DEB_ARCH=arm64 ;;
  * )
    echo Unsopported arch
    exit 1 ;;
esac
