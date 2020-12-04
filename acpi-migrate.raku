#!/usr/bin/env raku 

#`[ todos
-loop of loops
-error / sanity checking
-move pdf / new url
-handle issn (journal.issn?)
-gen article.xml
#]

#`[ items 
-1x pdf per issue
-open PDF for DOI (shell pdftotext *1077* scum.txt)
  3 Sophia Xiaoxia Duan School of Business IT and Logistics, RMIT University, Melbourne VIC 3000, Aust    ralia sophia.duan@rmit.edu.au
  4 DOI: 10.34190/EJISE.19.22.2.001
-(shell xmllint --noout sample.xml)
sample.xml:119: parser error : EntityRef: expecting ';'
ne, 2018. Disponível em: http://www.scielo.br/scielo.php?script=sci_arttext&pid
-missing xml elements
--galleys (use newurl)
--doi ref (maybe <id type="internal" advice="ignore"></id>)??
-ojs cli operation
#]

#`[[ some handy file ops
chdir( '../files2' );
my $dir = '.';

my @todo = $dir.IO;
while @todo {
	for @todo.pop.dir -> $path {
		say $path.Str;
		@todo.push: $path if $path.d;
	}
}
#]]

use XML;
use HTML::Parser::XML;

my $url = 'http://ejise.com/issue/current.html';

##shell( "wget $url" );
my $file = 'current.html';
my $fh = open( $file );
my $html = $fh.slurp;
$fh.close;

my $parser = HTML::Parser::XML.new;
$parser.parse($html);
my $d = $parser.xmldoc; # XML::Document

#### Define Structure ####
class journal {
	has $.name;
	has $.issn;
	has $.copyrightHolder;
	has @.volumes;
}
class volume {
	has $.number;
	has @.issues;
}
class issue {
	has $.number;
	has $.date;
	has $.oldurl;
	has $.id;
	has $.filename is rw;
	has @.articles; #index is from 1 to n
}
class article {
	has $.id;
	has $.title;
	has $.abstract;
	has @.keywords;
	has @.authors;
	has $.pprange;
	has $.oldurl;
	has $.filename is rw;
}

my $j = journal.new( 
	name => 'elise',
	issn => 'ISSN 1566-6379',
	copyrightHolder => 'Copyright © 1999-2021 Electronic Journal of Information Systems Evaluation',
);
$j = parse-issue-page( $d, $j );		#say $j;

my $xml = generate-xml( $j );			say $xml;

#### Generate XML ####
sub generate-xml( $j ) {
	my $verbose = 1;

	my $vi = 0;
	my $vol := $j.volumes[$vi]; 

	my $ii = 0;
	my $iss := $vol.issues[$ii];

	my $ax = XML::Document.load('./ojs-templates/article-blank.xml');

	#hardwire issue items for now FIXME
	my @itags = <copyrightHolder copyrightYear issue_identification= number year title>; #?? how to do nested items

	#the trailing () are required for a 'quoted method name'
	insert-text( 'copyrightHolder', $j.copyrightHolder );      
	insert-text( 'copyrightYear', date2year( $iss.date ) );      

	#### XML Subroutines ####
	sub insert-text( $tag, $text ) {
		$ax.elements(:TAG($tag)).first.insert( XML::Text.new( text => $text ) );
	}
	sub date2year( $date ) {
		$date ~~ m|(\d*)|;		#eg. 'Feb 2020'
say ~$0; #iamerejh
		return ~$0;
	}


	my $cy = 2020;  #FIXME same as issue/volume year
	my $in = 23;	#FIXME


	say $ax; 
	die;

	for 1..1 -> $ai {
	##for 1..$iss.articles.elems -> $ai {
		say "===Article No.$ai===" if $verbose;

		my $art := $iss.articles[$ai-1];
#`[
		my $id = $ax.elements(:TAG<id>).first;
		$id.insert( XML::Text.new( text => 'Nah Monthly' ) );

		$art = article.new( 
			title    => parse-title(    @title-elms[$ai-1] ),
			pprange  => parse-pprange(  @title-elms[$ai-1] ),
			authors  => parse-authors(  @author-elms[$ai-1] ),
			abstract => parse-abstract( @abstr-elms[$ai-1] ),
			oldurl   => $art-oldurl,
			id   => url2id( $art-oldurl ),
		);
		$art.filename = url2fn( $iss, $art ); 
#]
		say "+++++++++++++++++++\n" if $verbose;
	}


	my @art-items = <id title abstract keywords= authors= pages>;  #FIXME load keywords



	return $ax;

}

#### Load Structure from Old Issue Page ####
sub parse-issue-page( $d, $j ) {
	my $verbose = 0;

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
		id => url2id( $iss-oldurl ),
	);
	$iss.filename = url2fn( $iss ); 
	say "+++++++++++++++++++\n" if $verbose;

	for 1..@title-elms -> $ai {
		say "===Article No.$ai===" if $verbose;

		my $art-oldurl = parse-oldurl( @oldurl-elms[$ai-1] ),

		my $art := $iss.articles[$ai-1];
		$art = article.new( 
			title    => parse-title(    @title-elms[$ai-1] ),
			pprange  => parse-pprange(  @title-elms[$ai-1] ),
			authors  => parse-authors(  @author-elms[$ai-1] ),
			abstract => parse-abstract( @abstr-elms[$ai-1] ),
			oldurl   => $art-oldurl,
			id => url2id( $art-oldurl ),
		);
		$art.filename = url2fn( $iss, $art ); 
		say "+++++++++++++++++++\n" if $verbose;
	}

	return $j;

	sub url2fn( $iss, $art? ) {
		#EJISE-volume-23-issue-1.pdf
		my $res;
		if ! $art {
			$res = qq|{$j.name.uc}-volume-{$vol.number}-issue-{$iss.number}.pdf|;
		}
		#ejise-volume23-issue1-article1084.pdf
		else {
			$res = qq|{$j.name}-volume{$vol.number}-issue{$iss.number}-article{$art.id}.pdf|;
		}
		say "Filename:\n$res" if $verbose;
		return $res;
	}
	sub url2id( $url ) {
	#http://ejise.com/issue/download.html?idIssue=252
	#http://elise.com/issue/download.html?idArticle=1085
		$url ~~ m/id[Issue||Article] \= (\d*) $/;
		say "RefID:\n$0" if $verbose;
		return ~$0
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
}

#`[ some useful XML lookup commmands
my $head = $html.elements(:TAG<head>, :SINGLE);
my @stylesheets = $head.elements(:TAG<link>, :rel<stylesheet>);
my @middle = $table.elements(:!FIRST, :!LAST);
my @not-red = $div.elements(:class(* ne 'red'));
# find all elements by class name
my @elms-by-class-name = $html.elements(:RECURSE(Inf), :class('your-class-name')); 
#and for insert, replace...
my $id = $ax.elements(:TAG<id>).first; say $id;
my $ni = XML::Text.new( text => 'Nah Monthly' );
$id.insert( $ni );
my $nt = XML::Text.new( text => 'Nah Monthly' );
$ar[3].replace( $ar[3].nodes[0], $nt );
say $ar[3].nodes[0];
	my $ar = $ax.root; say $ar.name;
	for 1..10 -> $i {
		say "article child $i is:" ~ $ar[$i];
	}
	say $ar[3].attribs;
	say $ar[3].nodes;
	say $ar[3].nodes[0].WHAT;
	say $ar[3].nodes[0];
#]





