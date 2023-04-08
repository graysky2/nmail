#!/usr/bin/env bash

# make.sh
#
# Copyright (C) 2020-2023 Kristofer Berggren
# All rights reserved.
#
# See LICENSE for redistribution information.

# exiterr
exiterr()
{
  >&2 echo "${1}"
  exit 1
}

# process arguments
DEPS="0"
BUILD="0"
DEBUG="0"
TESTS="0"
DOC="0"
INSTALL="0"
SRC="0"
case "${1%/}" in
  deps)
    DEPS="1"
    ;;

  build)
    BUILD="1"
    ;;

  debug)
    DEBUG="1"
    ;;

  test*)
    BUILD="1"
    TESTS="1"
    ;;

  doc)
    BUILD="1"
    DOC="1"
    ;;

  install)
    BUILD="1"
    INSTALL="1"
    ;;

  src)
    SRC="1"
    ;;

  all)
    DEPS="1"
    BUILD="1"
    TESTS="1"
    DOC="1"
    INSTALL="1"
    ;;

  *)
    echo "usage: make.sh <deps|build|tests|doc|install|all>"
    echo "  deps      - install project dependencies"
    echo "  build     - perform build"
    echo "  debug     - perform debug build"
    echo "  tests     - perform build and run tests"
    echo "  doc       - perform build and generate documentation"
    echo "  install   - perform build and install"
    echo "  all       - perform deps, build, tests, doc and install"
    echo "  src       - perform source code reformatting"
    exit 1
    ;;
esac

# deps
if [[ "${DEPS}" == "1" ]]; then
  OS="$(uname)"
  if [ "${OS}" == "Linux" ]; then
    unset NAME
    eval $(grep "^NAME=" /etc/os-release 2> /dev/null)
    if [[ "${NAME}" == "Ubuntu" ]]; then
      sudo apt update && sudo apt -y install build-essential cmake libssl-dev libreadline-dev libncurses5-dev libetpan-dev libxapian-dev libsqlite3-dev libmagic-dev uuid-dev || exiterr "deps failed (ubuntu), exiting."
    elif [[ "${NAME}" == "Raspbian GNU/Linux" ]]; then
      sudo apt update && sudo apt -y install build-essential cmake libssl-dev libreadline-dev libncurses5-dev libetpan-dev libxapian-dev libsqlite3-dev libsasl2-modules libmagic-dev uuid-dev || exiterr "deps failed (raspbian gnu/linux), exiting."
    elif [[ "${NAME}" == "Fedora" ]]; then
      sudo yum -y install cmake libetpan-devel openssl-devel ncurses-devel xapian-core-devel sqlite-devel cyrus-sasl-devel cyrus-sasl-plain file-devel libuuid-devel clang || exiterr "deps failed (fedora), exiting."
    elif [[ "${NAME}" == "Arch Linux" ]]; then
      sudo pacman --needed -Sy cmake make libetpan openssl ncurses xapian-core sqlite cyrus-sasl file uuid clang || exiterr "deps failed (arch linux), exiting."
    elif [[ "${NAME}" == "Gentoo" ]]; then
      sudo sh -c 'echo "net-libs/libetpan sasl" > /etc/portage/package.use/d99kris-nmail' || exiterr "deps failed (gentoo), exiting."
      sudo emerge -n dev-util/cmake net-libs/libetpan dev-libs/openssl sys-libs/ncurses dev-libs/xapian dev-db/sqlite dev-libs/cyrus-sasl sys-apps/file || exiterr "deps failed (gentoo), exiting."
    else
      exiterr "deps failed (unsupported linux distro ${NAME}), exiting."
    fi
  elif [ "${OS}" == "Darwin" ]; then
    brew install openssl ncurses libetpan xapian sqlite libmagic ossp-uuid || exiterr "deps failed (mac), exiting."
  else
    exiterr "deps failed (unsupported os ${OS}), exiting."
  fi
fi

# src
if [[ "${SRC}" == "1" ]]; then
  uncrustify -c etc/uncrustify.cfg --replace --no-backup src/*.cpp src/*.h || \
    exiterr "unrustify failed, exiting."
fi

# build
if [[ "${BUILD}" == "1" ]]; then
  OS="$(uname)"
  MAKEARGS=""
  if [ "${OS}" == "Linux" ]; then
    MAKEARGS="-j$(nproc)"
  elif [ "${OS}" == "Darwin" ]; then
    MAKEARGS="-j$(sysctl -n hw.ncpu)"
  fi
  mkdir -p build && cd build && cmake .. && make ${MAKEARGS} && cd .. || exiterr "build failed, exiting."
fi

# debug
if [[ "${DEBUG}" == "1" ]]; then
  OS="$(uname)"
  MAKEARGS=""
  if [ "${OS}" == "Linux" ]; then
    MAKEARGS="-j$(nproc)"
  elif [ "${OS}" == "Darwin" ]; then
    MAKEARGS="-j$(sysctl -n hw.ncpu)"
  fi
  mkdir -p dbgbuild && cd dbgbuild && cmake -DCMAKE_BUILD_TYPE=Debug .. && make ${MAKEARGS} && cd .. || exiterr "debug build failed, exiting."
fi

# tests
if [[ "${TESTS}" == "1" ]]; then
  cd build && ctest --output-on-failure && cd .. || exiterr "tests failed, exiting."
fi

# doc
if [[ "${DOC}" == "1" ]]; then
  if [[ -x "$(command -v help2man)" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      SED="gsed -i"
    else
      SED="sed -i"
    fi
    help2man -n "ncurses mail" -N -o src/nmail.1 ./build/nmail && ${SED} "s/\.\\\\\" DO NOT MODIFY THIS FILE\!  It was generated by help2man.*/\.\\\\\" DO NOT MODIFY THIS FILE\!  It was generated by help2man./g" src/nmail.1 || exiterr "doc failed, exiting."
  fi
fi

# install
if [[ "${INSTALL}" == "1" ]]; then
  OS="$(uname)"
  if [ "${OS}" == "Linux" ]; then
    cd build && sudo make install && cd .. || exiterr "install failed (linux), exiting."
  elif [ "${OS}" == "Darwin" ]; then
    cd build && make install && cd .. || exiterr "install failed (mac), exiting."
  else
    exiterr "install failed (unsupported os ${OS}), exiting."
  fi
fi

# exit
exit 0
