#!/usr/bin/env bash
#bash script to populate cdn from cloud vault artifacts

# exit on error and dump debug info
set -e -x

source `dirname "$0"`/buildInfo.sh

#-----------------------------
# validate args as set
# $1 argName
# $2 argValue (if set)
#-----------------------------
function exitIfMissing() {
    if [ "" == "$2" ]
    then
        printf '%s not defined\n' $1
        exit 1
    fi
}

# check all required args are set
args=('buildNumber' 'buildHash' 'artifactVolumeCount' 'blobStore'  'cdnContainer' 'blobKey' 'artifactSasUrl_1' 'artifactSasUrl_2' )
for arg in ${args[@]}
do
    exitIfMissing $arg ${!arg}
done

# install dependencies (unzip, rsync, azcopy)

# install unzip and rsync
apt install unzip rsync libunwind8 -y

# install azcopy according to https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-linux
wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
tar -xf azcopy.tar.gz
./install.sh


# use azcopy to download the Intercom.CdnUpload.zip.[001, 002...] build artifact
for i in `seq 1 ${artifactVolumeCount}`;
do
    vol=artifactSasUrl_${i}
    azcopy --source ${!vol} --destination ./Intercom.CdnUpload.zip.00${i} --quiet
done

# combine the zip parts into zip file
rm -f Intercom.CdnUpload.zip
touch Intercom.CdnUpload.zip
for i in `seq -s " " -f %03g 1 ${artifactVolumeCount}`;
do
    vol=Intercom.CdnUpload.zip.${i}
    echo ${vol}
    cat ${vol} >> Intercom.CdnUpload.zip
done

# unzip the artifacts (-o for overwrite, only content under static/* to intercom.proxy/static)
unzip -o ./Intercom.CdnUpload.zip static/* -d ./intercom.proxy
# find the static folder in the unzipped folder
staticSrc=$(find ./intercom.proxy/  -type d -name static)

# azcopy static folder to cdn storage
azcopy --source $staticSrc --recursive --exclude-newer --exclude-older --set-content-type --dest-type blob --quiet --destination ${blobStore}/${cdnContainer}/${buildNumber}-${buildHash} --dest-key ${blobKey}
