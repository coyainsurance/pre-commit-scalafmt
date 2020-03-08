#!/usr/bin/env bash

set -e

BOOTSTRAP_DIR="$HOME/.scalafmt"
SCALAFMT_VERSION="1.4.0"
SCALAFMT_ORG="com.geirsson"
SERVER=1
SERVER_PORT="${NAILGUN_PORT:-2113}"
CONFIG=".scalafmt.conf"
TEST=1

OPTIND=1
while getopts "c:d:o:p:stv:" opt; do
	case $opt in
		c)
			CONFIG=$OPTARG
			;;
		d)
			BOOTSTRAP_DIR=$OPTARG
			;;
		o)
			SCALAFMT_ORG=$OPTARG
			;;
		p)
			SERVER=0
			SERVER_PORT=$OPTARG
			;;
		s)
			SERVER=0
			;;
		t)
			TEST=0
			;;
		v)
			SCALAFMT_VERSION=$OPTARG
			;;
		\?)
			exit 1
			;;
	esac
done
shift $((OPTIND - 1))

function cmd_not_exists() {
	if [[ $(command -v $1) ]]; then
		return 1
	else
		return 0
	fi
}

function version_neq() {
	if [[ $($1 --version | cut -d' ' -f2) != "$SCALAFMT_VERSION" ]]; then
		return 0
	else
		return 1
	fi
}

function is_server() {
	return $SERVER
}

function should_bootstrap() {
	if is_server; then
		(cmd_not_exists "scalafmt_ng" \
			&& cmd_not_exists "$BOOTSTRAP_DIR/$SCALAFMT_VERSION/scalafmt_ng") \
			|| version_neq "ng --nailgun-port $SERVER_PORT scalafmt"
	else
		(cmd_not_exists "scalafmt" || version_neq "scalafmt") \
			&& (cmd_not_exists "$BOOTSTRAP_DIR/$SCALAFMT_VERSION/scalafmt" \
				|| version_neq "$BOOTSTRAP_DIR/$SCALAFMT_VERSION/scalafmt")
	fi
}

function test_only() {
	return $TEST
}

function server_running() {
	lsof -ti tcp:$SERVER_PORT -sTCP:LISTEN >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		return 0
	else
		return 1
	fi
}

function wait_for_server() {
	end=$((SECONDS + 3))

	while [ $SECONDS -lt $end ]; do
		if server_running; then
			break
		fi
		sleep 0.25
	done
}

function kill_server() {
	local lsof_res
	if lsof_res=$(lsof -ti tcp:$SERVER_PORT -sTCP:LISTEN); then
		kill -9 $lsof_res
	fi
}

function start_server() {
	$1 $SERVER_PORT >/dev/null 2>&1 &
	wait_for_server
	ng --nailgun-port $SERVER_PORT ng-alias scalafmt org.scalafmt.cli.Cli
}

# bootstrap scalafmt if needed
if should_bootstrap; then
	mkdir -p "$BOOTSTRAP_DIR/$SCALAFMT_VERSION"

	if cmd_not_exists "coursier" && cmd_not_exists "$BOOTSTRAP_DIR/coursier"; then
		curl -L -o "$BOOTSTRAP_DIR/coursier" https://git.io/vgvpD && chmod +x "$BOOTSTRAP_DIR/coursier" >/dev/null
	fi

	if cmd_not_exists "coursier"; then
		COURSIER_CMD="$BOOTSTRAP_DIR/coursier"
	else
		COURSIER_CMD="coursier"
	fi

	if is_server; then
		$COURSIER_CMD bootstrap -f \
			--standalone "$SCALAFMT_ORG:scalafmt-cli_2.12:$SCALAFMT_VERSION" \
			--main com.martiansoftware.nailgun.NGServer \
			-o "$BOOTSTRAP_DIR/$SCALAFMT_VERSION/scalafmt_ng" >/dev/null
	else
		$COURSIER_CMD bootstrap -f \
			--standalone "$SCALAFMT_ORG:scalafmt-cli_2.12:$SCALAFMT_VERSION" \
			--main org.scalafmt.cli.Cli \
			-o "$BOOTSTRAP_DIR/$SCALAFMT_VERSION/scalafmt" >/dev/null
	fi
fi

# set proper command and start server if in server mode
if is_server; then
	SCALAFMT_CMD="ng --nailgun-port $SERVER_PORT scalafmt"

	if cmd_not_exists "scalafmt_ng"; then
		SERVER_CMD="$BOOTSTRAP_DIR/$SCALAFMT_VERSION/scalafmt_ng"
	else
		SERVER_CMD="scalafmt_ng"
	fi

	if version_neq "$SCALAFMT_CMD"; then
		kill_server
	fi
	if ! server_running; then
		start_server $SERVER_CMD >/dev/null
	fi
else
	if cmd_not_exists "scalafmt"; then
		SCALAFMT_CMD="$BOOTSTRAP_DIR/$SCALAFMT_VERSION/scalafmt"
	else
		SCALAFMT_CMD="scalafmt"
	fi
fi

# format passed files
if test_only; then
	$SCALAFMT_CMD --test -c $CONFIG "$@" >/dev/null
else
	$SCALAFMT_CMD -c $CONFIG "$@" >/dev/null
fi
