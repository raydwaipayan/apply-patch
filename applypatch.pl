#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-2.0

use strict;
use warnings;
use POSIX;
use File::Basename;
use Cwd;
use File::Find;
use File::Spec::Functions;
use Term::ANSIColor qw(:constants);
use Getopt::Long qw(:config no_auto_abbrev);

my $root = '../';
my $cur_path = fastgetcwd() . '/';
my $git_clang_format = 'git clang-format';
my $git_clang_format_file = '/usr/bin/git-clang-format';
my $use_clang_format = 0;
my @patch_files = ();
my @cmd_args = ();
my $orig_branch = '';
my $test_branch = '';
my $start_commit = '';
my $end_commit = '';
my $help = 0;
my $V = '0.1';
my $P = $0;

if (!GetOptions(
        'branch=s' => \$test_branch,
        'clang-format' => \$use_clang_format,
        'h|help|usage' => \$help,
        )) {
    die "$P: invalid argument - use --help if necessary\n";
}

foreach (@ARGV) {
    push(@cmd_args, $_);
    if ($_ =~ /.*\.patch$/) {
        push(@patch_files, $_);
    }
}

if (@cmd_args == 0 || $help != 0) {
    usage();
    exit 0;
}

my %VCS_cmds_git = (
    "apply_patch" => "git am \$patch",
    "get_current_branch" => "git branch --show-current",
    "get_short_revision" => "git rev-parse --short HEAD",
    "check_branch" => "git show-ref refs/heads/\$branch",
    "switch_branch" => "git checkout \$branch",
    "switch_branch_new" => "git checkout -b \$branch"
);

sub usage {
    print <<EOT;
usage: $P [options] patchfile
version: $V

Options:
--branch=<branch-name> => test branch name
--help => show this help information
EOT
}

sub git_execute_cmd {
    my ($cmd) = @_;
    my @lines = ();

    my $output = `$cmd`;
    $output =~ s/^\s*//gm;
    @lines = split("\n", $output);

    return @lines;
}

sub git_get_branch {
    my $cmd = $VCS_cmds_git{"get_current_branch"};
    my @lines = git_execute_cmd($cmd);

    return $lines[0];
}

sub git_get_revision {
    my $cmd = $VCS_cmds_git{"get_short_revision"};
    my @lines = git_execute_cmd($cmd);

    return $lines[0];
}

sub git_change_branch {
    my ($branch) = @_;
    my @lines = ();
    my $cmd = '';
    
    $cmd = $VCS_cmds_git{"check_branch"};
    $cmd =~ s/(\$\w+)/$1/eeg;
    @lines = git_execute_cmd($cmd);
    
    if (@lines) {
        $cmd = $VCS_cmds_git{"switch_branch"};
    } else {
        $cmd = $VCS_cmds_git{"switch_branch_new"};
    }
    $cmd =~s/(\$\w+)/$1/eeg;
    console_out($cmd);
    git_execute_cmd($cmd);
}

sub console_out {
    my ($out) = @_;
    print GREEN . $out . RESET . "\n";
}

sub run_clang_format {
    if (! -e $git_clang_format_file) {
        die "$P: clang-format not found\n";
    }
    my $cmd = "$git_clang_format --diff $start_commit..$end_commit";
    console_out($cmd);
    my @lines = git_execute_cmd($cmd);
}

sub apply {
    my @patches = @_;
    $start_commit = git_get_revision();

    foreach (@patches) {
        my $patch = $_;
        my $cmd = $VCS_cmds_git{"apply_patch"};
        $cmd =~ s/(\$\w+)/$1/eeg;
        console_out($cmd);
        git_execute_cmd($cmd);
    }
    $end_commit = git_get_revision();
}

$orig_branch = git_get_branch();
if ($test_branch eq '') {
    $test_branch = "test-" . $orig_branch;
}

git_change_branch($test_branch);

apply(@patch_files);
if ($use_clang_format) {
    run_clang_format();
}

git_change_branch($orig_branch);
