# Optional media preparation

These utilities are for maintainers regenerating media. Installation does not execute Python or need these packages.

Use a Python virtual environment and install requirements.txt. Build-DragonContinuity.py reads media/startup.mp4 and writes temporary candidates to qa/; review the motion and copy qa/continuity-continuous.mp4 to media/continuity.mp4 when satisfied. Optimize-DragonWallpaper.py accepts input/output paths; use `--help` for its options. The source artwork used before optimization is not included; the current deployable MP4 is in themes/dragon/.

After replacing distributed media, check licenses, update package-manifest.json with scripts/Update-Manifest.ps1, and rerun package tests/build. Requirements pin the PyAV major interface used by the remux step; other Python environments have not been validated by the normal Windows installer checks.
