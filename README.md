# HP iLO4 Quiet Fan Script With Watchdog

This is a no-Docker helper for HP Gen8/Gen9 servers with patched iLO 4 fan
commands. It combines the quiet fan/sensor tuning commands with a temperature
watchdog that reads iLO's JSON temperature endpoint.

The example is configured for one server. To manage more patched iLO4-family
servers, add more records to `HP_SERVERS`:

```bash
HP_SERVERS=(
  "server-a|192.0.2.10|22|Administrator|change-me"
  "server-b|192.0.2.11|22|Administrator|change-me"
)
```

Use this only on hardware you can monitor and recover physically. The fan
control commands are unofficial and require patched iLO 4 firmware.

Suggested cron:

```cron
*/5 * * * * /usr/bin/flock -n /tmp/hp-ilo4-watchdog.lock /path/hp-ilo4-quiet-watchdog.sh watchdog >/dev/null 2>&1
*/30 * * * * /usr/bin/flock -n /tmp/hp-ilo4-full.lock /path/hp-ilo4-quiet-watchdog.sh full >/dev/null 2>&1
```
