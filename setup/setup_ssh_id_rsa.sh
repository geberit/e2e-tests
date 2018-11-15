#!/bin/bash

if [ ! -f ~/.ssh/id_rsa ]
then
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
    cat ~/.ssh/id_rsa.pub
    bash
fi
