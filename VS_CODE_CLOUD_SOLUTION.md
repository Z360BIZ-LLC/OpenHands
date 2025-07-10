# OpenHands Cloud VS Code Integration - Complete Solution

## Problem Summary
Originally, VS Code integration only worked locally because:
1. VS Code server ran on a different port than OpenHands main app
2. Cross-origin cookie blocking prevented authentication
3. No session-specific workspaces
4. New sessions required manual configuration

## Solution Overview
The complete solution provides:
1. **Automatic proxy configuration** for ALL new sessions
2. **Session-specific workspaces** for file isolation
3. **Cloud-accessible URLs** for both VS Code and applications
4. **Zero manual intervention** required for new sessions

## Architecture

### Cloud Runtime (`openhands/runtime/impl/cloud/cloud_runtime.py`)
- Extends LocalRuntime with cloud-specific features
- Generates session-specific URLs: `https://openhands.zikrainfotech.com/vscode/{session_id}/`
- Creates isolated workspaces: `/home/ubuntu/openhands-workspace`
- Manages application URLs: `https://openhands.zikrainfotech.com/apps/{session_id}-{index}/`

### Nginx Configuration Generator (`/usr/local/bin/nginx-config-generator.sh`)
- **Key Fix**: Includes proper proxy headers for VS Code
- **Critical Headers**:
  - `proxy_set_header X-Forwarded-Path /vscode/{session_id}/;`
  - `proxy_set_header X-Original-URI $request_uri;`
- Automatically regenerates configuration for each new session
- Handles both VS Code and application proxying

### VS Code Plugin (`openhands/runtime/plugins/vscode/__init__.py`)
- Modified to allow `ubuntu` user (cloud environment)
- Properly starts VS Code server for each session
- Integrates with cloud runtime for URL generation

## How It Works for New Sessions

### 1. Session Creation
When a new session starts:
- Cloud runtime creates session-specific workspace directory
- Session metadata stored in `/tmp/openhands-sessions/{session_id}.json`
- Includes VS Code port and application ports

### 2. Nginx Configuration
The nginx generator script:
- Reads all session files from `/tmp/openhands-sessions/`
- Generates proxy configuration for each session
- **Includes proper VS Code headers** (the key fix!)
- Reloads nginx configuration automatically

### 3. VS Code Integration
For each session:
- VS Code server starts on session-specific port
- Nginx proxies requests to correct VS Code instance
- Headers prevent redirect loops back to OpenHands
- Each session gets isolated workspace

### 4. Application URLs
Applications in each session:
- Get cloud-accessible URLs automatically
- Proxied through nginx with session isolation
- No localhost URLs in cloud environment

## Files Modified/Created

### Core Files
- `openhands/runtime/impl/cloud/cloud_runtime.py` - Cloud runtime implementation
- `openhands/runtime/__init__.py` - Runtime registration
- `openhands/runtime/plugins/vscode/__init__.py` - VS Code plugin fixes

### Configuration Files
- `~/.openhands_env` - Environment configuration
- `/usr/local/bin/nginx-config-generator.sh` - Nginx proxy generator

### Fix Scripts (from this session)
- `fix_nginx_generator.sh` - Fixes nginx generator for ALL sessions
- `verify_cloud_runtime.sh` - Verifies complete setup

## Key Technical Details

### The Critical Fix
The main issue was nginx proxy configurations missing these headers:
```nginx
proxy_set_header X-Forwarded-Path /vscode/{session_id}/;
proxy_set_header X-Original-URI $request_uri;
```

Without these headers:
1. VS Code server receives requests without path context
2. VS Code redirects to root path
3. User sees OpenHands interface instead of VS Code

With these headers:
1. VS Code server knows it's behind a proxy
2. VS Code serves proper interface
3. Users see actual VS Code IDE

### Session Isolation
Each session gets:
- Unique workspace directory
- Separate VS Code server instance
- Individual nginx proxy configuration
- Isolated application URLs

## Running the Fix

### On the VM, run:
```bash
# Upload and run the fix script
chmod +x fix_nginx_generator.sh
./fix_nginx_generator.sh

# Verify everything is configured correctly
chmod +x verify_cloud_runtime.sh
./verify_cloud_runtime.sh

# Start OpenHands with cloud runtime
source ~/.openhands_env && python3 -m openhands.core.main
```

## Result

After running the fix:
- ✅ ALL new sessions automatically get proper VS Code configuration
- ✅ No manual intervention required for new sessions
- ✅ Session-specific workspaces work correctly
- ✅ Cloud URLs work for both VS Code and applications
- ✅ Cross-origin cookie issues completely resolved

## Testing

To verify the fix works:
1. Start OpenHands server
2. Create a new session
3. Click on VS Code tab
4. Should see actual VS Code interface (not OpenHands)
5. Files should appear in session-specific workspace
6. No redirect loops or authentication issues

## Maintenance

The solution is self-maintaining:
- New sessions automatically get proper configuration
- Nginx configuration regenerated automatically
- Session cleanup happens automatically
- No manual steps required for new sessions

This solution ensures that VS Code integration works seamlessly for all users creating new sessions on the cloud deployment.
