#!/bin/bash

# Find and remove old backup files older than 30 days
find /mnt/pihole_backups -maxdepth 1 -name "pi-hole-*" -type f -mtime +30 -delete

echo "Job complete at $(date)"
