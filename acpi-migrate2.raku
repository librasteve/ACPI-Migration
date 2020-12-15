#!/usr/bin/env raku 
#acpi-migrate2.raku

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
	has $.url;
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

	method year {	
		$!date ~~ m|^\w**3 \s (\d*)$| or die "bad year";		#eg. 'Feb 2020'
		return ~$0;
	}
}
class article {
	#synonymous with publication
	has $.id;
	has $.title;
	has $.abstract;
	has @.keywords;
	has @.authors;
	has $.pages;
	has $.oldurl;
	has $.filename is rw;

	method split-name( $author ) {
		$author ~~ m|^(.*) \s (.*)$|;
		return( ~$0, ~$1 )
	}
	method make-email( $author, $j ) {
		my ( $given, $family ) = self.split-name( $author );
		$given ~~ s:g|\s|\.|;
		return qq|$given.$family\@{$j.url}|;
	}
	method make-username( $author ) {
		my ( $given, $family ) = self.split-name( $author );
		$given ~~ s:g|\s|\-|;
		return qq|$given-$family|;
	}
}

my $j = journal.new( 
	name => 'elise',
	url  => 'elise.com',
	issn => 'ISSN 1566-6379',
	copyrightHolder => 'Copyright &#169; 1999-2021 Electronic Journal of Information Systems Evaluation',
);
$j = parse-issue-page( $d, $j );		#say $j;

my ( $art-xml, $use-xml ) = generate-xml( $j );			
say $art-xml; 
#say $use-xml;

#### Generate XML ####
sub generate-xml( $j ) {

	#### XML Subroutines ####
	#| the recurse control makes this convenient, but a tad imprecise
	sub insert-tag( $dx, $tag, $text ) {
		$dx.elements(:TAG($tag) :RECURSE).first.insert( XML::Text.new( text => $text ) );
	}
	#| need this variant to deal with one or two duplicate tag names (eg. title)
	sub insert-subtag( $dx, $tag, $text, $subtag ) {
		my $sx = $dx.elements(:TAG($subtag) :RECURSE).first;
		$sx.elements(:TAG($tag)).first.insert( XML::Text.new( text => $text ) );
	}
	sub insert-tag-to-elem( $elem, $tag, $text ) {
		$elem.elements(:TAG($tag)).first.insert( XML::Text.new( text => $text ) );
	}
	sub get-node( $dx, $tag ) {
		return $dx.elements(:TAG($tag) :RECURSE).first;
	}
	sub get-node-from-elem( $elem, $tag ) {
		return $elem.elements(:TAG($tag) :RECURSE).first;
	}
	sub clean-text( $txt is copy ) {
		$txt ~~ s:g|(\& <!before <[\#]> >)|"&amp;"|;
		return $txt;
	}

	#### Issue XML Substitutions ####

	my $ax = XML::Document.load('./ojs-templates/article-blank-cd14.xml');
	my $ux = XML::Document.load('./ojs-templates/users-blank-cd2.xml');

	my $vi = 0;
	my $vol := $j.volumes[$vi]; 

	my $ii = 0;
	my $iss := $vol.issues[$ii];

	#hardwire some article & publication attributes for now FIXME
	my @art-attrs = <current_publication_id	date_submitted stage status submission_progress>; 
	my $art-node = $ax;
	$art-node.attribs<current_publication_id> = '4'; #or make this $art.id?
	$art-node.attribs<date_submitted> = '2020-12-25';

	my $pub-node = get-node( $ax, 'publication' );
	$pub-node.attribs<date_published> = '2020-12-25',	say $pub-node.attribs;
#iamerejh not working
	my $pub-id = get-node-from-elem( $pub-node, 'id' ); #say $pub-id; #leave both at 4 for now
die "yo";

	#hardwire issue items for now FIXME
	my @iss-tags = <copyrightHolder copyrightYear issue_identification= number year title>;

	insert-tag( $ax, 'copyrightHolder', $j.copyrightHolder );      
	insert-tag( $ax, 'copyrightYear', $iss.year );      
	insert-tag( $ax, 'number', $iss.number );
	insert-tag( $ax, 'year',  $iss.year );
	insert-tag( $ax, 'volume',  $vol.number );
	insert-subtag( $ax, 'title', 
		qq|Volume {$vol.number} Issue {$iss.number} / {$iss.date}|, 'issue_identification' );

	my @art-tags = <id title abstract keywords= keyword authors= author= pages>;

	for 1..1 -> $ai {
	##for 1..$iss.articles.elems -> $ai {

		#### Article XML Substitutions ####

		my $art := $iss.articles[$ai-1];

		insert-tag( $ax, 'id', $art.id );							#ie. article id = 1084
		insert-tag( $ax, 'title', $art.title );
		insert-tag( $ax, 'abstract', clean-text( $art.abstract ) );
		insert-tag( $ax, 'pages', $art.pages );

		my $k-top = get-node( $ax, 'keywords' );					#say $k-top;
		my $k-old = get-node-from-elem( $k-top, 'keyword' ); 
		$k-old.remove;

		#| synthesize & populate keyword tags
		for $art.keywords -> $kw {
			$k-top.insert( 'keyword', clean-text( $kw ) );
		} 

		##my @aut-tags = <givenname familyname affiliation country email username orcid biography>;
		my @aut-tags = <givenname familyname email username>;   #omit empty tags "less is more"

		my $a-top = get-node( $ax, 'authors' );					#say $a-top;
		my $a-old = get-node-from-elem( $a-top, 'author' ); 
		$a-old.remove;

		#| synthesize & populate author & child tags
		for 0..^$art.authors.elems -> $i {
			my $n-aut = $a-top.insert( 'author', 
				#include_in_browser => "true", #not allowed ?
				user_group_ref => "Author",
				seq => $i,
				id => $art.id * 10 + $i,
			).first;
			my ( $givenname, $familyname ) = $art.split-name( $art.authors[$i] );
			my $email = $art.make-email( $art.authors[$i], $j );
			my $username = $art.make-username( $art.authors[$i] );

			for @aut-tags.reverse -> $aut-tag {
				given $aut-tag {
					when <givenname>   { $n-aut.insert( $_, $givenname,  locale => "en_US" ) }
					when <familyname>  { $n-aut.insert( $_, $familyname, locale => "en_US" ) }
					when <email>       { $n-aut.insert( $_, $email,      				   ) }
					when <username>    { $n-aut.insert( $_, $username,     				   ) }
				}
			}
		} 

		#### Users XML Substitutions ####

		my @use-tags = <givenname familyname email username>;
		#also need to handcrank user_group_ref password= value 

		my $u-top = get-node( $ux, 'users' );					#say $u-top;
		my $u-old = get-node-from-elem( $u-top, 'user' ); 
		$u-old.remove;

		#| synthesize & populate user & child tags
		for 0..^$art.authors.elems -> $i {
			my $n-use = $u-top.insert( 'user' ).first;

			my ( $givenname, $familyname ) = $art.split-name( $art.authors[$i] );
			my $email = $art.make-email( $art.authors[$i], $j );
			my $username = $art.make-username( $art.authors[$i] );

			$n-use.insert( 'user_group_ref', 'Author' );
			my $n-pass = $n-use.insert( 'password',
				encryption => "sha1",
				is_disabled => "false",
				must_change => "false",
			).first;
			$n-pass.insert( 'value' );						#say $n-pass;

			for @use-tags.reverse -> $use-tag {
				given $use-tag {
					when <givenname>   { $n-use.insert( $_, $givenname,  locale => "en_US" ) }
					when <familyname>  { $n-use.insert( $_, $familyname, locale => "en_US" ) }
					when <email>       { $n-use.insert( $_, $email,      				   ) }
					when <username>    { $n-use.insert( $_, $username,     				   ) }
				}
			}
		} 
	}

	return $ax, $ux;
}

#### Load Structure from Old Issue Page ####
sub parse-issue-page( $d, $j ) {
	my $verbose = 0;

	my @title-elms   = $d.elements(:RECURSE(Inf), :class('article-title-container')); 
	my @author-elms  = $d.elements(:RECURSE(Inf), :class('author-list')); 
	my @abstr-elms   = $d.elements(:RECURSE(Inf), :class('article-description-text')); 
	my @oldurl-elms  = $d.elements(:RECURSE(Inf), :class('article-sub-container')); 

	#| keywords class is duplicated - so need to keep only even elms
	my @keyword-elms = $d.elements(:RECURSE(Inf), :class('article-description-keywords')); 
	my @keyword-elms2;
	for 0..^@keyword-elms -> $k {
		@keyword-elms2.push: @keyword-elms[$k] if $k %% 2;
	}

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
	my $iss-keywords = parse-keywords( @keyword-elms2.splice(0,1).[0] ); #may need this later
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
			pages    => parse-pages(    @title-elms[$ai-1] ),
			authors  => parse-authors(  @author-elms[$ai-1] ),
			abstract => parse-abstract( @abstr-elms[$ai-1] ),
			keywords => parse-keywords( @keyword-elms2[$ai-1] ),
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
	sub parse-pages( $t ) {
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
	sub parse-keywords( $t ) {
		my @a    = $t.elements(:TAG<a>);
		my @res;
		say "Keywords:" if $verbose;
		for 0..^@a -> $j {
			my $res  = @a[$j].firstChild().text.trim;
			say "$res" if $verbose;
			@res.push: $res;
		}
		return @res;
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





