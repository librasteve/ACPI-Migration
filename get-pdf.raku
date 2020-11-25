#!/usr/bin/env raku 


#`[
- cpan HTTP::Command::Wrapper
- viz. https://metacpan.org/source/PINE/HTTP-Command-Wrapper-0.08/README.md
- zef install Inline::Perl5

/usr/local/Cellar/perl/5.30.2_1/lib/perl5/site_perl/5.30.2/Text/Levenshtein.pm

works...
wget http://ejise.com 
wget http://ejise.com/issue/current.html
wget 'http://ejise.com/issue/download.html?idArticle=1084' #escape me

broke...
http://ejise.com/issue/download.html?idArticle=1084

forget...
https://issuu.com/academic-conferences.org/docs/ejise-volume23-issue1-article1084?mode=a_p

#]

use HTTP::Command::Wrapper:from<Perl5> <create fetch download>;

my $client  = HTTP::Command::Wrapper.create; # auto detecting (curl or wget)
$client.download('https://github.com/');
wget 'http://ejise.com/issue/download.html?idArticle=1084' #escape me
##my $content = $client.fetch('https://github.com/');
##print "$content\n";


say "yo";
