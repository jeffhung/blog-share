#!/usr/bin/perl -w
# ---------------------------------------------------------------------------
# dsw2dot.pl - Extract and draw VC6 project dependencies.
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
# ----------------------------------------------------------------------------

use utf8;
use strict;
use warnings;
use File::Basename;
use Getopt::Long;
use ADE::Parser::VC6;
use JSON; # for --cluster
use List::Util qw(first);

my ($__exe_name__) = (basename($0));
my ($__revision__) = ('$Rev: 365 $' =~ m/(\d+)/o);
my ($__rev_date__) = ('$Date: 2008-10-21 10:48:05 +0800 (Tue, 21 Oct 2008) $' =~ m/(\d{4}-\d{2}-\d{2})/o);

sub usage
{
	print STDERR <<"EOF";
Usage: $__exe_name__ [ <option> ... ] <dsw-file> <dot-file>

Generate graphviz digraph script <dot-file> according to project dependencies
that parsed from VC6 workspace file <dsw-file>.

Options:

  -h,--help            Show this help message.
  --rankdir <rd>       Set drawing rank direction <rd> to TB (top-to-bottom),
                       LR (left-to-right), RL (right-to-left), or BT
                       (bottom-to-top).  (default: TB)
  --coloring <color>   Read node coloring information from <color>, which is
                       in JSON format.
  --cluster <cluster>  Read clustering information from <cluster>, which is
                       in JSON format.
  --hide <project>     Hide projects <project>.
  --png <png-file>     Output PNG format from <dot-file>, too.
  -v,--verbose         Show verbose progress messages.

Revision: r$__revision__ ($__rev_date__)
EOF
	exit(0);
}

sub msg_exit
{
	my $ex = ((scalar(@_) > 0) ? shift @_ : 0);
	foreach my $m (@_) {
		print STDERR "ERROR: $m\n";
	}
	print STDERR <<"EOF";
Usage: $__exe_name__ [ <option> ... ] <dsw-file> <dot-file>
Type '$__exe_name__ --help' for usage.
EOF
	exit($ex);
}

my $opt_verbose = 0;
my $opt_rankdir = 'TB';
my $opt_color = undef;
my $opt_cluster = undef;
my @opt_hide_projects;
my $opt_png_file = undef;
if (!GetOptions('h|help'     => sub { usage; },
                'rankdir=s'  => \$opt_rankdir,
                'coloring=s' => \$opt_color,
                'cluster=s'  => \$opt_cluster,
                'hide=s'     => \@opt_hide_projects,
                'png=s'      => \$opt_png_file,
                'v|verbose'  => \$opt_verbose)) {
	msg_exit(0);
}
my $arg_dsw_file = shift @ARGV || msg_exit(1, 'Missing <dsw-file>.');
my $arg_dot_file = shift @ARGV || msg_exit(1, 'Missing <dot-file>.');
if ($opt_rankdir !~ m/TB|LR|RL|BT/o) {
	msg_exit(1, "Bad <rd>: $opt_rankdir");
}

my $dot_version = `dot -V 2>&1`;
my ($dot_major_version, $dot_minor_version) = ($dot_version =~ m/(\d+)\.(\d+)\./o);

my $dot_options = { # default options
	'digraph' => {
		'fontsize'    => 10,
		'bgcolor'     => 'white', #'transparent',
#		'concentrate' => 'true',
		'splines'     => 'spline',
	},
	'node'  => {
		'shape'    => (($dot_minor_version >= 15) ? 'component' : 'record'),
		'fontsize' => 10,
		'fontname'    => 'Bitstream Vera Sans Mono',
	},
	'edge'  => {
		'fontsize'  => 8,
		'arrowhead' => 'vee', # or 'diamond', 'onormal'
		'arrowsize' => 0.5,
		'style'     => 'dashed', # or 'dotted'
#		'label'     => '<<depends on>>',
	},
};
if ($opt_rankdir ne 'TB') {
	$dot_options->{'digraph'}->{'rankdir'} = $opt_rankdir;
}
my $line = '';
if (defined($opt_color)) {
	open(my $color_fh, '<:encoding(utf8)', $opt_color)
		or msg_exit(2, "Cannot open $opt_color: $!");
	my $color_json = '';
	while ($line = <$color_fh>) {
		$color_json .= $line;
	}
	close($color_fh);
	$dot_options->{'node-colors'} = jsonToObj($color_json);
}
if (defined($opt_cluster)) {
	open(my $cluster_fh, '<:encoding(utf8)', $opt_cluster)
		or msg_exit(2, "Cannot open $opt_cluster: $!");
	my $cluster_json = '';
	while ($line = <$cluster_fh>) {
		$cluster_json .= $line;
	}
	close($cluster_fh);
	$dot_options->{'clusters'} = jsonToObj($cluster_json);
}
$dot_options->{'hide-projects'} = [];
@{$dot_options->{'hide-projects'}} = @opt_hide_projects;

_dsw2dot($arg_dsw_file, $arg_dot_file, $dot_options);

if (defined($opt_png_file)) {
	die unless defined($arg_dot_file);
	my $cmd = "dot -Tpng -o \"$opt_png_file\" \"$arg_dot_file\"";
#	print STDERR "CMD> $cmd\n";
	system($cmd);
}

sub _dsw2dot
{
	my ($dsw_file, $dot_file, $dot_options) = @_;

	my $vc6_parser = new ADE::Parser::VC6;
	my $dsw_info = $vc6_parser->dsw_info($dsw_file);

	my $dot_script = '';

	$dot_script .= sprintf("digraph %s {\n", $dsw_info->name());
	map {
		$dot_script .= sprintf(
			"\t%s = %s\n",
			$_,
			_quote_value($dot_options->{'digraph'}->{$_})
		);
	} keys %{$dot_options->{'digraph'}};
	$dot_script .= "\n";
	$dot_script .= "\t// general node style\n";
	$dot_script .= "\tnode [\n";
	map {
		$dot_script .= sprintf(
			"\t\t%s = %s\n",
			$_,
			_quote_value($dot_options->{'node'}->{$_})
		);
	} keys %{$dot_options->{'node'}};
	$dot_script .= "\t]\n";
	$dot_script .= "\n";
	$dot_script .= "\t// general edge style\n";
	$dot_script .= "\tedge [\n";
	map {
		$dot_script .= sprintf(
			"\t\t%s = %s\n",
			$_,
			_quote_value($dot_options->{'edge'}->{$_})
		);
	} keys %{$dot_options->{'edge'}};
	$dot_script .= "\t]\n";

	$dot_script .= "\n\t//\n\t// node list\n\t//\n\n";
	my @project_printed;
	if (defined($dot_options->{'clusters'})) {
		my $cluster_serial = 0;
		foreach my $c (sort keys %{$dot_options->{'clusters'}}) {
			my $cluster = $dot_options->{'clusters'}->{$c};

			my $one_in_projects = 0;
			foreach my $p (@$cluster) {
				if (defined(first { defined($_) && ($_ eq $p) } $dsw_info->project_names())) {
					$one_in_projects = 1;
					last; # foreach
				}
			}
			if ($one_in_projects) {
				$dot_script .= sprintf("\tsubgraph cluster%d {\n", ++$cluster_serial);
				$dot_script .= "\t\tlabel = \"$c\";\n";
				$dot_script .= "\t\tstyle = solid;\n";
				$dot_script .= "\t\tcolor = black;\n";
				foreach my $p (sort @$cluster) {
					if (defined(first { defined($_) && ($_ eq $p) } $dsw_info->project_names())) {
						$dot_script .= sprintf(
							"%s\t\t%s%s;\n",
							(grep(/$p/, @{$dot_options->{'hide-projects'}}) ? '//' : ''),
							sprintf('"%s"', $p), _dot_nodestyle($p, $dot_options)
						);
						push(@project_printed, $p);
					}
				}
				$dot_script .= "\t}\n";
				$dot_script .= "\n";
			}
		}
	}

	$dot_script .= "\t// Non-clustered Projects\n";
	foreach my $p (sort $dsw_info->project_names()) {
		if (!defined(first { defined($_) && ($_ eq $p) } @project_printed)) {
			$dot_script .= sprintf(
				"%s\t%s%s;\n",
				(grep(/$p/, @{$dot_options->{'hide-projects'}}) ? '//' : ''),
				sprintf('"%s"', $p), _dot_nodestyle($p, $dot_options)
			);
		}
	}

	foreach my $p (sort $dsw_info->project_names()) {
		$dot_script .= "\n\t// Dependencies of $p\n";
		foreach my $dp (sort $dsw_info->project_depends_on($p)) {
			$dot_script .= sprintf(
				"%s\t%-24s -> %-24s;\n",
				(
					grep(/$p/,  @{$dot_options->{'hide-projects'}}) ||
					grep(/$dp/, @{$dot_options->{'hide-projects'}}) ? '//' : ''
				),
				sprintf('"%s"', $p),
				sprintf('"%s"', $dp)
			);
		}
	}
	$dot_script .= "\n}\n";
	$dot_script .= "\n";

	open my $dotfh, '>', $dot_file;
	print $dotfh $dot_script;
	close $dotfh;
}

sub _quote_value
{
	my ($v) = @_;
	return (($v =~ m/^[0-9]+$/o) ? $v : "\"$v\"");
}

sub _dot_nodestyle
{
	my ($node, $dot_options) = @_;
	foreach my $c (keys %{$dot_options->{'node-colors'}}) {
		my $projects = $dot_options->{'node-colors'}->{$c};
		if (grep(/$node/, @$projects)) {
			return " [ style = \"filled\", fillcolor = \"$c\" ]";
		}
	}
	return '';
}

