#!/usr/bin/env perl
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use Getopt::Long qw(GetOptions);
use IPC::Open2;

my ($root, $base, $baseline, $print_base, $print_current, $fixture);
GetOptions(
  'root=s' => \$root, 'base=s' => \$base, 'baseline=s' => \$baseline,
  'print-base-baseline' => \$print_base, 'print-current-findings' => \$print_current,
  'self-test-fixture=s' => \$fixture,
) or die "invalid arguments\n";
die "--root, --base, and --baseline are required\n" unless defined($root) && defined($base) && defined($baseline);
chdir $root or die "could not enter repository root\n";
my $baseline_rel = $baseline;
$baseline_rel =~ s{^\Q$root\E/?}{} if $baseline_rel =~ m{^\Q$root\E(?:/|$)};

open my $policy_fh, '<', $baseline or die "baseline policy file is required\n";
my $policy_header = <$policy_fh> // '';
close $policy_fh;
die "baseline policy header is invalid\n"
  unless $policy_header =~ /^# tracked-privacy-exceptions-v1 maintainer-token=([A-Za-z0-9_-]+)\r?\n?$/;
my $token = $1;
my $cap = 64 * 1024;
sub git_bytes {
  my (@args) = @_;
  open my $fh, '-|', 'git', @args or die "could not start git command\n";
  binmode $fh;
  local $/;
  my $out = <$fh> // '';
  close $fh or die "git command failed\n";
  return $out;
}
sub tracked_paths {
  my ($rev) = @_;
  my $raw = defined($rev) ? git_bytes('ls-tree', '-r', '-z', '--name-only', $rev) : git_bytes('ls-files', '-z');
  return grep { length } split /\0/, $raw;
}
sub base_blob {
  my ($rev, $path) = @_;
  return git_bytes('cat-file', 'blob', "$rev:$path");
}
sub batch_blob_reader {
  my ($rev) = @_;
  my $raw = git_bytes('ls-tree', '-r', '-z', '--format=%(objectname)%x09%(path)', $rev);
  my %objects;
  for my $row (split /\0/, $raw) {
    my ($oid, $path) = split /\t/, $row, 2;
    $objects{$path} = $oid if defined($path) && $oid =~ /^[a-f0-9]{40,64}$/;
  }
  my ($out, $in);
  my $pid = open2($out, $in, 'git', 'cat-file', '--batch');
  binmode $out; binmode $in;
  my $read = sub {
    my ($path) = @_;
    my $oid = $objects{$path};
    return undef unless defined $oid;
    print {$in} "$oid\n" or die "could not request tracked blob\n";
    my $header = <$out>;
    die "could not read tracked blob header\n" unless defined $header && $header =~ /^[a-f0-9]{40,64} blob (\d+)\n$/;
    my $size = 0 + $1;
    my $bytes = '';
    while (length($bytes) < $size) {
      my $count = read($out, my $chunk, $size - length($bytes));
      die "truncated tracked blob\n" unless defined($count) && $count > 0;
      $bytes .= $chunk;
    }
    read($out, my $separator, 1);
    die "invalid tracked blob separator\n" unless $separator eq "\n";
    return $bytes;
  };
  my $close = sub {
    close $in; close $out;
    waitpid($pid, 0);
    die "tracked blob batch failed\n" if $? != 0;
  };
  return ($read, $close);
}
sub current_blob {
  my ($path) = @_;
  return undef unless -f $path;
  open my $fh, '<', $path or die "could not read tracked file\n";
  binmode $fh;
  local $/;
  return <$fh> // '';
}
sub findings_for {
  my ($files, $loader) = @_;
  my %found;
  for my $path (@$files) {
    my $bytes = $loader->($path);
    next unless defined $bytes;
    $bytes =~ s/\A# tracked-privacy-exceptions-v1 maintainer-token=\Q$token\E\r?\n// if $path eq $baseline_rel;
    my @matches;
    while ($bytes =~ m{(/(?:Users|home)/[^/\x00\r\n]+/)}g) { push @matches, ['home_path', $1] }
    while ($bytes =~ /(?<![A-Za-z0-9_:\/\.\-+\@])\Q$token\E(?![A-Za-z0-9_:\/\-+\@])/ig) { push @matches, ['maintainer_name', $&] }
    for my $match (@matches) {
      my ($kind, $value) = @$match;
      my $fingerprint = sha256_hex(join("\0", $kind, $path, lc($value)));
      $found{"$kind\t$fingerprint\t$path"} = 1;
    }
  }
  return [sort keys %found];
}
sub is_ledger {
  my ($path) = @_;
  return 1 if $path =~ m{^\.planning/(?:debug|execution|recovery)/.+\.json$}i;
  my ($name) = $path =~ m{(?:^|/)([^/]+)$};
  return defined($name) && $name =~ /(?:LEDGER|PRESERVATION|RECEIPT|RECEIPTS)/i && $name =~ /\.json$/i;
}
sub tree_sizes {
  my ($rev) = @_;
  my %sizes;
  my $raw = git_bytes('ls-tree', '-r', '-l', '-z', $rev);
  for my $entry (split /\0/, $raw) {
    my ($meta, $path) = split /\t/, $entry, 2;
    next unless defined $path && $path =~ /\.json$/i;
    my @fields = split / +/, $meta;
    next unless @fields >= 4 && $fields[3] =~ /^\d+$/;
    $sizes{$path} = 0 + $fields[3];
  }
  return \%sizes;
}
sub load_baseline {
  my ($path) = @_;
  open my $fh, '<', $path or return { findings => {}, ledgers => {} };
  binmode $fh;
  my $contents;
  { local $/; $contents = <$fh> // ''; }
  close $fh;
  return parse_baseline($contents);
}
sub parse_baseline {
  my ($contents) = @_;
  open my $fh, '<', \$contents or die "could not parse baseline\n";
  my (%findings, %ledgers, $header);
  while (my $line = <$fh>) {
    chomp $line;
    next if $line eq '';
    if ($line =~ /^# tracked-privacy-exceptions-v1 maintainer-token=([^\t]+)$/) {
      die "baseline policy header is invalid\n" if defined($header) || $1 ne $token;
      $header = 1;
      next;
    }
    my @f = split /\t/, $line, -1;
    if (@f == 4 && $f[0] eq 'finding' && $f[1] =~ /^(?:home_path|maintainer_name)$/ && $f[2] =~ /^[a-f0-9]{64}$/ && length($f[3])) {
      die "baseline contains duplicate finding rows\n" if $findings{$f[1]."\t".$f[2]."\t".$f[3]}++;
    } elsif (@f == 3 && $f[0] eq 'ledger' && $f[1] =~ /^\d+$/ && $f[2] !~ m{^(?:/|\.\.)} && $f[2] !~ m{(?:^|/)\.\.(?:/|$)}) {
      die "baseline contains duplicate ledger rows\n" if $ledgers{$f[2]}++;
      $ledgers{$f[2]} = 0 + $f[1];
    } else {
      die "baseline contains a malformed row\n";
    }
  }
  close $fh;
  die "baseline policy header is missing\n" unless $header;
  return { findings => \%findings, ledgers => \%ledgers };
}
sub emit_baseline {
  my ($findings, $ledgers) = @_;
  print "# tracked-privacy-exceptions-v1 maintainer-token=$token\n";
  print "finding\t$_\n" for @$findings;
  for my $path (sort keys %$ledgers) { print "ledger\t$ledgers->{$path}\t$path\n" }
}
sub fail { my ($message) = @_; print STDERR "$message\n"; exit 1 }

my $merge_base = git_bytes('merge-base', 'HEAD', $base);
$merge_base =~ s/\s+\z//;
fail('could not resolve merge base') unless $merge_base =~ /^[a-f0-9]{40,64}$/;
my @base_paths = tracked_paths($merge_base);
my @head_paths = tracked_paths(undef);
my ($read_base_blob, $close_base_blobs) = batch_blob_reader($merge_base);
my $base_findings = findings_for(\@base_paths, $read_base_blob);
$close_base_blobs->();
my $head_findings = findings_for(\@head_paths, sub { current_blob($_[0]) });
my $base_sizes = tree_sizes($merge_base);
my %base_legacy = map { $_ => $base_sizes->{$_} } grep { is_ledger($_) && ($base_sizes->{$_} // 0) > $cap } keys %$base_sizes;
my %base_f = map { $_ => 1 } @$base_findings;
my %head_f = map { $_ => 1 } @$head_findings;

if ($print_base) {
  emit_baseline($base_findings, \%base_legacy);
  exit 0;
}
if ($print_current) {
  print "$_\n" for @$head_findings;
  exit 0;
}

my $head_state = load_baseline($baseline);
my %base_path_set = map { $_ => 1 } @base_paths;
my $base_baseline_blob = $base_path_set{$baseline_rel} ? base_blob($merge_base, $baseline_rel) : undef;
my $base_has_baseline = defined($base_baseline_blob) && length($base_baseline_blob);
my $base_state;
if ($base_has_baseline) {
  $base_state = parse_baseline($base_baseline_blob);
} else {
  $base_state = { findings => { map { $_ => 1 } @$base_findings }, ledgers => \%base_legacy };
}
for my $finding (sort keys %{$head_state->{findings}}) {
  fail("baseline finding is not present in merge-base: $finding") unless $base_state->{findings}{$finding};
}
for my $finding (sort keys %head_f) {
  fail("unreviewed privacy finding: $finding") unless $head_state->{findings}{$finding};
}
for my $path (sort keys %{$head_state->{ledgers}}) {
  fail("ledger exception is not present in merge-base: $path") unless exists $base_state->{ledgers}{$path};
  fail("ledger exception ceiling grew: $path") if $head_state->{ledgers}{$path} > $base_state->{ledgers}{$path};
}
for my $path (@head_paths) {
  next unless is_ledger($path);
  my $bytes = current_blob($path);
  next unless defined $bytes;
  my $size = length($bytes);
  next if $size <= $cap;
  my $ceiling = $head_state->{ledgers}{$path};
  fail("oversized evidence ledger: $path") unless defined($ceiling) && $size <= $ceiling;
}
exit 0;
