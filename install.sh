#!/bin/bash

# Rename and move staging.sh file to /usr/bin/staging 
sudo cp staging.sh /usr/bin/staging 

# Make the NucleiFuzzer file executable
sudo chmod u+x /usr/binstaging 

echo "NucleiFuzzer has been installed successfully! Now Enter the command 'nf' to run the tool."
