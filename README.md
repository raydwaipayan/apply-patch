apply-patch
-----------

The applypatch script can automatically apply patches into a
test branch and run clang-format on the patch context.

### What it does?

- Formats the changes made to the files according to clang-format
- Makes the formatted changes in test branch (or branch value given to `--branch` option)
- Creates corresponding `.clang-format-fixes.diff` files, which shows the changes with respect to patch that are to be made according to clang-format for all the patches in patch series.<br/>
For eg, `patchfile1.clang-format-fixes.diff`

### How it works?

- Takes all the input patchfile(s) separated by spaces
- Formats the changes made according to clang-format and commits it to `test-{current_branch_name}`, if `--branch` is empty. Otherwise to the branch specified by the option.
- The original branch remains unchanged
- Formatted changes are made to the test branch, only if `--format` option is used. Else, the original changes are commited to the test branch, same as the patch.
- The diff with respect to original individual patches and clang-formatted patches are stored in `patchfile.clang-format-fixes.diff`. This step will take place, only if `--format` option is used to clang-format the patches.

### Pre-requisite(s) for this script:

- This script requires `clang-format-diff` to be installed on the user's system.
- The patchfile should be applicable to the recent state of the branch. If one of the patches in the patch series does not apply, all the patches after it are skipped.

### Steps to use the script:

- Copy this script in `scripts/` directory

- Run `perl ./scripts/applypatch.pl --format {patchfile1} {patchfile2} {patchfile3}` and so on... (replace 'patchfile1/2/3' with your corresponding patchfile).<br/>
- This will format the changes made using clang-format and apply it on top of a new branch("test-{your_current_branch}").<br/>
- For applying unformatted patch series, as is, just drop `--format` option from the above command.
You can provide your own branch name using `--branch={branch_name}` option.

### Steps to test the script:

- There are 2 patches provided in `test_patches` directory. These patches are just for testing purpose.
- Copy `applypatch.pl` script in `scripts/` directory
- Copy `test_patches` in root directory
- Run `perl scripts/applypatch.pl test_patches/*.patch --format` from the root directory
- This will create formatted changes on the test branch, and create `.clang-format-fixes.diff` files for individual patches.
