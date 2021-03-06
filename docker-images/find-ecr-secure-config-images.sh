#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

doc=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document)
export AWS_DEFAULT_REGION=$(printf "${doc}" | jq -r .region)

instance_description=$(
  aws ec2 describe-instances \
    --instance-ids $(printf "${doc}" | jq -r .instanceId)
)

instance_kubernetescluster_tag=$(
  printf "${instance_description}" \
  | jq -r '.Reservations[].Instances[].Tags[] | select(.Key=="KubernetesCluster") .Value'
)

registry=$(printf "%s.dkr.ecr.%s.amazonaws.com" \
  $(printf "${doc}" | jq -r .accountId) \
  $(printf "${doc}" | jq -r .region) \
)

print_image_variable() {
  local ecr_tag="${registry}/${instance_kubernetescluster_tag}/${1}/secure-config:${2}"
  local upcase_name=${2^^};
  echo KUBERNETES_ANYWHERE_${upcase_name/-/_}_SECURE_CONFIG_IMAGE=\"${ecr_tag}\"
}

for i in apiserver controller-manager scheduler
do print_image_variable master $i
done

for i in kubelet proxy tools
do print_image_variable node $i
done
