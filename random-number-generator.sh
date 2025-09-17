#!/bin/bash

line_numbers=20

for ((i=1; $i <= $line_numbers; i++))
do
        line_numbers=$(($RANDOM % 7))
        j=1
        while [ $j -le $numbers ]
        do
                echo -n $RANDOM >> file.txt
                echo -n ' ' >> file.txt
                j=$(($j+1))
        done
        echo >> file.txt

done
