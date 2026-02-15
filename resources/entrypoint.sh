#!/bin/bash
set -e
/usr/local/bin/banner.sh

# Default values
readonly DEFAULT_PUID=1000
readonly DEFAULT_PGID=1000
readonly DEFAULT_PORT=8045
readonly DEFAULT_INTERNAL_PORT=38046
readonly DEFAULT_PROTOCOL="SHTTP"
readonly SAFE_API_KEY_REGEX='^[A-Za-z0-9_:.@+= -]{5,128}$'
readonly FIRST_RUN_FILE="/tmp/first_run_complete"

# Neo4j defaults
readonly DEFAULT_NEO4J_URI="bolt://localhost:7687"
readonly DEFAULT_NEO4J_USERNAME="neo4j"
readonly DEFAULT_NEO4J_PASSWORD=""

# Detect OS type for package manager
detect_os() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

# Function to trim whitespace using parameter expansion
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Validate positive integers
is_positive_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

# Generate HAProxy configuration dynamically
generate_haproxy_config() {
    local config_file="/tmp/haproxy.cfg"
    local template_file="/etc/haproxy/haproxy.cfg.template"
    
    echo "Generating HAProxy configuration..."
    
    # Read template
    if [[ ! -f "$template_file" ]]; then
        echo "Error: HAProxy template not found at $template_file"
        exit 1
    fi
    
    # Generate API key check block
    local api_key_check=""
    if [[ -n "$API_KEY" ]]; then
        # Escape API_KEY for use in HAProxy config (handle special chars)
        local escaped_key="${API_KEY//\\/\\\\}"
        escaped_key="${escaped_key//\"/\\\"}"
        
        api_key_check="    # API Key authentication enabled
    acl auth_header_present var(txn.auth_header) -m found
    acl auth_valid var(txn.auth_header) -m str \"Bearer ${escaped_key}\"
    
    # Deny requests without valid authentication
    http-request deny deny_status 401 content-type \"application/json\" string '{\"error\":\"Unauthorized\",\"message\":\"Valid API key required\"}' if !auth_header_present
    http-request deny deny_status 403 content-type \"application/json\" string '{\"error\":\"Forbidden\",\"message\":\"Invalid API key\"}' if auth_header_present !auth_valid"
    else
        api_key_check="    # API Key authentication disabled - all requests allowed"
    fi
    
    # Replace placeholders in template
    sed -e "s|__PORT__|${PORT}|g" \
        -e "s|__INTERNAL_PORT__|${INTERNAL_PORT}|g" \
        "$template_file" > "$config_file.tmp"
    
    # Replace the API_KEY_CHECK placeholder with the generated block
    # Using awk to handle multi-line replacement
    awk -v replacement="$api_key_check" '
        /__API_KEY_CHECK__/ {
            print replacement
            next
        }
        { print }
    ' "$config_file.tmp" > "$config_file"
    
    rm -f "$config_file.tmp"
    
    echo "HAProxy configuration generated at $config_file"
    return 0
}

# First run handling
handle_first_run() {
    local uid_gid_changed=0

    # Handle PUID/PGID logic
    if [[ -z "$PUID" && -z "$PGID" ]]; then
        PUID="$DEFAULT_PUID"
        PGID="$DEFAULT_PGID"
        echo "PUID and PGID not set. Using defaults: PUID=$PUID, PGID=$PGID"
    elif [[ -n "$PUID" && -z "$PGID" ]]; then
        if is_positive_int "$PUID"; then
            PGID="$PUID"
        else
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    elif [[ -z "$PUID" && -n "$PGID" ]]; then
        if is_positive_int "$PGID"; then
            PUID="$PGID"
        else
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    else
        if ! is_positive_int "$PUID"; then
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
        fi
        
        if ! is_positive_int "$PGID"; then
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PGID="$DEFAULT_PGID"
        fi
    fi

    # Check existing UID/GID conflicts
    local current_user current_group
    current_user=$(id -un "$PUID" 2>/dev/null || true)
    current_group=$(getent group "$PGID" | cut -d: -f1 2>/dev/null || true)

    [[ -n "$current_user" && "$current_user" != "node" ]] &&
        echo "Warning: UID $PUID already in use by $current_user - may cause permission issues"

    [[ -n "$current_group" && "$current_group" != "node" ]] &&
        echo "Warning: GID $PGID already in use by $current_group - may cause permission issues"

    # Modify UID/GID if needed
    if [ "$(id -u node)" -ne "$PUID" ]; then
        if usermod -o -u "$PUID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change UID to $PUID. Using existing UID $(id -u node)"
            PUID=$(id -u node)
        fi
    fi

    if [ "$(id -g node)" -ne "$PGID" ]; then
        if groupmod -o -g "$PGID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change GID to $PGID. Using existing GID $(id -g node)"
            PGID=$(id -g node)
        fi
    fi

    [ "$uid_gid_changed" -eq 1 ] && echo "Updated UID/GID to PUID=$PUID, PGID=$PGID"
    touch "$FIRST_RUN_FILE"
}

# Validate and set PORT
validate_port() {
    PORT=${PORT:-$DEFAULT_PORT}
    
    if ! is_positive_int "$PORT"; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    elif [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    fi
    
    if [ "$PORT" -lt 1024 ] && [ "$(id -u)" -ne 0 ]; then
        echo "Warning: Port $PORT is privileged and might require root"
    fi
}

# Validate and set API_KEY (optional for CodeGraphContext)
validate_api_key() {
    if [[ -n "$API_KEY" ]]; then
        if [[ "$API_KEY" =~ $SAFE_API_KEY_REGEX ]]; then
            [[ "$API_KEY" =~ ^(password|secret|admin|token|key|test|demo)$ ]] &&
                echo "Warning: API_KEY is using a common value - consider more complex key"
            # Export for HAProxy to use
            export API_KEY
        else
            echo "Invalid API_KEY. Must be 5-128 chars with safe symbols. Ignoring API_KEY."
            unset API_KEY
        fi
    else
        unset API_KEY
    fi
}

# Validate Neo4j configuration
validate_neo4j_config() {
    NEO4J_URI=${NEO4J_URI:-$DEFAULT_NEO4J_URI}
    NEO4J_USERNAME=${NEO4J_USERNAME:-$DEFAULT_NEO4J_USERNAME}
    NEO4J_PASSWORD=${NEO4J_PASSWORD:-$DEFAULT_NEO4J_PASSWORD}

    # Validate URI format
    if [[ ! "$NEO4J_URI" =~ ^(bolt|neo4j|bolt\+s|neo4j\+s|bolt\+ssc|neo4j\+ssc)://.*$ ]]; then
        echo "Warning: Invalid NEO4J_URI format. Using default: $DEFAULT_NEO4J_URI"
        NEO4J_URI="$DEFAULT_NEO4J_URI"
    fi

    # Check if Neo4j credentials are provided
    if [[ -z "$NEO4J_PASSWORD" ]]; then
        echo "WARNING: NEO4J_PASSWORD not set. CodeGraphContext requires Neo4j database connection."
        echo "Please provide NEO4J_URI, NEO4J_USERNAME, and NEO4J_PASSWORD environment variables."
    fi

    # Export Neo4j environment variables for cgc
    export NEO4J_URI
    export NEO4J_USERNAME
    export NEO4J_PASSWORD
}

# Validate CORS patterns
validate_cors() {
    CORS_ARGS=()
    ALLOW_ALL_CORS=false
    local cors_value

    if [[ -n "${CORS}" ]]; then
        IFS=',' read -ra CORS_VALUES <<< "$CORS"
        for cors_value in "${CORS_VALUES[@]}"; do
            cors_value=$(trim "$cors_value")
            [[ -z "$cors_value" ]] && continue

            if [[ "$cors_value" =~ ^(all|\*)$ ]]; then
                ALLOW_ALL_CORS=true
                CORS_ARGS=(--cors)
                echo "Caution! CORS allowing all origins - security risk in production!"
                break
            elif [[ "$cors_value" =~ ^/.*/$ ]] ||
                 [[ "$cors_value" =~ ^https?:// ]] ||
                 [[ "$cors_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]+)?$ ]]
            then
                CORS_ARGS+=(--cors "$cors_value")
            else
                echo "Warning: Invalid CORS pattern '$cors_value' - skipping"
            fi
        done
    fi
}

# Start HAProxy with dynamically generated configuration
start_haproxy() {
    echo "Starting HAProxy on port $PORT..."
    
    # Display authentication status
    if [[ -n "$API_KEY" ]]; then
        echo "API_KEY authentication ENABLED via HAProxy"
    else
        echo "API_KEY authentication DISABLED - all requests will be forwarded"
    fi
    
    # Validate HAProxy config
    if ! haproxy -c -f /tmp/haproxy.cfg 2>&1; then
        echo "Error: Invalid HAProxy configuration"
        cat /tmp/haproxy.cfg
        exit 1
    fi
    
    # Start HAProxy in background as root (needed for port binding)
    haproxy -f /tmp/haproxy.cfg &
    HAPROXY_PID=$!
    
    # Wait a moment for HAProxy to start
    sleep 2
    
    if ! kill -0 $HAPROXY_PID 2>/dev/null; then
        echo "Error: HAProxy failed to start"
        exit 1
    fi
    
    echo "HAProxy started successfully (PID: $HAPROXY_PID)"
}

# Main execution
main() {
    # Trim all input parameters
    [[ -n "${PUID:-}" ]] && PUID=$(trim "$PUID")
    [[ -n "${PGID:-}" ]] && PGID=$(trim "$PGID")
    [[ -n "${PORT:-}" ]] && PORT=$(trim "$PORT")
    [[ -n "${API_KEY:-}" ]] && API_KEY=$(trim "$API_KEY")
    [[ -n "${PROTOCOL:-}" ]] && PROTOCOL=$(trim "$PROTOCOL")
    [[ -n "${CORS:-}" ]] && CORS=$(trim "$CORS")
    [[ -n "${NEO4J_URI:-}" ]] && NEO4J_URI=$(trim "$NEO4J_URI")
    [[ -n "${NEO4J_USERNAME:-}" ]] && NEO4J_USERNAME=$(trim "$NEO4J_USERNAME")
    [[ -n "${NEO4J_PASSWORD:-}" ]] && NEO4J_PASSWORD=$(trim "$NEO4J_PASSWORD")

    # Validate configurations FIRST (before first run handling)
    validate_port
    validate_api_key
    validate_neo4j_config
    validate_cors

    # Set INTERNAL_PORT early so it's available for config generation
    INTERNAL_PORT=$DEFAULT_INTERNAL_PORT

    # First run handling (now with all variables set)
    if [[ ! -f "$FIRST_RUN_FILE" ]]; then
        handle_first_run
    fi

    # Generate HAProxy config (with all variables now defined)
    if ! generate_haproxy_config; then
        echo "Error: Failed to generate HAProxy configuration"
        exit 1
    fi

    # Build MCP server command - cgc mcp start for CodeGraphContext
    MCP_SERVER_CMD="/opt/venv/bin/cgc mcp start"

    # Protocol selection
    local PROTOCOL_UPPER=${PROTOCOL:-$DEFAULT_PROTOCOL}
    PROTOCOL_UPPER=${PROTOCOL_UPPER^^}

    case "$PROTOCOL_UPPER" in
        "SHTTP"|"STREAMABLEHTTP")
            CMD_ARGS=(npx --yes supergateway --port "$INTERNAL_PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
        "SSE")
            CMD_ARGS=(npx --yes supergateway --port "$INTERNAL_PORT" --ssePath /sse --outputTransport sse "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SSE/Server-Sent Events"
            ;;
        "WS"|"WEBSOCKET")
            CMD_ARGS=(npx --yes supergateway --port "$INTERNAL_PORT" --messagePath /message --outputTransport ws "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="WS/WebSocket"
            ;;
        *)
            echo "Invalid PROTOCOL: '$PROTOCOL'. Using default: $DEFAULT_PROTOCOL"
            CMD_ARGS=(npx --yes supergateway --port "$INTERNAL_PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
    esac

    # Detect OS type
    OS_TYPE=$(detect_os)

    # Debug mode handling
    case "${DEBUG_MODE:-}" in
        [1YyTt]*|[Oo][Nn]|[Yy][Ee][Ss]|[Ee][Nn][Aa][Bb][Ll][Ee]*)
            echo "DEBUG MODE: Installing nano and pausing container"
            case "$OS_TYPE" in
                debian)
                    apt-get update && apt-get install -y nano 2>/dev/null || echo "Warning: Failed to install nano"
                    ;;
                alpine)
                    apk add --no-cache nano 2>/dev/null || echo "Warning: Failed to install nano"
                    ;;
                *)
                    echo "Warning: Unknown OS type, cannot install nano"
                    ;;
            esac
            echo "Container paused for debugging. Exec into container to investigate."
            exec tail -f /dev/null
            ;;
        *)
            # Normal execution
            echo "Launching CodeGraphContext MCP Server with protocol: $PROTOCOL_DISPLAY"
            echo "External port: $PORT (via HAProxy). *** Use this port to connect to this MCP server. ***"
            echo "Internal port: $INTERNAL_PORT (MCP server)"
            echo "Neo4j Connection: $NEO4J_URI (user: $NEO4J_USERNAME)"
            
            # Check for required commands
            if ! command -v /opt/venv/bin/cgc &>/dev/null; then
                echo "Error: cgc command not available. CodeGraphContext may not be properly installed."
                exit 1
            fi

            if ! command -v npx &>/dev/null; then
                echo "Error: npx not available. Cannot start supergateway."
                exit 1
            fi

            if ! command -v haproxy &>/dev/null; then
                echo "Error: haproxy not available. Cannot start reverse proxy."
                exit 1
            fi

            # Verify Neo4j connection before starting (optional but recommended)
            if command -v python3 &>/dev/null && [[ -n "$NEO4J_PASSWORD" ]]; then
                echo "Verifying Neo4j connection..."
                python3 -c "
from neo4j import GraphDatabase
import sys
import os
try:
    driver = GraphDatabase.driver(
        os.environ['NEO4J_URI'],
        auth=(os.environ['NEO4J_USERNAME'], os.environ['NEO4J_PASSWORD'])
    )
    driver.verify_connectivity()
    driver.close()
    print('Neo4j connection verified successfully')
except Exception as e:
    print(f'Warning: Neo4j connection check failed: {e}', file=sys.stderr)
    print('Continuing anyway - cgc will handle connection errors', file=sys.stderr)
" || echo "Neo4j verification skipped or failed - continuing anyway"
            fi

            # Start HAProxy first (runs as root)
            start_haproxy

            # Execute MCP server with appropriate user switching
            if [ "$(id -u)" -eq 0 ]; then
                # Detect which command is available
                if command -v gosu &>/dev/null; then
                    exec gosu node "${CMD_ARGS[@]}"
                elif command -v su-exec &>/dev/null; then
                    exec su-exec node "${CMD_ARGS[@]}"
                else
                    echo "Error: Neither gosu nor su-exec found. Cannot drop privileges."
                    exit 1
                fi
            else
                exec "${CMD_ARGS[@]}"
            fi
            ;;
    esac
}

# Run the script with error handling
if main "$@"; then
    exit 0
else
    exit 1
fi