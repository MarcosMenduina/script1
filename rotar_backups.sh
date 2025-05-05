#!/bin/bash

BACKUP_DIR="/var/backups/mensuales"
ARCHIVO="/var/backups/mensuales_$(date +%Y-%m).tar"

# Crear el directorio si no existe
mkdir -p "$BACKUP_DIR"

# Crear archivo mensual de backups
tar -cvf $ARCHIVO $BACKUP_DIR/*.tar

# Borrar backups con más de 1 año
find $BACKUP_DIR -name "mensuales_*.tar" -mtime +365 -delete

# Configurar logrotate
cat <<EOF > /etc/logrotate.d/backup_archives
$ARCHIVE {
    monthly
    rotate 12
    missingok
    notifempty
    copytruncate
}
EOF

# Ejecutar logrotate
logrotate -f /etc/logrotate.d/backup_archives
