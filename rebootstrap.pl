#!/usr/bin/env perl6
use v6;
use lib 'ext/File__Find/lib/';
use lib 'ext/Shell__Command/lib';
use Shell::Command;
%*ENV<PANDA_SUBMIT_TESTREPORTS>:delete;

sub MAIN(Str :$prefix is copy) {
    # Find old state file
    my ($state-file, $reports-file);
    for grep(*.defined, flat $prefix, %*CUSTOM_LIB<site home>) {
        if "$_/panda/state".IO.e {
            $prefix = ~$_;
            $state-file   = "$_/panda/state";
            $reports-file = "$_/panda/reports.{$*PERL.compiler.version}" if "$_/panda/reports.{$*PERL.compiler.version}".IO.e;
        }
    }

    if not $state-file.defined {
        say "No need to rebootstrap, running normal bootstrap";
        my $prefix_str = $prefix ?? "--prefix=$prefix" !! '';
        shell "$*EXECUTABLE bootstrap.pl $prefix_str";
        exit 0;
    }

    # Save a copy of the old state file to be written *after* bootstrapping again
    my $old-state   = slurp $state-file;
    my $old-reports = slurp $reports-file if $reports-file;

    # Find modules that were installed by request
    # (as opposed to just for dependency resolution)
    my @modules;
    given open($state-file) {
        for .lines() -> $line {
            my ($name, $state) = split /\s/, $line;
            next if $name eq any(<File::Find Shell::Command JSON::Fast panda>);
            if $state eq 'installed' {
                @modules.push: $name;
            }
        }
        .close;
    }

    # Clean old directories, boostrap a fresh panda,
    # and reinstall all manually-installed modules
    rm_f(dir(~$prefix)».grep({$_.basename ~~ /^ \d+ | MANIFEST $/})) if $prefix.IO.d;
    rm_rf "$prefix/lib";
    rm_rf "$prefix/panda";
    my $prefix_str = $prefix ?? "--prefix=$prefix" !! '';
    shell "$*EXECUTABLE bootstrap.pl $prefix_str";
    say "==> Reinstalling @modules[]";
    shell "$*EXECUTABLE bin/panda $prefix_str install @modules[]";

    # Save the backup state file back to $prefix/panda/
    spurt "$state-file.bak", $old-state   if $old-state;
    spurt $reports-file,     $old-reports if $old-reports;
}
