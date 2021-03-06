#!/usr/bin/env bash
# Copyright 2018 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o nounset
set -o errexit
set -o pipefail

cd $(git rev-parse --show-toplevel)

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") <github-login> </path/to/github/token> [git-name] [git-email] [--patch|--minor]" >&2
    exit 1
fi
user=$1
token=$2
shift 2
if [[ $# -ge 2 ]]; then
  echo "git config user.name=$1 user.email=$2..." >&2
  git config user.name "$1"
  git config user.email "$2"
  shift 2
fi
if ! git config user.name &>/dev/null && git config user.email &>/dev/null; then
    echo "ERROR: git config user.name, user.email unset. No defaults provided" >&2
    exit 1
fi

./hack/update-deps.sh "$@"  # --patch or --minor

git add -A
if git diff --name-only --exit-code HEAD; then
    echo "Nothing changed" >&2
    exit 0
fi

if ! bazel test //...; then
    echo "ERROR: update fails unit tests." >&2
    exit 1
fi

title="Run ./hack/update-deps.sh $@"
git commit -m "${title}"
git push -f "git@github.com:${user}/test-infra.git" HEAD:autoupdate

echo "Creating PR to merge ${user}:autoupdate into master..." >&2
bazel run //robots/pr-creator -- \
    --github-token-path="${token}" \
    --org=kubernetes --repo=test-infra --branch=master \
    --title="${title}" --head-branch="autoupdate" \
    --body="Automatic go module update. Please review" \
    --source="${user}":autoupdate \
    --confirm
