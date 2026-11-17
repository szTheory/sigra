#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;

my $base = shift @ARGV or die "usage: $0 <base-revision> [--include <file> ...]\n";
my @include;
while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq '--include') {
    my $file = shift @ARGV // die "--include requires a path\n";
    push @include, $file;
  } else {
    die "unknown argument\n";
  }
}

sub run_capture {
  my (@cmd) = @_;
  open my $fh, '-|', @cmd or die "could not start command\n";
  local $/;
  my $out = <$fh> // '';
  close $fh or die "command failed\n";
  return $out;
}

my $account = run_capture('id', '-un');
chomp $account;
my $git_name = run_capture('git', 'config', 'user.name');
chomp $git_name;
my $home = $ENV{HOME} // '';
die "runtime privacy values did not resolve\n" unless length($account) && length($git_name) && length($home);

open my $index, '<', 'brand/index.html' or die "required brand index is unavailable\n";
local $/;
my $html = <$index> // '';
close $index;
my ($origin) = $html =~ m{https?://([^/"'\s]+)}i;
die "brand-book origin did not resolve\n" unless defined($origin) && length($origin);

my @rules = (
  [account_name => qr/(?<![A-Za-z0-9_.-])\Q$account\E(?![A-Za-z0-9_.-])/i],
  [git_user_name => qr/(?<![A-Za-z0-9_:\/. -])\Q$git_name\E(?![A-Za-z0-9_:\/. -])/i],
  [home_prefix => qr/\Q$home\E/],
  [brand_origin => qr/\Q$origin\E/i],
  [non_test_email => qr/(?<![A-Za-z0-9_.+-])[A-Za-z0-9_.+-]+\@[A-Za-z0-9.-]+\.(?!test\b)[A-Za-z]{2,}/i],
);

# Prove each detector catches a synthetic control without exposing runtime values.
my @controls = (
  " $account ",
  "!$git_name!",
  "x$home/tmp x",
  "https://$origin/",
  'person@example.com',
);
for my $i (0 .. $#rules) {
  my $pattern = $rules[$i][1];
  die "privacy detector self-check failed (rule $rules[$i][0])\n"
    unless $controls[$i] =~ $pattern;
}
die "email fixture exception self-check failed\n"
  unless 'fixture@example.test' !~ $rules[-1][1] && 'fixture@example.com' =~ $rules[-1][1];

my @lines;
my $diff = run_capture('git', 'diff', '--no-ext-diff', '--unified=0', $base, '--', '.', ':!.planning/**');
for my $line (split /\n/, $diff) {
  push @lines, $line if $line =~ /^\+(?!\+\+)/;
}
my $commits = run_capture('git', 'log', '--format=%s%n%b', "$base..HEAD");
push @lines, split(/\n/, $commits);
for my $file (@include) {
  next if $file =~ m{^\.planning/};
  open my $fh, '<', $file or die "included file unavailable\n";
  push @lines, <$fh>;
  close $fh;
}

my $violations = 0;
for my $line (@lines) {
  for my $rule (@rules) {
    my ($name, $pattern) = @$rule;
    next unless $line =~ $pattern;
    $violations++;
    print "privacy gate: prohibited value detected (rule $name)\n";
    last;
  }
}
if ($violations) {
  print "privacy gate failed: $violations added line(s) matched\n";
  exit 1;
}
print "privacy gate passed\n";
