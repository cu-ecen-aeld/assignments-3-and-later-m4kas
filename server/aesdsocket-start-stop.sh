#!/bin/sh
case "$1" in
    start)
        echo "Starting the aesdsocket server"
        start-stop-daemon -S -n aesdsocket /usr/bin/aesdsocket -- -d
        ;;
    stop)
        echo "Stoping the aesdsocket server"
        start-stop-daemon -K -n aesdsocket
        ;;
    *)
        echo "Usage: $0 {start | stop}"
    exit 1
esac
