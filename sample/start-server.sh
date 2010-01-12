#!/bin/sh

ruby ./shogi-server --pid-file shogi-server.pid \
                    --daemon . \
                    --player-log-dir player-log-dir \
                    floodgatetest 4000
