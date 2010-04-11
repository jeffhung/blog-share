use File::Grep;
use File::Find::Rule;

print "CHECK: C/C++ sources must include <messy/config.h>.\n";
print join(
	"\n",
	map { "| $_->{'filename'}" }
	grep { $_->{'count'} == 0 }
	File::Grep::fgrep { /^\s*#\s*include\s+<messy\/config.h>/ }
	grep { $_ !~ m/messy\/config.h$/o }
	File::Find::Rule->or(
		File::Find::Rule->directory->name('.svn')->prune->discard,
		File::Find::Rule->file()->name(qr/\.(h|hpp|c|cpp)$/i)
	)->in('include', 'src')
) || "[ok]";
print "\n\n";

