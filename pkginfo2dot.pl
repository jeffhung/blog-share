#!/usr/bin/perl -w
# ---------------------------------------------------------------------------
# Amarganth Development Environment
# Copyright (c) 2007, Jeff Hung
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
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
# ---------------------------------------------------------------------------
# $Date: 2010-04-06 14:15:37 +0800 (Tue, 06 Apr 2010) $
# $Rev: 592 $
# $Author: jeffhung $
# ----------------------------------------------------------------------------
# revid: "@(#) $Id: pkginfo2dot.pl 592 2010-04-06 06:15:37Z jeffhung $"
# ----------------------------------------------------------------------------

use strict;
use utf8;
use File::Basename;
use Getopt::Long;

my ($__exe_name__) = (basename($0));
my ($__revision__) = ('$Rev: 592 $' =~ m/(\d+)/o);
my ($__rev_date__) = ('$Date: 2010-04-06 14:15:37 +0800 (Tue, 06 Apr 2010) $' =~ m/(\d{4}-\d{2}-\d{2})/o);

sub usage
{
	print STDERR <<"EOF";
Usage: $__exe_name__ [ <option> ... ] <dot-file> <pkg-glob> ...

Generate graphviz digraph script <dot-file> according to pkg_info(1) output
for package <pkg-glob>s..  If path of digraph script <dot-file> is a single
dash, will output to standard output.

Options:

  -h,--help               Show this help message.
  -n,--name <graph-name>  Set graph name to <graph-name>.  Default to first
                          <pkg-glob>.
  -v,--verbose            Show verbose progress messages.

Revision: r$__revision__ ($__rev_date__)
EOF
	exit(0);
}

sub msg_exit
{
	my $ex = ((scalar(@_) > 0) ? shift @_ : 0);
	print STDERR <<"EOF";
Usage: $__exe_name__ [ <option> ... ] <dot-file> <pkg-glob> ...

Type '$__exe_name__ --help' for usage.
EOF
	if (scalar @_ > 0) {
		print STDERR "\n";
		foreach my $m (@_) {
			print STDERR "ERROR: $m\n";
		}
	}
	exit($ex);
}

sub quote
{
	my ($v) = @_;
	return (($v =~ m/^[0-9]+$/o) ? $v : "\"$v\"");
}

sub pkginfo2dot
{
	my $graph_name = shift @_;
	my $dotfh = shift @_;
	my @pkg_names = @_;

	my $dot_data = [
		{
			'layout'  => 'digraph',
			'name'    => $graph_name,
			'graph_options' => {
				'fontsize' => 10,
				'bgcolor'  => 'transparent',
				'rankdir'  => 'RL',
			},
			'node_options' => {
				'shape'    => 'record',
				'fontsize' => 10,
			},
			'edge_options' => {
				'fontsize'  => 8,
				'arrowhead' => 'normal',
#				'label'     => '<<depends on>>',
			},
			'nodes' => {
#				$pkg_name => {
#					'style' => 'bold',
#				},
			},
			'edges' => [],
		},
	];

#	print "\@pkg_names: @pkg_names\n";

	foreach my $pkg_name (@pkg_names) {
#		print "---> $pkg_name\n";
		$dot_data->[0]->{'nodes'}->{$pkg_name} = {
			'style' => 'bold',
		};

		my $line;
		my @pkginfo_depends_out = split(qr/[\r\n]+/, `pkg_info -qr "$pkg_name"`);
		while ($line = shift @pkginfo_depends_out) {
			if ($line =~ m/^\@pkgdep (.*)$/o) {
				my $depended_pkg = $1;
#				print "$pkg_name depends on $depended_pkg\n";
				push(@{$dot_data->[0]->{'edges'}},
				     {$pkg_name => $depended_pkg});
			}
		}
		my @pkginfo_requiredby_out = split(qr/[\r\n]+/, `pkg_info -qR "$pkg_name"`);
		while ($line = shift @pkginfo_requiredby_out) {
			if (length($line) > 0) {
				my $required_by_pkg = $line;
#				print "$required_by_pkg depends on $pkg_name\n";
				push(@{$dot_data->[0]->{'edges'}},
				     {$required_by_pkg => $pkg_name});
			}
		}
	}

	#
	# Generate dot
	#

#	print "--------------------------------------------\n";
	foreach my $g (@$dot_data) {
		printf $dotfh ("%s %s {\n", $g->{'layout'}, quote($g->{'name'}));
		foreach my $gopt (keys %{$g->{'graph_options'}}) {
			printf $dotfh ("\t%s = %s\n",
			               $gopt, quote($g->{'graph_options'}->{$gopt}));
		}
		print $dotfh "\n";

		print $dotfh "\tnode [\n";
		foreach my $nopt (keys %{$g->{'node_options'}}) {
			printf $dotfh ("\t\t%s = %s\n",
			               $nopt, quote($g->{'node_options'}->{$nopt})
			);
		}
		print $dotfh "\t]\n";
		print $dotfh "\n";

		print $dotfh "\tedge [\n";
		foreach my $eopt (keys %{$g->{'edge_options'}}) {
			printf $dotfh ("\t\t%s = %s\n",
			               $eopt,
			               quote($g->{'edge_options'}->{$eopt})
			);
		}
		print $dotfh "\t]\n";
		print $dotfh "\n";

		foreach my $nname (keys %{$g->{'nodes'}}) {
			printf $dotfh ("\t%s [\n", quote($nname));
			foreach my $ndopt (keys %{$g->{'nodes'}->{$nname}}) {
				printf $dotfh ("\t\t%s = %s\n",
							   $ndopt,
							   quote($g->{'nodes'}->{$nname}->{$ndopt})
				);
			}
			print $dotfh "\t]\n";
			print $dotfh "\n";
		}

		foreach my $e (@{$g->{'edges'}}) {
			foreach my $src (keys %$e) {
				my $dst = $e->{$src};
				printf $dotfh ("\t%s -> %s\n", quote($src), quote($dst));
			}
		}

		print $dotfh "}\n";
		print $dotfh "\n";
	}
}

my $opt_verbose = 0;
my $opt_graph_name = undef;
my $opt_dot_file = undef;
my $opt_pkg_globs = [];
if (!GetOptions('h|help'    => sub { usage; },
                'n|name=s'  => \$opt_graph_name,
                'v|verbose' => \$opt_verbose)) {
	msg_exit(0);
}
$opt_dot_file = ((scalar @ARGV > 0) ? shift @ARGV : '-');
if (scalar(@ARGV) > 0) {
	@$opt_pkg_globs = @ARGV
}
else {
	msg_exit(1, 'Missing <pkg-glob>.');
}
if (!defined($opt_graph_name)) {
	$opt_graph_name = $opt_pkg_globs->[0];
}

#print "\$opt_verbose   : $opt_verbose\n";
#print "\$opt_dot_file  : $opt_dot_file\n";
#print "\$opt_pkg_globs : @$opt_pkg_globs\n";

my $dotfh;
if ($opt_dot_file ne '-') {
	open $dotfh, '>', $opt_dot_file;
}
else {
	$dotfh = \*STDOUT;
}

pkginfo2dot($opt_graph_name, $dotfh, @$opt_pkg_globs);

if ($opt_dot_file ne '-') {
	close $dotfh;
}


