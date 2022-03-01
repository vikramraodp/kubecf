#!/usr/bin/env bash

kubecf="$(dirname $(dirname $(realpath $0)) )"
src="${kubecf}/src"

if [[ ! "$(git submodule status -- ${src}/cf-deployment)" =~ ^[[:space:]] ]]; then
    die "git submodule for cf-deployment is uninitialized or not up-to-date"
fi

function view_release() {
  for rel in $(yq e -j '.releases' ${src}/cf-deployment/cf-deployment.yml | jq -cr '.[]'); do
      release_name=$(echo $rel | jq -r '.name' -)
      release_url=$(echo $rel | jq -r '.url' -)
      release_version=$(echo $rel | jq -r '.version' -)
      release_sha1=$(echo $rel | jq -r '.sha1' -)
      echo -e "Release information:"
      echo -e "  - Release name:    ${GREEN}${release_name}${NC}"
      echo -e "  - Release version: ${GREEN}${release_version}${NC}"
      echo -e "  - Release URL:     ${GREEN}${release_url}${NC}"
      echo -e "  - Release SHA1:    ${GREEN}${release_sha1}${NC}\n"
  done
}

function build_release() {
  registry="${1}"
  organization="${2}"
  stemcell_image="${3}"
  release_name="${4}"
  release_url="${5}"
  release_version="${6}"
  release_sha1="${7}"

  echo -e "Release information:"
  echo -e "  - Release name:    ${GREEN}${release_name}${NC}"
  echo -e "  - Release version: ${GREEN}${release_version}${NC}"
  echo -e "  - Release URL:     ${GREEN}${release_url}${NC}"
  echo -e "  - Release SHA1:    ${GREEN}${release_sha1}${NC}"

  build_args=(
    "--stemcell=${stemcell_image}"
    "--name=${release_name}"
    "--version=${release_version}"
    "--url=${release_url}"
    "--sha1=${release_sha1}"
    "--docker-registry=${registry}"
    "--docker-organization=${organization}"
    "${FORCE_OPTION}"
  )

  echo -e "Building release ${LIGHT_BLUE}${release_name} v${release_version}${NC} ...\n"
  ${SUDO_COMMAND} fissile build release-images "${build_args[@]}"
#  echo -e "Built image: ${GREEN}${built_image}${NC}"
#  docker push "${built_image}"

#  built_image=$(${SUDO_COMMAND} fissile build release-images --dry-run "${build_args[@]}" | head -2 | tail -1 | cut -d' ' -f3)
#  echo "${built_image}" >> "${BUILT_IMAGES}"
#  export DOCKER_CLI_EXPERIMENTAL=enabled
#  if docker manifest inspect "${built_image}" 2>&1 | grep --quiet "no such manifest"; then
#      ${SUDO_COMMAND} fissile build release-images "${build_args[@]}"
#      echo -e "Built image: ${GREEN}${built_image}${NC}"
#      docker push "${built_image}"
#      docker rmi "${built_image}"
#  else
#      echo -e "Skipping push for ${GREEN}${built_image}${NC} as it is already present in the registry..."
#  fi

  echo '----------------------------------------------------------------------------------------------------'
}

function build_all_releases() {
  echo "${REGISTRY_PASS}" | docker login "${REGISTRY_NAME}" --username "${REGISTRY_USER}" --password-stdin
  docker pull "${STEMCELL_IMAGE}"
  export BUILT_IMAGES="${kubecf}/imagelist.txt"
  export VERSION="${STEMCELL_TAG}"
  for rel in $(yq e -j '.releases' ${src}/cf-deployment/cf-deployment.yml | jq -cr '.[]'); do
    RELEASE_NAME=$(echo $rel | jq -r '.name' -)
    RELEASE_URL=$(echo $rel | jq -r '.url' -)
    RELEASE_VERSION=$(echo $rel | jq -r '.version' -)
    RELEASE_SHA=$(echo $rel | jq -r '.sha1' -)

    build_release "${REGISTRY_NAME}" "${REGISTRY_NAMESPACE}" "${STEMCELL_IMAGE}" "${RELEASE_NAME}" "${RELEASE_URL}" "${RELEASE_VERSION}" "${RELEASE_SHA}"
  done
}

GREEN='\033[0;32m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m'
STEMCELL_IMAGE=vikramraophil/fissile-stemcell-opensuse
STEMCELL_TAG=""
BUILD=0
REGISTRY_NAME=""
REGISTRY_NAMESPACE=""
REGISTRY_USER=""
REGISTRY_PASS=""
SUDO_COMMAND=""
FORCE_OPTION=""

while [ "$1" != "" ];
do
   case $1 in
    -S | --stemcell )
        shift
        STEMCELL_TAG="${1}"
        STEMCELL_IMAGE="${STEMCELL_IMAGE}:${STEMCELL_TAG}"
        ;;
    -P | --sudo )
        SUDO_COMMAND="sudo -E"
        ;;
    -F | --force )
        FORCE_OPTION="--force"
        ;;
    -R | --registry )
        shift
        REGISTRY_NAME="${1}"
        ;;
    -U | --username )
        shift
        REGISTRY_USER="${1}"
        ;;
    -W | --password )
        shift
        REGISTRY_PASS="${1}"
        ;;
    -N | --namespace )
        shift
        REGISTRY_NAMESPACE="${1}"
        ;;
    -B | --build )
        BUILD=1
        ;;
    -V | --version )
        view_release
        exit
        ;;
    -H | --help )
         echo "Usage: cf-deployment-build [OPTIONS]"
         echo "OPTION includes:"
         echo "   -S | --stemcell - The source stemcell tag"
         echo "   -P | --sudo - If specified, uses sudo privilege to build images"
         echo "   -F | --force - If specified, image creation will proceed even when images already exist"
         echo "   -R | --registry - The name of the container registry to push the images"
         echo "   -N | --namespace - The namespace of the container registry to push the images"
         echo "   -U | --username - The username for authenticating with the container registry"
         echo "   -W | --password - The password for authenticating with the container registry"
         echo "   -B | --build - Builds Docker images from cf-deployment BOSH releases"
         echo "   -V | --version - prints out version information of cf-deployment BOSH releases"
         echo "   -H | --help - displays this message"
         exit
      ;;
    * )
        echo "Invalid option: $1"
        echo "Usage: cf-deployment-build [-S] [-F] [-B] [-V] [-H]"
        echo "   -S | --stemcell - The source stemcell tag"
        echo "   -P | --sudo - If specified, uses sudo privilege to build images"
        echo "   -F | --force - If specified, image creation will proceed even when images already exist"
        echo "   -R | --registry - The url of the container registry to push the images"
        echo "   -U | --username - The username for authenticating with the container registry"
        echo "   -W | --password - The password for authenticating with the container registry"
        echo "   -B | --build - Builds Docker images from cf-deployment BOSH releases"
        echo "   -V | --version - prints out version information of cf-deployment BOSH releases"
        echo "   -H | --help - displays this message"
        echo "     the command requires cf-deployment git submodule to be initialized"
        exit
       ;;
  esac
  shift
done

[[ $BUILD -eq 1 ]] && build_all_releases