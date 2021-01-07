#!/usr/bin/env raku 
#eg. ./do-issue.raku -issurl='http://ejise.com/volume7/issue1'

#`[ 
not doing (yet)
-looper script
-- %h = %( vol.num => iss.elems ) 
-move pdf / new url
-error / sanity checking
#]

use XML;
use HTML::Parser::XML;

#Parse source url and generate xml for one issue
#Structure has one journal, one volume, one issue, many articles, many-many authors
#Needs valid source issue url as main argument - http://ejise.com/volume7/issue1
#Creates files/folders as follows:
#../files/ejise/htm/ejise-volume7-issue1.html
#../files/ejise/xml-use/ejise-volume7-issue1-use.xml
#../files/ejise/xml-iss/ejise-volume7-issue1-iss.xml
#../files/ejise/pdf/ejise-volume7-issue1-article623.pdf
#../files/ejise/pdf/ejise-volume7-issue1-article623.txt
#../files/ejise/pdf/ejise-volume7-issue1-article623.b64
#../files/ejise/pdf/ejise-volume7-issue1-article624.pdf
#../files/ejise/pdf/ejise-volume7-issue1-article624.txt
#../files/ejise/pdf/ejise-volume7-issue1-article624.b64
#... etc...
#Multiple runs with same url will overwrite

my @months = <Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>;
my %month-nos;
for 0..^@months -> $i { %month-nos{@months[$i]} = sprintf( "%02d", $i+1 ) } 

#### Define Structure ####
class journal {
	has $.name;
	has $.url;
	has $.issn;
	has $.copyrightHolder;
	has $.volume is rw;
}
class volume {
	has $.number;
	has $.issue is rw;
}
class issue {
	has $.number;
	has $.date;
	has $.oldurl;
	has $.id;
	has $.filename is rw;
	has @.articles; #index is from 1 to n

	method year {	
		$!date ~~ m|^\w**3 \s (\d*)$| or die "bad year {$!date}";				#eg. 'Feb 2020' => '2020'
		return ~$0;
	}
	method yyyy-mm-dd {
		$!date ~~ m|^(\w**3) \s (\d*)$| or die "bad yyyy-mm-dd {$!date}";		#eg. => '2020-02-01'
		return qq|$1-{%month-nos{$0}}-01|;
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
	has $.filesize is rw;
	has $.doi is rw;
	has $.base64 is rw;

	method split-name( $author ) {
		$author ~~ m|^(.*) \s* (.*)$|;
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

#### MAIN Loop ####
my %args = @*ARGS.map( {.substr(1).split('=')} ).flat;  

my $j = journal.new( 
	name => 'ejeg',
	url  => 'ejeg.com',
	issn => 'ISSN 1479-439X',
	copyrightHolder => 
			'Copyright &#169; 2003-2021 Electronic Journal of e-Government',
);														#say $j;

chdir( "../files/{$j.name}/htm" );						#dir.say;
my $issurl = %args<issurl>;								#eg. -issurl='http://ejise.com/volume7/issue1'
$issurl ~~ m|volume (\d*) \/ issue (\d*)|;
my $vol-num = $0;
my $iss-num = $1;

my $wget-html = 1;
my $fn-html = "{$j.name}-volume{$vol-num}-issue{$iss-num}.html";
shell( "wget -O $fn-html $issurl" ) if $wget-html;
my $fh-html = open( $fn-html );
my $html = $fh-html.slurp;
$fh-html.close;

my $parser = HTML::Parser::XML.new;
$parser.parse($html);
my $d = $parser.xmldoc;									#ie. XML::Document from html
chdir( "../pdf" );
parse-issue-page( $d, $j, :verbose, :do-pdf );

chdir( "../../../raku" );
my ( $iss-xml, $use-xml ) = generate-xml( $j );			#say $use-xml; #say $iss-xml; 

chdir( "../files/{$j.name}/xml-use" );
my $fh-xml-use = open( 'tmp.xml', :w );
$fh-xml-use.say( $use-xml );
$fh-xml-use.close;
my $fn-xml-use = "{$j.name}-volume{$vol-num}-issue{$iss-num}-use.xml";
shell( "xmllint --format tmp.xml > $fn-xml-use" );
unlink 'tmp.xml'; 

chdir( "../xml-iss" );
my $fh-xml-iss = open( 'tmp.xml', :w );
$fh-xml-iss.say( $iss-xml );
$fh-xml-iss.close;
my $fn-xml-iss = "{$j.name}-volume{$vol-num}-issue{$iss-num}-iss.xml";
shell( "xmllint --format tmp.xml > $fn-xml-iss" );
unlink 'tmp.xml'; 

#END

#### Parse OLD Issue Page ####
sub parse-issue-page( $d, $j, :$verbose, :$do-pdf ) {

	my @art-containers = $d.elements(:RECURSE(Inf), :class(/article\-container/)); 
	my $iss-container  = @art-containers.splice(0,1).[0];

	say "===Volume Info===" if $verbose;
	#eg. 'Volume 23 Issue 1 / Feb 2020'
	my $itc = $iss-container.elements(:RECURSE(Inf), :class('article-title-container')).first; 
	my $vit = parse-title( $itc );
	$vit ~~ m|Volume \s* (\d*) \s* Issue \s* (\d*) .*? \/ \s* (\w*\s+\d*)|;
	say "Volume Issue Title: $vit";

	my $vol := $j.volume; 
	$j.volume = volume.new( 
		number => +$0 
	);
	say "+++++++++++++++++++\n" if $verbose;

	say "===Issue Info===" if $verbose;
	my $i-c := $iss-container;
	my $iss-authors  = parse-authors(  $i-c.elements(:RECURSE(Inf), :class('author-list')).first ); #may need later
	my $iss-keywords = parse-keywords( $i-c.elements(:RECURSE(Inf), :class('article-description-keywords')).first ); #may need ltr
	my $iss-oldurl   = parse-oldurl(   $i-c.elements(:RECURSE(Inf), :class('article-sub-container')).first ); 

	my $iss := $vol.issue;
	$iss = issue.new( 
		number  => +$1, 
		date    => ~$2, 
		oldurl  => $iss-oldurl,
		authors => $iss-authors,
		id => url2id( $iss-oldurl ),
	);
	$iss.filename = url2fn( $iss ); 
	say "+++++++++++++++++++\n" if $verbose;

	for 0..^@art-containers -> $ai {
		my $a-c = @art-containers[$ai];

		say "===Article No.{$ai+1}===" if $verbose;

		my $art-oldurl = parse-oldurl( $a-c.elements(:RECURSE(Inf), :class('article-sub-container')).first ); 

		my $art := $iss.articles[$ai];
		$art = article.new( 
			title    => parse-title(    $a-c.elements(:RECURSE(Inf), :class('article-title-container')).first ), 
			pages    => parse-pages(    $a-c.elements(:RECURSE(Inf), :class('article-title-container')).first ), 
			authors  => parse-authors(  $a-c.elements(:RECURSE(Inf), :class('author-list'            )).first ), 
			abstract => parse-abstract( $a-c.elements(:RECURSE(Inf), :class('article-description-text')).first ), 
			keywords => parse-keywords( $a-c.elements(:RECURSE(Inf), :class('article-description-keywords')).first ), 
			oldurl   => $art-oldurl,
			id		 => url2id( $art-oldurl ),
		);

		if $do-pdf {
			### PDF File Operations ###
			my $fn-pdf = $art.filename = url2fn( $iss, $art ); 
			shell( "wget -O $fn-pdf {$art.oldurl}" );

			my $proc = shell "stat -f%z $fn-pdf",:out;
			my $size = $proc.out.slurp: :close;
			$art.filesize = +$size;

			$art.filename ~~ m|(.*)\.pdf|;
			my $fn-txt = "$0.txt"; 
			my $fn-b64 = "$0.b64"; 

			shell( "pdftotext -f 1 -l 1 -enc UTF-8 $fn-pdf $fn-txt" ); 
			my $fh-txt = open( $fn-txt );
			my @txt-lines = $fh-txt.lines;
			$fh-txt.close; 
			for @txt-lines -> $txt-line {
				if $txt-line ~~ m|DOI\: (.*) $| {
					$art.doi = $0.trim;
				}
			}

			shell( "base64 -i $fn-pdf -o $fn-b64" ); 
			my $fh-b64 = open( $fn-b64, :bin );
			$art.base64 = $fh-b64.slurp;
			$fh-b64.close; 
		}

		say "+++++++++++++++++++\n" if $verbose;
	}

	#### Parse Subroutines ####
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
			$res ~~ s:g/'&'//;
			say "$res" if $verbose;
			@res.push: $res;
		}
		return @res;
	}
	sub parse-abstract( $t ) {
		try {
			my $res  = $t.firstChild().text.trim;
			$res ~~ s:global/\n//;
			if $res ~~ /000000/ { return '' }
			say "Abstract:\n$res" if $verbose;
			return $res;
		} // warn "No abstract found.";
	}
	sub parse-keywords( $t ) {
		try {
			my @a    = $t.elements(:TAG<a>);
			my @res;
			say "Keywords:" if $verbose;
			for 0..^@a -> $j {
				my $res  = @a[$j].firstChild().text.trim;
				if $res ~~ /000000/ { return '' }
				if $res ~~ /<[þÿ]>/ { return '' }
				say "$res" if $verbose;
				@res.push: $res;
			}
			return @res;
		} // warn "No keywords found.";
	}
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
}

#### Generate XML ####
sub generate-xml( $j ) {

	#### Issue XML Substitutions ####
	my $ix = XML::Document.load('./ojs-templates/issues-blank-tw2.xml');
	my $ux = XML::Document.load('./ojs-templates/users-blank-cd2.xml');

	my $vol := $j.volume; 
	my $iss := $vol.issue;

	#| ignoring issue attrs
	#| my @iss-attrs = <url_path xmlns:ns xmlns published current xsi:schemaLocation xmlns:xsi access_status>

	#| adjusting issue id tags
	#| my @iss-tags = <id issue_identification= sections= articles=>;
	my @iid-tags = <volume number year>;

	my $iss-ii-node = get-node( $ix, 'issue_identification' ).first;
	for @iid-tags -> $iid-tag {
		get-node-from-elem( $iss-ii-node, $iid-tag ).remove;
	}
	$iss-ii-node.append( 'volume', $vol.number );
	$iss-ii-node.append( 'number', $iss.number );
	$iss-ii-node.append( 'year',   $iss.year );

	#| loop over articles
	my $articles-node = get-node( $ix, 'articles' );
	my $article-blank = get-node-from-elem( $articles-node, 'article' );
	$article-blank.remove;

	##for 1..2 -> $ai {
	for 1..$iss.articles.elems -> $ai {
		my $art := $iss.articles[$ai-1];

		my $n-art = $articles-node.append( 'article' )[*-1];
		do-art-xml-substitutions($n-art, $art, $iss, $ai);

		do-use-xml-substitutions($ux, $art);
	}
	return $ix, $ux;

	#### Article XML Substitutions ####
	sub	do-art-xml-substitutions($n-art,$art,$iss,$ai) {

		#| my @art-attrs = <current_publication_id date_submitted stage status submission_progress>;
		$n-art.attribs<current_publication_id>	= $art.id;
		$n-art.attribs<date_submitted>			= "{$iss.yyyy-mm-dd}";
		$n-art.attribs<stage>					= 'production';
		$n-art.attribs<status>					= '3';
		$n-art.attribs<submission_progress>		= '0';

		#| my @art-tags = <id submission_file publication>;
		$n-art.append( 'id', $art.id, type => 'internal', advice => 'ignore' );	#ie. article id = 1084

			my $n-sub = $n-art.append( 'submission_file' )[*-1];

			#| my @sub-attrs = <id stage xsi:schemaLocation>;
			$n-sub.attribs<id>						= "{20 + $ai}";  #make submission id unique
			$n-sub.attribs<stage>					= 'proof';
			$n-sub.attribs<xsi:schemaLocation>		= 'http://pkp.sfu.ca native.xsd';

			#| my @sub-tags = <revision>;
			my $n-rev = $n-sub.append( 'revision' )[*-1];

				#| my @rev-attrs = <date_modified date_uploaded filename filesize filetype genre number uploader viewable>;
				$n-rev.attribs<date_modified>			= "{$iss.yyyy-mm-dd}";
				$n-rev.attribs<date_uploaded>			= "{$iss.yyyy-mm-dd}";
				$n-rev.attribs<filename>				= $art.filename;
				$n-rev.attribs<filesize>				= $art.filesize;
				$n-rev.attribs<filetype>				= 'application/pdf';
				$n-rev.attribs<genre>					= 'Article Text';
				$n-rev.attribs<number>					= "{40 + $ai}"; #make revision number unique
				$n-rev.attribs<uploader>				= 'admin';
				$n-rev.attribs<viewable>				= 'false';

				#| my @rev-tags = <name embed>;
				$n-rev.append( 'name', $art.filename, locale => 'en_US' );
				$n-rev.append( 'embed', $art.base64.decode, encoding => 'base64' );

		my $n-pub = $n-art.append( 'publication' )[*-1];

		#| my @pub-attrs = <access_status date_published locale primary_contact_id 
		#|								section_ref seq status url_path version xsi:schemaLocation>
		$n-pub.attribs<access_status>			= '0'; 
		$n-pub.attribs<date_published>			= "{$iss.yyyy-mm-dd}";
		$n-pub.attribs<locale>					= 'en_US'; 
		$n-pub.attribs<primary_contact_id>		= '4';
		$n-pub.attribs<section_ref>				= 'ART';
		$n-pub.attribs<seq>						= $ai;      #sequence number of art in iss
		$n-pub.attribs<status>					= '3'; 
		$n-pub.attribs<url_path>				= '';
		$n-pub.attribs<version>					= '1';
		$n-pub.attribs<xsi:schemaLocation>		= 'http://pkp.sfu.ca native.xsd';

		#| my @pub-tags = <id title abstract pages copyrightHolder copyrightYear keywords= keyword authors= author=>;
		$n-pub.append( 'id', $art.id, type => 'internal', advice => 'ignore' );	#ie. article id = 1084
		if $art.doi {
			$n-pub.append( 'id', $art.doi, type => 'doi', advice => 'update' );	#ie. article doi = 10.34190/et.21.1.5
		}

		$n-pub.append( 'title', $art.title, locale => 'en_US' );
		$n-pub.append( 'abstract', clean-text($art.abstract), locale => 'en_US' );
		$n-pub.append( 'copyrightHolder', $j.copyrightHolder, locale => 'en_US' );
		$n-pub.append( 'copyrightYear', $iss.year );

		#| synthesize & populate keyword tags
		if $art.keywords {
			my $k-top = $n-pub.append( 'keywords', locale => 'en_US' )[*-1];
			for $art.keywords -> $kw {
				$k-top.append( 'keyword', clean-text( $kw ) );
			} 
		}

		#| synthesize & populate author & child tags
		#| my @aut-attrs = <id include_in_browse seq user_group_ref>;
		#| my @aut-tags = <givenname familyname affiliation country email username orcid biography>;
		my @aut-tags = <givenname familyname email>;   #omit empty tags "less is more"

		my $a-top = $n-pub.append( 'authors' )[*-1];
		$a-top.attribs<xsi:schemaLocation>		= 'http://pkp.sfu.ca native.xsd';

		for 0..^$art.authors.elems -> $i {
			my $n-aut = $a-top.insert( 'author', 
				#include_in_browser => "true",      #not allowed
				user_group_ref => "Author",
				seq => $i,
				id => $art.id * 10 + $i,
			).first;

			my ( $givenname, $familyname ) = $art.split-name( $art.authors[$i] );
			$n-aut.append( 'givenname',  $givenname,  locale => "en_US" );
			$n-aut.append( 'familyname', $familyname, locale => "en_US" );

			$n-aut.append( 'email', $art.make-email( $art.authors[$i], $j ) );
		} 

		my $n-gal = $n-pub.append( 'article_galley' )[*-1];

		#| my @gal-attrs = <approved locale xsi:schemaLocation>;
		$n-gal.attribs<approved>				= 'false';
		$n-gal.attribs<locale>					= 'en_US'; 
		$n-gal.attribs<xsi:schemaLocation>		= 'http://pkp.sfu.ca native.xsd';

		#| my @gal-tags = <id name seq submission_file_ref>;
		$n-gal.append( 'id', '2', type => 'internal', advice => 'ignore' );	#ie. gally id = 2
		$n-gal.append( 'name',  'PDF',  locale => "en_US" );
		$n-gal.append( 'seq', '0' );
		$n-gal.append( 'submission_file_ref', id => "{20+$ai}", revision => "{40+$ai}" );

		$n-pub.append( 'pages', $art.pages );				#leave in see if causes trouble FIXME
	}
	#### Users XML Substitutions ####
	sub do-use-xml-substitutions($ux,$art) {

		#| my @use-tags = <givenname familyname email username>;
		#| also need <user_group_ref password= value> 

		my $u-top = get-node( $ux, 'users' );					#say $u-top;
		my $u-old = get-node-from-elem( $u-top, 'user' ); 
		$u-old.remove;

		#| synthesize & populate user & child tags
		for 0..^$art.authors.elems -> $i {
			my $n-use = $u-top.insert( 'user' ).first;

			my ( $givenname, $familyname ) = $art.split-name( $art.authors[$i] );
			$n-use.append( 'givenname',  $givenname,  locale => "en_US" ); 
			$n-use.append( 'familyname', $familyname, locale => "en_US" );
			$n-use.append( 'email',      $art.make-email( $art.authors[$i], $j ) );
			$n-use.append( 'username',   $art.make-username( $art.authors[$i] ) );

			my $n-pass = $n-use.append( 'password',
				encryption => "sha1",
				is_disabled => "false",
				must_change => "false",
			)[*-1];
			$n-pass.append( 'value' );						#say $n-pass;

			$n-use.append( 'user_group_ref', 'Author' );
		} 
	}

	#### XML Subroutines ####
	#| the recurse control makes this convenient, but a tad imprecise
	sub get-node( $dx, $tag ) {
		return $dx.elements(:TAG($tag) :RECURSE).first;
	}
	sub get-node-from-elem( $elem, $tag ) {
		return $elem.elements(:TAG($tag) :RECURSE).first;
	}
	sub clean-text( $txt is copy ) {
		$txt ~~ s:g|(\& <!before <[\#]> >)|&amp;|;
		return $txt;
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
my $id = $ix.elements(:TAG<id>).first; say $id;
my $ni = XML::Text.new( text => 'Nah Monthly' );
$id.insert( $ni );
my $nt = XML::Text.new( text => 'Nah Monthly' );
$ar[3].replace( $ar[3].nodes[0], $nt );
say $ar[3].nodes[0];
	my $ar = $ix.root; say $ar.name;
	for 1..10 -> $i {
		say "article child $i is:" ~ $ar[$i];
	}
	say $ar[3].attribs;
	say $ar[3].nodes;
	say $ar[3].nodes[0].WHAT;
	say $ar[3].nodes[0];
#]

#EOF
