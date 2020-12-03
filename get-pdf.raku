#!/usr/bin/env raku 

#`[ todos
-loop of loops
-pdf url
#]

#`[ items 
- article level
-- my @keywords; #nope
- issue level
-- ?
#]

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
$fh.close;

use XML;
use HTML::Parser::XML;

my $parser = HTML::Parser::XML.new;
$parser.parse($html);
my $d = $parser.xmldoc; # XML::Document

my $verbose = 1;
my $journal-name = 'elise';

#### Define Structure ####

class journal {
	has $.name;
	has @.volumes;
}
class volume {
	has $.number;
	has @.issues;
}
class issue {
	has $.number;
	has $.date;
	#has $.pprange; #not needed(?)
	has @.authors; #ie. editors
	has $.oldurl;
	has $.ref-id;
	has $.filename;
	has @.articles; #index is from 1 to n
}
class article {
	has $.title;
	has $.pprange;
	has @.authors;
	has $.abstract;
	has $.oldurl;
	has $.ref-id;
	has $.filename;
}

#### Parse Issue Page, Load Structure ####

my $j = journal.new( 
	name => $journal-name 
);

my @title-elms  = $d.elements(:RECURSE(Inf), :class('article-title-container')); 
my @author-elms = $d.elements(:RECURSE(Inf), :class('author-list')); 
my @abstr-elms  = $d.elements(:RECURSE(Inf), :class('article-description-text')); 
my @oldurl-elms = $d.elements(:RECURSE(Inf), :class('article-sub-container')); 

say "===Volume Info===" if $verbose;
#using splices to handle re-use of tag for volume/issue

#eg. 'Volume 23 Issue 1 / Feb 2020'
my $vit = parse-title( @title-elms.splice(0,1).[0] );
$vit ~~ m|Volume \s* (\d*) \s* Issue \s* (\d*) \s* \/ \s* (\w*\s+\d*)|;

my $vi = 0;
my $vol := $j.volumes[$vi]; 
$vol = volume.new( 
	number => +$0 
);
say "+++++++++++++++++++\n" if $verbose;

say "===Issue Info===" if $verbose;
my $iss-authors = parse-authors( @author-elms.splice(0,1).[0] ); #may need this later
my $iss-oldurl = parse-oldurl( @oldurl-elms.splice(0,1).[0] );

my $ii = 0;
my $iss := $vol.issues[$ii];
$iss = issue.new( 
	number  => +$1, 
	date    => ~$2, 
	oldurl  => $iss-oldurl,
	authors => $iss-authors,
	refid   => url2refid( $iss-oldurl ),
);
#$iss.filename = url2fn( :issue ); 

say "+++++++++++++++++++\n" if $verbose;

for 1..@title-elms -> $ai {
	say "===Article No.$ai===" if $verbose;

	my $art-oldurl = parse-oldurl( @oldurl-elms[$ai-1] ),

	$iss.articles[$ai-1] = article.new( 
		title    => parse-title(    @title-elms[$ai-1] ),
		pprange  => parse-pprange(  @title-elms[$ai-1] ),
		authors  => parse-authors(  @author-elms[$ai-1] ),
		abstract => parse-abstract( @abstr-elms[$ai-1] ),
		oldurl   => $art-oldurl,
		refid    => url2refid( $art-oldurl ),
	);
	say "+++++++++++++++++++\n" if $verbose;
}
#`[iamerejh
sub url2fn( :$issue, :$article ) {
	#ejise-volume23-issue1-article1084.pdf
	if $issue {
		return qq|$j.name
	}
}
#]
sub url2refid( $url ) {
#http://ejise.com/issue/download.html?idIssue=252
#http://elise.com/issue/download.html?idArticle=1085
	$url ~~ m/id[Issue||Article] \= (\d*) $/;
	say "RefID:\n$0" if $verbose;
	return $0
}
sub parse-title( $t ) {
	my @a    = $t.elements(:TAG<a>);
	my $res  = @a[0].firstChild().text.trim;
	say "Title:\n$res" if $verbose;
	return $res;
}
sub parse-pprange( $t ) {
	my @span = $t.elements(:TAG<span>);
	my $res  = @span[0].firstChild().text.trim;
	say "Pages:\n$res" if $verbose;
	return $res;
}
sub parse-authors( $t ) {
	my @a    = $t.elements(:TAG<a>);
	my @res;
	say "Authors:" if $verbose;
	for 0..^@a -> $j {
		my $res  = @a[$j].firstChild().text.trim;
		say "$res" if $verbose;
		@res.push: $res;
	}
	return @res;
}
sub parse-abstract( $t ) {
	my $res  = $t.firstChild().text.trim;
	$res ~~ s:global/\n//;
	say "Abstract:\n$res" if $verbose;
	return $res;
}
sub parse-oldurl( $t ) {
#http://issuu.com/academic-conferences.org/docs/ejise-volume23-issue1-article1093?mode=a_p
#http://ejise.com/issue/download.html?idArticle=1084 -or- issue already in download form
	my @p    = $t.elements(:TAG<p>);
	my @a    = @p[0].elements(:TAG<a>);
	my $res  = @a[0].attribs<href>;
	unless $res ~~ m|download| {
		$res ~~ m|article(\d*)\?mode|;
		$res = qq|http://{$j.name}.com/issue/download.html?idArticle=$0|;
	}
	say "OldUrl:\n$res" if $verbose;
	return $res;
}

say $j; die;


#`[ some useful XML lookup commmands
my $head = $html.elements(:TAG<head>, :SINGLE);
my @stylesheets = $head.elements(:TAG<link>, :rel<stylesheet>);
my @middle = $table.elements(:!FIRST, :!LAST);
my @not-red = $div.elements(:class(* ne 'red'));
# find all elements by class name
my @elms-by-class-name = $html.elements(:RECURSE(Inf), :class('your-class-name')); 
#]





