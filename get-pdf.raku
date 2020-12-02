#!/usr/bin/env raku 
# vim: filetype=perl6

#`[
works...
wget http://ejise.com 
wget http://ejise.com/issue/current.html
wget 'http://ejise.com/issue/download.html?idArticle=1084' #escape me

broke...
http://ejise.com/issue/download.html?idArticle=1084

forget...
https://issuu.com/academic-conferences.org/docs/ejise-volume23-issue1-article1084?mode=a_p

shell( 'wget http://ejise.com/issue/current.html' ); #ok
#]

chdir( '../files2' );
my $dir = '.';

#`[[
my @todo = $dir.IO;
while @todo {
	for @todo.pop.dir -> $path {
		say $path.Str;
		@todo.push: $path if $path.d;
	}
}
#]]

my $url;
#$url = 'http://ejise.com';
$url = 'http://ejise.com/issue/current.html';
#$url = 'http://ejise.com/issue/download.html?idArticle=1084'; 

shell( "wget $url" );

my $file = 'current.html';
my $fh = open( $file );
my $html = $fh.slurp;

#`[[
my @lines = $fh.lines;
for @lines -> $line {
	if $line ~~ /Abstract/ {
		say $line;	
	}
}
#]]
$fh.close;

use XML;
use HTML::Parser::XML;
my $parser = HTML::Parser::XML.new;
$parser.parse($html);
my $doc = $parser.xmldoc; # XML::Document
say ~$doc;

