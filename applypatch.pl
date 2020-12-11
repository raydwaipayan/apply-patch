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
my $clang_format_diff = 'clang-format-diff-8 -p1 -i';
my $clang_format_diff_file = '/usr/bin/clang-format-diff-8';
my $use_clang_format = 0;
# my @patch_files = ();

# replacing array of patchfiles with only one patchfile, as most probably only one patchfile might be run to get the modified diff
# Ofcourse, it can be extended for multiple patchfiles as well, just multiple modified patches will be created
my $patchfile;

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
		# push(@patch_files, $_);
                $patchfile = $_;
	}
}

if (scalar @cmd_args == 0 || $help != 0) {
	usage();
	exit 0;
}

my %VCS_cmds_git = (
	"apply_patch" => "git am \$patch",
	"get_current_branch" => "git rev-parse --abbrev-ref HEAD",
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

sub install_clang_format {
        print <<EOT;
clang-format-diff-8 not found
You can install it using:
apt-get install clang-format-diff-8
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
	if (! -e $clang_format_diff_file) {
		die "$P: ". install_clang_format();
	}
        my $cmd = `cat $patchfile | $clang_format_diff`;
        $cmd = `git add -u`;
        $cmd = `git commit --amend --no-edit`;
	my $tmp_patch = `git format-patch -o /tmp/clang-format-diff HEAD~1`;
	$tmp_patch =~ s/\s*$//;
	my $new_patchfile = "$patchfile.EXPERIMENTAL-clang_format-fixes";
	$cmd = `cp $tmp_patch $new_patchfile`; # creates clang-format modified diff
	console_out("Clang formatted patchfile generated at: $new_patchfile");
}

sub apply {
	my ($patchfile) = @_;
	my $cmd = $VCS_cmds_git{"apply_patch"} . $patchfile;
	console_out($cmd);
	git_execute_cmd($cmd);
}

$orig_branch = git_get_branch();
if ($test_branch eq '') {
	$test_branch = "test-" . $orig_branch;
}

git_change_branch($test_branch);

apply($patchfile);
if ($use_clang_format) {
	run_clang_format();
}

git_change_branch($orig_branch);
