#!/bin/bash
helm uninstall antmedia 
rm *.tgz
helm package $(pwd)/.
