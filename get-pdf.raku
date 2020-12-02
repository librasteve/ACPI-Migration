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

##shell( "wget $url" );

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
my $d = $parser.xmldoc; # XML::Document

my @title-elms = $d.elements(:RECURSE(Inf), :class('article-title-container')); 
my @title-strs;
my @pp-ranges;
my @author-elms = $d.elements(:RECURSE(Inf), :class('author-list')); 
my @author-strs;
my @abstr-elms = $d.elements(:RECURSE(Inf), :class('article-description-text')); 
my @abstr-strs;

say "===Volume Info===";
my $volinf1 = @title-elms.splice(0,1).[0];
parse-title( $volinf1 );
my $volinf2 = @author-elms.splice(0,1).[0];		#may need for Volime Editor(s)

for 0..^@title-elms -> $i {
	say "===Article No.$i===";
	parse-title( @title-elms[$i] );
	parse-pprange( @title-elms[$i] );
	parse-authors( @author-elms[$i] );
	parse-abstr( @abstr-elms[$i] );
	say "+++++++++++++++++++\n";
}

sub parse-title( $t ) {
	my @a    = $t.elements(:TAG<a>);
	my $res  = @a[0].firstChild().text.trim;
	say "Title:\n$res";
	@title-strs.push: $res;
}
sub parse-pprange( $t ) {
	my @span = $t.elements(:TAG<span>);
	my $res  = @span[0].firstChild().text.trim;
	say "Pages:\n$res";
	@pp-ranges.push: $res;
}
sub parse-authors( $t ) {
	my @a    = $t.elements(:TAG<a>);
	my @res;
	say "Authors:";
	for 0..^@a -> $j {
		my $res  = @a[$j].firstChild().text.trim;
		say "$res";
		@res.push: $res;
	}
	@author-strs.push: @res;
}
sub parse-abstr( $t ) {
	my $res  = $t.firstChild().text.trim;
	say "Abstract:\n$res";
	@abstr-strs.push: $res;
}


#iamereh - line endings, then loop of loops & pdf url



#`[
my $head = $html.elements(:TAG<head>, :SINGLE);
my @stylesheets = $head.elements(:TAG<link>, :rel<stylesheet>);
my @middle = $table.elements(:!FIRST, :!LAST);
my @not-red = $div.elements(:class(* ne 'red'));
# find all elements by class name
my @elms-by-class-name = $html.elements(:RECURSE(Inf), :class('your-class-name')); 
#]

#`[ wantlist - article level :
my @keywords; #nope
#]

#`[ command dump
say @a[0];
say ~$d.version;
say ~$d.root.name;
say ~$d.root.firstChild();
say ~$d.root.lastChild();
my $head = $d.elements(:TAG<head>, :SINGLE); say $head;
#say @abstracts;
say ~@abstracts[0].name;
say @abstracts[0].nodes[0];
say @abstracts[0].nodes.elems;
#]



