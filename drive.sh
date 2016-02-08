#!/usr/bin/env bash
set -x

if [[ $# -lt 4 ]]; then
  echo "Usage: drive.sh <target_os> <arch> <compiler> <other_host>"
  echo "    target_os -- 'bitrig', 'netbsd', etc"
  echo "    arch      -- 'x86_64', 'i686', 'armv7', etc"
  echo "    compiler  -- 'gcc' or 'clang'"
  echo "    other_host -- the fqdn of the other host to work with"
  exit 1
fi

set -x
HOST=`uname -s | tr '[:upper:]' '[:lower:]'`
TARGET=$1
ARCH=$2
COMP=$3
OTHERMACHINE=$4

wait_for_file(){
  while [ ! -e ${1} ]; do
    sleep 60
  done
  echo "${1} received from ${OTHERMACHINE}..."
}

copy_file() {
  # copy the file to the other machine named .<filename>
  scp ${1} ${OTHERMACHINE}:${2}/.${1}
  # then use the atomic mv operation to rename it into place
  ssh ${OTHERMACHINE} mv ${2}/.${1} ${2}/${1}
}

setup(){
  rm -rf build*.log
  rm -rf stage1 stage2 stage3 stage4 stage1.tgz stage2.tgz stage3.tgz
  TOP=`pwd`
}

do_host() {
  echo "Driving the host side..."
  cd ${TOP}

  # build host stage 1
  if [ ! -e .stage1 ]; then
    ./stage1.sh ${TARGET} ${ARCH} ${COMP} 2>&1 | tee build1.log
    if (( $? )); then
      echo "stage1 ${HOST} failed"
      exit 1
    else
      cd ${TOP}
      date > .stage1
    fi
  else
    echo "Stage 1 already built on:" `cat .stage1`
  fi

  # wait for target stage 1
  if [ ! -e stage1.tgz ]; then
    wait_for_file stage1.tgz
  fi

  tar -zxvf stage1.tgz

  # build host stage 2
  if [ ! -e .stage2 ]; then
    ./stage2.sh ${TARGET} ${ARCH} ${COMP} 2>&1 | tee build2.log
    if (( $? )); then
      echo "stage2 ${HOST} failed"
      exit 1
    else
      cd ${TOP}
      date > .stage2
    fi
  else
    echo "Stage 2 already built on:" `cat .stage2`
  fi

  copy_file stage2.tgz /opt/rust-cross-toolkit
}

do_target(){
  echo "Driving the target side..."
  cd ${TOP}

  if [ ! -e .stage1 ]; then
    ./stage1.sh ${TARGET} ${ARCH} ${COMP} 2>&1 | tee build1.log
    if (( $? )); then
      echo "stage1 ${HOST} failed"
      exit 1
    else
      cd ${TOP}
      date > .stage1
    fi
  else
    echo "Stage 1 already built on:" `cat .stage1`
  fi

  copy_file stage1.tgz /opt/rust-cross-toolkit/

  if [ ! -e stage2.tgz ]; then
    wait_for_file stage2.tgz
  fi

  tar -zxvf stage2.tgz

  if [ ! -e .stage3 ]; then
    ./stage3.sh ${TARGET} ${ARCH} ${COMP} 2>&1 | tee build3.log
    if (( $? )); then
      echo "stage3 ${HOST} failed"
      exit 1
    else
      cd ${TOP}
      date > .stage3
    fi
  else
    echo "Stage 3 already built on:" `cat .stage3`
  fi

  if [ ! -e .stage4 ]; then
    ./stage4.sh ${TARGET} ${ARCH} ${COMP} 2>&1 | tee build4.log
    if (( $? )); then
      echo "stage4 ${HOST} failed"
      exit 1
    else
      cd ${TOP}
      date > .stage4
    fi
  else
    echo "Stage 4 already built on:" `cat .stage4`
  fi
}

setup
if [ ${HOST} == ${TARGET} ]; then
  do_target
else
  do_host
fi
