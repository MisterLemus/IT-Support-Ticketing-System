# KB-003: Network Connectivity
## Quick Fix (run in order)
```cmd
ipconfig /flushdns
ipconfig /release && ipconfig /renew
netsh winsock reset
netsh int ip reset
```
## OSI Approach
1. Physical: cable, WiFi, airplane mode
2. Network: ping 127.0.0.1 → gateway → 8.8.8.8
3. DNS: nslookup google.com → change to 8.8.8.8
4. App: proxy settings, firewall
