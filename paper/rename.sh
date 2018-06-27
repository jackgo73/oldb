#!/bin/bash

find . -name "* *" | while read filename
do
  ns=$(echo $filename | tr ' ' '_')
  mv "$filename" $ns
done
