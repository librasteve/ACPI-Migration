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

my $verbose = 1;
my $journal = 'ejise';

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
my @oldurl-elms = $d.elements(:RECURSE(Inf), :class('article-sub-container')); 
my @oldurl-strs;

say "===Volume Info===" if $verbose;
my $volinf1 = @title-elms.splice(0,1).[0];
parse-title( $volinf1 );
my $vol-title = @title-strs.splice(0,1).[0];
my $volinf2 = @author-elms.splice(0,1).[0];		#may need for Volime Editor(s)
my $volinf3 = @oldurl-elms.splice(0,1).[0];
parse-oldurl( $volinf3 );
my $vol-oldurl = @oldurl-strs.splice(0,1).[0];
say "+++++++++++++++++++\n" if $verbose;

for 0..^@title-elms -> $i {
	say "===Article No.$i===" if $verbose;
	parse-title(    @title-elms[$i]    );
	parse-pprange(  @title-elms[$i]    );
	parse-oldurl(   @oldurl-elms[$i]   );
	parse-authors(  @author-elms[$i]   );
	parse-abstr(    @abstr-elms[$i]    );
	say "+++++++++++++++++++\n" if $verbose;
}

sub parse-title( $t ) {
	my @a    = $t.elements(:TAG<a>);
	my $res  = @a[0].firstChild().text.trim;
	say "Title:\n$res" if $verbose;
	@title-strs.push: $res;
}
sub parse-pprange( $t ) {
	my @span = $t.elements(:TAG<span>);
	my $res  = @span[0].firstChild().text.trim;
	say "Pages:\n$res" if $verbose;
	@pp-ranges.push: $res;
}
#`[ transform from issuu url to download url
http://issuu.com/academic-conferences.org/docs/ejise-volume23-issue1-article1093?mode=a_p
http://ejise.com/issue/download.html?idArticle=1084
-or- can already be in download form
http://ejise.com/issue/download.html?idIssue=252
#]
sub parse-oldurl( $t ) {
	my @p    = $t.elements(:TAG<p>);
	my @a    = @p[0].elements(:TAG<a>);
	my $res  = @a[0].attribs<href>;
	unless $res ~~ m|download| {
		$res ~~ m|article(\d*)\?mode|;
		$res = qq|http://$journal.com/issue/download.html?idArticle=$0|;
	}
	say "OldUrl:\n$res" if $verbose;
	@oldurl-strs.push: $res;
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
	@author-strs.push: @res;
}
sub parse-abstr( $t ) {
	my $res  = $t.firstChild().text.trim;
	$res ~~ s:global/\n//;
	say "Abstract:\n$res" if $verbose;
	@abstr-strs.push: $res;
}

#`[check length
say @title-strs.elems;
say @pp-ranges.elems;
say @author-strs.elems;
say @abstr-strs.elems;
say @oldurl-strs.elems;
#]


#`[ some useful XML lookup commmands
my $head = $html.elements(:TAG<head>, :SINGLE);
my @stylesheets = $head.elements(:TAG<link>, :rel<stylesheet>);
my @middle = $table.elements(:!FIRST, :!LAST);
my @not-red = $div.elements(:class(* ne 'red'));
# find all elements by class name
my @elms-by-class-name = $html.elements(:RECURSE(Inf), :class('your-class-name')); 
#]





