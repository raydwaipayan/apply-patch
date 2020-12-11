apply-patch
-----------

The applypatch script can automatically apply patches into a
test branch and run clang-format on the patch context.

### Steps to run the script:

- Copy this script in `scripts/` directory

- Run `perl ./scripts/applypatch.pl --clang-format {patchfile}` (replace 'patchfile' with your patchfile).<br/>
- This will format the changes made using clang-format and apply it on top of a new branch("test-{your_current_branch}").<br/>
You can provide your own branch name using `--branch={branch_name}` option.
- Also a modified patchfile will be created alongside your pathfile with suffix `.EXPERIMENTAL-clang_format-fixes`.

### Pre-requisite for this script:

- The patchfile should be applicable to the recent state of the branch.
- This script is dependent on `clang-format-8` to function properly.<br/>
Any version less than 8 is dependent on python2 and the latest Terminals(atleast for Ubuntu 18.04) are dependent on python3. So changing Python version for running the script may not be a great option.
