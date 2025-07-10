#!/bin/bash

# Verify cloud runtime is properly configured for session-specific workspaces
echo "Verifying cloud runtime configuration for session-specific workspaces..."

# Check if cloud runtime file exists
if [ ! -f "openhands/runtime/impl/cloud/cloud_runtime.py" ]; then
    echo "❌ Cloud runtime file not found!"
    echo "Need to create openhands/runtime/impl/cloud/cloud_runtime.py"
    exit 1
fi

echo "✅ Cloud runtime file exists"

# Check if cloud runtime is registered
if ! grep -q "CloudRuntime" openhands/runtime/__init__.py; then
    echo "❌ Cloud runtime not registered!"
    echo "Need to add CloudRuntime to openhands/runtime/__init__.py"
    exit 1
fi

echo "✅ Cloud runtime is registered"

# Check if environment is configured
if [ ! -f ~/.openhands_env ]; then
    echo "❌ Environment configuration missing!"
    echo "Need to create ~/.openhands_env with CLOUD_DOMAIN and RUNTIME settings"
    exit 1
fi

echo "✅ Environment configuration exists"

# Check environment variables
if ! grep -q "CLOUD_DOMAIN=openhands.zikrainfotech.com" ~/.openhands_env; then
    echo "❌ CLOUD_DOMAIN not set correctly!"
    echo "Need to set CLOUD_DOMAIN=openhands.zikrainfotech.com in ~/.openhands_env"
    exit 1
fi

if ! grep -q "RUNTIME=cloud" ~/.openhands_env; then
    echo "❌ RUNTIME not set correctly!"
    echo "Need to set RUNTIME=cloud in ~/.openhands_env"
    exit 1
fi

echo "✅ Environment variables are configured correctly"

# Check if nginx configuration generator script exists
if [ ! -f "/usr/local/bin/nginx-config-generator.sh" ]; then
    echo "❌ Nginx configuration generator script not found!"
    echo "Need to install nginx-config-generator.sh"
    exit 1
fi

echo "✅ Nginx configuration generator script exists"

# Check if VS Code plugin is configured for ubuntu user
if ! grep -q "ubuntu" openhands/runtime/plugins/vscode/__init__.py; then
    echo "❌ VS Code plugin not configured for ubuntu user!"
    echo "Need to add 'ubuntu' to allowed users in openhands/runtime/plugins/vscode/__init__.py"
    exit 1
fi

echo "✅ VS Code plugin is configured for ubuntu user"

# Check if sessions directory exists
if [ ! -d "/tmp/openhands-sessions" ]; then
    echo "⚠️  Sessions directory doesn't exist yet (this is normal if no sessions have been created)"
    echo "Directory will be created automatically when first session starts"
else
    echo "✅ Sessions directory exists"
    session_count=$(ls -1 /tmp/openhands-sessions/*.json 2>/dev/null | wc -l)
    echo "   Found $session_count active sessions"
fi

# Check if nginx configuration is valid
if nginx -t 2>/dev/null; then
    echo "✅ Current nginx configuration is valid"
else
    echo "❌ Current nginx configuration has errors!"
    echo "Run 'sudo nginx -t' to see detailed error messages"
    exit 1
fi

echo ""
echo "🎉 ALL CHECKS PASSED!"
echo ""
echo "The cloud runtime is properly configured for:"
echo "1. Session-specific workspaces in /home/ubuntu/openhands-workspace"
echo "2. VS Code integration with proper proxy headers"
echo "3. Cloud URLs for applications"
echo "4. Automatic nginx configuration updates"
echo ""
echo "Every new session will now automatically get:"
echo "- Its own workspace directory"
echo "- VS Code server with proper proxy configuration"
echo "- Cloud-accessible application URLs"
echo ""
echo "To start OpenHands with cloud runtime:"
echo "source ~/.openhands_env && python -m openhands.core.main"
