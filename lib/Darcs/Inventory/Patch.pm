# Copyright (c) 2007-2008 David Caldwell,  All Rights Reserved. -*- perl -*-

use warnings;
use strict;

package Darcs::Inventory::Patch;
use base qw(Class::Accessor::Fast);

use Digest::SHA1 qw(sha1_hex);
use Time::Local;
use POSIX;

Darcs::Inventory::Patch->mk_accessors(qw(date raw_date author undo name long hash file raw));

sub darcs_date_str($) { strftime "%a %b %e %H:%M:%S %Z %Y", localtime $_[0] }

sub date_from_darcs($) {
    $_[0] =~ /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/ or die "Couldn't parse date: $_[0]";
    my ($y,$m,$d,$h,$min,$s) = ($1,$2,$3,$4,$5,$6);
    timegm($s,$min,$h,$d,$m-1,$y);
}

sub parse_patch($) {
    my @line = split /\n/, $_[0];
    my %patch;
    ($patch{file} = $1, pop @line) if $line[-1] =~ /^hash: ([0-9]{10}-[0-9a-f]{64})$/;
    @patch{qw(name meta long)} = (shift @line, shift @line, join "", map substr("$_\n",1), @line);
    chomp $patch{long};
    # Jim Radford <radford@golemgroup.com>**20061013045032] 
    $patch{meta} =~ /^(.*)\*([-*])(\d{14})/;
    @patch{qw(author undo date raw_date raw)} = ($1, !!($2 eq '-'), date_from_darcs($3), $3, $_[0]);

    # This hash code comes from reading this: http://wiki.darcs.net/DarcsWiki/NamedPatch
    # Which roughly documents the make_filename function in darcs' src/Darcs/Patch/Info.lhs file.
    my $hashee = join('', @patch{qw(name author raw_date long)}).($patch{undo} ? 't' : 'f');
    $hashee =~ s/\n//g;
    #$patch{computed} = $hashee;
    $patch{hash} = $patch{raw_date}. '-' .substr(sha1_hex($patch{author}), 0, 5). '-' . sha1_hex($hashee).'.gz';
    $patch{file} ||= $patch{hash};
    %patch;
}

sub new($$) {
    my ($class, $patch_string) = @_;
    my %patch = parse_patch($patch_string);
    return bless { %patch }, $class;
}

sub darcs_date($ ) {
    darcs_date_str $_[0]->date
}

sub as_string($) {
    my ($p) = @_;
    my $s = sprintf("%s %s\n  %s %s\n%s", $p->darcs_date, $p->author, $p->undo ? 'UNDO:' : '*', $p->name, $p->long);
    $s =~ s/^Ignore-this:\s+[0-9a-f]+$//m;
    $s;
}

1;
__END__

=head1 NAME

Darcs::Inventory::Patch - Object interface to patches read from the darcs inventory file

=head1 SYNOPSIS

    use Darcs::Inventory;
    $i = Darcs::Inventory->new("darcs_repo_dir");
    for ($i->patches) {
        print $_->date, "\n";         # eg: 1193248123
        print $_->darcs_date, "\n";   # eg: 'Wed Oct 24 10:48:43 PDT 2007'
        print $_->raw_date, "\n";     # eg: '20071024174843'
        print $_->author, "\n";       # eg: 'David Caldwell <david@porkrind.org>'
        print $_->undo, "\n";         # a boolean
        print $_->name, "\n";         # First line of recorded message
        print $_->long, "\n";         # Rest of recorded message (including newlines)
        print $_->hash, "\n";         # eg: '20071024174843-c490e-9dab450fd814405d8391c2cff7a4bce33c6a8234.gz'
        print $_->file, "\n";         # eg: '0000001672-d672e8c18c22cbd4cc8e65fe80a39e68384133083b0f623ae5d57cc563e5630b'
                                      # (Usually found in "_darcs/patches/")
        print $_->raw, "\n";          # The unparsed lines from the inventory for this patch
    }

    # Or, if you want to do it by hand for some reason:
    use Darcs::Inventory::Patch;
    @raw = Darcs::Inventory::read("darcs_repo_dir/_darcs/inventory");
    $patch = Darcs::Inventory::Patch->new($raw[0]);

=cut
