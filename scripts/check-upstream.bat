@echo off
REM Check how far your fork is from upstream (ayman708-UX/PlayTorrioV3)
REM Usage: scripts\check-upstream.bat

echo === Your branch ===
git branch --show-current
echo.
echo === Your commits ahead of upstream ===
git rev-list --left-right --count upstream/main...HEAD 2>nul | findstr /R "^[0-9]*[ ]*[0-9]*$" || echo "(run git fetch upstream first)"
echo.
echo === Upstream commits you don't have ===
git log --format="%%h %%s" upstream/main --not --main 2>nul | head -5 || echo "(run git fetch upstream first)"
echo.
echo === Latest upstream tag ===
git ls-remote --tags upstream 2>nul | findstr /R "v[0-9]+\.[0-9]+\.[0-9]+" | tail -1 || echo "(run git fetch upstream first)"
echo.
echo === Your latest tag ===
git describe --tags --abbrev=0 2>nul || echo "No local tag"
echo.
echo === Remotes ===
git remote -v
