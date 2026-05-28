#!/usr/bin/env python3
import json
import os
import time
from datetime import datetime

CALENDAR_FILE = os.path.expanduser("~/.config/hypr/scripts/quickshell/calendar/schedule/schedule.json")
SCRIPTS_DIR = os.path.expanduser("~/.config/hypr/scripts/")

def get_calendar_context():
    try:
        with open(CALENDAR_FILE, 'r') as f:
            data = json.load(f)
        
        now = time.time()
        today = datetime.now().date()
        
        events = []
        for item in data.get('lessons', []):
            if item.get('type') == 'class' and 'start' in item:
                # Check if event is today
                event_date = datetime.fromtimestamp(item['start']).date()
                if event_date == today:
                    time_str = item.get('time', 'Unknown time')
                    subject = item.get('subject', 'Unknown subject')
                    events.append(f"- {time_str}: {subject}")
        
        if not events:
            return "No scheduled events for today."
        return "\n".join(events)
    except Exception as e:
        return f"Could not read calendar: {e}"

def get_scripts_context():
    try:
        scripts = []
        for f in sorted(os.listdir(SCRIPTS_DIR)):
            if f.endswith('.sh') or f.endswith('.py'):
                scripts.append(f)
        return "\n".join([f"- {s}" for s in scripts])
    except Exception as e:
        return f"Could not list scripts: {e}"

if __name__ == "__main__":
    calendar = get_calendar_context()
    scripts = get_scripts_context()
    
    context = f"""
<system_state>
<calendar_today>
{calendar}

(AI Note: If you see an activity like 'Tidur' split into 00:00-05:15 and 22:15-00:00, this simply means the user sleeps from 22:15 at night until 05:15 the next morning. Explain it naturally as ONE overnight routine, do NOT say they have "two sleep sessions today".)
</calendar_today>

<available_tools>
The user has the following executable scripts in ~/.config/hypr/scripts/. You cannot run them directly yet, but you can suggest or discuss them:
{scripts}
</available_tools>
</system_state>
"""
    print(context.strip())
