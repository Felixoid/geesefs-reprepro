GIT_ROOT=$(git rev-parse --show-cdup)
GIT_ROOT=$(readlink -f "${GIT_ROOT:-.}")
ARCH=$(uname -m)
case "$ARCH" in
  x86_64 )
    DEB_ARCH=amd64 ;;
  aarch64 )
    # shellcheck disable=SC2034
    DEB_ARCH=arm64 ;;
  * )
    echo Unsopported arch
    exit 1 ;;
esac
