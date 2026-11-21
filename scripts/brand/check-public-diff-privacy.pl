#!/usr/bin/env perl
use strict;
use warnings;

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

sub name_pattern {
  my ($name) = @_;
  # Whitespace is a normal prose boundary, including around multi-word names.
  # URL/path and email punctuation remains excluded so an organization URL or
  # an allowed .test fixture does not look like a standalone name mention.
  return qr/(?<![A-Za-z0-9_:\/.\-+\@])\Q$name\E(?![A-Za-z0-9_:\/\-+\@])/i;
}

my @rules = (
  [account_name => name_pattern($account)],
  [git_user_name => name_pattern($git_name)],
  [home_prefix => qr/\Q$home\E/],
  [brand_origin => qr/\Q$origin\E/i],
  [non_test_email => qr/(?<![A-Za-z0-9_.+-])[A-Za-z0-9_.+-]+\@[A-Za-z0-9.-]+\.(?!test\b)[A-Za-z]{2,}/i],
);

# Prove each detector catches a synthetic control without exposing runtime values.
my @controls = (
  "The draft was prepared by $account.",
  "The draft was reviewed by $git_name.",
  "x$home/tmp x",
  "https://$origin/",
  join('', 'person', '@', 'example', '.', 'com'),
);
for my $i (0 .. $#rules) {
  my $pattern = $rules[$i][1];
  die "privacy detector self-check failed (rule $rules[$i][0])\n"
    unless $controls[$i] =~ $pattern;
}
my $synthetic_multiword = join(' ', 'Synthetic', 'Reviewer');
my $multiword_pattern = name_pattern($synthetic_multiword);
die "multi-word name boundary self-check failed\n"
  unless "The draft was reviewed by $synthetic_multiword." =~ $multiword_pattern;
die "name URL-boundary self-check failed\n"
  if "https://example.test/$synthetic_multiword/path" =~ $multiword_pattern;
my $account_test_email = join('', $account, '@', 'example', '.', 'test');
die "account name matched an allowed .test email control\n"
  if $account_test_email =~ $rules[0][1];
my $test_email = join('', 'fixture', '@', 'example', '.', 'test');
my $non_test_email = join('', 'fixture', '@', 'example', '.', 'com');
die "email fixture exception self-check failed\n"
  unless $test_email !~ $rules[-1][1] && $non_test_email =~ $rules[-1][1];

my @entries;
my $diff = run_capture('git', 'diff', '--no-ext-diff', '--unified=0', $base, '--', '.', ':!.planning/**');
my $active_path;
for my $line (split /\n/, $diff) {
  $line =~ s/\r\z//;
  if ($line =~ /^\+\+\+ b\/(.*)$/) {
    $active_path = $1;
    next;
  }
  next unless $line =~ /^\+(?!\+\+)/;
  push @entries, {
    source => 'diff',
    path => $active_path,
    text => substr($line, 1),
  };
}

my $commits = run_capture('git', 'log', '--format=%s%n%b', "$base..HEAD");
for my $line (split /\n/, $commits) {
  $line =~ s/\r\z//;
  push @entries, { source => 'commit', path => undef, text => $line };
}
for my $file (@include) {
  next if $file =~ m{^\.planning/};
  open my $fh, '<', $file or die "included file unavailable\n";
  while (my $line = <$fh>) {
    $line =~ s/\r?\n\z//;
    push @entries, { source => 'include', path => $file, text => $line };
  }
  close $fh;
}

sub is_approved_policy_header {
  my ($entry, $runtime_account) = @_;
  return 0 unless $entry->{source} eq 'diff';
  return 0 unless defined($entry->{path})
    && $entry->{path} eq 'test/fixtures/ci/tracked-privacy-exceptions.tsv';
  return $entry->{text} eq "# tracked-privacy-exceptions-v1 maintainer-token=$runtime_account";
}

my $violations = 0;
for my $entry (@entries) {
  my $approved_policy_header = is_approved_policy_header($entry, $account);
  for my $rule (@rules) {
    my ($name, $pattern) = @$rule;
    next if $approved_policy_header && $name eq 'account_name';
    next if $approved_policy_header && $name eq 'git_user_name'
      && lc($git_name) eq lc($account);
    next unless $entry->{text} =~ $pattern;
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
