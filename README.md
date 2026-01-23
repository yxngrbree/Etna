# Etna - Bash Pipeline Orchestrator

Etna is a Bash script that helps run multiple projects in order. It can run project steps, handle retries if a step fails, run projects at the same time, save logs, and send notifications on errors. Etna is useful for automating tasks like building, testing, and deploying projects.

## Features

- Run multiple projects with **dependencies** (projects can wait for others to finish)
- **Retries** for steps that fail
- **Parallel execution** for faster runs
- **Dry-run mode** to test without running commands
- **Step and project logs** with timestamps
- Save progress in **state file** to resume if interrupted
- Send notifications via **Email** or **Slack**
- Show **summary** in terminal after completion
- Configurable with a single **configuration file**

## Installation

Clone the repository:

```bash
git clone https://github.com/yxngrbree/Etna.git
cd etna
chmod +x etna.sh
```

Run Etna normally:
```
./etna.sh
```

Dry-run mode (simulate commands without running):
```
./etna.sh -d

Logs for each project: logs/PROJECT_NAME.log

Summary report: etna_report.log

Progress saved in etna.state to resume interrupted runs
