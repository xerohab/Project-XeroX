#!/usr/bin/env bash

xerox_service_validate()
{
    case "${SERVICE_MODE:-}" in
        systemd)
            [ -n "${SERVICE_NAME:-}" ] || {
                xerox_die "SERVICE_NAME required for systemd"
                return 1
            }

            if ! systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
                xerox_die "Configured systemd service does not exist: $SERVICE_NAME"
                return 1
            fi
            ;;

        pm2)
            [ -n "${SERVICE_NAME:-}" ] || {
                xerox_die "SERVICE_NAME required for pm2"
                return 1
            }

            command -v pm2 >/dev/null 2>&1 || {
                xerox_die "pm2 unavailable"
                return 1
            }

            if ! pm2 describe "$SERVICE_NAME" >/dev/null 2>&1; then
                xerox_die "Configured PM2 service does not exist: $SERVICE_NAME"
                return 1
            fi
            ;;

        supervisor)
            [ -n "${SERVICE_NAME:-}" ] || {
                xerox_die "SERVICE_NAME required for supervisor"
                return 1
            }

            command -v supervisorctl >/dev/null 2>&1 || {
                xerox_die "supervisorctl unavailable"
                return 1
            }

            if ! supervisorctl status "$SERVICE_NAME" >/dev/null 2>&1; then
                xerox_die "Configured supervisor service does not exist: $SERVICE_NAME"
                return 1
            fi
            ;;

        none)
            [ "${ALLOW_NO_SERVICE_RESTART:-0}" = "1" ] || {
                xerox_die "SERVICE_MODE=none requires ALLOW_NO_SERVICE_RESTART=1"
                return 1
            }
            ;;

        *)
            xerox_die "SERVICE_MODE must explicitly be systemd, pm2, supervisor or none"
            return 1
            ;;
    esac
}

xerox_service_stop()
{
    xerox_service_validate || return 1

    case "$SERVICE_MODE" in
        systemd)
            systemctl stop "$SERVICE_NAME"
            ;;
        pm2)
            pm2 stop "$SERVICE_NAME"
            ;;
        supervisor)
            supervisorctl stop "$SERVICE_NAME"
            ;;
        none)
            echo "SERVICE STOP: explicitly disabled by destination profile"
            ;;
    esac
}

xerox_service_start()
{
    xerox_service_validate || return 1

    case "$SERVICE_MODE" in
        systemd)
            systemctl start "$SERVICE_NAME"
            systemctl is-active --quiet "$SERVICE_NAME"
            ;;
        pm2)
            pm2 start "$SERVICE_NAME"
            pm2 describe "$SERVICE_NAME" >/dev/null
            ;;
        supervisor)
            supervisorctl start "$SERVICE_NAME"
            supervisorctl status "$SERVICE_NAME" |
                grep -q 'RUNNING'
            ;;
        none)
            echo "SERVICE START: explicitly disabled by destination profile"
            ;;
    esac
}
