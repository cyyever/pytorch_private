set -eu
git branch -D cyy || true
git push -d origin cyy || true

# branches="build_system_fix fix_pybind fix_leak miscellaneous_fixes ubsan fix_performance msvc_ssize use_dynamic_cast move make_unique dropout_seed cxx20 reference detailed_error"
branches="build_system_fix fix_pybind fix_leak miscellaneous_fixes ubsan fix_performance msvc_ssize use_dynamic_cast move dropout_seed cxx20 detailed_error"
for branch in $branches; do
  echo "rebase ${branch}"
  git checkout ${branch}
  git rebase up/master
  git push --force
  echo "end rebase ${branch}"
done
git checkout -b cyy
for branch in $branches; do
  echo "rebase ${branch}"
  git rebase ${branch}
  echo "end rebase ${branch}"
done
git push --set-upstream origin cyy
