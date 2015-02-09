#!/bin/bash
# Usage: repack.sh [location of source tarball]
#
# The program will build a .orig.tar.gz file
# for consumption by debian package build process from a raw 'upstream'
# Percona XtraDB Clusterr source tarball.
#

# Bail out on errors, be strict
set -ue

# The working directory and location of resulting files
WORKING_DIR=$PWD

# The given source tarball location
SOURCE_TAR_FILE=''

# Read from the VERSION file
MYSQL_VERSION_MAJOR=''
MYSQL_VERSION_MINOR=''
MYSQL_VERSION_PATCH=''
MYSQL_VERSION_EXTRA=''

# Pulled from wsrep
WSREP_VERSION=''
WSREP_REV=''

# Composed versions
PERCONA_XTRADB_CLUSTER_FULLNAME=''
PERCONA_XTRADB_CLUSTER_DEBNAME=''

# Don't clean up after ourselves
DONT_CLEAN=''

# Display usage
function show_usage()
{
	if [ $# -gt 1 ]; then
		echo "ERROR : ${2}"
	fi

	echo \
"Usage:
	$(basename $0) [options] [location of source tarball]
Options:
	-d | --dont-clean	Don't clean directories afterwards.
	-h | --help		Display this help message."
	exit $1
}

# Examine parameters
go_out="$(getopt --options="dh" --longoptions="dont-clean,help" \
	--name="$(basename "$0")" -- "$@")"
eval set -- "$go_out"

for arg
do
	case "$arg" in
	-- ) shift; break;;
	-d | --dont-clean ) shift; DONT_CLEAN='true';;
	-h | --help ) shift; show_usage 0;;
	esac
done

if [ $# -eq 0 ]; then
	show_usage 1 "No source tarball specified"
fi
SOURCE_TAR_FILE=$@;

echo "SOURCE_TAR_FILE=${SOURCE_TAR_FILE}"
echo "WORKING_DIR=${WORKING_DIR}"

# And away we go...
cd ${WORKING_DIR}

# Find the source tarball
SOURCE_TAR=$(basename $(find . -type f -name '*.tar.gz' | sort | tail -n1))
if [ ! -e "${SOURCE_TAR_FILE}" ] || [ ! -f "${SOURCE_TAR_FILE}" ]; then
  echo "ERROR : No source tar file \"${SOURCE_TAR_FILE}\" found."
  exit 1
fi
SOURCE_TAR_DIR=$(basename ${SOURCE_TAR_FILE%".tar.gz"})

# Extract the source tar
if [ -d "${SOURCE_TAR_DIR}" ]; then
	rm -rf ${SOURCE_TAR_DIR}
fi
tar -xzf ${SOURCE_TAR_FILE}

if [ ! -d "${SOURCE_TAR_DIR}" ]; then
	echo "ERROR : Directory \"${SOURCE_TAR_DIR}\" not found after extracting \"${SOURCE_TAR_FILE}\""
	exit 1
fi

# Read version info from the VERSION file
. ${SOURCE_TAR_DIR}/VERSION

# Figure out WSREP version
WSREP_VERSION="$(grep WSREP_INTERFACE_VERSION ${SOURCE_TAR_DIR}/wsrep/wsrep_api.h | cut -d '"' -f2).$(grep 'SET(WSREP_PATCH_VERSION'  "${SOURCE_TAR_DIR}/cmake/wsrep.cmake" | cut -d '"' -f2)"
WSREP_REV="$(test -r ${SOURCE_TAR_DIR}/WSREP-REVISION && cat ${SOURCE_TAR_DIR}/WSREP-REVISION)"

# Build out various file and directory names
MYSQL_VERSION_EXTRA=${MYSQL_VERSION_EXTRA#-}
PERCONA_XTRADB_CLUSTER_FULLNAME=Percona-XtraDB-Cluster-${MYSQL_VERSION_MAJOR}.${MYSQL_VERSION_MINOR}.${MYSQL_VERSION_PATCH}-${MYSQL_VERSION_EXTRA}
PERCONA_XTRADB_CLUSTER_DEBNAME=percona-xtradb-cluster-${MYSQL_VERSION_MAJOR}.${MYSQL_VERSION_MINOR}_${MYSQL_VERSION_MAJOR}.${MYSQL_VERSION_MINOR}.${MYSQL_VERSION_PATCH}-${WSREP_VERSION}
BZR_REVISION=$(grep "REVISION = " ${SOURCE_TAR_DIR}/build-ps/debian/rules |  awk -F "'" '{print $2}')

# Sanity version test
if [ "${PERCONA_XTRADB_CLUSTER_FULLNAME}" != "${SOURCE_TAR_DIR}" ]; then
	echo "ERROR : Source tarball \"${SOURCE_TAR}\" name does not match internal \"${PERCONA_XTRADB_CLUSTER_FULLNAME}\""
	exit 1
fi

# Write DEB-VERSION file and make a copy in the source tree
echo "MYSQL_VERSION_MAJOR=${MYSQL_VERSION_MAJOR}" > ${SOURCE_TAR_DIR}/DEB-VERSION
echo "MYSQL_VERSION_MINOR=${MYSQL_VERSION_MINOR}" >> ${SOURCE_TAR_DIR}/DEB-VERSION
echo "MYSQL_VERSION_PATCH=${MYSQL_VERSION_PATCH}" >> ${SOURCE_TAR_DIR}/DEB-VERSION
echo "MYSQL_VERSION_EXTRA=${MYSQL_VERSION_EXTRA}" >> ${SOURCE_TAR_DIR}/DEB-VERSION
echo "PERCONA_XTRADB_CLUSTER_FULLNAME=${PERCONA_XTRADB_CLUSTER_FULLNAME}" >> ${SOURCE_TAR_DIR}/DEB-VERSION
echo "PERCONA_XTRADB_CLUSTER_DEBNAME=${PERCONA_XTRADB_CLUSTER_DEBNAME}" >> ${SOURCE_TAR_DIR}/DEB-VERSION
echo "WSREP_VERSION=${WSREP_VERSION}" >> ${SOURCE_TAR_DIR}/DEB-VERSION
echo "WSREP_REV=${WSREP_REV}" >> ${SOURCE_TAR_DIR}/DEB-VERSION

# And now our locals for the task at hand
ORIG_TAR_DIR=percona-xtradb-cluster-${MYSQL_VERSION_MAJOR}.${MYSQL_VERSION_MINOR}.${MYSQL_VERSION_PATCH}-${MYSQL_VERSION_EXTRA}
ORIG_TAR=${PERCONA_XTRADB_CLUSTER_DEBNAME}.orig.tar.gz

# Remove anything not needed for debian build.
rm -f ${SOURCE_TAR_DIR}/doc-pxc/source/percona-theme/static/jquery.min.js
rm -f ${SOURCE_TAR_DIR}/doc/source/percona-theme/static/jquery.min.js
rm -rf ${SOURCE_TAR_DIR}/python-for-subunit2junitxml
rm -f ${SOURCE_TAR_DIR}/subunit2junitxml
rm -f ${SOURCE_TAR_DIR}/Docs/INFO_SRC
rm -f ${SOURCE_TAR_DIR}/mysql-test/t/file_contents.test
rm -f ${SOURCE_TAR_DIR}/mysql-test/r/file_contents.result
rm -rf ${SOURCE_TAR_DIR}/build-ps/debian
rm -f ${SOURCE_TAR_DIR}/build-ps/percona-server.spec
rm -f ${SOURCE_TAR_DIR}/build-ps/build-dpkg-for-archive.sh

# Rename the source dir to the correct orig dir name
mv ${SOURCE_TAR_DIR} ${ORIG_TAR_DIR}

# Build the orig tarfile
tar --owner=0 --group=0 --exclude=.bzr --exclude=.git -czf ${ORIG_TAR} ${ORIG_TAR_DIR}

# Clean up
if [ "${DONT_CLEAN}" != "true" ]; then
	rm -rf ${SOURCE_TAR_DIR}
fi

# Return
exit 0
