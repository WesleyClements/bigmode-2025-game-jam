#!/bin/bash

platform=linux

while getopts ":p:" option; do
   case $option in
      p) 
        extension_path=$OPTARG
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

scons platform=$platform custom_api_file=$extension_path bits=64