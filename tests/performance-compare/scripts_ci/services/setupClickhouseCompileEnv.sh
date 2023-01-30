#!/bin/bash


echo "$(date '+%F %T'): Clickhouse backend compile env setup begin"

echo "$(date '+%F %T'): install gcc"
if [ $(which gcc) -ne 0 ];then
  sudo apt install -y gcc-9 g++-9 gcc-10 g++-10
  sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 --slave /usr/bin/g++ g++ /usr/bin/g++-10 --slave /usr/bin/gcov gcov /usr/bin/gcov-10
  sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90 --slave /usr/bin/g++ g++ /usr/bin/g++-9 --slave /usr/bin/gcov gcov /usr/bin/gcov-9
fi

echo "$(date '+%F %T'): install clang"
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -
if [ $(grep -r llvm /etc/apt/sources.list) -ne 0 ];then
  sudo echo "deb http://apt.llvm.org/focal/ llvm-toolchain-focal main" >> /etc/apt/sources.list
  sudo echo "deb-src http://apt.llvm.org/focal/ llvm-toolchain-focal main" >> /etc/apt/sources.list
fi




echo "$(date '+%F %T'): Clickhouse backend compile env setup well!"
sudo apt update

sudo apt install -y clang-12 lldb-12 lld-12 clang-12-doc llvm-12-doc llvm-12-examples clang-tools-12 libclang-12-dev clang-format-12 libfuzzer-12-dev libc++-12-dev libc++abi-12-dev libllvm-12-ocaml-dev

sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-12 100 --slave /usr/bin/clang++ clang++ /usr/bin/clang++-12

echo "$(date '+%F %T'): install git ccache python3 ninja-build!"
sudo apt-get install -y git ccache python3 ninja-build

echo "$(date '+%F %T'): install cmake"
if [ $(which cmake) -ne 0 ];then
  mkdir -p ~/setup && cd ~/setup
  wget https://cmake.org/files/v3.20/cmake-3.20.0-linux-x86_64.tar.gz
  tar -xzvf cmake-3.20.0-linux-x86_64.tar.gz
  sudo ln -sf ~/setup/cmake-3.20.0-linux-x86_64/bin/*  /usr/bin/
  cd -
fi


if [ $(grep -r "CC=clang" /etc/profile) -ne 0 ];then
  sudo echo "export CC=clang-12" >> /etc/profile
  sudo echo "export CXX=clang++-12" >> /etc/profile
fi

echo "$(date '+%F %T'): Clickhouse backend compile env setup end"
