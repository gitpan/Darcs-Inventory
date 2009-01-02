#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use List::Util;
use Darcs::Inventory;

my @flavor = ( {flavor=>'darcs-old',    format=>'old',                inventory=>'inventory' },
               {flavor=>'darcs-hashed', format=>"hashed\n",           inventory=>'hashed_inventory' },
               {flavor=>'darcs-2',      format=>"hashed\ndarcs-2\n",  inventory=>'hashed_inventory' } );

my $create_cache = List::Util::first { $_ eq '--cache' } @ARGV;

sub load_flavor($)
{
    my ($flavor) = @_;
    my $dir = "t/$flavor";

    # Let you test even if you don't have a darcs executable or XML::Simple:
    if (!$create_cache && -f "t/$flavor/darcs-changes.pl") { return @{do "t/$flavor/darcs-changes.pl"} };

    my $darcs_changes_xml;
    open CHANGES, "-|", qw(darcs change --xml), "--repo=t/$flavor" or die "$flavor: darcs changes: $!";
    {
        local $/;
        $darcs_changes_xml = <CHANGES>;
        close CHANGES;
    }

    eval "use XML::Simple; 1;" or die "No XML::Simple and no cached darcs output";
    my @darcs_patches = reverse @{XMLin($darcs_changes_xml, ForceArray=>1)->{patch}};

    # Stupid XML::Simple
    for (@darcs_patches) {
        $_->{author} =~ s/&gt;/>/g;
        $_->{author} =~ s/&lt;/</g;
    }

    use Data::Dumper;
    if ($create_cache) {
        open CACHE, ">", "t/$flavor/darcs-changes.pl" or die "t/$flavor/darcs-changes.pl: $!";
        print CACHE Data::Dumper->Dump([\@darcs_patches], ["darcs_patches"]);
        close CACHE;
    }

    @darcs_patches;
}

@{$_->{patches}} = load_flavor $_->{flavor} foreach @flavor;
# use Data::Dumper;
# print Dumper \@flavor;

my $patches = List::Util::sum map { scalar @{$_->{patches}} } @flavor;

plan tests => $patches * 7 + 4 * scalar @flavor;

sub test_flavor($)
{
    my ($flavor, $inventory, $format, @darcs_patches) = (@{$_[0]}{qw(flavor inventory format)}, @{$_[0]->{patches}});

    my $inv = Darcs::Inventory->new("t/$flavor");
    isnt(undef, $inv, "$flavor: inventory loaded");
    my @patches = $inv->patches;

    is($inv->format, $format, "$flavor: format detection");
    is($inv->file,   "t/$flavor/_darcs/$inventory", "$flavor: inventory file accessor");
    is(scalar @darcs_patches, scalar @patches, "$flavor: Correct number of patches");

    for (0..scalar @darcs_patches-1) {
        is($patches[$_]->hash,                    $darcs_patches[$_]->{hash},                   "$flavor: patch $_ hash");
        is($patches[$_]->undo ? 'True' : 'False', $darcs_patches[$_]->{inverted},               "$flavor: patch $_ undo");
        is($patches[$_]->author,                  $darcs_patches[$_]->{author},                 "$flavor: patch $_ author");
        is($patches[$_]->raw_date,                $darcs_patches[$_]->{date},                   "$flavor: patch $_ raw_date");
        is($patches[$_]->darcs_date,              $darcs_patches[$_]->{local_date},             "$flavor: patch $_ darcs_date");
        is($patches[$_]->name,                    $darcs_patches[$_]->{name}->[0],              "$flavor: patch $_ name");
        is($patches[$_]->long,                    ($darcs_patches[$_]->{comment}||[''])->[0],   "$flavor: patch $_ long");
    }
}

test_flavor($_) foreach @flavor;
