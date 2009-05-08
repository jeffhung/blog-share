#!/usr/bin/perl -w
# ---------------------------------------------------------------------------
# wp2docbook.pl - Perl script to convert wordpress dump file to docbook XML
# files.
# Copyright (c) 2007-2009, Jeff Hung
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

# @see http://developer.apple.com/internet/webcontent/xmltransformations.html
# @see http://www.badgers-in-foil.co.uk/projects/docbook-css/
# @see http://www.w3.org/TR/xml-stylesheet/
# @see http://www.brainbell.com/articles/xml/Styling_XML_with_CSS/XML_CSS_and_Internet_Explorer.html

package HtmlAttrCleaner;
use strict;
use utf8;
use HTML::Filter;

our @ISA=qw(HTML::Filter);
sub output { push(@{$_[0]->{fhtml}}, $_[1]); }
sub filtered_html { join('', @{$_[0]->{fhtml}}); }
sub start
{
	my $self = shift or die;
	my ($tagname, $attrs, $attrseq, $text) = @_;
	foreach my $name (keys %$attrs) {
		my $value = $attrs->{$name};
		if ($value) {
			$value = xmlspecialchars_($value);
			$attrs->{$name} = $value;
		}
	}
	$text = "<$tagname";
	foreach my $attr_name (@$attrseq) {
		next if ($attr_name =~ m/\//o);
		$text .= " $attr_name=\"$attrs->{$attr_name}\"";
	}
	$text .= '>';
	$self->output($text);
}

sub xmlspecialchars_
{
	my $s = shift or die;
	$s =~ s/&/&amp;/go;
	$s =~ s/</&lt;/go;
	$s =~ s/>/&gt;/go;
	$s =~ s/'/&apos;/go;
	$s =~ s/"/&quot;/go;
	return $s;
}

1;

package main;
use strict;
use utf8;
use File::Basename;
use Getopt::Long;
use XML::DOM;
use File::Path;

my ($__exe_name__) = (basename($0));
my ($__revision__) = ('$Rev: 113 $' =~ m/(\d+)/o);
my ($__rev_date__) = ('$Date: 2008-03-13 02:46:55 +0800 (Thu, 13 Mar 2008) $' =~ m/(\d{4}-\d{2}-\d{2})/o);

sub usage
{
	print STDERR <<"EOF";
Usage: $__exe_name__ [ <option> ... ] <wp-dump-file> <docbook-file>

Convert wordpress dump file to DocBook format.

Options:

  -h,--help                   Show this help message.
  -v,--verbose                Show verbose progress messages.
  -s,--section-wrap           Wrap article with at least one <section>.
  -p,--post <post-id>         Convert only post #<post-id>.
  --split <articles-dir>      Split individual articles to <articles-dir>.
  --css-stylesheet <css-uri>  URI, either absolute or relative, of the CSS
                              stylesheet for the generated DocBook XML
                              document.  Can be specified many times, and will
                              be listed in the command-line order.

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
Usage: $__exe_name__ [ <option> ... ] <wp-dump-file> <docbook-file>
Type '$__exe_name__ --help' for usage.
EOF
	exit($ex);
}

my $opt_verbose = 0;
my $opt_section_wrap = 0;
my @opt_posts;
my @opt_css_uris;
my $opt_articles_dir = undef;
if (!GetOptions('h|help'           => sub { usage; },
                's|section-wrap'   => \$opt_section_wrap,
                'p|post=i'         => \@opt_posts,
                'split=s'          => \$opt_articles_dir,
                'css-stylesheet=s' => \@opt_css_uris,
                'v|verbose'        => \$opt_verbose)) {
	msg_exit(0);
}
my $arg_wp_dump_file = shift @ARGV or msg_exit(1, 'Missing <wp-dump-file>');
my $arg_docbook_file = shift @ARGV or msg_exit(1, 'Missing <docbook-file>');

my $options = { posts => @opt_posts };
wordpress_dump_to_docbook($arg_wp_dump_file, $arg_docbook_file, $options);

sub value_in_list
{
	my $value = shift or die;
	my @list  = shift or die;
	foreach my $l (@list) {
		if ($value eq $l) {
			return 1;
		}
	}
	return 0;
}

sub read_text_file
{
 	my $path = shift or die;
	my ($encoding) = (shift or 'utf8');

	my $fh;
	if ($path ne '-') {
		open($fh, "<:encoding($encoding)", $path)
			or msg_exit(2, "Cannot open '$path' for read: $!");
	}
	else {
		$fh = \*STDIN;
	}
	my $content = '';
	while (my $line = <$fh>) {
		$content .= $line;
	}
	if ($path ne '-') {
		close($fh);
	}
	return $content;
}

sub write_text_file
{
	my $path = shift or die;
	my $content = shift or die;
	my ($encoding) = (shift or 'utf8');

	my $fh;
	if ($path ne '-') {
		open($fh, ">:encoding($encoding)", $path)
			or msg_exit(2, "Cannot open '$path' for write: $!");
	}
	else {
		$fh = \*STDOUT;
	}
	print $fh $content;
	if ($path ne '-') {
		close($fh);
	}
}

##
# Remove XML DOM node $node, and move its child nodes to its parent node at
# the position of $node.
#
sub xmldom_node_remove
{
	my $node = shift or die;

	my $parent_node = $node->getParentNode();
	while ($node->hasChildNodes()) {
		my $kid = $node->removeChild($node->getFirstChild());
		$parent_node->insertBefore($kid, $node);
	}
	$parent_node->removeChild($node);
	$node->dispose();
}

##
# Purge XML DOM node $node and its all child nodes recursively.
#
sub xmldom_node_purge
{
	my $node = shift or die;

	$node->getParentNode()->removeChild($node);
	$node->dispose();
}

sub xmldom_node_replace
{
	my $old_node = shift or die;
	my $new_node = shift or die;

	my $parent_node = $old_node->getParentNode();
	if ($parent_node) {
		while ($old_node->hasChildNodes()) {
			my $kid = $old_node->removeChild($old_node->getFirstChild());
			$new_node->appendChild($kid);
		}
		$parent_node->replaceChild($new_node, $old_node);
	}
}

sub in_array_
{
	my $v = shift or die;
	my @a = @_;
	foreach my $x (@a) {
		return 1 if ($x eq $v);
	}
	return 0;
}

sub xmldom_parent_element
{
	my $node = shift or die;
	while ($node = $node->getParentNode()) {
		if ($node->getNodeType() == XML::DOM::ELEMENT_NODE) {
			return $node;
		}
	}
	return undef;
}

sub xmldom_next_sibling_element
{
	my $elem = shift or die;
	die unless ($elem->getNodeType() == XML::DOM::ELEMENT_NODE);
	my $node = $elem;
	while ($node = $node->getNextSibling()) {
		if ($node->getNodeType() == XML::DOM::ELEMENT_NODE) {
			return $node;
		}
	}
	return undef;
}

sub xmldom_first_child_element
{
	my $node = shift or die;
	my $child_nodes = $node->getChildNodes();
	foreach my $child_node (@$child_nodes) {
		if ($child_node->getNodeType() == XML::DOM::ELEMENT_NODE) {
			return $child_node;
		}
	}
#	print STDERR "[no element found in 1st level]";
	# no element node found in first level child nodes
	# search recursively
	foreach my $child_node (@$child_nodes) {
		my $x = xmldom_first_child_element($child_node);
		return $x if ($x);
	}
	return undef;
}

##
# Given a XML DOM element, it contains only text nodes recursively
#
sub xmldom_only_text_child_nodes
{
	my $node = shift or die;

	if ($node->getNodeType() == XML::DOM::TEXT_NODE) {
		return 1;
	}
	my $is_only_text = 0;
	my $child_nodes = $node->getChildNodes();
	foreach my $child_node (@$child_nodes) {
		$is_only_text = xmldom_only_text_child_nodes($child_node);
		last if (!$is_only_text); # foreach
	}
	return $is_only_text;
}

sub xmldom_element_match
{
	my $elem = shift or die;
	my $spec = shift or die;

	if ($spec->{'tag_name'}) {
		if ($elem->getTagName() ne $spec->{'tag_name'}) {
			return 0;
		}
	}
	if ($spec->{'required_attributes'}) {
		foreach my $required_attr (@{$spec->{'required_attributes'}}) {
			my $no_required_attr = 1;
			my $attr_nodes = $elem->getAttributes();
			for (my $i = 0; $i < $attr_nodes->getLength(); ++$i) {
				my $attr_node = $attr_nodes->item($i);
				my $attr_name = $attr_node->getName();
				if ($attr_name eq $required_attr) {
					$no_required_attr = 0;
					last; # for
				}
			}
			return 0 if ($no_required_attr);
		}
	}
	if ($spec->{'required_classes'}) {
		my $class_attr = $elem->getAttribute('class');
		my @classes = split(/\s+/, $class_attr);
		foreach my $required_class (@{$spec->{'required_classes'}}) {
			if (!in_array_($required_class, @classes)) {
				return 0;
			}
		}
	}
	if ($spec->{'parent_spec'}) {
		my $parent_elem = xmldpm_parent_element($elem);
		if ($parent_elem) {
			if (!xmldom_element_match($parent_elem, $spec->{'parent_spec'})) {
				return 0;
			}
		}
		else {
			return 0;
		}
	}
	return 1;
}

##
# Find a list of XML DOM elements that matching given criteria.
#
sub xmldom_element_find
{
	my $base_elem = shift or die; # starting point
	my $spec = shift or die;

	my $found_elems = []; # type: XML::DOM::Element
	my $elems = $base_elem->getElementsByTagName($spec->{'tag_name'});
	for (my $i = 0; $i < $elems->getLength(); ++$i) {
		my $elem = $elems->item($i);
		if (xmldom_element_match($elem, $spec)) {
			push(@$found_elems, $elem);
		}
	}
	return $found_elems;
}


#sub xmlspecialchars
#{
#	my $s = shift or die;
#	$s =~ s/&/&amp;/go;
#	$s =~ s/</&lt;/go;
#	$s =~ s/>/&gt;/go;
#	$s =~ s/'/&apos;/go;
#	$s =~ s/"/&quot;/go;
#	return $s;
#}

sub xml_clean_attr_values
{
	my $incomplete_xml = shift or die;

	my $hf = new HtmlAttrCleaner();
	$hf->parse($incomplete_xml);
	return $hf->filtered_html();

	# TODO: Use HTML::Parser instead?!
#	use HTML::TagFilter;
#	my $tf = new HTML::TagFilter(
##		log_rejects => 1,
##		verbose => 1,
#		on_open_tag => sub {
#			my ($self, $tag, $attributes, $sequence) = @_;
#			foreach my $name (@$sequence) {
#				my $value = $attributes->{$name};
##				print STDERR "Processing attribute '$name': $value\n";
#				$value = xmlspecialchars($value);
#				$attributes->{$name} = $value;
#			}
#		},
#	);
#	$tf->parse($incomplete_xml);
#	# Report rejected tags/attributes/...
#	# TODO: We hope not rejecting anything.
##	foreach my $report ($tf->report()) {
##		foreach my $k (keys %$report) {
##			print STDERR "\n[HTML::TagFilter: $k => $report->{$k}]";
##		}
##	}
#	return $tf->output();
}

sub tidy_xml_file
{
	my $xml_file = shift or die;
	print STDERR "Tidy XML file '$xml_file'...";
# jeffhung.20070816: Using tidy will break whitespaces in <programlisting>.
#	`tidy -quiet -xml -indent -wrap 79 -utf8 -modify $xml_file`;
	print STDERR " [done]\n";
}


##
# Clone DOM node $node on (maybe) different DOM document $doc.
#
sub xmldom_clone_across_doc
{
	my $node = shift or die;
	my $doc = shift or die;

	my $new_node;
	my $node_type = $node->getNodeType();
	if ($node_type == XML::DOM::UNKNOWN_NODE) {
		die "UNKNOWN_NODE found";
	}
	elsif ($node_type == XML::DOM::ELEMENT_NODE) {
		$new_node = $doc->createElement($node->getTagName());
		my $attr_nodes = $node->getAttributes();
		for (my $i = 0; $i < $attr_nodes->getLength(); ++$i) {
			my $attr_node = $attr_nodes->item($i);
			$new_node->setAttribute($attr_node->getName(), $attr_node->getValue());
		}
	}
#	elsif ($node_type == XML::DOM::ATTRIBUTE_NODE) {
#		my $attr_name = $node->getName();
#		my $attr_value = $node->getValue();
#		print STDERR "[attribute:$attr_name=\"$attr_value\"]";
#		$new_node = $doc->createAttribute($node->getName(), $node->getValue());
#	}
	elsif ($node_type == XML::DOM::TEXT_NODE) {
		$new_node = $doc->createTextNode($node->getNodeValue());
	}
	elsif ($node_type == XML::DOM::CDATA_SECTION_NODE) {
		$new_node = $doc->createCDATASection($node->getData());
	}
	elsif ($node_type == XML::DOM::ENTITY_REFERENCE_NODE) {
		$new_node = $doc->createEntityReference($node->getNodeValue());
	}
#	elsif($node_type == XML::DOM::ENTITY_NODE) {
#		$new_node = $doc->createEntity(); # ...
#	}
#	elsif($node_type == XML::DOM::PROCESSING_INSTRUCTION_NODE) {
#	}
	elsif($node_type == XML::DOM::COMMENT_NODE) {
		$new_node = $doc->createComment($node->getData());
	}
	elsif($node_type == XML::DOM::DOCUMENT_NODE) {
		die "Should not encounter document node";
	}
	elsif($node_type == XML::DOM::DOCUMENT_TYPE_NODE) {
		die "Should not encounter document-type node";
	}
#	elsif($node_type == XML::DOM::DOCUMENT_FRAGMENT_NODE) {
#	}
#	elsif($node_type == XML::DOM::NOTATION_NODE) {
#	}
#	elsif($node_type == XML::DOM::ELEMENT_DECL_NODE) {
#	}
#	elsif($node_type == XML::DOM::ATT_DEF_NODE) {
#	}
	elsif($node_type == XML::DOM::XML_DECL_NODE) {
		die "Should not encounter xml-decl node";
	}
#	elsif($node_type == XML::DOM::ATTLIST_DECL_NODE) {
#	}
	else {
		die "Unknown node_type: $node_type";
	}

	# Clone child nodes
	foreach my $child ($node->getChildNodes()) {
		$new_node->appendChild(xmldom_clone_across_doc($child, $doc));
	}

	return $new_node;
}

##
# Get text value inside a XML element.
#
sub xmldom_element_text_value
{
	my $elem = shift or die;
	die unless ($elem->getNodeType() == XML::DOM::ELEMENT_NODE);
	my $text = '';
	foreach my $child ($elem->getChildNodes()) {
		if ($child->getNodeType() == XML::DOM::TEXT_NODE) {
			my $fragment = $child->getNodeValue();
			$text .= $fragment;
		}
	}
	return $text;
}

sub wordrpess_item_content_to_docbook_article_fragment
{
	my $wordpress_item_content = shift or die;
	my $docbook_document = shift or die;

	write_text_file(sprintf('item-%d.xml', __LINE__), $wordpress_item_content);

	my $content = "<?xml version=\"1.0\"?>\n";
	$content .= '<content>';
	$content .= xml_clean_attr_values($wordpress_item_content);
	$content .= '</content>';

	write_text_file(sprintf('content-%d.xml', __LINE__), $content);

	# Deal with unmatched tags
	$content =~ s/<\s*br[^>]*>/<br\/>/go;
	$content =~ s/<\s*hr[^>]*>/<hr\/>/go;
	$content =~ s/<\s*img([^>]*)>/<img$1\/>/go;

	# http://www.w3schools.com/tags/ref_entities.asp
	# http://www.digitalmediaminute.com/reference/entity/index.php
	# http://www.danshort.com/HTMLentities/index.php
	# http://www.w3.org/TR/xhtml-modularization/dtd_module_defs.html#a_xhtml_character_entities

	$content =~ s/&nbsp;/&#160;/go;    # no-break space = non-breaking space, U+00A0 ISOnum
	$content =~ s/&iexcl;/&#161;/go;   # inverted exclamation mark, U+00A1 ISOnum
	$content =~ s/&cent;/&#162;/go;    # cent sign, U+00A2 ISOnum
	$content =~ s/&pound;/&#163;/go;   # pound sign, U+00A3 ISOnum
	$content =~ s/&curren;/&#164;/go;  # currency sign, U+00A4 ISOnum
	$content =~ s/&yen;/&#165;/go;     # yen sign = yuan sign, U+00A5 ISOnum
	$content =~ s/&brvbar;/&#166;/go;  # broken bar = broken vertical bar, U+00A6 ISOnum
	$content =~ s/&sect;/&#167;/go;    # section sign, U+00A7 ISOnum
	$content =~ s/&uml;/&#168;/go;     # diaeresis = spacing diaeresis, U+00A8 ISOdia
	$content =~ s/&copy;/&#169;/go;    # copyright sign, U+00A9 ISOnum
	$content =~ s/&ordf;/&#170;/go;    # feminine ordinal indicator, U+00AA ISOnum
	$content =~ s/&laquo;/&#171;/go;   # left-pointing double angle quotation mark = left pointing guillemet, U+00AB ISOnum
	$content =~ s/&not;/&#172;/go;     # not sign, U+00AC ISOnum
	$content =~ s/&shy;/&#173;/go;     # soft hyphen = discretionary hyphen, U+00AD ISOnum
	$content =~ s/&reg;/&#174;/go;     # registered sign = registered trade mark sign, U+00AE ISOnum
	$content =~ s/&macr;/&#175;/go;    # macron = spacing macron = overline = APL overbar, U+00AF ISOdia
	$content =~ s/&deg;/&#176;/go;     # degree sign, U+00B0 ISOnum
	$content =~ s/&plusmn;/&#177;/go;  # plus-minus sign = plus-or-minus sign, U+00B1 ISOnum
	$content =~ s/&sup2;/&#178;/go;    # superscript two = superscript digit two = squared, U+00B2 ISOnum
	$content =~ s/&sup3;/&#179;/go;    # superscript three = superscript digit three = cubed, U+00B3 ISOnum
	$content =~ s/&acute;/&#180;/go;   # acute accent = spacing acute, U+00B4 ISOdia
	$content =~ s/&micro;/&#181;/go;   # micro sign, U+00B5 ISOnum
	$content =~ s/&para;/&#182;/go;    # pilcrow sign = paragraph sign, U+00B6 ISOnum
	$content =~ s/&middot;/&#183;/go;  # middle dot = Georgian comma = Greek middle dot, U+00B7 ISOnum
	$content =~ s/&cedil;/&#184;/go;   # cedilla = spacing cedilla, U+00B8 ISOdia
	$content =~ s/&sup1;/&#185;/go;    # superscript one = superscript digit one, U+00B9 ISOnum
	$content =~ s/&ordm;/&#186;/go;    # masculine ordinal indicator, U+00BA ISOnum
	$content =~ s/&raquo;/&#187;/go;   # right-pointing double angle quotation mark = right pointing guillemet, U+00BB ISOnum
	$content =~ s/&frac14;/&#188;/go;  # vulgar fraction one quarter = fraction one quarter, U+00BC ISOnum
	$content =~ s/&frac12;/&#189;/go;  # vulgar fraction one half = fraction one half, U+00BD ISOnum
	$content =~ s/&frac34;/&#190;/go;  # vulgar fraction three quarters = fraction three quarters, U+00BE ISOnum
	$content =~ s/&iquest;/&#191;/go;  # inverted question mark = turned question mark, U+00BF ISOnum
	$content =~ s/&Agrave;/&#192;/go;  # latin capital A with grave = latin capital A grave, U+00C0 ISOlat1
	$content =~ s/&Aacute;/&#193;/go;  # latin capital A with acute, U+00C1 ISOlat1
	$content =~ s/&Acirc;/&#194;/go;   # latin capital A with circumflex, U+00C2 ISOlat1
	$content =~ s/&Atilde;/&#195;/go;  # latin capital A with tilde, U+00C3 ISOlat1
	$content =~ s/&Auml;/&#196;/go;    # latin capital A with diaeresis, U+00C4 ISOlat1
	$content =~ s/&Aring;/&#197;/go;   # latin capital A with ring above = latin capital A ring, U+00C5 ISOlat1
	$content =~ s/&AElig;/&#198;/go;   # latin capital AE = latin capital ligature AE, U+00C6 ISOlat1
	$content =~ s/&Ccedil;/&#199;/go;  # latin capital C with cedilla, U+00C7 ISOlat1
	$content =~ s/&Egrave;/&#200;/go;  # latin capital E with grave, U+00C8 ISOlat1
	$content =~ s/&Eacute;/&#201;/go;  # latin capital E with acute, U+00C9 ISOlat1
	$content =~ s/&Ecirc;/&#202;/go;   # latin capital E with circumflex, U+00CA ISOlat1
	$content =~ s/&Euml;/&#203;/go;    # latin capital E with diaeresis, U+00CB ISOlat1
	$content =~ s/&Igrave;/&#204;/go;  # latin capital I with grave, U+00CC ISOlat1
	$content =~ s/&Iacute;/&#205;/go;  # latin capital I with acute, U+00CD ISOlat1
	$content =~ s/&Icirc;/&#206;/go;   # latin capital I with circumflex, U+00CE ISOlat1
	$content =~ s/&Iuml;/&#207;/go;    # latin capital I with diaeresis, U+00CF ISOlat1
	$content =~ s/&ETH;/&#208;/go;     # latin capital ETH, U+00D0 ISOlat1
	$content =~ s/&Ntilde;/&#209;/go;  # latin capital N with tilde, U+00D1 ISOlat1
	$content =~ s/&Ograve;/&#210;/go;  # latin capital O with grave, U+00D2 ISOlat1
	$content =~ s/&Oacute;/&#211;/go;  # latin capital O with acute, U+00D3 ISOlat1
	$content =~ s/&Ocirc;/&#212;/go;   # latin capital O with circumflex, U+00D4 ISOlat1
	$content =~ s/&Otilde;/&#213;/go;  # latin capital O with tilde, U+00D5 ISOlat1
	$content =~ s/&Ouml;/&#214;/go;    # latin capital O with diaeresis, U+00D6 ISOlat1
	$content =~ s/&times;/&#215;/go;   # multiplication sign, U+00D7 ISOnum
	$content =~ s/&Oslash;/&#216;/go;  # latin capital O with stroke = latin capital O slash, U+00D8 ISOlat1
	$content =~ s/&Ugrave;/&#217;/go;  # latin capital U with grave, U+00D9 ISOlat1
	$content =~ s/&Uacute;/&#218;/go;  # latin capital U with acute, U+00DA ISOlat1
	$content =~ s/&Ucirc;/&#219;/go;   # latin capital U with circumflex, U+00DB ISOlat1
	$content =~ s/&Uuml;/&#220;/go;    # latin capital U with diaeresis, U+00DC ISOlat1
	$content =~ s/&Yacute;/&#221;/go;  # latin capital Y with acute, U+00DD ISOlat1
	$content =~ s/&THORN;/&#222;/go;   # latin capital THORN, U+00DE ISOlat1
	$content =~ s/&szlig;/&#223;/go;   # latin small sharp s = ess-zed, U+00DF ISOlat1
	$content =~ s/&agrave;/&#224;/go;  # latin small a with grave = latin small a grave, U+00E0 ISOlat1
	$content =~ s/&aacute;/&#225;/go;  # latin small a with acute, U+00E1 ISOlat1
	$content =~ s/&acirc;/&#226;/go;   # latin small a with circumflex, U+00E2 ISOlat1
	$content =~ s/&atilde;/&#227;/go;  # latin small a with tilde, U+00E3 ISOlat1
	$content =~ s/&auml;/&#228;/go;    # latin small a with diaeresis, U+00E4 ISOlat1
	$content =~ s/&aring;/&#229;/go;   # latin small a with ring above = latin small a ring, U+00E5 ISOlat1
	$content =~ s/&aelig;/&#230;/go;   # latin small ae = latin small ligature ae, U+00E6 ISOlat1
	$content =~ s/&ccedil;/&#231;/go;  # latin small c with cedilla, U+00E7 ISOlat1
	$content =~ s/&egrave;/&#232;/go;  # latin small e with grave, U+00E8 ISOlat1
	$content =~ s/&eacute;/&#233;/go;  # latin small e with acute, U+00E9 ISOlat1
	$content =~ s/&ecirc;/&#234;/go;   # latin small e with circumflex, U+00EA ISOlat1
	$content =~ s/&euml;/&#235;/go;    # latin small e with diaeresis, U+00EB ISOlat1
	$content =~ s/&igrave;/&#236;/go;  # latin small i with grave, U+00EC ISOlat1
	$content =~ s/&iacute;/&#237;/go;  # latin small i with acute, U+00ED ISOlat1
	$content =~ s/&icirc;/&#238;/go;   # latin small i with circumflex, U+00EE ISOlat1
	$content =~ s/&iuml;/&#239;/go;    # latin small i with diaeresis, U+00EF ISOlat1
	$content =~ s/&eth;/&#240;/go;     # latin small eth, U+00F0 ISOlat1
	$content =~ s/&ntilde;/&#241;/go;  # latin small n with tilde, U+00F1 ISOlat1
	$content =~ s/&ograve;/&#242;/go;  # latin small o with grave, U+00F2 ISOlat1
	$content =~ s/&oacute;/&#243;/go;  # latin small o with acute, U+00F3 ISOlat1
	$content =~ s/&ocirc;/&#244;/go;   # latin small o with circumflex, U+00F4 ISOlat1
	$content =~ s/&otilde;/&#245;/go;  # latin small o with tilde, U+00F5 ISOlat1
	$content =~ s/&ouml;/&#246;/go;    # latin small o with diaeresis, U+00F6 ISOlat1
	$content =~ s/&divide;/&#247;/go;  # division sign, U+00F7 ISOnum
	$content =~ s/&oslash;/&#248;/go;  # latin small o with stroke, = latin small o slash, U+00F8 ISOlat1
	$content =~ s/&ugrave;/&#249;/go;  # latin small u with grave, U+00F9 ISOlat1
	$content =~ s/&uacute;/&#250;/go;  # latin small u with acute, U+00FA ISOlat1
	$content =~ s/&ucirc;/&#251;/go;   # latin small u with circumflex, U+00FB ISOlat1
	$content =~ s/&uuml;/&#252;/go;    # latin small u with diaeresis, U+00FC ISOlat1
	$content =~ s/&yacute;/&#253;/go;  # latin small y with acute, U+00FD ISOlat1
	$content =~ s/&thorn;/&#254;/go;   # latin small thorn with, U+00FE ISOlat1
	$content =~ s/&yuml;/&#255;/go;    # latin small y with diaeresis, U+00FF ISOlat1
	# end of xhtml-lat1.ent

	# ISO 8859-1 Symbol Entities
#	$content =~ s/&nbsp;/ /go;         # non-breaking space
	# Some Other Entities supported by HTML
	$content =~ s/&OElig;/&#338;/go;   # capital ligature OE
	$content =~ s/&oelig;/&#339;/go;   # small ligature oe
	$content =~ s/&Scaron;/Š/go;       # capital S with caron
	$content =~ s/&scaron;/š/go;       # small S with caron
	$content =~ s/&Yuml;/Ÿ/go;         # capital Y with diaeres
	$content =~ s/&circ;/ˆ/go;         # modifier letter circumflex accent
	$content =~ s/&tilde;/˜/go;        # small tilde
	$content =~ s/&ensp;/&#8194;/go;   # en space
	$content =~ s/&emsp;/&#8195;/go;   # em space
	$content =~ s/&thinsp;/&#8201;/go; # thin space
	$content =~ s/&zwnj;/&#8204;/go;   # zero width non-joiner
	$content =~ s/&zwj;/&#8205;/go;    # zero width joiner
	$content =~ s/&lrm;/&#8206;/go;    # left-to-right mark
	$content =~ s/&rlm;/&#8207;/go;    # right-to-left mark
	$content =~ s/&ndash;/&#8211;/go;  # en dash
	$content =~ s/&mdash;/&#8212;/go;  # em dash
	$content =~ s/&lsquo;/&#8216;/go;  # left single quotation mark
	$content =~ s/&rsquo;/&#8217;/go;  # right single quotation mark
	$content =~ s/&sbquo;/&#8218;/go;  # single low-9 quotation mark
	$content =~ s/&ldquo;/&#8220;/go;  # left double quotation mark
	$content =~ s/&rdquo;/&#8221;/go;  # right double quotation mark
	$content =~ s/&bdquo;/&#8222;/go;  # double low-9 quotation mark
	$content =~ s/&dagger;/&#8224;/go; # dagger
	$content =~ s/&Dagger;/&#8225;/go; # double dagger
	$content =~ s/&hellip;/&#8230;/go; # horizontal ellipsis
	$content =~ s/&permil;/&#8240;/go; # per mille
	$content =~ s/&lsaquo;/&#8249;/go; # single left-pointing angle quotation
	$content =~ s/&rsaquo;/&#8250;/go; # single right-pointing angle quotation
#	$content =~ s///go;

	# Other html entities
	$content =~ s/&radic;/&#8730;/go;  # radical sign
	# http://www.webmasterworld.com/forum21/11238.htm
	# http://www.codingforums.com/showthread.php?threadid=30181
	# http://www.fileformat.info/info/unicode/char/00ab/index.htm
	$content =~ s/&laquo;/&#171;/go;   # left-pointing double angle quotation mark
	# http://www.fileformat.info/info/unicode/char/00bb/index.htm
	$content =~ s/&raquo;/&#187;/go;   # right-pointing double angle quotation mark
	# http://en.wikipedia.org/wiki/Interpunct
	$content =~ s/&middot;/&#183;/go;  # interpunct, middle dot

	# Greek Letters
	# http://www.danshort.com/HTMLentities/index.php?w=greek
	# http://www.w3.org/TR/xhtml-modularization/dtd_module_defs.html#a_xhtml_character_entities
	$content =~ s/&Alpha;/&#913;/go;   # greek capital letter alpha, U+0391
	$content =~ s/&Beta;/&#914;/go;    # greek capital letter beta, U+0392
	$content =~ s/&Gamma;/&#915;/go;   # greek capital letter gamma, U+0393 ISOgrk3
	$content =~ s/&Delta;/&#916;/go;   # greek capital letter delta, U+0394 ISOgrk3
	$content =~ s/&Epsilon;/&#917;/go; # greek capital letter epsilon, U+0395
	$content =~ s/&Zeta;/&#918;/go;    # greek capital letter zeta, U+0396
	$content =~ s/&Eta;/&#919;/go;     # greek capital letter eta, U+0397
	$content =~ s/&Theta;/&#920;/go;   # greek capital letter theta, U+0398 ISOgrk3
	$content =~ s/&Iota;/&#921;/go;    # greek capital letter iota, U+0399
	$content =~ s/&Kappa;/&#922;/go;   # greek capital letter kappa, U+039A
	$content =~ s/&Lambda;/&#923;/go;  # greek capital letter lambda, U+039B ISOgrk3
	$content =~ s/&Mu;/&#924;/go;      # greek capital letter mu, U+039C
	$content =~ s/&Nu;/&#925;/go;      # greek capital letter nu, U+039D
	$content =~ s/&Xi;/&#926;/go;      # greek capital letter xi, U+039E ISOgrk3
	$content =~ s/&Omicron;/&#927;/go; # greek capital letter omicron, U+039F
	$content =~ s/&Pi;/&#928;/go;      # greek capital letter pi, U+03A0 ISOgrk3
	$content =~ s/&Rho;/&#929;/go;     # greek capital letter rho, U+03A1
	# there is no Sigmaf, and no U+03A2 character either
	$content =~ s/&Sigma;/&#931;/go;   # greek capital letter sigma, U+03A3 ISOgrk3
	$content =~ s/&Tau;/&#932;/go;     # greek capital letter tau, U+03A4
	$content =~ s/&Upsilon;/&#933;/go; # greek capital letter upsilon, U+03A5 ISOgrk3
	$content =~ s/&Phi;/&#934;/go;     # greek capital letter phi, U+03A6 ISOgrk3
	$content =~ s/&Chi;/&#935;/go;     # greek capital letter chi, U+03A7
	$content =~ s/&Psi;/&#936;/go;     # greek capital letter psi, U+03A8 ISOgrk3
	$content =~ s/&Omega;/&#937;/go;   # greek capital letter omega, U+03A9 ISOgrk3
	$content =~ s/&alpha;/&#945;/go;   # greek small letter alpha, U+03B1 ISOgrk3
	$content =~ s/&beta;/&#946;/go;    # greek small letter beta, U+03B2 ISOgrk3
	$content =~ s/&gamma;/&#947;/go;   # greek small letter gamma, U+03B3 ISOgrk3
	$content =~ s/&delta;/&#948;/go;   # greek small letter delta, U+03B4 ISOgrk3
	$content =~ s/&epsilon;/&#949;/go; # greek small letter epsilon, U+03B5 ISOgrk3
	$content =~ s/&zeta;/&#950;/go;    # greek small letter zeta, U+03B6 ISOgrk3
	$content =~ s/&eta;/&#951;/go;     # greek small letter eta, U+03B7 ISOgrk3
	$content =~ s/&theta;/&#952;/go;   # greek small letter theta, U+03B8 ISOgrk3
	$content =~ s/&iota;/&#953;/go;    # greek small letter iota, U+03B9 ISOgrk3
	$content =~ s/&kappa;/&#954;/go;   # greek small letter kappa, U+03BA ISOgrk3
	$content =~ s/&lambda;/&#955;/go;  # greek small letter lambda, U+03BB ISOgrk3
	$content =~ s/&mu;/&#956;/go;      # greek small letter mu, U+03BC ISOgrk3
	$content =~ s/&nu;/&#957;/go;      # greek small letter nu, U+03BD ISOgrk3
	$content =~ s/&xi;/&#958;/go;      # greek small letter xi, U+03BE ISOgrk3
	$content =~ s/&omicron;/&#959;/go; # greek small letter omicron, U+03BF NEW
	$content =~ s/&pi;/&#960;/go;      # greek small letter pi, U+03C0 ISOgrk3
	$content =~ s/&rho;/&#961;/go;     # greek small letter rho, U+03C1 ISOgrk3
	$content =~ s/&sigmaf;/&#962;/go;  # greek small letter final sigma, U+03C2 ISOgrk3
	$content =~ s/&sigma;/&#963;/go;   # greek small letter sigma, U+03C3 ISOgrk3
	$content =~ s/&tau;/&#964;/go;     # greek small letter tau, U+03C4 ISOgrk3
	$content =~ s/&upsilon;/&#965;/go; # greek small letter upsilon, U+03C5 ISOgrk3
	$content =~ s/&phi;/&#966;/go;     # greek small letter phi, U+03C6 ISOgrk3
	$content =~ s/&chi;/&#967;/go;     # greek small letter chi, U+03C7 ISOgrk3
	$content =~ s/&psi;/&#968;/go;     # greek small letter psi, U+03C8 ISOgrk3
	$content =~ s/&omega;/&#969;/go;   # greek small letter omega, U+03C9 ISOgrk3
	$content =~ s/&thetasym;/&#977;/go;# greek small letter theta symbol, U+03D1 NEW
	$content =~ s/&upsih;/&#978;/go;   # greek upsilon with hook symbol, U+03D2 NEW
	$content =~ s/&piv;/&#982;/go;     # greek pi symbol, U+03D6 ISOgrk3

	# Letterlike Symbols
	$content =~ s/&weierp;/&#8472;/go;  # script capital P = power set = Weierstrass p, U+2118 ISOamso
	$content =~ s/&image;/&#8465;/go;   # blackletter capital I = imaginary part, U+2111 ISOamso
	$content =~ s/&real;/&#8476;/go;    # blackletter capital R = real part symbol, U+211C ISOamso
	$content =~ s/&trade;/&#8482;/go;   # trade mark sign, U+2122 ISOnum
	$content =~ s/&alefsym;/&#8501;/go; # alef symbol = first transfinite cardinal, U+2135 NEW
	# alef symbol is NOT the same as hebrew letter alef, U+05D0 although
	# the same glyph could be used to depict both characters

	# lsaquo is proposed but not yet ISO standardized
	$content =~ s/&lsaquo;/&#8249;/go; # single left-pointing angle quotation mark, U+2039 ISO proposed
	# rsaquo is proposed but not yet ISO standardized
	$content =~ s/&rsaquo;/&#8250;/go; # single right-pointing angle quotation mark, U+203A ISO proposed
	$content =~ s/&euro;/&#8364;/go;   # euro sign, U+20AC NEW

	# Miscellaneous Symbols
	# http://www.w3.org/TR/xhtml-modularization/dtd_module_defs.html#a_xhtml_character_entities
	$content =~ s/&spades;/&#9824;/go; # black spade suit, U+2660 ISOpub
	# black here seems to mean filled as opposed to hollow
	$content =~ s/&clubs;/&#9827;/go;  # black club suit = shamrock, U+2663 ISOpub
	$content =~ s/&hearts;/&#9829;/go; # black heart suit = valentine, U+2665 ISOpub
	$content =~ s/&diams;/&#9830;/go;  # black diamond suit, U+2666 ISOpub

#	write_text_file('content.html', $content);
#	tidy_xml_file('content.html');

	write_text_file(sprintf('content-%d.xml', __LINE__), $content);
	my $xml_parser = new XML::DOM::Parser;
	my $doc = $xml_parser->parse($content);
#	write_text_file(sprintf('fixed-%d.xml', __LINE__), $doc->toString());

	# replace <p> to <para>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'p',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('para');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <strong> to <emphasis>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'strong',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('emphasis');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <a href="..."> to <ulink url="...">
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'a',
			'required_attributes' => [ 'href' ],
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('ulink');
			$new_elem->setAttribute('url', $old_elem->getAttribute('href'));
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <code class="inline_code"> to <code>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'code',
			'required_classes' => [ 'inline_code' ],
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('code');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <span class="footnote"> to <footnote>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'span',
			'required_classes' => [ 'footnote' ],
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('footnote');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <img ...> with <mediaobject><imageobject><imagedata>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'img',
		});
		foreach my $old_elem (@$old_elems) {
			my $img_src = $old_elem->getAttribute('src');
			my $img_title = $old_elem->getAttribute('title');
			my $img_alt = $old_elem->getAttribute('alt');
			my $mediaobject_elem = $doc->createElement('mediaobject');
			my $imageobject_elem = $doc->createElement('imageobject');
			$mediaobject_elem->appendChild($imageobject_elem);
			if ($img_src) {
				my $imagedata_elem = $doc->createElement('imagedata');
				$imagedata_elem->setAttribute('fileref', $img_src);
				$imageobject_elem->appendChild($imagedata_elem);
			}
			my $img_text = (defined($img_title) ? $img_title : $img_alt);
			if ($img_text) {
				my $textobject_elem = $doc->createElement('textobject');
				my $phrase_elem = $doc->createElement('phrase');
				$phrase_elem->appendChild($doc->createTextNode($img_text));
				$textobject_elem->appendChild($phrase_elem);
				$mediaobject_elem->appendChild($textobject_elem);
			}
			xmldom_node_replace($old_elem, $mediaobject_elem);
			$old_elem->dispose();
		}
	}

	# replace <pre class="code"> and <pre class="docbook-programlisting"> to <programlisting>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'pre',
			'required_classes' => [ 'code' ],
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('programlisting');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'pre',
			'required_classes' => [ 'docbook-programlisting' ],
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('programlisting');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <pre class="terminal_screen"> and <pre class="docbook-screen"> to <screen>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'pre',
			'required_classes' => [ 'terminal_screen' ],
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('screen');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'pre',
			'required_classes' => [ 'docbook-screen' ],
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('screen');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <pre> to <literallayout>
	# NOTE: This must after processing other DocBook line-specific block
	#       elements that has semantic associated with.
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'pre',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('literallayout');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <br/> to "\n"
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'br',
		});
		foreach my $old_elem (@$old_elems) {
#			xmldom_node_remove($old_elem);
			my $new_node = $doc->createTextNode("\n");
			xmldom_node_replace($old_elem, $new_node);
			$old_elem->dispose();
		}
	}

	# replace <para> containing only whitespaces text nodes
	{
		my $has_empty_para = 0;
		do {
			$has_empty_para = 0;
			my $elems = $doc->getDocumentElement()->getElementsByTagName('para');
			foreach my $elem (@$elems) {
				my $elem_text = '';
				my $has_child_element = 0;
				my $child_nodes = $elem->getChildNodes();
				foreach my $child_node (@$child_nodes) {
					if ($child_node->getNodeType() == XML::DOM::ELEMENT_NODE) {
						$has_child_element = 1;
						last; # foreach
					}
					elsif ($child_node->getNodeType() == XML::DOM::TEXT_NODE) {
						$elem_text .= $child_node->getData();
					}
				}
				if (!$has_child_element && ($elem_text =~ m/^\s+$/o)) {
					xmldom_node_purge($elem);
					$has_empty_para = 1;
					last; # foreach
				}
			}
		} while ($has_empty_para);
	}

	# replace <para><strong>#TEXT with <section><title>
	# - step 1: replace <para><strong>#TEXT with <title>
	{
		my $repeat;
		do {
			$repeat = 0;
			my $para_elems = $doc->getDocumentElement()->getElementsByTagName('para');
			foreach my $para_elem (@$para_elems) {
				my $emphasis_elem = xmldom_first_child_element($para_elem);
				if ($emphasis_elem && ($emphasis_elem->getTagName() eq 'emphasis')) {
#					print STDERR "[<para><emphasis>]";
					if (xmldom_only_text_child_nodes($emphasis_elem)) {
#						print STDERR "[Can insert <section><title>]";
						xmldom_node_remove($emphasis_elem);
						my $title_elem = $doc->createElement('title');
						xmldom_node_replace($para_elem, $title_elem);
						$repeat = 1;
						last; # foreach
					}
				}
			}
		} while ($repeat);
	}
#	write_text_file(sprintf('fixed-%d.xml', __LINE__), $doc->toString());
	# - step 2: add <section>s according to <title> position.
	{
		my $title_elems = $doc->getDocumentElement()->getElementsByTagName('title');
		for (my $i = 0; $i < $title_elems->getLength(); ++$i) {
			my $section_elem = $doc->createElement('section');
			my $node = $title_elems->item($i);
			$node->getParentNode()->insertBefore($section_elem, $node);
			do {
				my $x = $node;
				$node = $node->getNextSibling();
				$section_elem->appendChild($x->getParentNode()->removeChild($x));
			} while ($node &&
			         !(($node->getNodeType() == XML::DOM::ELEMENT_NODE) &&
			           ($node->getTagName() eq 'title')));
		}
	}
#	write_text_file(sprintf('fixed-%d.xml', __LINE__), $doc->toString());

	# replace <dl> with <glosslist>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'dl',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('glosslist');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	# replace <dt> with <glossterm>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'dt',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('glossterm');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	# replace <dd> with <glossdef>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'dd',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('glossdef');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	# surrand <glossterm> which follows <glossdef> with <glossentry>
	{
		my $repeat;
		my $glossterm_elems = $doc->getDocumentElement()->getElementsByTagName('glossterm');
		foreach my $glossterm_elem (@$glossterm_elems) {
			my $parent_elem = xmldom_parent_element($glossterm_elem);
			next if ($parent_elem->getTagName() eq 'glossentry'); # it's already done
			my $glossdef_elem = xmldom_next_sibling_element($glossterm_elem);
			if (defined($glossdef_elem) && ($glossdef_elem->getTagName() eq 'glossdef')) {
				my $glossentry_elem = $doc->createElement('glossentry');
				$glossterm_elem->getParentNode()->insertBefore($glossentry_elem, $glossterm_elem);
				$glossentry_elem->appendChild($glossterm_elem->getParentNode()->removeChild($glossterm_elem));
				$glossentry_elem->appendChild($glossdef_elem->getParentNode()->removeChild($glossdef_elem));
			}
		}
	}

	# replace <ul> with <itemizedlist>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'ul',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('itemizedlist');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	# replace <ol> with <itemizedlist>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'ol',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('orderedlist');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	# replace <li> with <listitem>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'li',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('listitem');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <em> with <quote>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'em',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('quote');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	# replace <sup> with <superscript>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'sup',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('superscript');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}
	# replace <sub> with <subscript>
	{
		my $old_elems = xmldom_element_find($doc->getDocumentElement(), {
			'tag_name' => 'sub',
		});
		foreach my $old_elem (@$old_elems) {
			my $new_elem = $doc->createElement('subscript');
			xmldom_node_replace($old_elem, $new_elem);
			$old_elem->dispose();
		}
	}

	my $cloned_content_elem = xmldom_clone_across_doc($doc->getDocumentElement(), $docbook_document);
#	write_text_file(sprintf('fixed-%d.xml', __LINE__), $cloned_content_elem->toString());
	my $docbook_fragment = $docbook_document->createDocumentFragment();
	foreach my $cloned_child ($cloned_content_elem->getChildNodes()) {
		$docbook_fragment->appendChild($cloned_child->cloneNode(1));
	}

	return $docbook_fragment;
}

##
# Convert wordpress-dump's <item> to docbook's <article>
#
# Returns (XML::DOM::Element of <article>, $meta)
#
sub wordpress_item_to_docbook_article
{
	my $wordpress_item_postid = shift or die;
	my $wordpress_item_elem = shift or die;
	die unless ($wordpress_item_elem->getNodeType() == XML::DOM::ELEMENT_NODE);
	my $docbook_document = shift or die;

	print STDERR "Converting article #$wordpress_item_postid...";

	my $meta = {};

	#
	# Parse
	#

	my $title_elems = $wordpress_item_elem->getElementsByTagName('title');
	die "Missing <title>" unless ($title_elems->getLength() > 0);
	$meta->{'title'} = xmldom_element_text_value($title_elems->item(0));

	my $postid_elems = $wordpress_item_elem->getElementsByTagName('wp:post_id');
	die "Missing <wp:post_id>" unless ($postid_elems->getLength() > 0);
	$meta->{'wp:post_id'} = xmldom_element_text_value($postid_elems->item(0));
	die "Mismatched <wp:post_id>" unless ($meta->{'wp:post_id'} == $wordpress_item_postid);

	my $guid_elems = $wordpress_item_elem->getElementsByTagName('guid');
	die "Missing <guid>" unless ($guid_elems->getLength() > 0);
	$meta->{'guid'} = xmldom_element_text_value($guid_elems->item(0));

	my $link_elems = $wordpress_item_elem->getElementsByTagName('link');
	die "Missing <link>" unless ($link_elems->getLength() > 0);
	$meta->{'link'} = xmldom_element_text_value($link_elems->item(0));

	my $post_name_elems = $wordpress_item_elem->getElementsByTagName('wp:post_name');
	die "Missing <wp:post_name>" unless ($post_name_elems->getLength() > 0);
	$meta->{'wp:post_name'} = xmldom_element_text_value($post_name_elems->item(0));

	my $status_elems = $wordpress_item_elem->getElementsByTagName('wp:status');
	die "Missing <wp:status>" unless ($status_elems->getLength() > 0);
	$meta->{'wp:status'} = xmldom_element_text_value($status_elems->item(0));

	my $pubdate_elems = $wordpress_item_elem->getElementsByTagName('pubDate');
	die "Missing <pubDate>" unless ($pubdate_elems->getLength() > 0);
	$meta->{'pubDate'} = xmldom_element_text_value($pubdate_elems->item(0));

	my $postdate_elems = $wordpress_item_elem->getElementsByTagName('wp:post_date');
	die "Missing <wp:post_date>" unless ($postdate_elems->getLength() > 0);
	$meta->{'wp:post_date'} = xmldom_element_text_value($postdate_elems->item(0));

	my $postdategmt_elems = $wordpress_item_elem->getElementsByTagName('wp:post_date_gmt');
	die "Missing <wp:post_date_gmt>" unless ($postdategmt_elems->getLength() > 0);
	$meta->{'wp:post_date_gmt'} = xmldom_element_text_value($postdategmt_elems->item(0));

	my $creator_elems = $wordpress_item_elem->getElementsByTagName('dc:creator');
	die "Missing <dc:creator>" unless ($creator_elems->getLength() > 0);
	$meta->{'dc:creator'} = xmldom_element_text_value($creator_elems->item(0));

	my $content_elems = $wordpress_item_elem->getElementsByTagName('content:encoded');
	die "Missing <content:encoded>" unless ($content_elems->getLength() > 0);
	my $content = xmldom_element_text_value($content_elems->item(0));

	#
	# Generate
	#

	my $article_elem = $docbook_document->createElement('article');

	$article_elem->appendChild($docbook_document->createComment("[wp:post_id: $meta->{'wp:post_id'}]"));
	$article_elem->appendChild($docbook_document->createComment("[guid: $meta->{'guid'}]"));
	$article_elem->appendChild($docbook_document->createComment("[link: $meta->{'link'}]"));
	$article_elem->appendChild($docbook_document->createComment("[wp:post_name: $meta->{'wp:post_name'}]"));
	$article_elem->appendChild($docbook_document->createComment("[wp:status: $meta->{'wp:status'}]"));

	my $title_elem = $docbook_document->createElement('title');
	$title_elem->appendChild($docbook_document->createTextNode($meta->{'title'}));
	$article_elem->appendChild($title_elem);

	my $articleinfo_elem = $docbook_document->createElement('articleinfo');

	my $author_elem = $docbook_document->createElement('author');
	# TODO: There cannot have #PCDATA in <author>.
	$author_elem->appendChild($docbook_document->createTextNode($meta->{'dc:creator'}));
	$articleinfo_elem->appendChild($author_elem);

	# <pubDate> sometimes containing bad data (eg., un-published post)
	# GMT time is prefered
	# TODO: Preprocess $post_date_gmt to use formal datetime format.
	my $pubdate_elem = $docbook_document->createElement('pubdate');
	$pubdate_elem->appendChild($docbook_document->createTextNode("$meta->{'wp:post_date_gmt'} GMT"));
	$articleinfo_elem->appendChild($pubdate_elem);

	$article_elem->appendChild($articleinfo_elem);

	if ($content) {
		my $content_frag = wordrpess_item_content_to_docbook_article_fragment($content, $docbook_document);
		if ($opt_section_wrap) {
			my $section_elem = $docbook_document->createElement('section');
			$section_elem->appendChild($content_frag);
			$article_elem->appendChild($section_elem);
		}
		else {
			$article_elem->appendChild($content_frag);
		}
	}

	print STDERR " [done]\n";

	return ($article_elem, $meta);
}

sub wordpress_dump_to_docbook
{
	my $wp_dump_file = shift or die;
	my $docbook_file = shift or die;
	my ($options) = (shift or {});

	my $step1_cache_file = "$wp_dump_file.cache1";
	my $wp_xml;
	if (-r $step1_cache_file) {
		print STDERR "Loading step1 cache file '$step1_cache_file'...";
		$wp_xml = read_text_file($step1_cache_file);
		print STDERR " [done]\n";
	}
	else {
		print STDERR "Reading wordpress-dump '$wp_dump_file'...";
		$wp_xml .= read_text_file($wp_dump_file);
		print STDERR " [done]\n";

		print STDERR "Fixing wordpress-dump...";

		$wp_xml =~ s|<wp:meta_value>|<wp:meta_value><!\[CDATA[|go;
		$wp_xml =~ s|</wp:meta_value>|]]></wp:meta_value>|go;

		$wp_xml =~ s|<wp:comment_content>|<wp:comment_content><!\[CDATA[|go;
		$wp_xml =~ s|</wp:comment_content>|]]></wp:comment_content>|go;

#		$wp_xml =~ s|<wp:comment_author>|<wp:comment_author><!\[CDATA[|go;
#		$wp_xml =~ s|</wp:comment_author>|]]></wp:comment_author>|go;

		$wp_xml =~ s|<wp:comment_author_email>|<wp:comment_author_email><!\[CDATA[|go;
		$wp_xml =~ s|</wp:comment_author_email>|]]></wp:comment_author_email>|go;

		$wp_xml =~ s|<wp:comment_author_url>|<wp:comment_author_url><!\[CDATA[|go;
		$wp_xml =~ s|</wp:comment_author_url>|]]></wp:comment_author_url>|go;

		$wp_xml =~ s|||go;

		print STDERR " [done]\n";

		print STDERR "Saving step1 cache file '$step1_cache_file'...";
		write_text_file($step1_cache_file, $wp_xml);
		print STDERR " [done]\n";
	}

#	write_text_file(sprintf('fixed-%d.xml', __LINE__), $wp_xml);

	print STDERR "Parsing wordpress-dump...";
	my $xml_parser = new XML::DOM::Parser;
	my $wp_doc = $xml_parser->parse($wp_xml);
	print STDERR " [done]\n";

	my $db_doc = new XML::DOM::Document;
	$db_doc->setXMLDecl($db_doc->createXMLDecl('1.0', 'utf-8'));
	$db_doc->setDoctype($db_doc->createDocumentType(
		'book',
		'http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd',
		'-//OASIS//DTD DocBook XML V4.5//EN'
	));
	foreach my $css_uri (@opt_css_uris) {
		$db_doc->appendChild($db_doc->createProcessingInstruction(
			'xml-stylesheet',                              # target
			sprintf('href="%s" type="text/css"', $css_uri) # data
		));
	}
	$db_doc->appendChild($db_doc->createElement('book'));

	my $item_no_converting = 0;
	foreach my $item_elem ($wp_doc->getDocumentElement()->getElementsByTagName('item')) {
		my $postid_elems = $item_elem->getElementsByTagName('wp:post_id');
		die "Missing <wp:post_id>" unless ($postid_elems->getLength() > 0);
		my $postid = xmldom_element_text_value($postid_elems->item(0));
		die unless (defined($postid));
		if (!defined($options->{'posts'}) || value_in_list($postid, $options->{'posts'})) {
			printf STDERR ('[%04d] ', ++$item_no_converting);
			my ($article_elem, $meta) = wordpress_item_to_docbook_article($postid, $item_elem, $db_doc);
			$db_doc->getDocumentElement()->appendChild($article_elem);
			if ($opt_articles_dir) {
				if (!-d $opt_articles_dir) {
					mkpath($opt_articles_dir)
						or die "Cannot make directory: $opt_articles_dir: $!";
				}
				my $article_doc = new XML::DOM::Document;
				$article_doc->setXMLDecl($article_doc->createXMLDecl('1.0', 'utf-8'));
				$article_doc->setDoctype($article_doc->createDocumentType(
					'article',
					'http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd',
					'-//OASIS//DTD DocBook XML V4.5//EN'
				));
				foreach my $css_uri (@opt_css_uris) {
					$article_doc->appendChild($article_doc->createProcessingInstruction(
						'xml-stylesheet',                              # target
						sprintf('href="%s" type="text/css"', $css_uri) # data
					));
				}
				my $cloned_article_elem = xmldom_clone_across_doc($article_elem, $article_doc);
				$article_doc->appendChild($cloned_article_elem);
				my $article_file = ($meta->{'wp:status'} eq 'publish')
				                 ? sprintf('%s/article-%04d.xml', $opt_articles_dir, $postid)
				                 : sprintf('%s/draft-%04d.xml',   $opt_articles_dir, $postid);
				write_text_file($article_file, $article_doc->toString());
			}
		}
	}

	print STDERR "Writing DocBook format...";
	write_text_file($docbook_file, $db_doc->toString());
	print STDERR " [done]\n";

	tidy_xml_file($docbook_file);
}

#sub wpdump2docbook
#{
#	my $wp_dump_file = shift or die;
#	my $docbook_file = shift or die;
#
#	my $wp_xml = "<?xml version=\"1.0\"?>\n";
#	$wp_xml .= "<post>\n";
#	$wp_xml .= read_text_file($wp_dump_file);
#	$wp_xml .= "</post>\n";
#	$wp_xml =~ s|&nbsp;| |go; # XML do not understand &nbsp;
#
##	$wp_xml =~ s|<\s*p\s*>|<para>|go;
##	$wp_xml =~ s|<\s*/\s*p\s*>|</para>|go;
#
##	write_text_file($docbook_file, $wp_xml);
#
#	my $xml_parser = new XML::DOM::Parser;
#	my $wp_doc = $xml_parser->parse($wp_xml);
#
#	my $num_replaced;
#	my $elems;
#	my $elem;
#
#	# replace <post> with <article>
#	$num_replaced = 0;
#	while (1) {
#		$elems = $wp_doc->getDocumentElement()->getElementsByTagName('post', 1);
#		last if ($elems->getLength() == 0);
#		$elem = $elems->item(0);
#
#		xmldom_element_morph($elem, 'article');
#
#		++$num_replaced;
#		printf STDERR ("\rReplacing <post> with <article>: %d replaced...", $num_replaced);
#	}
#	print STDERR " [done]\n";
#
#	# replace <p> with <para>
#	$num_replaced = 0;
#	while (1) {
#		$elems = $wp_doc->getDocumentElement()->getElementsByTagName('p', 1);
#		last if ($elems->getLength() == 0);
#		$elem = $elems->item(0);
#
#		xmldom_element_morph($elem, 'para');
#
#		++$num_replaced;
#		printf STDERR ("\rReplacing <p> with <para>: %d replaced...", $num_replaced);
#	}
#	print STDERR " [done]\n";
#
#	# replace <a href="..."> with <ulink url="...">
#	$num_replaced = 0;
#	while (1) {
#		$elems = $wp_doc->getDocumentElement()->getElementsByTagName('a', 1);
#		last if ($elems->getLength() == 0);
#		$elem = $elems->item(0);
#
#		my $href = $elem->getAttribute('href');
#		if ($href ne '') {
#			xmldom_element_morph($elem, 'ulink', { 'url' => $href });
#		}
#
#		++$num_replaced;
#		printf STDERR ("\rReplacing <a href=\"...\"> with <ulink url=\"...\">: %d replaced...", $num_replaced);
#	}
#	print STDERR " [done]\n";
#	write_text_file($docbook_file, $wp_doc->toString());
#}

#sub xmldom_element_morph
#{
#	my $old_element = shift or die;
#	die unless ($old_element->getNodeType() == XML::DOM::ELEMENT_NODE);
#	my ($new_tag_name) = (shift or $old_element->getTagName());
#	my $attr_map = shift;
#
#	my $new_element = $old_element->getOwnerDocument()->createElement($new_tag_name);
#	my $old_attr_nodes = $old_element->getAttributes();
#	for (my $i = 0; $i < $old_attr_nodes->getLength(); ++$i) {
#		my $old_attr_node = $old_attr_nodes->item($i);
#		my $attr_name = $old_attr_node->getName();
#		if (defined($attr_map) && defined($attr_map->{$attr_name})) {
#			$attr_name = $attr_map->{$attr_name};
#		}
#		$new_element->setAttribute($attr_name, $old_attr_node->getValue());
#	}
#	foreach my $kid ($old_element->getChildNodes()) {
#		my $new_kid = $kid->cloneNode(1);
#		$new_element->appendChild($new_kid);
#	}
#	my $parent_node = $old_element->getParentNode() or die;
#	$parent_node->replaceChild($new_element, $old_element);
#}
#
#sub xmldom_elements_morph
#{
#	my $base_elem = shift or die;
#	my $old_tag_name = shift or die;
#	my $new_tag_name = shift;
#	my $attr_map = shift;
#
#	my $num_replaced = 0;
#	while (1) {
#		my $elems = $base_elem->getElementsByTagName($old_tag_name, 1);
#		last if ($elems->getLength() == 0);
#		my $elem = $elems->item(0);
#		xmldom_element_morph($elem, $new_tag_name, $attr_map);
#		++$num_replaced;
#	}
#}

#sub tr_by_table
#{
#	my $input = shift or die;
#	my $table = shift or die;
#
##	print STDERR "\$input: $input\n";
#
#	my $input_length = length($input);
#	my $output = '';
#	my $beg = 0;
#	my $end = 0;
#	while (1) {
#		my %candidates; # pos => key of %$table
#		foreach my $t (keys %$table) {
#			my $pos = index($input, $t, $end);
#			if ($pos >= 0) {
#				$candidates{$pos} = $t;
#			}
#		}
#		last unless (scalar(keys %candidates) > 0);
#		use List::Util qw(min);
#		$beg = min(keys(%candidates));
#		my $len = length($candidates{$beg});
##		print STDERR "\$beg: $beg\n\$end: $end\n\$len: $len\n";
#		$output .= substr($input, $end, ($beg - $end));
#		$output .= $candidates{$beg};
#		$beg += $len;
#		$end = $beg;
#	}
#	$output .= substr($input, $end);
#
##	while (($beg = index($input, $left_mark, $beg)) >= 0) {
##		$output .= substr($input, $end, ($beg - $end));
##		$end = index($input, $right_mark, ($beg + $left_mark_length));
##		die unless ($end >= 0);
##		$end += $right_mark_length;
##		my $target = substr($input, $beg, ($end - $beg));
##		if (defined($table->{$target})) {
##			$output .= $table->{$target};
##		}
##	}
##	$output .= substr($input, $end);
##	return $output;
#}

#sub tidy_html_file
#{
#	my $html_file = shift or die;
#	print STDERR "Tidy HTML file '$html_file'...";
#	`tidy -quiet -indent -wrap 79 -utf8 -modify $html_file`;
#	print STDERR " [done]\n";
#}

#sub wordpress_dump_fix
#{
#	my $wp_xml = shift or die;
#
#	my $new_wp_xml = '';
#
#	my $meta_value_beg_tag = '<wp:meta_value>';
#	my $meta_value_beg_tag_length = length($meta_value_beg_tag);
#	my $meta_value_beg = 0;
#	my $meta_value_end_tag = '</wp:meta_value>';
#	my $meta_value_end_tag_length = length($meta_value_end_tag);
#	my $meta_value_end = 0;
#	while (($meta_value_beg = index($wp_xml, $meta_value_beg_tag, $meta_value_beg)) > 0) {
#		$new_wp_xml .= substr($wp_xml, $meta_value_end, ($meta_value_beg - $meta_value_end));
#
#		$meta_value_beg += $meta_value_beg_tag_length;
#		$meta_value_end = index($wp_xml, $meta_value_end_tag, $meta_value_beg);
#		die unless ($meta_value_end >= 0);
#		my $meta_value = substr($wp_xml, $meta_value_beg, ($meta_value_end - $meta_value_beg));
#		$new_wp_xml .= $meta_value_beg_tag;
#		$new_wp_xml .= xmlspecialchars($meta_value);
#		$new_wp_xml .= $meta_value_end_tag;
#		$meta_value_end += $meta_value_end_tag_length;
#		$meta_value_beg = $meta_value_end;
#
##		print "\$meta_value_beg: $meta_value_beg\n";
##		print "\$meta_value_end: $meta_value_end\n";
#	}
#	$new_wp_xml .= substr($wp_xml, $meta_value_end, ($meta_value_beg - $meta_value_end));
#
#	return $new_wp_xml;
#}

#sub unxmlspecialchars
#{
#	my $s = shift or die;
#	return tr_by_table($s, {
#		'&lt;'   => '<',
#		'&gt;'   => '>',
#		'&apos;' => "'",
#		'&quot;' => '"',
#		'&amp;'  => '&',
#	});
##	$s =~ s/&lt;/</go;
##	$s =~ s/&gt;/>/go;
##	$s =~ s/&apos;/'/go;
##	$s =~ s/&quot;/"/go;
##	$s =~ s/&amp;/&/go;
##	return $s;
#}

#sub unhtmlspecialchars
#{
#	my $s = shift or die;
#	return tr_by_table($s, {
#		'&lt;'   => '<',
#		'&gt;'   => '>',
#		'&apos;' => "'",
#		'&quot;' => '"',
#		'&amp;'  => '&',
#		'&nbsp;' => ' ',
#	});
#}
