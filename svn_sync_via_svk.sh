#!/bin/sh -e
# ---------------------------------------------------------------------------
# Copyright (c) 2007, Jeff Hung
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#.
#  - Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  - Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  - Neither the name of the copyright holders nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# ----------------------------------------------------------------------------

svn_sync_via_svk()
{
	local name="$1"; shift;
	local from_url="$1"; shift;
	local to_url="$1"; shift;
	local svk_depot_name="$1"; shift;
	local svk_depot_path="$1"; shift;
	local svk_sync_limit="$1"; shift;

	# Ensure that $svk_depot_path doesn't contain '~'.
	svk_depot_path=`realpath "$svk_depot_path"`;

	echo "[INFO] Setting up SVK transporter at $svk_depot,";
	echo "[INFO] | using SVK depot '$svk_depot_name' at '$svk_depot_path',";
	echo "[INFO] | which can be later accessed via 'svk depot /$svk_depot_name'.";
	svk depotmap "$svk_depot_name" "$svk_depot_path";

	echo "[INFO] Setting mirror from $from_url to /$svk_depot_name/$name/remote.";
	svk mirror "/$svk_depot_name/$name/remote" "$arg_from_url";

	echo "[INFO] Setting mirror from $arg_to_url to /$svk_depot_name/$name/local.";
	svk mirror "/$svk_depot_name/$name/local" "$arg_to_url";

	from_url_head=`\
		svn info --xml "$arg_from_url" \
		| xml sel --text --template --value-of //entry/@revision \
		`;
	echo "[INFO] Head revision of $arg_from_url is r$from_url_head.";

	from_url_rev_beg=0;
	from_url_rev_end="$opt_svk_sync_limit";
	while [ $from_url_rev_beg -lt $from_url_head ]; do
		echo "[INFO] Syncing from -r$from_url_rev_beg:$from_url_rev_end $arg_from_url.";

		if [ $from_url_rev_end -le $from_url_head ]; then
			svk sync --torev $from_url_rev_end "/$svk_depot_name/$name/remote";
		else
			svk sync "/$svk_depot_name/$name/remote";
		fi;
		if [ $from_url_rev_beg -eq 0 ]; then
			svk smerge --incremental --log --baseless \
			           "/$svk_depot_name/$name/remote" \
			           "/$svk_depot_name/$name/local" \
			;
		fi;
		svk sync "/$svk_depot_name/$name/local";
	
		from_url_rev_beg=`expr $from_url_rev_end + 1`;
		from_url_rev_end=`expr $from_url_rev_beg + $opt_svk_sync_limit - 1`;
	done;
	echo "[INFO] Done.";
}

svn_sync_via_svk $@;

