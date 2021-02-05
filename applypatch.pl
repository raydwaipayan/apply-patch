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

my $root;
my $python = "python3";
my $clang_format_diff = '';
my $clang_format_opt = '-p1 -i';
my $use_clang_format = 0;
my @patch_files = ();

my @cmd_args = ();
my $orig_branch = '';
my $test_branch = '';
my $start_rev = '';
my $end_rev = '';
my $help = 0;
my $V = '0.1';
my $P = $0;

if (!GetOptions(
		'branch=s' 		=> \$test_branch,
		'root=s'		=> \$root,
		'clang-format-diff=s'	=> \$clang_format_diff,
		'format' 		=> \$use_clang_format,
		'h|help|usage' 		=> \$help,
		)) {
	die "$P: invalid argument - use --help if necessary\n";
}

foreach (@ARGV) {
	push(@cmd_args, $_);
	if ($_ =~ /.*\.patch$/) {
		push(@patch_files, $_);
	}
}

if (scalar @cmd_args == 0 || $help != 0) {
	usage();
	exit 0;
}

my %VCS_cmds_git = (
	"check_apply_patch" => "git apply --check \$patch",
	"apply_patch" => "git am \$patch",
	"apply_diff_patch" => "git apply \$patch",
	"clear_changes" => "git reset --hard",
	"get_diff" => "git diff -U0 --no-color",
	"get_current_branch" => "git rev-parse --abbrev-ref HEAD",
	"get_short_revision" => "git rev-parse --short HEAD",
	"check_branch" => "git show-ref refs/heads/\$branch",
	"switch_branch" => "git checkout \$branch",
	"switch_branch_new" => "git checkout -b \$branch",
	"commit_changes" => "git commit -a --amend --no-edit"
);

sub usage {
	print <<EOT;
usage: $P [options] patchfile
version: $V
Options:
--branch=<branch-name> => test branch name
--format => Use clang format
--clang-format-diff=<s> => clang-format-diff path
--help => show this help information
--root=<root_dir> => root dir location
EOT
}

sub top_of_kernel_tree {
	my ($root) = @_;

	my @tree_check = (
		"COPYING", "CREDITS", "Kbuild", "MAINTAINERS", "Makefile",
		"README", "Documentation", "arch", "include", "drivers",
		"fs", "init", "ipc", "kernel", "lib", "scripts",
	);

	foreach my $check (@tree_check) {
		if (! -e $root . '/' . $check) {
			return 0;
		}
	}
	return 1;
}

sub console_out {
	my ($out) = @_;
	print GREEN . $out . RESET . "\n";
}

sub console_info {
	my ($out) = @_;
	print YELLOW . $out . RESET . "\n";
}

sub console_err {
	my ($out) = @_;
	print RED . $out . RESET . "\n";
}

sub get_cmd_path {
	my $path = `sh -c 'command -v $_[0]'`;
	$path =~ s/\n$//g;
	return $path;
}

sub execute_cmd {
	my ($cmd) = @_;
	my @lines = ();

	my $output = `$cmd`;
	$output =~ s/^\s*//gm;
	@lines = split("\n", $output);

	return @lines;
}

sub git_get_branch {
	my $cmd = $VCS_cmds_git{"get_current_branch"};
	my @lines = execute_cmd($cmd);

	return $lines[0];
}

sub git_get_revision {
	my $cmd = $VCS_cmds_git{"get_short_revision"};
	my @lines = execute_cmd($cmd);

	return $lines[0];
}

sub git_change_branch {
	my ($branch) = @_;
	my @lines = ();
	my $cmd = '';
	
	$cmd = $VCS_cmds_git{"check_branch"};
	$cmd =~ s/(\$\w+)/$1/eeg;
	@lines = execute_cmd($cmd);
	
	if (@lines) {
		$cmd = $VCS_cmds_git{"switch_branch"};
	} else {
		$cmd = $VCS_cmds_git{"switch_branch_new"};
	}

	$cmd =~s/(\$\w+)/$1/eeg;
	console_out($cmd);
	execute_cmd($cmd);
}

sub run_clang_format {
	if (! -e $clang_format_diff) {
		console_err('Error: This script requires clang-format-diff to be installed.');
		exit(2);
	}

	console_out("Running clang-format");
	my $cmd = $VCS_cmds_git{"get_diff"} . " $start_rev..$end_rev | $python $clang_format_diff $clang_format_opt";
	execute_cmd($cmd);

	$cmd = $VCS_cmds_git{"get_diff"} . " > clang-format-fixes.diff";
	my @lines = execute_cmd($cmd);
	console_info("Diff written to clang-format-fixes.diff");

	$cmd = $VCS_cmds_git{"commit_changes"};
	execute_cmd($cmd);
	console_info("Formatted changes committed to $test_branch");

	$cmd = $VCS_cmds_git{"clear_changes"};
	execute_cmd($cmd);
}

sub check_apply {
	my ($patch) = @_;
	my $cmd = $VCS_cmds_git{"check_apply_patch"};
	$cmd =~ s/(\$\w+)/$1/eeg;
	execute_cmd($cmd);
	return 1 if ($? == 0);
	return 0;
}

sub apply {
	my ($patch) = @_;

	# check if patch applies; if not, exit
	if (check_apply($patch)) {
		$start_rev = git_get_revision();
		my $cmd = $VCS_cmds_git{"apply_patch"};
		$cmd =~ s/(\$\w+)/$1/eeg;
		console_out($cmd);
		execute_cmd($cmd);

		$end_rev = git_get_revision();
	}
}

sub get_clang_version {
	my $version = `clang-format --version`;
	$version =~ /version\s*(\d)\./;
	return $1;
}

sub find_clang_format_diff {
	my $clang_format_diff;
	if (get_cmd_path('clang-format-diff.py') ne '') {
		$clang_format_diff = get_cmd_path('clang-format-diff.py');
	}
	elsif (get_cmd_path('clang-format-diff') ne '') {
		$clang_format_diff = get_cmd_path('clang-format-diff');

		# clang-format-diff before version 8, depends on python2
		if (get_clang_version() < 8) {
			$python = "python2";
		}
	}
	return $clang_format_diff;
}

if (defined $root) {
	if (!top_of_kernel_tree($root)) {
		die "$P: $root: --root does not point at a valid tree\n";
	} else {
		if (top_of_kernel_tree('.')) {
			$root = '.';
		}
	}
	if(!defined $root) {
		console_err("Must be run from the top-level dir. of a kernel tree");
		exit(2);
	}
}

if ($clang_format_diff eq '') {
	$clang_format_diff = find_clang_format_diff();
}

$orig_branch = git_get_branch();
if ($test_branch eq '') {
	$test_branch = "test-" . $orig_branch;
}

if ($orig_branch ne $test_branch) {
	git_change_branch($test_branch);
}

my $patch_applies = 1;
foreach my $patch (@patch_files) {
	if (! -e $patch) {
		console_err("Patchfile not found: $patch");
		next;
	}

	apply($patch);

	if ($start_rev eq $end_rev) {
		console_err("Patch apply failed: $patch");
		$patch_applies = 0;
		last;
	} else {
		console_out("Patch applied successfully: $patch");
	}
}

if ($use_clang_format && $patch_applies) {
	run_clang_format();
}

if ($orig_branch ne $test_branch) {
	git_change_branch($orig_branch);
}
