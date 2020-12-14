#!/bin/bash

# This script get metadata and manifest from https://github.com/open-cluster-management/registration-operator
# And then generate the dockerfile for bundle.
# When this script run successfully, metadata manifests and Dockerfile will be generated.

# Args:
#
# -r Current release branch, the default value is "master" which code is same as the current release.
# -p Previous klusterlet operator version, default:""
# -c Use a specific commit in git clone, default: ""
#

# Currentlly, we master branch code is same as the current release
default_release_branch="master"

opt_flags="r:c:p:"

push_the_image=0

while getopts "$opt_flags" OPTION; do
   case "$OPTION" in
      r) current_release_branch="$OPTARG"
         ;;
      p) previous_operator_version="$OPTARG"
         ;;
      c) use_commit="$OPTARG"
         ;;
      ?) exit 1
         ;;
   esac
done
shift "$(($OPTIND -1))"

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))

python3 -m pip install pyyaml

if [ "${current_release_branch}" = "" ]; then
current_release_branch=${default_release_branch}
fi

echo "current branch is ${current_release_branch}"

channels_label=${current_release_branch}

tmp_dir="${my_dir}/tmp"
registration_operator_url="https://github.com/open-cluster-management/registration-operator.git"

#clean previous data if it's exist
rm -rf $tmp_dir ${my_dir}/manifests ${my_dir}/metadata ${my_dir}/Dockerfile
mkdir -p $tmp_dir

pwd=`pwd`
cd $tmp_dir

echo "clone registration-operator ${current_release_branch}"
git clone -b "${current_release_branch}" "${registration_operator_url}"
if [[ $? -ne 0 ]]; then
  >&2 echo "Error: Could not clone registration-operator ${current_release_branch} repo."
  >&2 echo "Aborting."
  exit 2
fi

if [ "${use_commit}" != "" ]; then
  echo "Use commit ${use_commit}"
  cd registration-operator
  git checkout "${use_commit}"
  if [[ $? -ne 0 ]]; then
    >&2 echo "Error: Could not checkout to ${use_commit}."
    >&2 echo "Aborting."
    exit 2
  fi
fi

# If their is no previous version, delete "replaces:" field in csv
if [ "$previous_operator_version" = "" ]; then
  echo "Previous version is null ${previous_operator_version}"
  sed -i '/^ *replaces:.*/d' $tmp_dir/registration-operator/deploy/klusterlet/olm-catalog/klusterlet/manifests/klusterlet.clusterserviceversion.yaml
fi

mv $tmp_dir/registration-operator/deploy/klusterlet/olm-catalog/klusterlet/manifests ${my_dir}
mv $tmp_dir/registration-operator/deploy/klusterlet/olm-catalog/klusterlet/metadata ${my_dir}

cd ${my_dir}
csv_file_path=${my_dir}/manifests/klusterlet.clusterserviceversion.yaml
echo $csv_file_path
csv_version=`python -c 'import parse_csv; print(parse_csv.get_version('\"${csv_file_path}\"'))'`

# Rename csv to versioned csv
mv ${my_dir}/manifests/klusterlet.clusterserviceversion.yaml ${my_dir}/manifests/klusterlet.${csv_version}.clusterserviceversion.yaml 

# Turn metadata/annotations.yaml into LABEL statemetns for Dockerfile
# - Drop "annotations:" line
# - Convert all others to LABEL statement
#tmp_label_lines="$tmp_dir/label-lines"
#tail -n +2 "${my_dir}/metadata/annotations.yaml" | \
#    sed "s/: /=/" | sed "s/^ /LABEL/" | sed "s/stable/${channels_label}/g"> "$tmp_label_lines"

#cat "$my_dir/Dockerfile.template" | \
#    sed "/!!ANNOTATION_LABELS!!/r $tmp_label_lines" | \
#    sed "/!!ANNOTATION_LABELS!!/d" > "${my_dir}/Dockerfile"
rm -rf "$tmp_dir"

cd $pwd

echo "Finished to generate Dockerfile"
