set -eu
git branch -D cyy || true
git push -d origin cyy || true

# branches="build_system_fix miscellaneous_fixes ubsan fix_performance msvc_ssize use_dynamic_cast cxx20 detailed_error fixwarning various_fix cpp17 fix_gil_bug"
# branches="build_system_fix use_dynamic_cast detailed_error fix_gil_bug"
# branches="fix_gil_bug"
# for branch in $branches; do
#   echo "rebase ${branch}"
#   git branch -D ${branch} || true
#   git checkout ${branch}
#   git rebase up/viable/strict
#   git push --force
#   echo "end rebase ${branch}"
# done
git checkout -b cyy
# for branch in $branches; do
#   echo "rebase ${branch}"
#   git rebase ${branch}
#   echo "end rebase ${branch}"
# done
git push --set-upstream origin cyy
