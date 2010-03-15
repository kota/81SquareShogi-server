#!/bin/sh

ruby ./shogi-server --pid-file shogi-server.pid \
                    --daemon . \
                    --player-log-dir log \
                    floodgatetest 4081
