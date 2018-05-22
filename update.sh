#!/bin/bash
git config --global push.default simple
git add -A
git commit -m "update"
git push origin -u
