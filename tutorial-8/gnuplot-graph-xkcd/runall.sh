#!/bin/bash

# Distribution Plots
for F in distribution-*.gp; do 
	echo "Plotting $F ..."
	gnuplot $F
done

