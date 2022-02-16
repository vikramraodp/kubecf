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
#  [[ $SUDO -eq 1 ]] && sudo_command="sudo " | sudo_command=""
  sudo_command="sudo "
  [[ $FORCE -eq 1 ]] && force_option="--force " | force_option=""
  echo "${sudo_command}"
  for rel in $(yq e -j '.releases' ${src}/cf-deployment/cf-deployment.yml | jq -cr '.[]'); do
    release_name=$(echo $rel | jq -r '.name' -)
    release_url=$(echo $rel | jq -r '.url' -)
    release_version=$(echo $rel | jq -r '.version' -)
    release_sha1=$(echo $rel | jq -r '.sha1' -)

    build_args=(
      "--stemcell=${STEMCELL_IMAGE}"
      "--name=${release_name}"
      "--version=${release_version}"
      "--url=${release_url}"
      "--sha1=${release_sha1}"
      "${force_option}"
    )

    echo -e "Building release ${LIGHT_BLUE}${release_name} v${release_version}${NC} ...\n"
    built_image=$(${sudo_command}fissile build release-images --dry-run "${build_args[@]}" | cut -d' ' -f3)
    ${sudo_command}fissile build release-images "${build_args[@]}"
    echo -e "Built image: ${GREEN}${built_image}${NC}"

##    echo "${built_image}" >> "${BUILT_IMAGES}"
#    export DOCKER_CLI_EXPERIMENTAL=enabled
#    if docker manifest inspect "${built_image}" 2>&1 | grep --quiet "no such manifest"; then
#        ${sudo_command}fissile build release-images "${build_args[@]}"
#        echo -e "Built image: ${GREEN}${built_image}${NC}"
#    else
#        echo -e "Skipping push for ${GREEN}${built_image}${NC} as it is already present in the registry..."
#    fi

    echo '----------------------------------------------------------------------------------------------------'

  done
}

GREEN='\033[0;32m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m'
SUDO=0
FORCE=0
STEMCELL_IMAGE=splatform/fissile-stemcell-sle

while [ "$1" != "" ];
do
   case $1 in
    -S | --stemcell )
        shift
        STEMCELL_IMAGE="${STEMCELL_IMAGE}:${1}"
        export VERSION=${1}
        ;;
    -P | --sudo )
        SUDO=1
        ;;
    -F | --force )
        FORCE=1
        ;;
    -B | --build )
        build_release
        ;;
    -V | --version )
        view_release
        ;;
    -H | --help )
         echo "Usage: cf-deployment-build [OPTIONS]"
         echo "OPTION includes:"
         echo "   -S | --stemcell - The source stemcell tag"
         echo "   -P | --sudo - If specified, uses sudo privilege to build images"
         echo "   -F | --force - If specified, image creation will proceed even when images already exist"
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
        echo "   -B | --build - Builds Docker images from cf-deployment BOSH releases"
        echo "   -V | --version - prints out version information of cf-deployment BOSH releases"
        echo "   -H | --help - displays this message"
        echo "     the command requires cf-deployment git submodule to be initialized"
        exit
       ;;
  esac
  shift
done