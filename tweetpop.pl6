#!/usr/bin/env perl6

use v6.c;
use strict;
use fatal; # Terminate if tweet fails
use Twitter;

sub MAIN (Str :$consumer-key, Str :$consumer-secret, Str :$access-token,
    Str :$access-token-secret, Str :$queue-file, Str :$completed-file) {
  my Twitter $twitter .= new(
    consumer-key => $consumer-key,
    consumer-secret => $consumer-secret,
    access-token => $access-token,
    access-token-secret => $access-token-secret);

  # read the first line from the queue
  my @lines = $queue-file.IO.lines;
  my $text = @lines.shift;

  # post it to Twitter
  my %response = $twitter.tweet($text);
  $*ERR.say("Tweet successful: {%response.perl}");

  my IO::Handle $out = open($queue-file, :w);
  $out.say($_) for @lines;
  $out.close;

  with $completed-file {
    spurt $_, $text ~ "\n", :append;
  }
}
