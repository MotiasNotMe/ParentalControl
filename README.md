# ParentalControl
Powershell script for user time limits written by DeepseekAI
## Functions of restriction
- Of a specific user
- Of operating mode (supporting 12\24h)
- Of daily usage minutes
## Configuration
Edit ParentalControl.ps1 with Notepad 
``` powershell
$targetUserName = "User" # Replace with username
$allowedTimeStart = "9:30"    # 9:30 AM (format: HH:mm)
$allowedTimeEnd = "22:15"     # 10:15 PM (format: HH:mm)
$maxDailyUsageMinutes = 120 # 2 hours
```
