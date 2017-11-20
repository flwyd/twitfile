#!/usr/bin/env perl6

use v6.c;
use strict;

sub substitute-dashes (Str:D $text) returns Str:D {
  $text.subst(/ \- ** 3 <!before \-> /, "\c[EM DASH]", :g)
    .subst(/ \- ** 2 <!before \-> /, "\c[EN DASH]", :g);
}

sub substitute-ellipsis (Str:D $text) returns Str:D {
  $text.subst(/ \. ** 3 <!before \.> /, "\c[HORIZONTAL ELLIPSIS]", :g);
}

sub single-space (Str:D $text) returns Str:D {
  $text.subst(/ \s ** 2..* /, " "):g;
}

sub educate-double (Str:D $text) returns Str:D {
  my $seen = 0;
  $text.subst('"', {
    $seen++ %% 2 ?? "\c[LEFT DOUBLE QUOTATION MARK]"
      !! "\c[RIGHT DOUBLE QUOTATION MARK]"
  }, :g);
}

sub educate-single (Str:D $text) returns Str:D {
  $text.subst(/ <after <:L>> \' <before <:L>> /,
    "\c[MODIFIER LETTER APOSTROPHE]"):g;
}

sub substitute-ligatures (Str:D $text) returns Str:D {
  constant %ligatures = {
    ff => "\c[LATIN SMALL LIGATURE FF]",
    fi => "\c[LATIN SMALL LIGATURE FI]",
    fl => "\c[LATIN SMALL LIGATURE FL]",
    ffi => "\c[LATIN SMALL LIGATURE FFI]",
    ffl => "\c[LATIN SMALL LIGATURE FFL]",
    ij => "\c[LATIN SMALL LIGATURE IJ]",
    oe => "\c[LATIN SMALL LIGATURE OE]",
    st => "\c[LATIN SMALL LIGATURE ST]"};
  $text.subst(/ (ff | ff?<[il]> | ij | oe | st) /, { %ligatures{$_[0]} }, :g);
}

sub trim-dash (Str:D $text) returns Str:D {
  $text.subst(/ \s (\c[EN DASH] | \c[EM DASH]) \s /, *[0], :g);
}

sub strip-scheme (Str:D $text) returns Str:D {
  $text.subst(/ https?\:\/\/ /, '', :g);
}

sub strip-self-attribution (Str:D $text) returns Str:D {
  $text.subst(/ \c[EN DASH] me $ /, '');
}

sub if-longer-than(Int $length, &func) returns Sub {
  return sub (Str:D $text) returns Str {
    return $text.NFC.codes <= $length ?? $text !! func($text);
  }
}

subset PositiveInt of Int where * > 0;
subset ExFile of Str where { $_ === Nil || $_.IO.e };

sub MAIN (PositiveInt :$queue-size is copy = 30, Str :$suffix = ' #quotefile',
    PositiveInt :$tweet-length = 140, ExFile :$queue-file = ExFile,
    ExFile :$completed-file = ExFile, *@files) {
  die "--tweet-length=$tweet-length is not longer than --suffix=\"$suffix\""
    if $tweet-length <= $suffix.chars;
  # Order of text transformations
  my @transforms :=
    &substitute-dashes,
    &substitute-ellipsis,
    &single-space,
    &educate-single,
    &educate-double,
    &if-longer-than($tweet-length - $suffix.chars, &trim-dash),
    &if-longer-than($tweet-length - $suffix.chars, &strip-scheme),
    &if-longer-than($tweet-length - $suffix.chars, &substitute-ligatures),
    &if-longer-than($tweet-length - $suffix.chars, &strip-self-attribution);
  my @queue-lines = do with $queue-file { $_.IO.lines } else { [] };
  my @completed-lines = do with $completed-file { $_.IO.lines } else { [] };
  my $skip = set(|@queue-lines, |@completed-lines);
  $queue-size -= @queue-lines.elems min $queue-size;
  # Shuffle all input lines
  my @lines = IO::ArgFiles.new(args => @files).lines.pick(*);
  my @results;
  while @results.elems < $queue-size and @lines {
    my $text = @lines.pop;
    $text = $_($text) for @transforms;
    $text ~= $suffix;
    @results.push($text) if $text ∉ $skip && $text.NFC.codes <= $tweet-length;
  }
  .say for @results;
}
