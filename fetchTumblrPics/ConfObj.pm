package fetchTumblrPics::ConfObj;

use strict;
use warnings;

our $VERSION = "0.1";

sub new {
  my $classname 	= shift;
  my $self 		= shift;
  $self->{'mode'}	= undef;
  $self->{'url'}	= undef;
  $self->{'outputDir'}  = undef;
  $self->{'fetched'}	= undef;
  $self->{'debug'}      = undef;
  $self->{'conf'}       = undef;
  $self->{'do_init'}	= undef;
  bless $self,ref($classname)||$classname;
}

sub set {
  my $self = shift;
  my $var = shift;
  my $to = shift;
  return unless (defined($var) && defined($to));
  if (exists($self->{$var})) {
    $self->{$var} = $to;
  }
  return;
}

sub getParam {
  my $self = shift;
  my $param = shift;
  return $self->{$param};
}

sub setConf {
  my $self = shift;
  my $conf = shift;
  return unless defined($conf);
  $self->{'conf'} = $conf;
  return;
}

sub fillGlobals {
  my $self = shift;
  if (defined($self->{'conf'}{'FTP:global'}{'fetchedFile'})) {
    $self->{'fetched'}	= $self->{'conf'}{'FTP:global'}{'fetchedFile'};
  } 
  if (!-e $self->{'conf'}{'FTP:global'}{'fetchedFile'}) {
    warn "You set a fetchedFile (".$self->{'conf'}{'FTP:global'}{'fetchedFile'}.") that does not exist! Hope we can create it later...";
  }
  if (defined($self->{'conf'}{'FTP:global'}{'outputDir'}) && -d $self->{'conf'}{'FTP:global'}{'outputDir'}) {
    $self->{'outputDir'} = $self->{'conf'}{'FTP:global'}{'outputDir'};
  } elsif (!-d $self->{'conf'}{'FTP:global'}{'outputDir'}) {
    warn "You set a outputDir (".$self->{'conf'}{'FTP:global'}{'outputDir'}.") that does not exist!";
  }
  $self->{'debug'} = $self->{'conf'}{'FTP:global'}{'debug'};
}

sub fillDefaults {
  my $self = shift;
  if (defined($self->{'conf'}{'FTP:default'}{'mode'}) && (
      $self->{'conf'}{'FTP:default'}{'mode'} =~ /^api$/i || 
      $self->{'conf'}{'FTP:default'}{'mode'} =~ /^rss$/i || 
      $self->{'conf'}{'FTP:default'}{'mode'} =~ /^html$/i)) {
    $self->{mode} = $self->{'conf'}{'FTP:default'}{'mode'};
  }
}

sub prepare {
  my $self = shift;
  $self->fillGlobals();
  $self->fillDefaults();
}

sub fillJob {
  my $self = shift;
  my $job = shift;
  my %jobParams = (     'mode'  =>      $self->{'mode'},
                        'outputDir'     =>      $self->{'outputDir'},
                        'fetched'       =>      $self->{'fetched'},
                        'debug'         =>      $self->{'debug'},
                        'url'           =>      $self->{'url'}
                  );
  if(!defined($job)) {
    return;
  } else {
    $self->{'url'} = 'http://' . $job . '.tumblr.com';
  }
  foreach my $key (keys %jobParams) {
    if (defined($self->{'conf'}{$job}{$key})) {
      # Please no overwrite "self" in config :)
      $self->{$key} = $self->{'conf'}{$job}{$key};
    }
  }
  if ($self->{'mode'} =~ /api/ && $self->{'url'} !~ /api\/read$/) {
    $self->{'url'} .= '/api/read';
  } elsif ($self->{'mode'} =~ /rss/ && $self->{'url'} !~ /rss$/) {
    $self->{'url'} .= '/rss';
  }
}

sub getJobs {
  my $self = shift;
  return unless defined($self->{'conf'});
  my @jobs;
  foreach my $job (keys %{$self->{'conf'}{'FTP:list'}}) {
    push @jobs,$job;
    $self->{'debug'} && print "Found Job: " . $job . "\n";
  }
  foreach my $job (keys %{$self->{'conf'}}) {
    next unless $job !~ /^FTP:/;
    push @jobs,$job;
    $self->{'debug'} && print "Found Job: " . $job . "\n";
  }
  $self->{'debug'} && print "Jobs: @jobs\n";
  return @jobs;
}

1;
