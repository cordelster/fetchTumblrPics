package fetchTumblrPics::GetObj;

use 5.005;
use strict;
use warnings;
use Switch;
use LWP::UserAgent;
use XML::LibXML;
use HTML::TreeBuilder;

our $VERSION = '0.01';

sub new {
  my $classname 	= shift;
  my $self 		= shift;
  $self->{'job'}	= undef;
  $self->{'fetched'}	= ();
  $self->{'get'}	= [];
  bless $self,ref($classname)||$classname;
}

sub run {
	my $self = shift;
	$self->readFetched();
	$self->getFeed();
	$self->getContent();
	$self->writeFetched();
}

sub setJob {
	my $self = shift;
	my $job = shift;
	return unless defined($job);
	$self->{'job'} = $job;
}

sub readFetched {
	my $self = shift;
	if (!-e ($self->{'job'})->getParam('fetched')) {
		warn ("Fetched-file " . ($self->{'job'})->getParam('fetched') . " not found. Will maybe be created.\n");
	} else {
		my $uf = open(IN,"<",($self->{'job'})->getParam('fetched')) or die $!;
		while (my $line = <IN>) {
			chomp $line;
			($self->{'job'})->getParam('debug') && print $line . "\n";
			$self->{'fetched'}{$line} = 1; # TODO: This will become a timestamp for auto-delete.
		}
	}
}

sub getFeed {
	my $self = shift;
	return unless defined(($self->{'job'})->getParam('url'));
	my $mode = ($self->{'job'})->getParam('mode');
	my $url = ($self->{'job'})->getParam('url');
	if ($mode !~ /rss/ && $mode !~ /html/ && $mode !~ /api/) {
		warn ("Mode for Job " . $url . " is not valid, using API!\n");
		$mode = 'api';
	}
	my ($start,$baseUrl,$num);
	$baseUrl = $url;
	$num = 50;
	$start = 0;
CATCH:	while (1) {
		my $ua = LWP::UserAgent->new;
		$ua->timeout(30);
		$ua->env_proxy;
		if ($mode =~ /api/) {
			$url = $baseUrl . "?type=photo&num=$num&start=$start";	
		}
		my $resp = $ua->get($url);
		if (!$resp->is_success) {
			print "Some Error on " . $url . " - skipping! ";
			print $resp->status_line;
			last CATCH;
		} else {
			binmode (STDOUT,":utf8");
			switch($mode) {
				case 'rss' {
					print "\nParsing RSS: $url!\n";
					my $parser = XML::LibXML->new();
					my $doc = $parser->parse_string($resp->content);
					my $root = $doc->documentElement();
					my $xcont = XML::LibXML::XPathContext->new($root);
					my $imgnodes = $xcont->findnodes('//description');
					foreach my $itemnode ($imgnodes->get_nodelist) {
						my $descnd = $itemnode->firstChild;
						if (!defined($descnd)) { next; }
						my $desc = $descnd->getValue;
						if ($desc =~ /http.*"/x) {
							$desc =~ /(http.*?)"/x;
							my $getFile = $1;
							push @{$self->{'get'}},$getFile;
							last CATCH;
						}
					}
				}
				case 'html' {
					print "\nParsing HTML: $url!\n";
					my $tree = HTML::TreeBuilder->new_from_content($resp->content);
					foreach my $img ($tree->look_down(_tag=>'img')) {
						$img->look_down( 
							sub { 
								my $src = $_[0]->attr('src');
								push @{$self->{'get'}},$src;
								last CATCH;
							}
						)
					}
				}
				case 'api' {
					print "\nParsing the api output: $url\n";
					my $parser = XML::LibXML->new();
					my $doc = $parser->parse_string($resp->content);
					my $root = $doc->documentElement();
					my $xcont = XML::LibXML::XPathContext->new($root);
					my $imgnodes = $xcont->findnodes('//photo-url[@max-width="1280"]');
					if (!defined($imgnodes)) {
						warn("No big image found on $url!\n");
					}
					foreach my $itemnode ($imgnodes->get_nodelist) {
						my $imagenode = $itemnode->firstChild;
						my $imglink = $imagenode->getValue;
						if (!defined($imglink)) { next; }
						if ($imglink =~ /http.*/) {
							push @{$self->{'get'}},$imglink;
						}
					}
					if (defined(($self->{'job'})->getParam('do_init'))) {
						my $countNode = $xcont->findnodes('//posts');
						my $count = (($countNode->get_nodelist)[0])->findvalue('@total');
						if (($start + $num) < $count) {
							print "\ninit mode: running next iteration: " . ($start + $num) . " until $count\n";
							sleep 2; # TODO: remove
							$start = $start + $num;
							next CATCH;
						}
					}
					last CATCH;
				}
				else {
					# Whatever!
					last CATCH;
				}
			}
		}
	}
}

sub writeFetched {
	my $self = shift;
	open(F,">",($self->{'job'})->getParam('fetched')) or die $!;
	foreach my $key (keys %{$self->{'fetched'}}) {
		print F $key . "\n";
	}
	close F;
}

sub getContent {
	my $self = shift;
	# Get a new UserAgent:
	my $ua = LWP::UserAgent->new;
	$ua->timeout(30);
	$ua->env_proxy;
	foreach my $getFile (@{$self->{'get'}}) {
		if ($getFile !~ /(\.jpg|\.gif|\.jpeg|\.png|\.JPG|\.GIF|\.JPEG|\.PNG|\.tumblr\.com.*photo.*)$/) {
			($self->{'job'})->getParam('debug') && print $getFile . " maybe is no picture!\n";
			next;
		} elsif ($getFile =~ /avatar/) {
			($self->{'job'})->getParam('debug') && print $getFile . " might be an avatar!\n";
			next;
		}
		if (exists($self->{'fetched'}{$getFile})) {
			($self->{'job'})->getParam('debug') && print $getFile . " is already fetched!\n";
		} else {
			my $picr = $ua->get($getFile);
			if (!$picr->is_success) {
				print "Error on " . $getFile . ": " . $picr->status_line . "\n";
			} else {
				my $fileName = $getFile;
				$fileName =~ s/^.*\///;
				if (-e ($self->{'job'})->getParam('outputDir') . $fileName) {
					print "Error: " . $fileName ." already exists!";
				} else {
					open(O,">",($self->{'job'})->getParam('outputDir') . $fileName) or die $!;
					print O $picr->content;
					close O;
					($self->{'job'})->getParam('debug') && print $fileName . " written!\n";
					($self->{'job'})->getParam('debug') || print ".";
					$self->{'fetched'}{$getFile} = 1;
				}
			}
		}
	}
}

1;
