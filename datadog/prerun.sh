#!/usr/bin/env bash

if [ -n "$HEROKU_RELEASE_VERSION" ]; then 
	DD_VERSION=$HEROKU_RELEASE_VERSION
fi
