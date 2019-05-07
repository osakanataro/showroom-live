#!/bin/bash

FLAG=0

while [ $FLAG -ne 1 ];
do
  ./showroom-live.ps1 -roomurl "https://www.showroom-live.com/ringo-005" -output -outdir /mnt/work/ringo
done
