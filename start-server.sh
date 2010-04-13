#!/bin/sh

ruby ./shogi-server --pid-file shogi-server.pid \
                    --daemon . \
                    floodgatetest 4081
#                    --player-log-dir log \
