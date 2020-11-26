#!/bin/bash

# This script get metadata and manifest from https://github.com/open-cluster-management/registration-operator
# And then generate the dockerfile for bundle.
# When this script run successfully, metadata manifests and Dockerfile will be generated.

# Args:
#
# $1 = Current release branch eg:release-2.2
#

# Should change this value before each release.
default_release_branch="release-2.2"


current_release_branch="$1"

if [[ ${current_release_branch:0:7} != "release" ]];then
current_release_branch=${default_release_branch}
fi

echo "current branch is ${current_release_branch}"

channels_label=${current_release_branch}

pwd=`pwd`
tmp_dir="${pwd}/tmp"
registration_operator_url="https://github.com/open-cluster-management/registration-operator.git"

#clean previous data if it's exist
rm -rf $tmp_dir
mkdir -p $tmp_dir

cd $tmp_dir

echo "clone registration-operator ${current_release_branch}"
git clone -b "${current_release_branch}" "${registration_operator_url}"

if [[ $? -ne 0 ]]; then
  >&2 echo "Error: Could not clone registration-operator ${current_release_branch} repo."
  >&2 echo "Aborting."
  exit 2
fi

mv $tmp_dir/registration-operator/deploy/klusterlet/olm-catalog/klusterlet/manifests ${pwd}
mv $tmp_dir/registration-operator/deploy/klusterlet/olm-catalog/klusterlet/metadata ${pwd}

# Turn metadata/annotations.yaml into LABEL statemetns for Dockerfile
# - Drop "annotations:" line
# - Convert all others to LABEL statement
tmp_label_lines="$tmp_dir/label-lines"
tail -n +2 "${pwd}/metadata/annotations.yaml" | \
    sed "s/: /=/" | sed "s/^ /LABEL/" | sed "s/stable/${channels_label}/g"> "$tmp_label_lines"

cat "$pwd/Dockerfile.template" | \
    sed "/!!ANNOTATION_LABELS!!/r $tmp_label_lines" | \
    sed "/!!ANNOTATION_LABELS!!/d" > "${pwd}/Dockerfile"
rm -rf "$tmp_dir"

echo "Finished to generate Dockerfile"

