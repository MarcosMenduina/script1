#!/bin/bash

# Ruta del archivo fijo que se rotará
BACKUP_DIR="/var/backups"
ARCHIVE_DIR="$BACKUP_DIR/mensuales"
ARCHIVO_FIJO="$ARCHIVE_DIR/backup-mensual.tar"

mkdir -p "$ARCHIVE_DIR"

# Sobrescribe el anterior (porque logrotate lo rotará)
tar -cf "$ARCHIVO_FIJO" $(find "$BACKUP_DIR" -type f -name "*.tar.bz2" -newermt "$(date +%Y-%m-01)" ! -newermt "$(date -d 'next month' +%Y-%m-01)")

# Ejecutar logrotate para rotar ese archivo
logrotate -f /etc/logrotate.d/backup-mensual

