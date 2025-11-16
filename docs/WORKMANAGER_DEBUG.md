# WorkManager Debuging LOGCAT

## Android

### Job Scheduler Inspection

Use ADB to inspect Android's job scheduler:

```bash
# View scheduled jobs
adb shell dumpsys jobscheduler | grep yourapp

# View detailed job info
adb shell dumpsys jobscheduler yourapp

# Force run job (debug only)
adb shell cmd jobscheduler run -f yourapp JOB_ID
```

### Monitor Job Execution

```bash
# Monitor WorkManager logs
adb logcat | grep WorkManager

# Monitor app background execution
adb logcat | grep "yourapp"
```

### Debug Commands

```bash
# Check if your app is whitelisted from battery optimization
adb shell dumpsys deviceidle whitelist

# Check battery optimization status
adb shell settings get global battery_saver_constants

# Force device into idle mode (testing)
adb shell dumpsys deviceidle force-idle
```
