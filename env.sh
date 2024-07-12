GIT_ROOT=$(git rev-parse --show-cdup)
GIT_ROOT=$(readlink -f "${GIT_ROOT:-.}")
