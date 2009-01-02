# Copyright (c) 2007-2008 David Caldwell,  All Rights Reserved. -*- perl -*-

package Darcs::Inventory;

$VERSION = '0.9';

use strict;
use warnings;
use Darcs::Inventory::Patch;

sub read($) {
    my ($filename) = @_;
    my (@patch, $patch);
    open INV, "<", $filename or return undef;
    while (<INV>) {
        next if /^pristine:$/ && !defined $patch;
        $patch[-1] .= "\n$1" if /^(hash: .*)$/ && !defined $patch;
        (push(@patch, $patch . ($1||"")), undef $patch) if s/^(.*\*[-*]\d{14})?\]//;
        $patch = '' if s/^\s*\[//;
        $patch .= $_ if defined $patch;
    }
    close INV;
    \@patch;
}

sub load($$) {
    my ($class, $filename) = @_;
    my $patch = Darcs::Inventory::read($filename);
    return undef unless $patch;
    bless { patches => [map { new Darcs::Inventory::Patch($_) } @$patch],
            file    => $filename }, $class;
}

sub new($$) {
    my ($class, $repo) = @_;

    my $repo_format = eval {
        local $/;
        open FORMAT, '<', "$repo/_darcs/format" or return "old";
        my $f = <FORMAT>;
        close FORMAT;
        $f
    };
    my $inventory_file = $repo_format =~ /hashed/ ? "$repo/_darcs/hashed_inventory" : "$repo/_darcs/inventory";
    my $inventory = $class->load($inventory_file);
    return undef unless $inventory;
    $inventory->{format} = $repo_format;
    $inventory;
}

sub format($)  { return $_[0]->{format} || "unknown" };
sub file($)    { return $_[0]->{file} };
sub patches($) { return @{$_[0]->{patches}} };

1;
__END__

=head1 NAME

Darcs::Inventory - Read and parse a darcs version 1 or 2 inventory file

=head1 SYNOPSIS

    use Darcs::Inventory;
    $i = Darcs::Inventory->new("repo_dir");
    $i = Darcs::Inventory->load("repo_dir/_darcs/inventory");
    for ($i->patches) {
        print $_->info;
    }
    $i->format; # contents of _darcs/format, or "old", or "unknown"
    $i->file;   # The path to the inventory file.

    @raw = Darcs::Inventory::read("_darcs/inventory");
    print $raw[0];         # Prints the unparsed contents of the
                           # first patch in the inventory file.
=cut
