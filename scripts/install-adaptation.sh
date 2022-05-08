#!/bin/bash
#
# install-adaptation
# Copyright (C) 2022 Eugenio "g7" Paolantonio <me@medesimo.eu>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the <organization> nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -e

info() {
	echo "I: $@"
}

warning() {
	echo "W: $@" >&2
}

error() {
	echo "E: $@" >&2
	exit 1
}

cleanup() {
	[ -e "${tmpdir}" ] && rm -rf "${tmpdir}"
}

tmpdir="$(mktemp -d)"
trap cleanup EXIT

packages="${@}"
apt_config_dir="${tmpdir}/_apt"
pkg_extract_dir="${tmpdir}/_pkg_extract"

[ -n "${packages}" ] || error "No packages specified! Use $0 --help for more details"

cp -R /etc/apt "${apt_config_dir}"

chmod 755 ${tmpdir} ${apt_config_dir}

adaptation_packages=""
for package in ${packages}; do
	if [[ ${package} == adaptation-* ]]; then
		# If an adaptation package has been specified, download it
		# first and hunt for custom repositories and pinning rules.
		# This allows to properly handle custom repositories and pinning
		# rules so that they can be honoured during the feature bundle
		# installation.
		adaptation_packages="${adaptation_packages} ${package}"
	fi
done

if [ -n "${adaptation_packages}" ]; then
	# Download using apt-get download
	adaptation_download_target="${tmpdir}/_adaptation"
	mkdir -p "${adaptation_download_target}"
	(cd "${adaptation_download_target}" ; apt-get download ${adaptation_packages})

	for package in ${adaptation_packages}; do
		# TODO: Move package extraction to a function?
		mkdir -p "${pkg_extract_dir}"
		dpkg-deb -x ${adaptation_download_target}/${package}_*.deb ${pkg_extract_dir}

		# Handle package lists
		for repository in $(find ${pkg_extract_dir} -wholename '*/sources.list.d/*.list' -type f); do
			[ ! -L "${repository}" ] || continue
			info "Found extra repository description $(basename ${repository})"
			cp ${repository} ${apt_config_dir}/sources.list.d/
		done

		# Handle apt pinning preferences
		for preference in $(find ${pkg_extract_dir} -wholename '*/preferences.d/*' -type f); do
			[ ! -L "${preference}" ] || continue
			info "Found extra pinning preference $(basename ${preference})"
			cp ${preference} ${apt_config_dir}/preferences.d/
		done

		# Handle extra gpg keys
		for gpg in $(find ${pkg_extract_dir} -wholename '*/trusted.gpg.d/*' -type f); do
			[ ! -L "${gpg}" ] || continue
			info "Found extra GPG key $(basename ${gpg})"
			cp ${gpg} ${apt_config_dir}/trusted.gpg.d/
		done

		# Handle extra packages we should download and that the adaptation
		# package conveniently tells us - this is only used by package-sideload-create
		# and not by our receiver.
		# This can also be used to "forcibly downgrade" packages, provided
		# APT pins are in place.
		for package_list in $(find ${pkg_extract_dir} -wholename '*/package-sideload-create.d/*' -type f); do
			[ ! -L "${package_list}" ] || continue
			info "Found extra package list $(basename ${package_list})"
			packages="${packages} $(tr '\n' ' ' < ${package_list})"
		done

		rm -rf "${pkg_extract_dir}"
	done

	rm -rf "${adaptation_download_target}"
fi

info "Updating package list"

/usr/bin/apt-get \
	--option "dir::etc=${apt_config_dir}" \
	--option "Debug::NoLocking=1" \
	update

info "Installing packages"

/usr/bin/apt-get \
	--option "dir::etc=${apt_config_dir}" \
	--option "Debug::NoLocking=1" \
	--assume-yes \
	--allow-downgrades \
	--reinstall \
	install \
	${packages}
