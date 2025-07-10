#!/bin/bash

# Fix nginx generator script to include proper VS Code proxy headers
# This ensures ALL new sessions automatically get proper VS Code configuration

echo "Fixing nginx generator script to include proper VS Code proxy headers..."

# Create the fixed nginx generator script
cat > /tmp/nginx-config-generator-fixed.sh << 'EOF'
#!/bin/bash

NGINX_CONFIG="/etc/nginx/sites-available/openhands"
SESSIONS_DIR="/tmp/openhands-sessions"

# Create sessions directory if it doesn't exist
mkdir -p "$SESSIONS_DIR"

# Start nginx configuration
cat > "$NGINX_CONFIG" << 'NGINX_EOF'
server {
    listen 80;
    server_name openhands.zikrainfotech.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name openhands.zikrainfotech.com;

    ssl_certificate /etc/letsencrypt/live/openhands.zikrainfotech.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/openhands.zikrainfotech.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;

    # Main OpenHands app
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }

    # WebSocket endpoint
    location /ws {
        proxy_pass http://localhost:3000/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

NGINX_EOF

# Add session-specific configurations
session_count=0
for session_file in "$SESSIONS_DIR"/*.json; do
    if [ -f "$session_file" ]; then
        session_id=$(basename "$session_file" .json)

        # Extract ports from session file with validation
        vscode_port=$(python3 -c "
import json
import sys
try:
    with open('$session_file', 'r') as f:
        data = json.load(f)
    port = data.get('vscode_port', 8080)
    if port and port > 0:
        print(port)
    else:
        print(8080)
except Exception as e:
    print(8080)
" 2>/dev/null)

        # Validate port
        if [ -z "$vscode_port" ] || [ "$vscode_port" -lt 1 ] || [ "$vscode_port" -gt 65535 ]; then
            vscode_port=8080
        fi

        # Add VS Code configuration for this session WITH PROPER PROXY HEADERS
        cat >> "$NGINX_CONFIG" << NGINX_EOF

    # VS Code for session $session_id
    location /vscode/$session_id/ {
        proxy_pass http://localhost:$vscode_port/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Path /vscode/$session_id/;
        proxy_set_header X-Original-URI \$request_uri;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
NGINX_EOF

        # Add app configurations for this session
        app_ports=$(python3 -c "
import json
try:
    with open('$session_file', 'r') as f:
        data = json.load(f)
    ports = data.get('app_ports', [8081, 8082])
    for i, port in enumerate(ports):
        if port and port > 0:
            print(f'{i}:{port}')
except:
    print('0:8081')
    print('1:8082')
" 2>/dev/null)

        if [ -n "$app_ports" ]; then
            echo "$app_ports" | while IFS=':' read -r index port; do
                if [ -n "$port" ] && [ "$port" -gt 0 ] && [ "$port" -lt 65536 ]; then
                    cat >> "$NGINX_CONFIG" << NGINX_EOF

    # App $index for session $session_id
    location /apps/$session_id-$index/ {
        proxy_pass http://localhost:$port/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
NGINX_EOF
                fi
            done
        fi

        ((session_count++))
    fi
done

# Close server block
cat >> "$NGINX_CONFIG" << 'NGINX_EOF'
}
NGINX_EOF

# Test nginx configuration before reloading
if nginx -t 2>/dev/null; then
    systemctl reload nginx
    echo "Nginx configuration updated successfully with $session_count sessions"
else
    echo "Nginx configuration test failed, not reloading"
    nginx -t
fi
EOF

# Make the script executable
chmod +x /tmp/nginx-config-generator-fixed.sh

# Create backup of original
sudo cp /usr/local/bin/nginx-config-generator.sh /usr/local/bin/nginx-config-generator.sh.backup

# Replace the original with the fixed version
sudo cp /tmp/nginx-config-generator-fixed.sh /usr/local/bin/nginx-config-generator.sh
sudo chmod +x /usr/local/bin/nginx-config-generator.sh

echo "Fixed nginx generator script has been installed!"
echo "The key change is the addition of these headers for VS Code:"
echo "  proxy_set_header X-Forwarded-Path /vscode/SESSION_ID/;"
echo "  proxy_set_header X-Original-URI \$request_uri;"
echo ""
echo "Now regenerating nginx configuration..."
sudo /usr/local/bin/nginx-config-generator.sh

echo ""
echo "✅ ALL DONE! Now every new session will automatically get proper VS Code proxy headers."
echo "This means VS Code will work correctly in all new sessions without manual intervention."
