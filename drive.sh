#!/usr/bin/env bash

usage(){
  cat<<EOF
  usage: $0 options

  This script drives the whole bootstrapping process.

  OPTIONS:
    -h      Show this message.
    -c      Continue previous build. Default is to rebuild all.
    -r      Revision to build. Default is to build most recent snapshot revision.
    -t      Target OS. Required. Valid options: 'bitrig' or 'netbsd'.
    -a      CPU archictecture. Required. Valid options: 'x86_64' or 'i686'.
    -p      Compiler. Required. Valid options: 'gcc' or 'clang'.
    -o      Other host. Required.  The other machine doing the bootstrapping.
    -v      Verbose output from this script.
EOF
}

HOST=`uname -s | tr '[:upper:]' '[:lower:]'`
CONTINUE=
REV=
TARGET=
ARCH=
COMP=
OTHERMACHINE=
VERBOSE=
TOP=`pwd`

while getopts "hcr:t:a:p:o:v" OPTION; do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    c)
      CONTINUE="yes"
      ;;
    r)
      REV=$OPTARG
      ;;
    t)
      TARGET=$OPTARG
      ;;
    a)
      ARCH=$OPTARG
      ;;
    p)
      COMP=$OPTARG
      ;;
    o)
      OTHERMACHINE=$OPTARG
      ;;
    v)
      VERBOSE="yes"
      set -x
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

if [[ -z $TARGET ]] || [[ -z $ARCH ]] || [[ -z $COMP ]] || [[ -z $OTHERMACHINE ]]; then
  usage
  exit 1
fi

check_error(){
  if (( $1 )); then
    echo $2
    exit $1
  fi
}

set_opt_if(){
  if [[ ! -z ${1} ]]; then
    echo -n ${2}
  fi
}

setup(){
  if [[ -z $CONTINUE ]]; then
    rm -rf build*.log
    rm -rf stage1 stage2 stage3 stage4 stage1.tgz stage2.tgz stage3.tgz
    rm -rf .stage1 .stage2 .stage3 .stage4
  fi
}

wait_for_file(){
  while [ ! -e ${1} ]; do
    sleep 60
  done
  echo "${1} received from ${OTHERMACHINE}..."
  tar -zxvf ${1}
}

send_file() {
  # copy the file to the other machine named .<filename>
  scp ${1} ${OTHERMACHINE}:${2}/.${1}
  # then use the atomic mv operation to rename it into place
  ssh ${OTHERMACHINE} mv ${2}/.${1} ${2}/${1}
}

build_stage(){
  SCRIPT="stage${1}.sh"
  LOG="build${1}.log"
  ROPT=$(set_opt_if $REV "-r ${REV}")
  VOPT=$(set_opt_if $VERBOSE "-v")
  COPT=$(set_opt_if $CONTINUE "-c")

  # execute the stage script
  ./${SCRIPT} -t ${TARGET} -a ${ARCH} -p ${COMP} ${ROPT} ${VOPT} ${COPT} 2>&1 | tee ${LOG}
  check_error $? "${SCRIPT} ${HOST} failed"
  cd ${TOP}
}

do_host() {
  echo "Driving the host side..."
  cd ${TOP}

  # build host stage 1
  build_stage 1

  # wait for stage 1 from target machine
  wait_for_file stage1.tgz

  # build host stage 2
  build_stage 2

  # send stage 2 to target machine
  send_file stage2.tgz /opt/rust-cross-toolkit
}

do_target(){
  echo "Driving the target side..."
  cd ${TOP}

  # build target stage 1
  build_stage 1

  # send target stage 1 to host
  send_file stage1.tgz /opt/rust-cross-toolkit/

  # wait for host stage 2
  wait_for_file stage2.tgz

  # build target stage 3
  build_stage 3

  # build target stage 4
  build_stage 4
}

setup
if [ ${HOST} == ${TARGET} ]; then
  do_target
else
  do_host
fi
echo "Done!"
