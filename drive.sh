#!/usr/bin/env bash
set -x

OS=`uname -s`

wait_for_file(){
  while [ ! -e ${1} ]; do
    sleep 10
  done
  echo "${1} received"
}

setup(){
  rm -rf stage1 stage2 stage3 stage4 stage1.tgz stage2.tgz

  ROOT=`pwd`

  # directory for git cache
  export GIT_COW=${ROOT}/.cache/
}

if [ ${OS} == "Linux" ]; then
  setup
  ./stage1.sh
  wait_for_file stage1.tgz
  tar -zxvf stage1.tgz
  ./stage2.sh
  scp stage2.tgz ${1}:/opt/rust-cross-bitrig/
elif [ ${OS} == "Bitrig" ]; then
  setup
  ./stage1.sh
  scp stage1.tgz ${1}:/opt/rust-cross-bitrig/
  wait_for_file stage2.tgz
  tar -zxvf stage2.tgz
  ./stage3.sh
  ./stage4.sh
else
  echo "You must run this on Linux or Bitrig"
  exit 1
fi
