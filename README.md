apply-patch
-----------

The applypatch script can automatically apply patches into a
test branch and run clang-format on the patch context.

### What it does?

- Formats the changes made to the files according to clang-format
- Makes the formatted changes in test branch (or branch value given to `--branch` option)
- Creates a clang-format-fixes.diff file, which shows the changes with respect to patch that are to be made according to clang-format. Currently, it stores diff wrt only last commit. It has to be modified as mentioned in the ToDo below.

### How it works?

- Takes all the input patchfile(s) separated by spaces
- Formats the changes made according to clang-format and commits it to `test-{current_branch_name}`, if `--branch` is empty. Otherwise to the branch specified by the option.
- The original branch remains unchanged
- Formatted changes are made to the test branch

### Steps to use the script:

- Copy this script in `scripts/` directory

- Run `perl ./scripts/applypatch.pl --format {patchfile1} {patchfile2} {patchfile3}` and so on... (replace 'patchfile1/2/3' with your corresponding patchfile).<br/>
- This will format the changes made using clang-format and apply it on top of a new branch("test-{your_current_branch}").<br/>
You can provide your own branch name using `--branch={branch_name}` option.
- A single diff with the changes made by last commit will be created clang-formatted at `clang-format-fixes.diff`

### Steps to test the script:

- There are 2 patches provided in `test_patches` directory. These patches are just for testing purpose.
- Copy `applypatch.pl` script in `scripts/` directory
- Copy `test_patches` in root directory
- Run `perl scripts/applypatch.pl ./test_patches/*.patch --format` from the root directory

### Todo:
- For each patch, create corresponding diff.

### Pre-requisite for this script:

- The patchfile should be applicable to the recent state of the branch.
- This script is dependent on `clang-format-diff` to function properly.<br/>
