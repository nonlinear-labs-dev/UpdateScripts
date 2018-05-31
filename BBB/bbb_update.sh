#!/bin/sh

version=`date +"%Y-%m-%d-%H-%M"`

chmod +x /update/BBB/playground/playground
cp -r /update/BBB/playground /nonlinear/playground-$version
ln -sf /nonlinear/playground-$version /nonlinear/playground
